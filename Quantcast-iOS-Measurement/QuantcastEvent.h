//
// Copyright (c) 2012, Quantcast Corp.
// This software is licensed under the Quantcast Mobile API Beta Evaluation Agreement and may not be used except as permitted thereunder or copied, modified, or distributed in any case.
//

#import <UIKit/UIKit.h>
#import "QuantcastNetworkReachability.h"

@class QuantcastPolicy;

/*!
 @class QuantcastEvent
 @internal
 */
@interface QuantcastEvent : NSObject {
    
    NSDate* _timestamp;
    NSString* _sessionID;
    
    NSMutableDictionary* _parameters;
    
}
@property (readonly) NSDate* timestamp;
@property (readonly) NSString* sessionID;

// time stamp is set to the current time
-(id)initWithSessionID:(NSString*)inSessionID;
-(id)initWithSessionID:(NSString*)inSessionID timeStamp:(NSDate*)inTimeStamp;


#pragma mark - Parameter Management
@property (readonly) NSDictionary* parameters;

-(void)putParameter:(NSString*)inParamKey withValue:(id)inValue enforcingPolicy:(QuantcastPolicy*)inPolicyOrNil;
-(id)getParameter:(NSString*)inParamKey;

#pragma mark - JSON conversion

-(NSString*)JSONStringEnforcingPolicy:(QuantcastPolicy*)inPolicyOrNil;

#pragma mark - Debugging
@property (assign,nonatomic) BOOL enableLogging;

- (NSString *)description;

#pragma mark - Event Factory

+(QuantcastEvent*)eventWithSessionID:(NSString*)inSessionID
                     enforcingPolicy:(QuantcastPolicy*)inPolicy;


+(QuantcastEvent*)openSessionEventWithClientUserHash:(NSString*)inHashedUserIDOrNil
                                    newSessionReason:(NSString*)inReason
                                       networkStatus:(QuantcastNetworkStatus)inNetworkStatus
                                           sessionID:(NSString*)inSessionID
                                       publisherCode:(NSString*)inPublisherCode
                                          appleAppId:(NSNumber*)inAppleAppIDOrNil
                                    deviceIdentifier:(NSString*)inDeviceID
                                       appIdentifier:(NSString*)inAppID
                                     enforcingPolicy:(QuantcastPolicy*)inPolicy
                                         eventLabels:(NSString*)inEventLabelsOrNil;

+(QuantcastEvent*)closeSessionEventWithSessionID:(NSString*)inSessionID 
                                 enforcingPolicy:(QuantcastPolicy*)inPolicy
                                     eventLabels:(NSString*)inEventLabelsOrNil;

+(QuantcastEvent*)pauseSessionEventWithSessionID:(NSString*)inSessionID 
                                 enforcingPolicy:(QuantcastPolicy*)inPolicy
                                     eventLabels:(NSString*)inEventLabelsOrNil;

+(QuantcastEvent*)resumeSessionEventWithSessionID:(NSString*)inSessionID 
                                  enforcingPolicy:(QuantcastPolicy*)inPolicy
                                      eventLabels:(NSString*)inEventLabelsOrNil;


+(QuantcastEvent*)logEventEventWithEventName:(NSString*)inEventName
                                 eventLabels:(NSString*)inEventLabelsOrNil   
                                   sessionID:(NSString*)inSessionID 
                             enforcingPolicy:(QuantcastPolicy*)inPolicy;

+(QuantcastEvent*)logUploadLatency:(NSUInteger)inLatencyMilliseconds
                       forUploadId:(NSString*)inUploadID
                     withSessionID:(NSString*)inSessionID 
                   enforcingPolicy:(QuantcastPolicy*)inPolicy;

+(QuantcastEvent*)geolocationEventWithCountry:(NSString*)inCountry
                                     province:(NSString*)inLocality
                                         city:(NSString*)inCity
                                withSessionID:(NSString*)inSessionID 
                              enforcingPolicy:(QuantcastPolicy*)inPolicy;



+(QuantcastEvent*)networkReachabilityEventWithNetworkStatus:(QuantcastNetworkStatus)inNetworkStatus
                                              withSessionID:(NSString*)inSessionID
                                            enforcingPolicy:(QuantcastPolicy*)inPolicy;


@end
