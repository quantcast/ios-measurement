//
// Copyright (c) 2012, Quantcast Corp.
// This software is licensed under the Quantcast Mobile API Beta Evaluation Agreement and may not be used except as permitted thereunder or copied, modified, or distributed in any case.
//

#ifndef __has_feature
#define __has_feature(x) 0
#endif
#ifndef __has_extension
#define __has_extension __has_feature // Compatibility with pre-3.0 compilers.
#endif

#if __has_feature(objc_arc) && __clang_major__ >= 3
#error "Quantcast Measurement is not designed to be used with ARC. Please add '-fno-objc-arc' to this file's compiler flags"
#endif // __has_feature(objc_arc)

#ifndef QCMEASUREMENT_ENABLE_JSONKIT
#define QCMEASUREMENT_ENABLE_JSONKIT 0
#endif

#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "QuantcastPolicy.h"
#import "QuantcastParameters.h"
#import "QuantcastUtils.h"

#if QCMEASUREMENT_ENABLE_JSONKIT
#import "JSONKit.h"
#endif

#define QCMEASUREMENT_DO_NOT_SALT_STRING    @"MSG"

@interface QuantcastPolicy ()

-(void)setPolicywithJSONData:(NSData*)inJSONData;
-(void)networkReachabilityChanged:(NSNotification*)inNotification;
-(void)startPolicyDownloadWithURL:(NSURL*)inPolicyURL;

@end


@implementation QuantcastPolicy
@synthesize deviceIDHashSalt=_didSalt;
@synthesize isMeasurementBlackedout=_isMeasurementBlackedout;
@synthesize hasPolicyBeenLoaded=_policyHasBeenLoaded;
@synthesize hasUpdatedPolicyBeenDownloaded=_policyHasBeenDownloaded;
@synthesize sessionPauseTimeoutSeconds=_sessionTimeout;

-(id)initWithPolicyURL:(NSURL*)inPolicyURL reachability:(id<QuantcastNetworkReachability>)inNetworkReachabilityOrNil {
    self = [super init];
    
    if (self) {
        _sessionTimeout = QCMEASUREMENT_DEFAULT_MAX_SESSION_PAUSE_SECOND;
        
        _policyHasBeenLoaded = NO;
        _policyHasBeenDownloaded = NO;
        _waitingForUpdate = NO;
       // first, determine if there is a saved polciy on disk, if not, create it with default polciy
        NSString* cacheDir = [QuantcastUtils quantcastCacheDirectoryPath];
        
        NSString* policyFilePath = [cacheDir stringByAppendingPathComponent:QCMEASUREMENT_POLICY_FILENAME];
        
        NSFileManager* fileManager = [NSFileManager defaultManager];
        
        NSData* policyData = nil;
        
        if ( [fileManager fileExistsAtPath:policyFilePath] ) {
            
            policyData = [NSData dataWithContentsOfFile:policyFilePath];
            
            if ([policyData length] != 0 ){
                [self setPolicywithJSONData:policyData];
                
            }
        }
                                                              
        //
        // Now set up for a download of policy 
        _policyURL = [inPolicyURL retain];
            
        [self downloadLatestPolicyWithReachability:inNetworkReachabilityOrNil];
    }
    
    return self;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_blacklistedParams release];
    if ( nil!= _downloadConnection) {
        [_downloadConnection cancel];
        [_downloadConnection release];
    }
    [_downloadData release];
    [_policyURL release];
    [_didSalt release];
    
    [super dealloc];
}

-(void)downloadLatestPolicyWithReachability:(id<QuantcastNetworkReachability>)inNetworkReachabilityOrNil {
    if ( nil != inNetworkReachabilityOrNil && nil != _policyURL && !_waitingForUpdate) {
        
        _waitingForUpdate = YES;
        
        
        // if the network is available, check to see if there is a new
        
        if ([inNetworkReachabilityOrNil currentReachabilityStatus] != NotReachable ) {
            [self startPolicyDownloadWithURL:_policyURL];
        }
        else {
            
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkReachabilityChanged:) name:kQuantcastNetworkReachabilityChangedNotification object:inNetworkReachabilityOrNil];
        }
    }
    
}

