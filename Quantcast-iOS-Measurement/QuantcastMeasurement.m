/*
 * © Copyright 2012-2017 Quantcast Corp.
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

#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <AdSupport/AdSupport.h>
#import <ifaddrs.h>
#import <sys/socket.h>
#import <netdb.h>
#import <arpa/inet.h>
#import <WebKit/WebKit.h>
#import "QuantcastMeasurement.h"
#import "QuantcastMeasurement+Internal.h"
#import "QuantcastParameters.h"
#import "QuantcastDataManager.h"
#import "QuantcastEvent.h"
#import "QuantcastUtils.h"
#import "QuantcastPolicy.h"
#import "QuantcastOptOutViewController.h"
#import "QuantcastNetworkReachability.h"
#import "QuantcastOptOutDelegate.h"

@interface QuantcastMeasurement () <QuantcastNetworkReachability> {
    WKWebView* agentWebView;
    NSOperationQueue* _quantcastQueue;
    UIBackgroundTaskIdentifier _backgroundTaskID;
    
    SCNetworkReachabilityRef _reachability;
    QuantcastNetworkStatus _currentReachability;
    QuantcastPolicy* _policy;
    
    BOOL _geoLocationEnabled;
    
    BOOL _isOptedOut;
    
    id<NSObject> _networkLabels;
    
    QuantcastDataManager* _dataManager;

    BOOL _appIsDeclaredDirectedAtChildren;
    CTTelephonyNetworkInfo* _telephoneInfo;
    BOOL _usesOneStep;
    
    NSUInteger _uploadEventCount;
    
    id<NSObject> _internalSDKAppLabels;
    id<NSObject> _internalSDKNetworkLabels;
}

@property (strong, nonatomic) NSString* quantcastAPIKey;
@property (strong, nonatomic) NSString* quantcastNetworkPCode;
@property (strong, nonatomic) NSString* cachedAppInstallIdentifier;
@property (strong, nonatomic) NSString* hashedUserId;
@property (readonly) NSOperationQueue* quantcastQueue;

+(BOOL)isOptedOutStatus;

-(NSString*)appInstallIdentifierWithUserAdvertisingPreference:(BOOL)inAdvertisingTrackingEnabled;
-(BOOL)hasUserAdvertisingPrefChangeWithCurrentPref:(BOOL)inCurrentPref;

-(void)enableDataUploading;
-(void)recordEvent:(QuantcastEvent*)inEvent;

-(void)logUploadLatency:(NSUInteger)inLatencyMilliseconds forUploadId:(NSString*)inUploadID;
-(void)logSDKError:(NSString*)inSDKErrorType withError:(NSError*)inErrorOrNil errorParameter:(NSString*)inErrorParametOrNil;


-(void)setOptOutStatus:(BOOL)inOptOutStatus;
+(BOOL)validateQuantcastAPIKey:(NSString*)inQuantcastAppId quantcastNetworkPCode:(NSString*)inQuantcastNetworkPCode;

-(void)logNetworkReachability;
-(BOOL)startReachabilityNotifier;
-(void)stopReachabilityNotifier;

@end

@implementation QuantcastMeasurement
@synthesize currentSessionID;

+(QuantcastMeasurement*)sharedInstance {
    static dispatch_once_t pred;
    static QuantcastMeasurement* gSharedInstance = nil;
    dispatch_once(&pred, ^{
        gSharedInstance = [[QuantcastMeasurement alloc] init];
    });
    
    return gSharedInstance;
}

-(id)init {
    self = [super init];
    if (self) {
        
        [self checkInitalAdPref];
        [self moveCacheDirectoryIfNeeded];
        
        _currentReachability = QuantcastUnknownReachable;
        _backgroundTaskID = UIBackgroundTaskInvalid;
        _quantcastQueue = [[NSOperationQueue alloc] init];
        //operation count needs to be 1 to ensure event task synchronization
        _quantcastQueue.maxConcurrentOperationCount = 1;
        _quantcastQueue.name = @"com.quantcast.measure.eventQueue";
        [_quantcastQueue addObserver:self forKeyPath:@"operationCount" options:0 context:NULL];
        
        _appIsDeclaredDirectedAtChildren = NO;
        _cachedAppInstallIdentifier = nil;
        
        // the first thing to do is determine user opt-out status, as that will guide everything else.
        _isOptedOut = [QuantcastMeasurement isOptedOutStatus];
        if (_isOptedOut) {
            [self setOptOutCookie:YES];
        }
        
        Class telephonyClass = NSClassFromString(@"CTTelephonyNetworkInfo");
        if ( nil != telephonyClass ) {
            _telephoneInfo = [[telephonyClass alloc] init];
        }
        _uploadEventCount = QCMEASUREMENT_DEFAULT_UPLOAD_EVENT_COUNT;
        
    }
    
    return self;
}

-(void)dealloc {
    [_quantcastQueue removeObserver:self forKeyPath:@"operationCount"];
    [_quantcastQueue cancelAllOperations];
    
    [self stopReachabilityNotifier];
    
}

-(void)checkInitalAdPref{
    //if ad pref doesnt exist than set the default ad Pref to Enabled
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    if ([prefs objectForKey:QCMEASUREMENT_ADIDPREF_DEFAULTS] == nil) {
        BOOL initialValue = YES;
        NSString* cacheDir = [QuantcastUtils quantcastDeprecatedCacheDirectoryPath];
        NSString* adIdPrefFile = [cacheDir stringByAppendingPathComponent:QCMEASUREMENT_DEPRECATED_ADIDPREF_FILENAME];
        if ([[NSFileManager defaultManager] fileExistsAtPath:adIdPrefFile] ) {
            NSError* __autoreleasing readError = nil;
            NSString* savedAdIdPref = [NSString stringWithContentsOfFile:adIdPrefFile encoding:NSUTF8StringEncoding error:&readError];
            if(readError == nil){
                initialValue = [savedAdIdPref boolValue];
            }
        }
        [prefs setBool:initialValue forKey:QCMEASUREMENT_ADIDPREF_DEFAULTS];
        [prefs synchronize];
    }
}

/* As of v1.4.8 the Quantcast cache directory has been moved to a different location.  This method makes sure that when apps upgrade SDK
   versions, the old cache files are moved to the new location.
*/
-(void)moveCacheDirectoryIfNeeded {
    NSString* cacheDir = [QuantcastUtils quantcastDeprecatedCacheDirectoryPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:cacheDir]) {
        return;
    }
    
    NSString* supportDir = [QuantcastUtils quantcastSupportDirectoryPath];
    
    NSError* __autoreleasing moveError = nil;
    if ([[NSFileManager defaultManager] moveItemAtPath:cacheDir toPath:supportDir error:&moveError]) {
        //if move successful the mark all files to not back up
        [QuantcastUtils excludeBackupToItemAtPath:supportDir];
        NSArray* folderContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:supportDir error:&moveError];
        
        for (NSString* item in folderContent)
        {
            NSString* path = [supportDir stringByAppendingPathComponent:item];
            [QuantcastUtils excludeBackupToItemAtPath:path];
        }
        [[NSFileManager defaultManager] removeItemAtPath:cacheDir error:nil];
    }
}

