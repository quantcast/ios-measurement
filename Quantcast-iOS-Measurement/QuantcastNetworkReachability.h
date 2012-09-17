//
// Copyright (c) 2012, Quantcast Corp.
// This software is licensed under the Quantcast Mobile API Beta Evaluation Agreement and may not be used except as permitted thereunder or copied, modified, or distributed in any case.
//

#import <Foundation/Foundation.h>

typedef enum {
    NotReachable = 0,
    ReachableViaWiFi,
    ReachableViaWWAN
} QuantcastNetworkStatus;

#define kQuantcastNetworkReachabilityChangedNotification @"QuantcastNetworkReachabilityChangedNotification"

/*!
 @internal
 @protocol QuantcastNetworkReachability
 @abstract Protocol for object that provides network reachability status.
 */
@protocol QuantcastNetworkReachability <NSObject>

@required
-(QuantcastNetworkStatus)currentReachabilityStatus;

@end