-(void)setPolicywithJSONData:(NSData*)inJSONData {
    
    NSDictionary* policyDict = nil;
    NSError* jsonError = nil;
    
    // try to use NSJSONSerialization first. check to see if class is available (iOS 5 or later)
    Class jsonClass = NSClassFromString(@"NSJSONSerialization");
    
    if ( nil != jsonClass ) {
        policyDict = [jsonClass JSONObjectWithData:inJSONData
                                           options:NSJSONReadingMutableLeaves
                                             error:&jsonError];
    }
#if QCMEASUREMENT_ENABLE_JSONKIT 
    else {
        // try with JSONKit
       policyDict = [[JSONDecoder decoder] objectWithData:inJSONData error:&jsonError];
    }
#else
    else {
        NSLog( @"QC MEasurement: ERROR - There is no available JSON decoder to user. Please enable JSONKit in your project!" );
        _policyHasBeenLoaded = NO;
        _policyHasBeenDownloaded = NO;
        return;
    }
#endif
    
    if ( nil != jsonError ) {
        NSLog(@"QC MEasurement: Unable to parse policy JSON data. error = %@", jsonError);
        _policyHasBeenLoaded = NO;
        _policyHasBeenDownloaded = NO;
        return;
    }
    
    @synchronized(self) {
    
        [_blacklistedParams release];
        _blacklistedParams = nil;
        
        if (nil != policyDict) {
            NSArray* blacklistedParams = [policyDict objectForKey:@"blacklist"];
            
            if ( nil != blacklistedParams && [blacklistedParams count] > 0 ) {
                _blacklistedParams = [[NSSet setWithArray:blacklistedParams] retain];
            }
            
            id saltObj = [policyDict objectForKey:@"salt"];
            
            if ( nil != saltObj && [saltObj isKindOfClass:[NSString class]] ) {
                NSString* saltStr = (NSString*)saltObj;
                
                _didSalt = [saltStr retain];
             }
            else if ( nil != saltObj && [saltObj isKindOfClass:[NSNumber class]] ) {
                NSNumber* saltNum = (NSNumber*)saltObj;
                
                _didSalt = [[saltNum stringValue] retain];
            }
            else {
                _didSalt = nil;
            }
            
            if ( _didSalt != nil && [QCMEASUREMENT_DO_NOT_SALT_STRING compare:_didSalt] == NSOrderedSame) {
                [_didSalt release];
                _didSalt = nil;
            }
            
            
            id blackoutTimeObj = [policyDict objectForKey:@"blackout"];
            
            if ( nil != blackoutTimeObj && [blackoutTimeObj isKindOfClass:[NSString class]]) {
                NSString* blackoutTimeStr = (NSString*)blackoutTimeObj;
                int64_t blackoutValue; // this value will be in terms of milliseconds since Jan 1, 1970
                
                if ( nil != blackoutTimeStr && [[NSScanner scannerWithString:blackoutTimeStr] scanLongLong:&blackoutValue]) {
                    NSDate* blackoutTime = [NSDate dateWithTimeIntervalSince1970:( (NSTimeInterval)blackoutValue/1000.0 )];
                    NSDate* nowTime = [NSDate date];
                    
                    // check to ensure that nowTime is greater than blackoutTime 
                    if ( [nowTime compare:blackoutTime] == NSOrderedDescending ) {
                        _isMeasurementBlackedout = NO;
                    }
                    else {
                        _isMeasurementBlackedout = YES;
                    }
                    
                }
                else {
                    _isMeasurementBlackedout = NO;
                }
            }
            else if ( nil != blackoutTimeObj && [blackoutTimeObj isKindOfClass:[NSNumber class]] ) {
                int64_t blackoutValue = [(NSNumber*)blackoutTimeObj longLongValue];
                
                NSDate* blackoutTime = [NSDate dateWithTimeIntervalSince1970:( (NSTimeInterval)blackoutValue/1000.0 )];
                NSDate* nowTime = [NSDate date];
                
                // check to ensure that nowTime is greater than blackoutTime 
                if ( [nowTime compare:blackoutTime] == NSOrderedDescending ) {
                    _isMeasurementBlackedout = NO;
                }
                else {
                    _isMeasurementBlackedout = YES;
                }
            }
            else {
                _isMeasurementBlackedout = NO;
            }
            
            id sessionTimeOutObj = [policyDict objectForKey:@"sessionTimeOutSeconds"];
            _sessionTimeout = QCMEASUREMENT_DEFAULT_MAX_SESSION_PAUSE_SECOND;
            
            if ( nil != sessionTimeOutObj && [sessionTimeOutObj isKindOfClass:[NSString class]]) {
                NSString* timeoutStr = (NSString*)sessionTimeOutObj;
                int64_t timeoutValue; // this value will be in terms of milliseconds since Jan 1, 1970
                
                if ( nil != timeoutStr && [[NSScanner scannerWithString:timeoutStr] scanLongLong:&timeoutValue]) {
                    
                    _sessionTimeout = timeoutValue;
                }
            }
            else if ( nil != sessionTimeOutObj && [sessionTimeOutObj isKindOfClass:[NSNumber class]] ) {
                _sessionTimeout = [(NSNumber*)sessionTimeOutObj doubleValue];
            }
            
            _policyHasBeenLoaded = YES;
        }
    }
}


#pragma mark - Policy Values

-(BOOL)isBlacklistedParameter:(NSString*)inParamName {
    
    BOOL isBlacklisted = NO;
    
    @synchronized(self) {
        isBlacklisted = [_blacklistedParams containsObject:inParamName];
    }
    
    return isBlacklisted;
}


