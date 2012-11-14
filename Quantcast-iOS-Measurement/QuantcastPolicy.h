//
// Copyright (c) 2012, Quantcast Corp.
// This software is licensed under the Quantcast Mobile API Beta Evaluation Agreement and may not be used except as permitted thereunder or copied, modified, or distributed in any case.
//

#import <Foundation/Foundation.h>
#import "QuantcastNetworkReachability.h"

/*!
 @class QuantcastPolicy
 @internal
 */
@interface QuantcastPolicy : NSObject <NSURLConnectionDataDelegate> {
    NSSet* _blacklistedParams;
    NSString* _didSalt;
    BOOL _isMeasurementBlackedout;
    
    BOOL _policyHasBeenLoaded;
    BOOL _policyHasBeenDownloaded;
    BOOL _waitingForUpdate;
    
    NSURL* _policyURL;
    NSURLConnection* _downloadConnection;
    NSMutableData* _downloadData;
    
    NSTimeInterval _sessionTimeout;
}
@property (readonly) NSString* deviceIDHashSalt;
@property (readonly) BOOL isMeasurementBlackedout;
@property (readonly) BOOL hasPolicyBeenLoaded;
@property (readonly) BOOL hasUpdatedPolicyBeenDownloaded;
@property (readonly) NSTimeInterval sessionPauseTimeoutSeconds;

-(id)initWithPolicyURL:(NSURL*)inPolicyURL reachability:(id<QuantcastNetworkReachability>)inNetworkReachabilityOrNil enableLogging:(BOOL)inEnableLogging;
-(void)downloadLatestPolicyWithReachability:(id<QuantcastNetworkReachability>)inNetworkReachabilityOrNil;

-(BOOL)isBlacklistedParameter:(NSString*)inParamName;

+(QuantcastPolicy*)policyWithAPIKey:(NSString*)inQuantcastAPIKey networkReachability:(id<QuantcastNetworkReachability>)inReachability enableLogging:(BOOL)inEnableLogging;

#pragma mark - Debugging Support
@property (assign) BOOL enableLogging;


@end
