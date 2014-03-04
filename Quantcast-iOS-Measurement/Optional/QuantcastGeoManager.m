/*
 * © Copyright 2012-2014 Quantcast Corp.
 *
 * This software is licensed under the Quantcast Mobile App Measurement Terms of Service
 * https://www.quantcast.com/learning-center/quantcast-terms/mobile-app-measurement-tos
 * (the “License”). You may not use this file unless (1) you sign up for an account at
 * https://www.quantcast.com and click your agreement to the License and (2) are in
 * compliance with the License. See the License for the specific language governing
 * permissions and limitations under the License. Unauthorized use of this file constitutes
 * copyright infringement and violation of law.
 */

#if !__has_feature(objc_arc)
#error "Quantcast Measurement is designed to be used with ARC. Please turn on ARC or add '-fobjc-arc' to this file's compiler flags"
#endif // !__has_feature(objc_arc)

#import "QuantcastParameters.h"

#if QCMEASUREMENT_ENABLE_GEOMEASUREMENT

#import "QuantcastGeoManager.h"
#import "QuantcastEvent.h"
#import "QuantcastPolicy.h"
#import "QuantcastUtils.h"

#define GEOTIMER_START_WAIT_TIME_SECONDS 60*10
#define GEOTIMER_MAX_DETAILED_MEASURE_SECONDS 60*1
#define GEOTIMER_STANDOFF_FACTOR 2.0
#define MAX_DETAILED_MEASURE_ATTEMPTS 4
#define DESIRED_LOCATION_ACCURACY kCLLocationAccuracyNearestTenMeters
#define GENERATE_YESNO_STR( x ) x ? @"YES" : @"NO"

@interface QuantcastGeoManager () {
    BOOL _geoLocationEnabled;
}
@property (unsafe_unretained,nonatomic) id<QuantcastEventLogger> eventLogger;
@property (strong,nonatomic) CLLocationManager* locationManager;
@property (strong,nonatomic) CLGeocoder* geocoder;
@property (strong,nonatomic) NSOperationQueue* opQueue;
@property (strong,nonatomic) NSTimer* locationMeasurementTimer;
@property (assign,nonatomic) NSTimeInterval detailedGeoMeasureWaitInterval;
@property (strong,nonatomic) CLLocation* lastLocationProcessed;
@property (assign,nonatomic) NSUInteger detailedMeasurementUpdateCount;
@property (assign,nonatomic) BOOL detailedGeoMeasureInProgress;

-(void)startGeoMonitoring;
-(void)stopGeoMonitoring;

-(void)restartDetailedGeoMeasurementTimerWithResetTimerInterval:(BOOL)inResetTimerInterval;
-(void)invalidateActiveLocationMeasurementTimer;
-(void)detailedGeoMeasureTimerAction:(NSTimer*)inTimer;
-(void)startLocationMeasurement;

-(void)generateGeoEventWithLocation:(CLLocation*)inLocation isAppInBackground:(BOOL)inIsAppInBackground;
-(void)processGeoEventWithLocation:(CLLocation*)inLocation placemark:(NSArray*)inPlacemarkList isAppInBackground:(BOOL)inIsAppInBackground;
-(void)recordGeoEventWithCountry:(NSString*)inCountry province:(NSString*)inProvince city:(NSString*)inCity timestamp:(NSDate*)inTimestamp isAppInBackground:(BOOL)inIsAppInBackground;

@end

@implementation QuantcastGeoManager

-(id)initWithEventLogger:(id<QuantcastEventLogger>)inEventLogger{
    
    self = [super init];
    if (nil != self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppPause) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppResume) name:UIApplicationWillEnterForegroundNotification object:nil];
        _eventLogger = inEventLogger;
        _detailedGeoMeasureWaitInterval = GEOTIMER_START_WAIT_TIME_SECONDS;
        _detailedMeasurementUpdateCount = 0;
        _geoLocationEnabled = NO;
    }
    
    return self;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self invalidateActiveLocationMeasurementTimer];
    
    _eventLogger = nil;
    
    [_opQueue cancelAllOperations];
    
}

-(void)privacyPolicyUpdate:(NSNotification*)inNotification {
    if ( nil != self.eventLogger && nil != self.eventLogger.policy ) {
        [self stopGeoMonitoring];
        [self startGeoMonitoring];
    }
}