-(void)appendUserAgent:(BOOL)add {
    [self getOriginalUserAgent:^(NSString *originalUserAgent) {
        [self performAppendUserAgent:originalUserAgent shouldAdd:add];
    }];
}

-(void)performAppendUserAgent:(NSString*)userAgent shouldAdd:(BOOL)add {
    //check for quantcast user agent first
     NSString* qcRegex = [NSString stringWithFormat:@"%@/iOS_(\\d+)\\.(\\d+)\\.(\\d+)/([a-zA-Z0-9]{16}-[a-zA-Z0-9]{16}|p-[-_a-zA-Z0-9]{13})", QCMEASUREMENT_UA_PREFIX];
     NSError* __autoreleasing regexError = nil;
     NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:qcRegex options:0 error:&regexError];
     if(nil != regexError){
         QUANTCAST_LOG(@"Error creating user agent regular expression = %@ ", regexError );
     }
     
     NSRange start = [regex rangeOfFirstMatchInString:userAgent options:0 range:NSMakeRange(0, userAgent.length)];
     
     NSString* newUA = nil;
     if( start.location == NSNotFound && add ) {
         if( nil != self.quantcastAPIKey ){
             newUA = [userAgent stringByAppendingFormat:@"%@/%@/%@", QCMEASUREMENT_UA_PREFIX, QCMEASUREMENT_API_IDENTIFIER, self.quantcastAPIKey];
         }else{
             newUA = [userAgent stringByAppendingFormat:@"%@/%@/%@", QCMEASUREMENT_UA_PREFIX, QCMEASUREMENT_API_IDENTIFIER, self.quantcastNetworkPCode];
         }
     }
     else if( start.location != NSNotFound && !add ) {
         newUA = [NSString stringWithFormat:@"%@%@", [userAgent substringToIndex:start.location], [userAgent substringFromIndex:NSMaxRange(start)]];
     }
     
     if( nil != newUA ) {
         NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
         NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:newUA, @"UserAgent", nil];
         [userDefaults registerDefaults:dictionary];
         
         //special check if Cordova is used
         
         NSString *cordovaValue = [userDefaults stringForKey:@"Cordova-User-Agent"];
         if( nil != cordovaValue ) {
             [userDefaults setValue:newUA forKey:@"Cordova-User-Agent"];
         }
     }
}

/*
     Developer notes:
     Run JS in web views is now asynchronous with the no-deprecated WKWebView,
     so i had to change the entire implementation in order to support the asynchronous response.
 */
-(void)getOriginalUserAgent:(void (^)(NSString* result))completionHandler {
    __block NSString* userAgent = [[[NSUserDefaults standardUserDefaults] stringForKey:@"UserAgent"] copy];
    
    if(nil != userAgent) {
        completionHandler(userAgent);
        return;
    }
    
    NSString* scriptToRun = @"navigator.userAgent";
    
    // Webview creation and evaluting MUST be done on main thread, so wait here for results.
    dispatch_sync(dispatch_get_main_queue(), ^{
        agentWebView = [[WKWebView alloc] initWithFrame:CGRectZero];
        
        [agentWebView evaluateJavaScript:scriptToRun completionHandler:^(NSString* result, NSError* error) {
            if (error != nil || result == nil) {
                completionHandler(@"");
                return;
            }
            
            completionHandler(result);
        }];
    });
}

-(BOOL)advertisingTrackingEnabled {
    BOOL userAdvertisingPreference = YES;
    
    Class adManagerClass = NSClassFromString(@"ASIdentifierManager");
    
    if ( nil != adManagerClass ) {
        
        id adPrefManager = [adManagerClass sharedManager];
        
        userAdvertisingPreference = [adPrefManager isAdvertisingTrackingEnabled];
    }

    return userAdvertisingPreference;
}

-(QuantcastPolicy*)policy {
    return _policy;
}

#pragma mark - Device Identifier
-(NSString*)deviceIdentifier {
    
    if ( self.isOptedOut ) {
        return nil;
    }

    return [QuantcastUtils deviceIdentifier:_policy];
}

-(NSString*)appInstallIdentifier {
    if ( nil == self.cachedAppInstallIdentifier ) {
        self.cachedAppInstallIdentifier = [self appInstallIdentifierWithUserAdvertisingPreference:self.advertisingTrackingEnabled];
    }
    
    return self.cachedAppInstallIdentifier;
}