#pragma mark - Download Handling

-(void)networkReachabilityChanged:(NSNotification*)inNotification {
    
    id<QuantcastNetworkReachability> reachabilityObj = (id<QuantcastNetworkReachability>)[inNotification object];
    
    
    if ([reachabilityObj currentReachabilityStatus] != NotReachable ) {
        [self startPolicyDownloadWithURL:_policyURL];
    }
  
}

-(void)startPolicyDownloadWithURL:(NSURL*)inPolicyURL {
    
    if ( nil != inPolicyURL ) {
        
        NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:inPolicyURL 
                                                               cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                           timeoutInterval:QCMEASUREMENT_CONN_TIMEOUT_SECONDS];
        
        
        _downloadData = [[NSMutableData dataWithCapacity:512] retain];
        _downloadConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
        
    }
}

- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [_downloadData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_downloadData appendData:data];
}

- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (self.enableLogging) {
        NSLog(@"QC Measurement: Error downloading policy JSON from connection %@, error = %@", connection, error );
    }

    [_downloadConnection release];
    _downloadConnection = nil;
    
    [_downloadData release];
    _downloadData = nil;

    _waitingForUpdate = NO;

}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (self.enableLogging) {
        NSLog(@"QC Measurement: Successfully downloaded policy from connection %@", connection);
    }
    
    
    [self setPolicywithJSONData:_downloadData];
    
    // check to see if the policy succesfully loaded
    
    if ( self.hasPolicyBeenLoaded ) {
        // save this to the file policy file
        
        // first, determine if there is a saved polciy on disk, if not, create it with default polciy
        NSString* cacheDir = [QuantcastUtils quantcastCacheDirectoryPath];
        
        NSString* policyFilePath = [cacheDir stringByAppendingPathComponent:QCMEASUREMENT_POLICY_FILENAME];
        
        NSFileManager* fileManager = [NSFileManager defaultManager];
        
        if ( ![fileManager createFileAtPath:policyFilePath contents:_downloadData attributes:nil] && self.enableLogging ) {
            NSLog(@"QC Measurement: Could not create downloaded policy JSON at path = %@",policyFilePath);
        }
        
        [_downloadConnection release];
        _downloadConnection = nil;

        [_downloadData release];
        _downloadData = nil;
        
        _policyHasBeenDownloaded = YES;
        
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }

    _waitingForUpdate = NO;

}

#pragma mark - Policy Factory


+(QuantcastPolicy*)policyWithPublisherCode:(NSString*)inPublisherCode networkReachability:(id<QuantcastNetworkReachability>)inReachability {
    
    
    NSString* mcc = nil;
    
    // Setup the Network Info and create a CTCarrier object
    // first check to ensure the developper linked the CoreTelephony framework
    Class telephonyClass = NSClassFromString(@"CTTelephonyNetworkInfo");
    if ( nil != telephonyClass ) {
        CTTelephonyNetworkInfo *networkInfo = [[[telephonyClass alloc] init] autorelease];
        
        if ( nil != networkInfo ) {
            CTCarrier *carrier = [networkInfo subscriberCellularProvider];
            
            
            // Get mobile country code
            NSString* countryCode = [carrier isoCountryCode];
            
            if ( nil != countryCode ) {
                mcc = countryCode;
            }
            
        }
    }
    
    // if the cellular country is not available, use locale country as a proxy
    if ( nil == mcc ) {
        NSLocale* locale = [NSLocale currentLocale];
        
        NSString* localeCountry = [locale objectForKey:NSLocaleCountryCode];
        
        if ( nil != localeCountry ) {
            mcc = [localeCountry uppercaseString];
        }
        else {
            // country is unknown
            mcc = @"XX";
        }
    }
    
    NSString* osString = @"IOS";
        
    NSString* osVersion = [[UIDevice currentDevice] systemVersion];
    
    if ([osVersion compare:@"4.0" options:NSNumericSearch] == NSOrderedAscending) {
        NSLog(@"QC Measurement: Unable to support iOS version %@",osVersion);
        return nil;
    }
    else if ([osVersion compare:@"5.0" options:NSNumericSearch] == NSOrderedAscending) {
        osString = @"IOS4";
    }
    else if ([osVersion compare:@"6.0" options:NSNumericSearch] == NSOrderedAscending) {
        osString = @"IOS5";
    }
    else {
        osString = @"IOS";
    }
    
    
    NSString* policyURLStr = [NSString stringWithFormat:QCMEASUREMENT_POLICY_URL_FORMAT,inPublisherCode,QCMEASUREMENT_API_VERSION,osString,[mcc uppercaseString]];
    
    NSURL* policyURL = [NSURL URLWithString:policyURLStr];
        
    return [[[QuantcastPolicy alloc] initWithPolicyURL:policyURL reachability:inReachability] autorelease];
}

#pragma mark - Debugging Support
@synthesize enableLogging;

@end