-(void)startGeoMonitoring {
    if ( self.geoLocationEnabled ) {
        if (nil == self.locationManager) {
            self.locationManager = [[CLLocationManager alloc] init];
            self.locationManager.delegate = self;
            self.locationManager.desiredAccuracy = self.eventLogger.policy.desiredGeoLocationAccuracy;
            self.locationManager.distanceFilter = self.eventLogger.policy.geoMeasurementUpdateDistance;
        }
        
        if ( nil == self.opQueue ) {
            self.opQueue = [[NSOperationQueue alloc] init];
            self.opQueue.maxConcurrentOperationCount = 1;
            [self.opQueue setName:@"com.quantcast.measure.operationsqueue.geomanager"];
        }
        
       QUANTCAST_LOG(@"Enabling geo-monitoring." );
        
        if ( ( ![CLLocationManager significantLocationChangeMonitoringAvailable] ) && [UIApplication sharedApplication].applicationState != UIApplicationStateBackground ) {
            [self startLocationMeasurement];
        }
        else if ( [CLLocationManager significantLocationChangeMonitoringAvailable] ) {
            [self.locationManager startMonitoringSignificantLocationChanges];
        }
        else {
           QUANTCAST_LOG(@"Could not start geo measurement due to configuration: significantLocationChangeMonitoringAvailable = %@, UIApplicationStateBackground = %@", GENERATE_YESNO_STR( [CLLocationManager significantLocationChangeMonitoringAvailable] ), GENERATE_YESNO_STR( [UIApplication sharedApplication].applicationState == UIApplicationStateBackground ) );
        }
    }
    else if (_geoLocationEnabled && self.eventLogger.isOptedOut ) {
       QUANTCAST_LOG(@"Geo measurement was requested but not enabled due to user opt out.");
    }
    else if (_geoLocationEnabled && !self.eventLogger.policy.allowGeoMeasurement && self.eventLogger.policy.hasPolicyBeenLoaded ) {
       QUANTCAST_LOG(@"Geo measurement was requested but not enabled due to the current privacy policy for this app.");
    }
}

-(void)stopGeoMonitoring {
    
    if (nil != self.locationManager ) {
       QUANTCAST_LOG(@"QC Measurement: Disabling geo-monitoring.");
        [self invalidateActiveLocationMeasurementTimer];
        [self.locationManager stopUpdatingLocation];
        
        if ([CLLocationManager significantLocationChangeMonitoringAvailable]) {
            [self.locationManager stopMonitoringSignificantLocationChanges];
        }
        self.detailedGeoMeasureInProgress = NO;
        self.detailedMeasurementUpdateCount = 0;
        self.lastLocationProcessed = nil;
        
        self.locationManager = nil;
    }
  
}

-(void)setGeoLocationEnabled:(BOOL)inGeoLocationEnabled {
    
    Class geoCoderClass = NSClassFromString(@"CLGeocoder");
    
    if ( nil != geoCoderClass ) {
        _geoLocationEnabled = inGeoLocationEnabled;
        
        if ( _geoLocationEnabled ) {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(privacyPolicyUpdate:) name:QUANTCAST_NOTIFICATION_POLICYLOAD object:nil];
            [self startGeoMonitoring];
        }
        else {
            [[NSNotificationCenter defaultCenter] removeObserver:self];
            [self stopGeoMonitoring];
        }
    }
}

-(BOOL)geoLocationEnabled {    
    if ( [[CLLocationManager class] respondsToSelector:@selector(authorizationStatus)] ) {
        CLAuthorizationStatus authStatus = [CLLocationManager authorizationStatus];

        return _geoLocationEnabled && self.eventLogger.policy.allowGeoMeasurement && !self.eventLogger.isOptedOut && [CLLocationManager locationServicesEnabled] && ( authStatus == kCLAuthorizationStatusNotDetermined || authStatus == kCLAuthorizationStatusAuthorized );
    }
    return NO;
}


-(void)handleAppPause {    
    if ( self.isGeoMonitoringActive ) {
        [self stopGeoMonitoring];
    }
}

-(void)handleAppResume {
    if ( self.geoLocationEnabled ) {        
        [self startGeoMonitoring];
    }
}

-(BOOL)isGeoMonitoringActive {
    return nil != self.locationManager;
}
#pragma mark - Detailed Geo Measurement