-(NSString*)appInstallIdentifierWithUserAdvertisingPreference:(BOOL)inAdvertisingTrackingEnabled {
    // this method is factored out for testability reasons
    
    if ( self.isOptedOut ) {
        return nil;
    }
   
    // first, check if one exists and use it contents
    
    NSString* aidDir = [QuantcastUtils quantcastSupportDirectoryPathCreatingIfNeeded];
    
    if ( nil == aidDir) {
        return @"";
    }
    
    NSError* __autoreleasing writeError = nil;

    NSString* identFile = [aidDir stringByAppendingPathComponent:QCMEASUREMENT_IDENTIFIER_FILENAME];
    
    // first thing is to determine if apple's ad ID pref has changed. If so, create a new app id.
    BOOL adIdPrefHasChanged = [self hasUserAdvertisingPrefChangeWithCurrentPref:inAdvertisingTrackingEnabled];
    
    
    if ( [[NSFileManager defaultManager] fileExistsAtPath:identFile] && !adIdPrefHasChanged ) {
        NSError* __autoreleasing readError = nil;
        
        NSString* idStr = [NSString stringWithContentsOfFile:identFile encoding:NSUTF8StringEncoding error:&readError];
        
        if ( nil != readError ) {
            [self logSDKError:QC_SDKERRORTYPE_AIDREADFAILURE withError:readError errorParameter:nil];
            QUANTCAST_LOG(@"Error reading app specific identifier file = %@ ", readError );
        }
        
        // make sure string is of proper size before using it. Expecting something like "68753A44-4D6F-1226-9C60-0050E4C00067"
        
        if ( [idStr length] == 36 ) {
            return idStr;
        }
    }
    
    // a condition exists where a new app install ID needs to be created. create a new ID
    NSString* newAppInstallIdStr = [QuantcastUtils generateUUID];
    
    writeError = nil;
    
    [newAppInstallIdStr writeToFile:identFile atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
    [QuantcastUtils excludeBackupToItemAtPath:identFile];
    
    if ( nil != writeError ) {
        [self logSDKError:QC_SDKERRORTYPE_AIDWRITEFAILURE withError:writeError errorParameter:nil];
        QUANTCAST_LOG(@"Error when writing app specific identifier = %@", writeError);
    }
    else {
       QUANTCAST_LOG(@"Create new app identifier '%@' and wrote to file '%@'", newAppInstallIdStr, identFile );
    }
    
    return newAppInstallIdStr;
}

-(BOOL)hasUserAdvertisingPrefChangeWithCurrentPref:(BOOL)inCurrentPref {

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    BOOL savedAdIdPref = [defaults boolForKey:QCMEASUREMENT_ADIDPREF_DEFAULTS];
    BOOL adIdPrefHasChanged = inCurrentPref ^ savedAdIdPref;
    
    if ( adIdPrefHasChanged ) {
        [defaults setBool:inCurrentPref forKey:QCMEASUREMENT_ADIDPREF_DEFAULTS];
        [defaults synchronize];
    }
    
    return adIdPrefHasChanged;

}

#pragma mark - Event Recording

-(void)recordEvent:(QuantcastEvent*)inEvent withUpload:(BOOL)upload{
    if (upload) {
        [_dataManager recordEvent:inEvent withPolicy:_policy];
    }
    else {
        [_dataManager recordEventWithoutUpload:inEvent withPolicy:_policy];
    }
}

-(void)recordEvent:(QuantcastEvent*)inEvent {
    
    [self recordEvent:inEvent withUpload:YES];
}

-(void)enableDataUploading {
    // this method is factored out primarily for unit testing reasons
    [_dataManager enableDataUploadingWithReachability:self];
    
}

#pragma mark - Session Management
-(NSString*)generateNewSessionId{
    NSString* sessionId = [QuantcastUtils generateUUID];
    [self saveSessionId:sessionId];
    return sessionId;
}

-(void)saveSessionId:(NSString*) sessionID{
    NSString* cacheDir = [QuantcastUtils quantcastSupportDirectoryPathCreatingIfNeeded];
    NSString* sessionIdFile = [cacheDir stringByAppendingPathComponent:QCMEASUREMENT_SESSIONID_FILENAME];
    [[NSFileManager defaultManager] createFileAtPath:sessionIdFile contents:[sessionID dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
    [QuantcastUtils excludeBackupToItemAtPath:sessionIdFile];
}

-(void)updateSessionTimestamp{
    NSString* cacheDir = [QuantcastUtils quantcastSupportDirectoryPathCreatingIfNeeded];
    NSString* sessionIdFile = [cacheDir stringByAppendingPathComponent:QCMEASUREMENT_SESSIONID_FILENAME];
    
    NSDictionary* attribDict = @{NSFileModificationDate:[NSDate date]};
    [[NSFileManager defaultManager] setAttributes:attribDict ofItemAtPath:sessionIdFile error:nil];
}

-(BOOL)checkSessionID {
    BOOL newSession = NO;
    NSString* cacheDir = [QuantcastUtils quantcastSupportDirectoryPathCreatingIfNeeded];
    NSString* sessionIdFile = [cacheDir stringByAppendingPathComponent:QCMEASUREMENT_SESSIONID_FILENAME];
    
    NSTimeInterval modified = [self checkTimestamp:sessionIdFile];
    
    if(modified > 0){
        if((NSDate.timeIntervalSinceReferenceDate - modified) > _policy.sessionPauseTimeoutSeconds){
            newSession = YES;
        }
        else if( nil == self.currentSessionID ){
            NSError* __autoreleasing readError = nil;
            self.currentSessionID = [NSString stringWithContentsOfFile:sessionIdFile encoding:NSUTF8StringEncoding error:&readError];
            if ( nil != readError ) {
                QUANTCAST_LOG(@"Error reading session file = %@ ", readError );
                [self logSDKError:QC_SDKERRORTYPE_SESSIONREADFAILURE withError:readError errorParameter:nil];
                newSession = YES;
            }
        }
    }else{
        newSession = YES;
    }
    return newSession;
    
}

-(NSTimeInterval)checkTimestamp:(NSString*)path{
    NSTimeInterval timestamp = 0;
    if ( [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSError* __autoreleasing error = nil;
        NSDictionary* attrib = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
        if (nil != error) {
           QUANTCAST_LOG(@"Error getting session attributes = %@ ", error );
        }
        else {
            NSDate* modified = [attrib objectForKey:NSFileModificationDate];
            if(nil != modified){
                timestamp = modified.timeIntervalSinceReferenceDate;
            }
        }
    }
    return timestamp;
}


-(BOOL)isMeasurementActive {
    return nil != self.currentSessionID;
}

-(NSString*)setupMeasurementSessionWithAPIKey:(NSString*)inQuantcastAPIKey userIdentifier:(NSString*)userIdentifierOrNil labels:(id<NSObject>)inLabelsOrNil{
    NSString* userhash = nil;
    if ( !self.isOptedOut ) {
        
        if(self.isMeasurementActive){
           QUANTCAST_ERROR(@"beginMeasurementSessionWithAPIKey was already called.  Remove all beginMeasurementSessionWithAPIKey, pauseSessionWithLabels, resumeSessionWithLabels, and endMeasurementSessionWithLabels calls when you use setupMeasurementSessionWithAPIKey.");
            return nil;
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(terminateNotification) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pauseNotification) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resumeNotification) name:UIApplicationWillEnterForegroundNotification object:nil];
        
        NSMutableArray* labels = [NSMutableArray array];
        if ([inLabelsOrNil isKindOfClass:[NSArray class]]) {
            [labels addObjectsFromArray:(NSArray*)inLabelsOrNil];
        }
        else if ([inLabelsOrNil isKindOfClass:[NSString class]]) {
            [labels addObject:inLabelsOrNil];
        }

        self.appLabels = [QuantcastUtils combineLabels:self.appLabels withLabels:labels];
        
        userhash = [self internalBeginSessionWithAPIKey:inQuantcastAPIKey attributedNetwork:nil userIdentifier:userIdentifierOrNil appLabels:nil networkLabels:nil appIsDeclaredDirectedAtChildren:NO];
    }
    _usesOneStep = YES;
    return userhash;
}

-(void)terminateNotification{
    [self internalEndMeasurementSessionWithAppLabels:nil networkLabels:nil];
}

-(void)pauseNotification{
    [self internalPauseSessionWithAppLabels:nil networkLabels:nil];
}

-(void)resumeNotification{
    [self internalResumeSessionWithAppLabels:nil networkLabels:nil];
}

-(void)startNewSessionAndGenerateEventWithReason:(NSString*)inReason withAppLabels:(id<NSObject>)inAppLabelsOrNil networkLabels:(id<NSObject>)inNetworkLabelsOrNil eventTimestamp:(NSDate *)timestamp{

    self.currentSessionID = [self generateNewSessionId];
    _currentReachability = [self currentReachabilityStatus];
    QuantcastEvent* e = [QuantcastEvent openSessionEventWithClientUserHash:self.hashedUserId
                                                            eventTimestamp:timestamp
                                                          newSessionReason:inReason
                                                            connectionType:[self reachabilityAsString:_currentReachability]
                                                                 sessionID:self.currentSessionID
                                                           quantcastAPIKey:self.quantcastAPIKey
                                                     quantcastNetworkPCode:self.quantcastNetworkPCode
                                                          deviceIdentifier:self.deviceIdentifier
                                                      appInstallIdentifier:self.appInstallIdentifier
                                                            eventAppLabels:[QuantcastUtils combineLabels:self.appLabels withLabels:inAppLabelsOrNil]
                                                        eventNetworkLabels:inNetworkLabelsOrNil
                                                                   carrier:self.carrier];
    
    
    [self recordEvent:e];
}


-(void)beginMeasurementSessionWithAPIKey:(NSString*)inQuantcastAPIKey labels:(id<NSObject>)inLabelsOrNil {
    [self beginMeasurementSessionWithAPIKey:inQuantcastAPIKey userIdentifier:nil labels:inLabelsOrNil];
}

-(NSString*)beginMeasurementSessionWithAPIKey:(NSString*)inQuantcastAPIKey userIdentifier:(NSString*)inUserIdentifierOrNil labels:(id<NSObject>)inLabelsOrNil {
    
    NSString* hashedUserID = nil;
    if([self validateUsageForMessageNamed:NSStringFromSelector(_cmd)]){
        hashedUserID = [self internalBeginSessionWithAPIKey:inQuantcastAPIKey attributedNetwork:nil userIdentifier:inUserIdentifierOrNil appLabels:inLabelsOrNil networkLabels:nil appIsDeclaredDirectedAtChildren:NO];
    }
    return hashedUserID;
}


-(void)endMeasurementSessionWithLabels:(id<NSObject>)inLabelsOrNil {
    //still log the errors, but always let a session be closed.
    [self validateUsageForMessageNamed:NSStringFromSelector(_cmd)];
    [self internalEndMeasurementSessionWithAppLabels:inLabelsOrNil networkLabels:nil];
}

-(void)pauseSessionWithLabels:(id<NSObject>)inLabelsOrNil {
    if([self validateUsageForMessageNamed:NSStringFromSelector(_cmd)]){
        [self internalPauseSessionWithAppLabels:inLabelsOrNil networkLabels:nil];
    }
}

-(void)resumeSessionWithLabels:(id<NSObject>)inLabelsOrNil {
    if([self validateUsageForMessageNamed:NSStringFromSelector(_cmd)]){
        [self internalResumeSessionWithAppLabels:inLabelsOrNil networkLabels:nil];
    }
}

-(BOOL)validateUsageForMessageNamed:(NSString*)name{
    BOOL allowed = YES;
    if (_usesOneStep) {
       QUANTCAST_ERROR(@"No need to explictly call any %@ when setupMeasurementSessionWithAPIKey is used.", name);
        allowed = NO;
    }
    if (self.hasNetworkIntegration) {
       QUANTCAST_ERROR(@"The direct app integration form of %@ should not be called for network integrations. Please see QuantcastMeasurement+Networks.h for more information",name);
    }
    return allowed;
}

-(BOOL)startNewSessionIfUsersAdPrefChangedWithAppLabels:(id<NSObject>)inAppLabelsOrNil networkLabels:(id<NSObject>)inNetworkLabels eventTimestamp:(NSDate *)timestamp{
    if ( [self hasUserAdvertisingPrefChangeWithCurrentPref:self.advertisingTrackingEnabled]) {
       QUANTCAST_LOG(@"The user has changed their advertising tracking preference. Adjusting identifiers and starting a new session.");
        
        [self startNewSessionAndGenerateEventWithReason:QCPARAMETER_REASONTYPE_ADPREFCHANGE withAppLabels:inAppLabelsOrNil networkLabels:inNetworkLabels eventTimestamp:timestamp];
        return YES;
    }
    
    return NO;
}

+(BOOL)validateQuantcastAPIKey:(NSString*)inQuantcastAPIKeyId quantcastNetworkPCode:(NSString*)inQuantcastNetworkPCode {
    
    if ( nil == inQuantcastAPIKeyId && nil == inQuantcastNetworkPCode ) {
       QUANTCAST_ERROR(@"No Quantcast API Key or Network P-Code was passed to the SDK.");
        return NO;
    }
    if ( nil != inQuantcastAPIKeyId ) {
        //validate that api key in form [a-zA-Z0-9]{16}-[a-zA-Z0-9]{16}
        BOOL valid = NO;
        if(inQuantcastAPIKeyId.length == 33 && [inQuantcastAPIKeyId characterAtIndex:16] == '-'){
            NSCharacterSet* apiKeySet = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"] invertedSet];
            NSString* sec1 = (NSString*)[inQuantcastAPIKeyId substringToIndex:16];
            NSRange ran = [sec1 rangeOfCharacterFromSet:apiKeySet];
            if(ran.location == NSNotFound){
                sec1 = (NSString*)[inQuantcastAPIKeyId substringFromIndex:17];
                if(sec1.length == 16){
                    if([sec1 rangeOfCharacterFromSet:apiKeySet].location == NSNotFound){
                        valid = YES;
                    }
                }
            }
        }
        
        if ( !valid ) {
           QUANTCAST_ERROR(@"The Quantcast API Key passed to the SDK is malformed.");
            return NO;
        }
    }
    
    //validate p-code of form p-[-_a-zA-Z0-9]{13}
    if ( nil != inQuantcastNetworkPCode ) {
        BOOL valid = NO;
        if([inQuantcastNetworkPCode hasPrefix:@"p-"]){
            NSString* code = [inQuantcastNetworkPCode substringFromIndex:2];
            if(code.length == 13){
                NSCharacterSet* pcodeSet = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-_"] invertedSet];
                if([code rangeOfCharacterFromSet:pcodeSet].location == NSNotFound){
                    valid = YES;
                }
            }
        }
        if ( !valid ) {
           QUANTCAST_ERROR(@"The Quantcast Network P-Code passed to the SDK is malformed.");
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - Internal Session Management
-(BOOL)hasNetworkIntegration {
    return ( nil != self.quantcastNetworkPCode );
}

/*!
 @method internalBeginSessionWithAPIKey:attributedNetwork:userIdentifier:appLabels:networkLabels:appIsDirectedAtChildren:
 @internal
 @abstract Begins Quantcast Measure for Apps. Common internal method for both direct app and platform/network integrations.
 @param inQuantcastAPIKey The declared API Key for this app. May be nil, in which case inNetworkPCode must not be nil.
 @param inNetworkPCode The network p-code this app's traffic though be syndicated to. May be nil, in which case inQuantcastAPIKey must not be nil.
 @param inUserIdentifierOrNil the user identifier passed by the SDK user
 @param inAppLabelsOrNil labels that should be attributed to the app integration (API Key)
 @param inNetworkLabelsOrNil labels that should be attributed to the platform/network integration (network p-code)
 @param inAppIsDirectedAtChildren Whether the app has declared itself as directed at children under 13 or not. This is only used (that is, not NO) for network/platform integrations. Directly quantified apps (apps with an API Key) should declare their "directed at children under 13" status at the Quantcast.com website. Ultimately, this value and the Quantcast.com value will be OR'ed together to get final determination.
 */
-(NSString*)internalBeginSessionWithAPIKey:(NSString*)inQuantcastAPIKey attributedNetwork:(NSString*)inNetworkPCode userIdentifier:(NSString*)inUserIdentifierOrNil appLabels:(id<NSObject>)inAppLabelsOrNil networkLabels:(id<NSObject>)inNetworkLabelsOrNil appIsDeclaredDirectedAtChildren:(BOOL)inAppIsDirectedAtChildren {
    // first check that app ID is proprly formatted
    
    if ( ![QuantcastMeasurement validateQuantcastAPIKey:inQuantcastAPIKey quantcastNetworkPCode:inNetworkPCode] ) {
        return nil;
    }

    NSString* hashedId = [self hashUserIdentifier:inUserIdentifierOrNil];
    self.quantcastAPIKey = inQuantcastAPIKey;
    self.quantcastNetworkPCode = inNetworkPCode;
    _appIsDeclaredDirectedAtChildren = inAppIsDirectedAtChildren;
    
    if ( !self.isOptedOut ) {
        //copy the incoming labels.  This prevents the client from changing the original object from underneath us.
        NSArray* appLabelCopy = [QuantcastUtils copyLabels:inAppLabelsOrNil];
        NSArray* networkLabelCopy = [QuantcastUtils copyLabels:inNetworkLabelsOrNil];
        
        [self launchOnQuantcastThread:^(NSDate *timestamp) {
            if ( !self.isMeasurementActive ) {
                if(nil != hashedId){
                    self.hashedUserId = hashedId;
                }
    #ifdef __IPHONE_7_0
                if ( nil != self->_telephoneInfo ){
                    BOOL radioNotificationExists = YES;
                    #if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0
                        radioNotificationExists = &CTRadioAccessTechnologyDidChangeNotification != NULL;
                    #endif
                    if( [self->_telephoneInfo respondsToSelector:@selector(currentRadioAccessTechnology)] && radioNotificationExists ){
                        
                        NSString *notificationName = @"";
                        
                        if (@available(iOS 12, *)) {
                            notificationName = CTServiceRadioAccessTechnologyDidChangeNotification;
                        } else {
                            notificationName = CTRadioAccessTechnologyDidChangeNotification;
                        }
                        
                        [[NSNotificationCenter defaultCenter] addObserver:self
                                                                 selector:@selector(radioAccessChanged:)
                                                                     name:notificationName
                                                                   object:nil];
                    }
                }
    #endif
                [self startReachabilityNotifier];
                [self appendUserAgent:YES];
            
                if (nil == self->_dataManager) {
                    self->_policy = [QuantcastPolicy policyWithAPIKey:self.quantcastAPIKey networkPCode:self.quantcastNetworkPCode networkReachability:self countryCode:self.carrier.isoCountryCode appIsDirectAtChildren:inAppIsDirectedAtChildren];
                    
                    if ( nil == self->_policy ) {
                        // policy wasn't able to be built. Stop reachability and bail, thus not activating measurement.
                        [self stopReachabilityNotifier];
                       QUANTCAST_LOG(@"QC Measurement: Unable to activate measurement due to policy object being nil.");
                    }
                
                    self->_dataManager = [[QuantcastDataManager alloc] initWithOptOut:self.isOptedOut];
                    self->_dataManager.uploadEventCount = self.uploadEventCount;
                
                }
            
                [self enableDataUploading];
                
                if([self checkSessionID]){
                    [self startNewSessionAndGenerateEventWithReason:QCPARAMETER_REASONTYPE_LAUNCH withAppLabels:[QuantcastUtils combineLabels:self.appLabels withLabels:appLabelCopy] networkLabels:networkLabelCopy eventTimestamp:(NSDate *)timestamp];
                }else{
                    QuantcastEvent* e = [QuantcastEvent resumeSessionEventWithSessionID:self.currentSessionID eventTimestamp:timestamp applicationInstallID:self.appInstallIdentifier eventAppLabels:[QuantcastUtils combineLabels:self.appLabels withLabels:appLabelCopy] eventNetworkLabels:networkLabelCopy];
                    
                    [self recordEvent:e];
                }
               QUANTCAST_LOG(@"QC Measurement: Using '%@' for upload server.",[QuantcastUtils updateSchemeForURL:[NSURL URLWithString:QCMEASUREMENT_UPLOAD_URL]]);
                [self->_dataManager initiateDataUploadWithPolicy:self->_policy];
            }
        }];
    }
    
    return hashedId;
}

-(void)internalEndMeasurementSessionWithAppLabels:(id<NSObject>)inAppLabelsOrNil networkLabels:(id<NSObject>)inNetworkLabelsOrNil {
    if ( !self.isOptedOut  ) {
        //copy the incoming labels.  This prevents the client from changing the original object from underneath us.
        NSArray* appLabelCopy = [QuantcastUtils copyLabels:inAppLabelsOrNil];
        NSArray* networkLabelCopy = [QuantcastUtils copyLabels:inNetworkLabelsOrNil];
        [self launchOnQuantcastThread:^(NSDate *timestamp) {
            if ( self.isMeasurementActive ) {
                QuantcastEvent* e = [QuantcastEvent closeSessionEventWithSessionID:self.currentSessionID eventTimestamp:timestamp applicationInstallID:self.appInstallIdentifier eventAppLabels:[QuantcastUtils combineLabels:self.appLabels withLabels:appLabelCopy] eventNetworkLabels:networkLabelCopy];
                
                [self recordEvent:e withUpload:YES];
                [self updateSessionTimestamp];
                
                [self stopReachabilityNotifier];
                
                self.currentSessionID = nil;
                
                [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
                [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
                [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
                self->_usesOneStep = NO;
            }
            else {
               QUANTCAST_ERROR(@"endMeasurementSessionWithLabels: was called without first calling beginMeasurementSession:");
            }
        }];
    }
}

-(void)internalPauseSessionWithAppLabels:(id<NSObject>)inAppLabelsOrNil networkLabels:(id<NSObject>)inNetworkLabelsOrNil {
    
    if ( !self.isOptedOut ) {
        //copy the incoming labels.  This prevents the client from changing the original object from underneath us.
        NSArray* appLabelCopy = [QuantcastUtils copyLabels:inAppLabelsOrNil];
        NSArray* networkLabelCopy = [QuantcastUtils copyLabels:inNetworkLabelsOrNil];
        [self launchOnQuantcastThread:^(NSDate *timestamp) {
            if ( self.isMeasurementActive ) {
                QuantcastEvent* e = [QuantcastEvent pauseSessionEventWithSessionID:self.currentSessionID eventTimestamp:timestamp applicationInstallID:self.appInstallIdentifier eventAppLabels:[QuantcastUtils combineLabels:self.appLabels withLabels:appLabelCopy] eventNetworkLabels:networkLabelCopy];
                
                [self recordEvent:e withUpload:NO];
                
                [self updateSessionTimestamp];
                
                [self stopReachabilityNotifier];
                
                //force upload if we can
                BOOL exitsOnSuspend = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIApplicationExitsOnSuspend"] boolValue];
                if(!exitsOnSuspend){
                    [self->_dataManager initiateDataUploadWithPolicy:self->_policy];
                }
            }
            else {
               QUANTCAST_ERROR(@"pauseSessionWithLabels: was called without first calling beginMeasurementSession:");
            }
        }];
    }
}

-(void)internalResumeSessionWithAppLabels:(id<NSObject>)inAppLabelsOrNil networkLabels:(id<NSObject>)inNetworkLabelsOrNil {
    [self setOptOutStatus:[QuantcastMeasurement isOptedOutStatus]];
    
    if ( !self.isOptedOut ) {
        //copy the incoming labels.  This prevents the client from changing the original object from underneath us.
        NSArray* appLabelCopy = [QuantcastUtils copyLabels:inAppLabelsOrNil];
        NSArray* networkLabelCopy = [QuantcastUtils copyLabels:inNetworkLabelsOrNil];
        [self launchOnQuantcastThread:^(NSDate *timestamp) {
            if ( self.isMeasurementActive ) {
                QuantcastEvent* e = [QuantcastEvent resumeSessionEventWithSessionID:self.currentSessionID eventTimestamp:timestamp applicationInstallID:self.appInstallIdentifier eventAppLabels:[QuantcastUtils combineLabels:self.appLabels withLabels:appLabelCopy] eventNetworkLabels:networkLabelCopy];

                [self startReachabilityNotifier];
                
                [self->_policy downloadLatestPolicyWithReachability:self];
                
                [self recordEvent:e];
                
                if (![self startNewSessionIfUsersAdPrefChangedWithAppLabels:[QuantcastUtils combineLabels:self.appLabels withLabels:appLabelCopy] networkLabels:networkLabelCopy eventTimestamp:timestamp]) {
                    if ( [self checkSessionID] ) {
                        [self->_policy downloadLatestPolicyWithReachability:self];
                        [self startNewSessionAndGenerateEventWithReason:QCPARAMETER_REASONTYPE_RESUME withAppLabels:[QuantcastUtils combineLabels:self.appLabels withLabels:appLabelCopy] networkLabels:networkLabelCopy eventTimestamp:timestamp];
                       QUANTCAST_LOG(@"Starting new session after app being paused for extend period of time.");
                    }
                }
                
            }
            else {
               QUANTCAST_ERROR(@"resumeSessionWithLabels: was called without first calling beginMeasurementSession:");
            }
        }];
    }
}

#pragma mark - Internal Label Management

-(void)addInternalSDKAppLabels:(NSArray*)inAppLabels networkLabels:(NSArray*)inNetworkLabels {
    
    _internalSDKAppLabels = [QuantcastUtils combineLabels:inAppLabels withLabels:self.internalSDKAppLabels];
    _internalSDKNetworkLabels = [QuantcastUtils combineLabels:inNetworkLabels withLabels:self.internalSDKNetworkLabels];
}

-(void)setInternalSDKAppLabels:(NSArray*)inAppLabels networkLabels:(NSArray*)inNetworkLabels {
    _internalSDKAppLabels = inAppLabels;
    _internalSDKNetworkLabels = inNetworkLabels;
}

-(id<NSObject>)internalSDKAppLabels {
    return _internalSDKAppLabels;
}

-(id<NSObject>)internalSDKNetworkLabels {
    return _internalSDKNetworkLabels;
}

-(id<NSObject>)appLabels {
    return [QuantcastUtils combineLabels:_appLabels withLabels:self.internalSDKAppLabels];
}

#pragma mark - Telephony
-(CTCarrier*)carrier{
    CTCarrier* carrier = nil;
    
    if(_telephoneInfo == nil) {
        return carrier;
    }
    
    if (@available(iOS 12, *)) {
        if(_telephoneInfo.serviceSubscriberCellularProviders.allValues.count == 0) {
            return carrier;
        }
        
        @try {
           carrier = (CTCarrier *)_telephoneInfo.serviceSubscriberCellularProviders.allValues.firstObject;
        }
        @catch (NSException *exception) {
            NSLog(@"%@", exception.reason);
            return carrier;
        }
        
        return carrier;
    } else {
        return _telephoneInfo.subscriberCellularProvider;
    }
}


#pragma mark - Network Reachability

static void QuantcastReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
#pragma unused (target, flags)
    if ( info == NULL ) {
        QUANTCAST_ERROR(@"Info was NULL in QuantcastReachabilityCallback");
        return;
    }
    if ( ![(__bridge NSObject*) info isKindOfClass: [QuantcastMeasurement class]] ) {
        QUANTCAST_ERROR(@"Info was wrong class in QuantcastReachabilityCallback");
        return;
    }

    @autoreleasepool {
    
        QuantcastMeasurement* qcMeasurement = (__bridge QuantcastMeasurement*) info;
        [[NSNotificationCenter defaultCenter] postNotificationName:kQuantcastNetworkReachabilityChangedNotification object:qcMeasurement];
        [qcMeasurement logNetworkReachability];
    
    }
}


-(void)logNetworkReachability{
    if ( !self.isOptedOut){
        [self launchOnQuantcastThread:^(NSDate *timestamp) {
            if(self.isMeasurementActive ) {
        
                //make sure we dont send duplicate reachability events
                QuantcastNetworkStatus status = [self currentReachabilityStatus];
                if (status != self->_currentReachability) {
                    self->_currentReachability = status;
                    QuantcastEvent* e = [QuantcastEvent networkReachabilityEventWithConnectionType:[self reachabilityAsString:self->_currentReachability]
                                                                        withSessionID:self.currentSessionID
                                                                       eventTimestamp:timestamp
                                                                 applicationInstallID:self.appInstallIdentifier];
        
                    [self recordEvent:e];
                }
            }
        }];
    }
}


-(BOOL)startReachabilityNotifier
{
    BOOL retVal = NO;
    
    if ( NULL == _reachability ) {
        SCNetworkReachabilityContext    context = {0, (__bridge void *)(self), NULL, NULL, NULL};

        NSURL* url = [NSURL URLWithString:QCMEASUREMENT_UPLOAD_URL];
    
        _reachability = SCNetworkReachabilityCreateWithName(NULL, [[url host] UTF8String]);
        
        if(SCNetworkReachabilitySetCallback(_reachability, QuantcastReachabilityCallback, &context))
        {
            if(SCNetworkReachabilityScheduleWithRunLoop(_reachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode))
            {
                retVal = YES;
            }
        }
    }
    return retVal;
}

-(void)stopReachabilityNotifier
{
    if(NULL != _reachability )
    {
        SCNetworkReachabilityUnscheduleFromRunLoop(_reachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        
        CFRelease(_reachability);
        
        _reachability = NULL;
    }
}

-(QuantcastNetworkStatus)currentReachabilityStatus
{
    if ( NULL == _reachability ) {
        return QuantcastNotReachable;
    }

    QuantcastNetworkStatus retVal = QuantcastNotReachable;
    SCNetworkReachabilityFlags flags;
    if (SCNetworkReachabilityGetFlags(_reachability, &flags))
    {
        if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
        {
            // if target host is not reachable
            return QuantcastNotReachable;
        }

        if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
        {
            // if target host is reachable and no connection is required
            //  then we'll assume (for now) that your on Wi-Fi
            retVal = QuantcastReachableViaWiFi;
        }


        if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
             (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
        {
            // ... and the connection is on-demand (or on-traffic) if the
            //     calling application is using the CFSocketStream or higher APIs
            
            if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
            {
                // ... and no [user] intervention is needed
                retVal = QuantcastReachableViaWiFi;
            }
        }

        if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
        {
            // ... but WWAN connections are OK if the calling application
            //     is using the CFNetwork (CFSocketStream?) APIs.
            retVal = QuantcastReachableViaWWAN;
        }
    }
    return retVal;
}

-(NSString*)reachabilityAsString:(QuantcastNetworkStatus)status{
    NSString* defaultValue = @"unknown";
    NSString* retVal = nil;
    switch (status) {
        case QuantcastNotReachable:
            retVal = @"disconnected";
            break;
        case QuantcastReachableViaWiFi:
            retVal = @"wifi";
            break;
        case QuantcastReachableViaWWAN:
#ifdef __IPHONE_7_0
            if([_telephoneInfo respondsToSelector:@selector(currentRadioAccessTechnology)]){
                
                if (@available(iOS 12, *)) {
                    if (_telephoneInfo.serviceCurrentRadioAccessTechnology.allValues.count > 0) {
                        @try {
                            retVal = (NSString *) _telephoneInfo.serviceCurrentRadioAccessTechnology.allValues.firstObject;
                        } @catch (NSException *exception) {
                            NSLog(@"%@", exception.reason);
                            retVal = defaultValue;
                        }
                    }
                } else {
                    retVal = _telephoneInfo.currentRadioAccessTechnology;
                }
            }
#endif
            if( nil == retVal){
                retVal = @"wwan";
            }
            break;
        default:
            retVal = defaultValue;
            break;
    }
    return retVal;
}

-(void)radioAccessChanged:(NSNotification*) inNotification{
    [self logNetworkReachability];
}

#pragma mark - Measurement and Analytics

-(NSString*)hashUserIdentifier:(NSString*)inUserIdentifierOrNil {
    NSString* hashedUserIdentifier = nil;
    if (!self.isOptedOut) {
        if ( nil != inUserIdentifierOrNil ) {
            hashedUserIdentifier = [QuantcastUtils quantcastHash:inUserIdentifierOrNil];
        }
    }
    return hashedUserIdentifier;
}

-(NSString*)recordUserIdentifier:(NSString*)inUserIdentifierOrNil withLabels:(id<NSObject>)inLabelsOrNil {
    if (self.hasNetworkIntegration) {
       QUANTCAST_ERROR(@"The direct app integration form of recordUserIdentifier should not be called for network integrations. Please see QuantcastMeasurement+Networks.h for more information");
    }

    return [self internalRecordUserIdentifier:inUserIdentifierOrNil withAppLabels:inLabelsOrNil networkLabels:nil];
}

-(NSString*)internalRecordUserIdentifier:(NSString*)inUserIdentifierOrNil withAppLabels:(id<NSObject>)inAppLabelsOrNil networkLabels:(id<NSObject>)inNetworkLabels {
    if (self.isOptedOut) {
        return nil;
    }
    
    NSString* hashedId = [self hashUserIdentifier:inUserIdentifierOrNil];
    
    [self launchOnQuantcastThread:^(NSDate *timestamp) {
        if ( self.isMeasurementActive ) {
            // save current hashed user ID in order to detect session changes
            NSString* originalHashedUserId = self->_hashedUserId;
            if ( ( originalHashedUserId == nil && hashedId != nil ) ||
                ( originalHashedUserId != nil && hashedId == nil ) ||
                ( originalHashedUserId != nil && ![originalHashedUserId isEqualToString:hashedId] ) ) {
                self.hashedUserId = hashedId;
                [self startNewSessionAndGenerateEventWithReason:QCPARAMETER_REASONTYPE_USERHASH withAppLabels:inAppLabelsOrNil networkLabels:inNetworkLabels eventTimestamp:timestamp];
            }
        }else{
            QUANTCAST_ERROR(@"recordUserIdentifier:withLabels: was called without first calling beginMeasurementSession:");
        }
    }];
    
    return hashedId;
}

-(void)logEvent:(NSString*)inEventName withLabels:(id<NSObject>)inLabelsOrNil {
    if (self.hasNetworkIntegration) {
       QUANTCAST_ERROR(@"The direct app integration form of logEvent should not be called for network integrations. Please see QuantcastMeasurement+Networks.h for more information");
    }

    [self internalLogEvent:inEventName withAppLabels:inLabelsOrNil networkLabels:nil];
}

-(void)internalLogEvent:(NSString*)inEventName withAppLabels:(id<NSObject>)inAppLabelsOrNil networkLabels:(id<NSObject>)inNetworkLabels {

    if ( !self.isOptedOut ) {
        [self launchOnQuantcastThread:^(NSDate *timestamp) {
            if (self.isMeasurementActive) {
                QuantcastEvent* e = [QuantcastEvent logEventEventWithEventName:inEventName
                                                                eventTimestamp:timestamp
                                                                eventAppLabels:[QuantcastUtils combineLabels:self.appLabels withLabels:inAppLabelsOrNil]
                                                            eventNetworkLabels:inNetworkLabels
                                                                     sessionID:self.currentSessionID
                                                          applicationInstallID:self.appInstallIdentifier];
                
                [self recordEvent:e];
            }
            else {
               QUANTCAST_ERROR(@"logEvent:withLabels: was called without first calling beginMeasurementSession:");
            }
        }];
    }
}

-(void)logUploadLatency:(NSUInteger)inLatencyMilliseconds forUploadId:(NSString*)inUploadID {
    if ( !self.isOptedOut ) {
        [self launchOnQuantcastThread:^(NSDate *timestamp) {
            if(self.isMeasurementActive){
                QuantcastEvent* e = [QuantcastEvent logUploadLatency:inLatencyMilliseconds
                                                         forUploadId:inUploadID
                                                       withSessionID:self.currentSessionID
                                                      eventTimestamp:[NSDate date]
                                                applicationInstallID:self.appInstallIdentifier];
                
                [self recordEvent:e];
            }
        }];
    }
}


#pragma mark - User Privacy Management
@synthesize isOptedOut=_isOptedOut;

+(BOOL)isOptedOutStatus {
    
    // check Quantcast opt-out status
    return [[NSUserDefaults standardUserDefaults] boolForKey:QCMEASUREMENT_OPTOUT_DEFAULTS];
}


-(void)setOptOutStatus:(BOOL)inOptOutStatus {
    
    if ( _isOptedOut != inOptOutStatus ) {
        _isOptedOut = inOptOutStatus;
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        [defaults setBool:inOptOutStatus forKey:QCMEASUREMENT_OPTOUT_DEFAULTS];
        [defaults synchronize];
    
        [self launchOnQuantcastThread:^(NSDate *timestamp) {
            self.cachedAppInstallIdentifier = nil;
            // setting the data manager to opt out will cause the cache directory to be emptied.
            self->_dataManager.isOptOut = inOptOutStatus;
            
            if ( inOptOutStatus && self.isMeasurementActive) {
                // stop the various services
                
                [self stopReachabilityNotifier];
                [self appendUserAgent:NO];
                [self setOptOutCookie:YES];
                
                if (self->_usesOneStep) {
                    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
                    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
                    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
                }
                self.currentSessionID = nil;
            }
            else if( !inOptOutStatus && (self.quantcastAPIKey != nil || self.quantcastNetworkPCode != nil )){
                // if the opt out status goes to NO (meaning we can do measurement), begin a new session
                if (self->_usesOneStep) {
                    [self setupMeasurementSessionWithAPIKey:self.quantcastAPIKey userIdentifier:nil labels:@"_OPT-IN"];
                }
                else {
                    [self internalBeginSessionWithAPIKey:self.quantcastAPIKey attributedNetwork:self.quantcastNetworkPCode userIdentifier:nil appLabels:@"_OPT-IN" networkLabels:nil appIsDeclaredDirectedAtChildren:self->_appIsDeclaredDirectedAtChildren];
                }
            
                [self setOptOutCookie:NO];
            }
        }];
    }
    
}

-(void)setOptOutCookie:(BOOL)add {
    if( add ) {
        NSHTTPCookie* optOutCookie = [NSHTTPCookie cookieWithProperties:@{NSHTTPCookieDomain : @".quantserve.com", NSHTTPCookiePath : @"/", NSHTTPCookieName: @"qoo", NSHTTPCookieValue: @"OPT_OUT", NSHTTPCookieExpires : [NSDate dateWithTimeIntervalSinceNow:60*60*24*365*10]}];
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:optOutCookie];
    }
    else {
        for(NSHTTPCookie* cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]){
            if([cookie.name isEqualToString:@"qoo"] && [cookie.domain isEqualToString:@".quantserve.com"]) {
                [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
                break;
            }
        }
    }
    
}

-(void)displayQuantcastPrivacyPolicy{
    [self displayQuantcastPrivacyPolicy:nil];
}

-(void)displayQuantcastPrivacyPolicy:(UIViewController*)inController{
    NSURL* qcPrivacyURL = [NSURL URLWithString:@"https://www.quantcast.com/privacy/"];
    if(nil == inController){
            [[UIApplication sharedApplication] openURL:qcPrivacyURL options:@{} completionHandler:nil];
    }else{
        //keep them in app
        UIViewController* webController = [[UIViewController alloc] init];
        webController.title = @"Privacy Policy";
        WKWebView* web = [[WKWebView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [web loadRequest:[NSURLRequest requestWithURL:qcPrivacyURL]];
        webController.view = web;
        
        if( nil != inController.navigationController ){
            [inController.navigationController pushViewController:webController animated:YES];
        }
        else{
            UINavigationController* navWrapper = [[UINavigationController alloc] initWithRootViewController:webController];
            navWrapper.title = @"Quantcast Privacy Policy";
            navWrapper.navigationBar.topItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissPrivacyPolicy:)];
            navWrapper.modalPresentationStyle = UIModalPresentationFormSheet;
            [inController presentViewController:navWrapper animated:YES completion:NULL];
        }
        
    }
}

-(void)dismissPrivacyPolicy:(id)button{
    if ([[QuantcastUtils.keyWindow.rootViewController presentedViewController] respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {
        
        [[QuantcastUtils.keyWindow.rootViewController presentedViewController] dismissViewControllerAnimated:YES completion:NULL];
    }
    else {
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        [[[UIApplication sharedApplication].keyWindow.rootViewController presentedViewController] dismissModalViewControllerAnimated:YES];
#pragma GCC diagnostic warning "-Wdeprecated-declarations"
    }
    
}

-(void)displayUserPrivacyDialogOver:(UIViewController*)inCurrentViewController withDelegate:(id<QuantcastOptOutDelegate>)inDelegate {
 
    QuantcastOptOutViewController* optOutController = [[QuantcastOptOutViewController alloc] initWithDelegate:inDelegate];
    UINavigationController* navWrapper = [[UINavigationController alloc] initWithRootViewController:optOutController];
    
    navWrapper.modalPresentationStyle = UIModalPresentationFormSheet;
    if ([inCurrentViewController respondsToSelector:@selector(presentViewController:animated:completion:)]) {
        [inCurrentViewController presentViewController:navWrapper animated:YES completion:NULL];
    }
    else {
        // pre-iOS 5
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        [inCurrentViewController presentModalViewController:navWrapper animated:YES];
#pragma GCC diagnostic warning "-Wdeprecated-declarations"
    }

}

#pragma mark - SDK Customization

-(NSUInteger)uploadEventCount {
    if ( nil != _dataManager ) {
        return _dataManager.uploadEventCount;
    }
    
    return _uploadEventCount;
}

-(void)setUploadEventCount:(NSUInteger)inUploadEventCount {
    
    if ( inUploadEventCount > 1 ){
        if ( nil != _dataManager ) {
            _dataManager.uploadEventCount = inUploadEventCount;
        }
        
        _uploadEventCount = inUploadEventCount;
    }
    else {
       QUANTCAST_ERROR( @"Tried to set uploadEventCount to disallowed value %lu", (unsigned long)inUploadEventCount );
    }
}


#pragma mark - Debugging
-(void)setEnableLogging:(BOOL)inEnableLogging {
    QuantcastUtils.logging = inEnableLogging;
}

-(BOOL)enableLogging{
    return QuantcastUtils.logging;
}

- (NSString *)description {
    NSString* descStr = [NSString stringWithFormat:@"<QuantcastMeasurement %p: data manager = %@>", self, self.dataManager];
    
    return descStr;
}

-(void)logSDKError:(NSString*)inSDKErrorType withError:(NSError*)inErrorOrNil errorParameter:(NSString*)inErrorParametOrNil {
    if ( !self.isOptedOut ) {
        [self launchOnQuantcastThread:^(NSDate *timestamp) {
            if( self.isMeasurementActive ){
                QuantcastEvent* e = [QuantcastEvent logSDKError:inSDKErrorType withErrorObject:inErrorOrNil errorParameter:inErrorParametOrNil withSessionID:self.currentSessionID eventTimestamp:timestamp applicationInstallID:self.appInstallIdentifier];
                //dont try to upload event immediately.  This should prevent the same error from being triggered over and over
                [self recordEvent:e withUpload:NO];
            }
        }];
    }
    
}

-(QuantcastDataManager*)dataManager{
    return _dataManager;
}

-(void)launchOnQuantcastThread:(void (^)(NSDate *))block {
    NSDate *timestamp = [NSDate date];
    [_quantcastQueue addOperationWithBlock:^{
        block(timestamp);
    }];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                         change:(NSDictionary *)change context:(void *)context
{
    if (object == _quantcastQueue && [keyPath isEqualToString:@"operationCount"]) {
        if(_quantcastQueue.operationCount == 1 && _backgroundTaskID == UIBackgroundTaskInvalid){
            _backgroundTaskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                [[UIApplication sharedApplication] endBackgroundTask: self->_backgroundTaskID];
                self->_backgroundTaskID = UIBackgroundTaskInvalid;
            }];
        }
        else if(_quantcastQueue.operationCount == 0 && _backgroundTaskID != UIBackgroundTaskInvalid){
            [[UIApplication sharedApplication] endBackgroundTask: _backgroundTaskID];
            _backgroundTaskID = UIBackgroundTaskInvalid;
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object
                               change:change context:context];
    }
}


@end
