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

#import "QuantcastMeasurement+Networks.h"
#import "QuantcastMeasurement+Internal.h"
#import "QuantcastEvent.h"
#import "QuantcastParameters.h"
#import "QuantcastUtils.h"

@interface QuantcastMeasurement (){
    id<NSObject> _networkLabels;
}
-(void)launchOnQuantcastThread:(void (^)(NSDate *))block;
@end

@implementation QuantcastMeasurement (Networks)

-(NSString*)beginMeasurementSessionWithAPIKey:(NSString*)inQuantcastAPIKey
                            attributedNetwork:(NSString*)inNetworkPCode
                               userIdentifier:(NSString*)inUserIdentifierOrNil
                                    appLabels:(id<NSObject>)inAppLabelsOrNil
                                networkLabels:(id<NSObject>)inNetworkLabelsOrNil
                      appIsDirectedAtChildren:(BOOL)inIsAppDirectedAtChildren
{
    if (nil == inNetworkPCode) {
       QUANTCAST_ERROR(@"You must pass a network p-code in attributedNetwork: if you are going to start measurement with the Network form of beginMeasurementSessionWithAPIKey:");
        return nil;
    }
    
    NSString* hashedUserID = [self internalBeginSessionWithAPIKey:inQuantcastAPIKey attributedNetwork:inNetworkPCode userIdentifier:inUserIdentifierOrNil appLabels:inAppLabelsOrNil
                                                    networkLabels:[QuantcastUtils combineLabels:self.networkLabels withLabels:inNetworkLabelsOrNil] appIsDeclaredDirectedAtChildren:inIsAppDirectedAtChildren];
    
    return hashedUserID;
}

-(void)endMeasurementSessionWithAppLabels:(id<NSObject>)inAppLabelsOrNil networkLabels:(id<NSObject>)inNetworkLabelsOrNil {
    if([self validateNetworkForMessageNamed:NSStringFromSelector(_cmd)]){
        [self internalEndMeasurementSessionWithAppLabels:inAppLabelsOrNil networkLabels:[QuantcastUtils combineLabels:self.networkLabels withLabels:inNetworkLabelsOrNil]];
    }
}

-(void)pauseSessionWithAppLabels:(id<NSObject>)inAppLabelsOrNil networkLabels:(id<NSObject>)inNetworkLabelsOrNil {
    if([self validateNetworkForMessageNamed:NSStringFromSelector(_cmd)]){
        [self internalPauseSessionWithAppLabels:inAppLabelsOrNil networkLabels:[QuantcastUtils combineLabels:self.networkLabels withLabels:inNetworkLabelsOrNil]];
    }
}


-(void)resumeSessionWithAppLabels:(id<NSObject>)inAppLabelsOrNil networkLabels:(id<NSObject>)inNetworkLabelsOrNil {
    if([self validateNetworkForMessageNamed:NSStringFromSelector(_cmd)]){
        [self internalResumeSessionWithAppLabels:inAppLabelsOrNil networkLabels:[QuantcastUtils combineLabels:self.networkLabels withLabels:inNetworkLabelsOrNil]];
    }
}


-(NSString*)recordUserIdentifier:(NSString*)inUserIdentifierOrNil withAppLabels:(id<NSObject>)inAppLabelsOrNil networkLabels:(id<NSObject>)inNetworkLabelsOrNil {
    if([self validateNetworkForMessageNamed:NSStringFromSelector(_cmd)]){
        return [self internalRecordUserIdentifier:inUserIdentifierOrNil withAppLabels:inAppLabelsOrNil networkLabels:[QuantcastUtils combineLabels:self.networkLabels withLabels:inNetworkLabelsOrNil]];
    }
    return nil;
}


-(void)logEvent:(NSString*)inEventName withAppLabels:(id<NSObject>)inAppLabelsOrNil networkLabels:(id<NSObject>)inNetworkLabelsOrNil {
    if([self validateNetworkForMessageNamed:NSStringFromSelector(_cmd)]){
        [self internalLogEvent:inEventName withAppLabels:inAppLabelsOrNil networkLabels:[QuantcastUtils combineLabels:self.networkLabels withLabels:inNetworkLabelsOrNil]];
    }
}

-(void)logNetworkEvent:(NSString*)inNetworkEventName withNetworkLabels:(id<NSObject>)inNetworkLabelsOrNil {
    if([self validateNetworkForMessageNamed:NSStringFromSelector(_cmd)]){
        if ( !self.isOptedOut ) {
            [self launchOnQuantcastThread:^(NSDate *timestamp) {
                if (self.isMeasurementActive) {
                    QuantcastEvent* e = [QuantcastEvent logNetworkEventEventWithEventName:inNetworkEventName eventNetworkLabels:[QuantcastUtils combineLabels:self.networkLabels withLabels:inNetworkLabelsOrNil] sessionID:self.currentSessionID eventTimestamp:timestamp applicationInstallID:self.appInstallIdentifier];
                    
                    [self recordEvent:e];
                }
                else {
                   QUANTCAST_LOG(@"logNetworkEvent:withNetworkLabels: was called without first calling beginMeasurementSession:");
                }
            }];
        }
    }
}

-(void)setNetworkLabels:(id<NSObject>)inNetworkLabels{
    _networkLabels = inNetworkLabels;
}

-(id<NSObject>)networkLabels{
    return [QuantcastUtils combineLabels:_networkLabels withLabels:self.internalSDKNetworkLabels];
}

-(BOOL)validateNetworkForMessageNamed:(NSString*)name{
    BOOL allow = self.hasNetworkIntegration;
    if (!allow) {
       QUANTCAST_ERROR(@"%@ should only be called for network integrations. Please see QuantcastMeasurement+Networks.h for more information", name);
    }
    return allow;
}
@end