-(void)restartDetailedGeoMeasurementTimerWithResetTimerInterval:(BOOL)inResetTimerInterval {
    [self invalidateActiveLocationMeasurementTimer];

    if ( self.detailedGeoMeasureInProgress  ) {
       QUANTCAST_LOG(@"QC Measurement: Detailed geo-measurement has been taken. Returning geo-measurement to monitoring significant changes.");
        
        [self.locationManager stopUpdatingLocation];
        self.detailedGeoMeasureInProgress = NO;
        if ( [CLLocationManager significantLocationChangeMonitoringAvailable] ) {
            [self.locationManager startMonitoringSignificantLocationChanges];
        }
    }
    
    // detailed measurement has been taken, restart timer and monitor for signficant changes
    if ( inResetTimerInterval ) {
        self.detailedGeoMeasureWaitInterval = GEOTIMER_START_WAIT_TIME_SECONDS;
    }
    else {
        self.detailedGeoMeasureWaitInterval *= GEOTIMER_STANDOFF_FACTOR;
    }
    
    if ( self.detailedGeoMeasureWaitInterval < GEOTIMER_START_WAIT_TIME_SECONDS ) {
        self.detailedGeoMeasureWaitInterval = GEOTIMER_START_WAIT_TIME_SECONDS;
    }
    
    if ( [UIApplication sharedApplication].applicationState != UIApplicationStateBackground ) {
        self.locationMeasurementTimer = [NSTimer scheduledTimerWithTimeInterval:self.detailedGeoMeasureWaitInterval
                                                                        target:self
                                                                      selector:@selector(detailedGeoMeasureTimerAction:)
                                                                      userInfo:nil
                                                                       repeats:NO];
       QUANTCAST_LOG(@"QC Measurement: Starting detailed geo-measurement timer with a wait time of %.0f seconds. Fire date = %@", self.detailedGeoMeasureWaitInterval, [self.locationMeasurementTimer.fireDate description]);
    }
}

-(void)invalidateActiveLocationMeasurementTimer {
    if (nil != self.locationMeasurementTimer ) {
        [self.locationMeasurementTimer invalidate];
        self.locationMeasurementTimer = nil;
    }
}

-(void)detailedGeoMeasureTimerAction:(NSTimer*)inTimer {
    self.locationMeasurementTimer = nil;
   QUANTCAST_LOG(@"Detailed geo measurement timer fired. Starting a detailed geo-measurement" );
    [self startLocationMeasurement];
}

-(void)startLocationMeasurement {
    if ( self.geoLocationEnabled && [UIApplication sharedApplication].applicationState != UIApplicationStateBackground ) {
         
        if ( [CLLocationManager significantLocationChangeMonitoringAvailable] ) {
            [self.locationManager stopMonitoringSignificantLocationChanges];
        }
        
        self.detailedGeoMeasureInProgress = YES;
        self.detailedMeasurementUpdateCount = 0;
        [self.locationManager startUpdatingLocation];
        
        self.locationMeasurementTimer = [NSTimer scheduledTimerWithTimeInterval:GEOTIMER_MAX_DETAILED_MEASURE_SECONDS
                                                                        target:self
                                                                      selector:@selector(stopDetailedGeoMeasureTimerAction:)
                                                                      userInfo:nil
                                                                       repeats:NO];
    }    
}

-(void)stopDetailedGeoMeasureTimerAction:(NSTimer*)innTimer {
    self.locationMeasurementTimer = nil;
   QUANTCAST_LOG(@"Max time passed while in detailed geo measurement. Returning geo-measurement to monitoring significant changes." );
    [self restartDetailedGeoMeasurementTimerWithResetTimerInterval:YES];
}

#pragma mark - CLLocationManagerDelegate

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
#pragma clang diagnostic pop
{
    // pre-iOS 6 version of this method
    
    NSArray* locationList = [NSArray arrayWithObject:newLocation];
    
    [self locationManager:manager didUpdateLocations:locationList];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    if ([locations count] == 0 ) {
        QUANTCAST_WARN( @"locationManager:didUpdateLocations: Got a zero-lengthed locations list. Doing nothing");
        return;
    }
    
    BOOL isAppInBackground = [UIApplication sharedApplication].applicationState == UIApplicationStateBackground;

    for (CLLocation* location in locations ) {
        [self generateGeoEventWithLocation:location isAppInBackground:isAppInBackground];
    }

    if ( self.detailedGeoMeasureInProgress ) {
        BOOL signficantDistanceTraveled = YES;
        
        CLLocation* mostRecentLocation = [locations lastObject];

        if ( nil != self.lastLocationProcessed  ) {
            CLLocationDistance distance = [mostRecentLocation distanceFromLocation:self.lastLocationProcessed];
            
            if ( distance < self.eventLogger.policy.geoMeasurementUpdateDistance ) {
                signficantDistanceTraveled = NO;
            }
        }
        
        self.detailedMeasurementUpdateCount += locations.count;
        
        if ( self.detailedMeasurementUpdateCount < MAX_DETAILED_MEASURE_ATTEMPTS && mostRecentLocation.horizontalAccuracy > self.eventLogger.policy.desiredGeoLocationAccuracy ) {
            // don't stop detailed measurement nor restart timer
           QUANTCAST_LOG(@"Continuing with detailed geo measurments. Measure count = %lu, measure accuracy = %f", (unsigned long)self.detailedMeasurementUpdateCount, mostRecentLocation.horizontalAccuracy );
        }
        else {
            // only change the lastLocationProcessed if moved significant distance
            if ( signficantDistanceTraveled ) {
                self.lastLocationProcessed = mostRecentLocation;
            }
            
            [self restartDetailedGeoMeasurementTimerWithResetTimerInterval:signficantDistanceTraveled];
        }
    }
}

-(void)generateGeoEventWithLocation:(CLLocation*)inLocation isAppInBackground:(BOOL)inIsAppInBackground {
    if (nil == self.geocoder ) {
        self.geocoder = [[CLGeocoder alloc] init];
    }
    
    [self.opQueue addOperationWithBlock:^{
        if ( nil != self.geocoder ) {
            // wait for geo-coding to be done
            while (  self.geocoder.geocoding ) {
                [NSThread sleepForTimeInterval:1];
            }
            
            [self.geocoder reverseGeocodeLocation:inLocation
                                completionHandler:^(NSArray* inPlacemarkList, NSError* inError) {
                                    if ( nil != inError ) {
                                        [self.eventLogger logSDKError:QC_SDKERRORTYPE_GEOCODERFAILURE withError:inError errorParameter:[inLocation description]];
                                    }
                                    
                                    [self processGeoEventWithLocation:inLocation placemark:inPlacemarkList isAppInBackground:inIsAppInBackground];
                                } ];
        }
        
    } ];
    
    
}

-(void)processGeoEventWithLocation:(CLLocation*)inLocation placemark:(NSArray*)inPlacemarkList isAppInBackground:(BOOL)inIsAppInBackground {
    if ( self.geoLocationEnabled) {
        NSString* geoCountry = nil;
        NSString* geoProvince = nil;
        NSString* geoCity = nil;
        
        if ( nil != inPlacemarkList && inPlacemarkList.count > 0 ) {
            CLPlacemark* placemark = (CLPlacemark*)[inPlacemarkList objectAtIndex:0];
            
            geoCountry = [placemark country];
            geoProvince = [placemark administrativeArea];
            geoCity = [placemark locality];
            
        }
        else {
            // nothing of interest has occured. skip creating an event.
            return;
        }
        
       QUANTCAST_LOG(@"QC Measurement: Logging location event = %@, with country = %@, province = %@, city = %@", inLocation, geoCountry, geoProvince, geoCity );
        
        [self recordGeoEventWithCountry:geoCountry
                               province:geoProvince
                                   city:geoCity
                              timestamp:inLocation.timestamp
                      isAppInBackground:inIsAppInBackground];
    }
}

-(void)recordGeoEventWithCountry:(NSString*)inCountry province:(NSString*)inProvince city:(NSString*)inCity timestamp:(NSDate*)inTimestamp isAppInBackground:(BOOL)inIsAppInBackground {
    
    [self.eventLogger launchOnQuantcastThread:^(NSDate *unusedTimestamp) {
        // first check to ensure optout hasn't changed
        if ( self.geoLocationEnabled) {
            QuantcastEvent* e = [QuantcastEvent geolocationEventWithCountry:inCountry
                                                                   province:inProvince
                                                                       city:inCity
                                                             eventTimestamp:inTimestamp
                                                          appIsInBackground:inIsAppInBackground
                                                              withSessionID:self.eventLogger.currentSessionID
                                                       applicationInstallID:self.eventLogger.appInstallIdentifier];
            
            [self.eventLogger recordEvent:e];
        }
    }];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
   QUANTCAST_LOG(@"The location manager failed with error = %@", error );
}


@end

#endif
