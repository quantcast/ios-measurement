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

#import "QuantcastMeasurement+Advertising.h"
#import "QuantcastEventLogger.h"
#import "QuantcastUtils.h"
#import "QuantcastEvent.h"
#import "QuantcastParameters.h"

@interface QuantcastMeasurement ()<QuantcastEventLogger>
@property (readonly,nonatomic) BOOL isMeasurementActive;
@end

@implementation QuantcastMeasurement (Advertising)
-(void)logAdImpressionForCampaign:(NSString*)inCampaignNameOrNil media:(NSString*)inMediaOrNil placement:(NSString*)inPlacementOrNil withAppLabels:(id<NSObject>)inAppLabelsOrNil{
    if ( !self.isOptedOut ) {
        [self launchOnQuantcastThread:^(NSDate *timestamp) {
            if (self.isMeasurementActive) {
                
                NSMutableArray* netLabels = [NSMutableArray arrayWithCapacity:3];
                if( nil != inCampaignNameOrNil ){
                    NSString* campaignLabel = [NSString stringWithFormat:@"ad-campaign.%@%@",
                                               inCampaignNameOrNil,
                                               nil != inMediaOrNil ? [NSString stringWithFormat:@".%@", inMediaOrNil ] : @""];
                    [netLabels addObject:campaignLabel];
                }
                
                if (nil != inMediaOrNil){
                    NSString* mediaLabel = [NSString stringWithFormat:@"ad-media.%@",
                                            inMediaOrNil];
                    [netLabels addObject:mediaLabel];
                }
                
                
                if( nil != inPlacementOrNil ){
                    if( nil != inCampaignNameOrNil){
                        NSString* placementCampaignLabel = [NSString stringWithFormat:@"ad-placement.%@.campaign.%@",
                                                            inPlacementOrNil, inCampaignNameOrNil ];
                        if(nil != inMediaOrNil){
                            placementCampaignLabel = [NSString stringWithFormat:@"%@.%@", placementCampaignLabel, inMediaOrNil];
                        }
                        [netLabels addObject:placementCampaignLabel];
                    }
                    
                    if (nil != inMediaOrNil){
                        NSString* placementMedia = [NSString stringWithFormat:@"ad-placement.%@.media.%@", inPlacementOrNil, inMediaOrNil];
                        [netLabels addObject:placementMedia];
                    }
                    
                }
                
                id<NSObject> combinedLabels = [QuantcastUtils combineLabels:netLabels withLabels:inAppLabelsOrNil];
                
                QuantcastEvent* e = [QuantcastEvent eventWithSessionID:self.currentSessionID eventTimestamp:timestamp applicationInstallID:self.appInstallIdentifier];
                    
                [e putParameter:QCPARAMETER_EVENT withValue:QCMEASUREMENT_EVENT_ADEVENT];
                [e putParameter:QCPARAMETER_CAMPAIGN withValue:inCampaignNameOrNil];
                [e putParameter:QCPARAMETER_MEDIA withValue:inMediaOrNil];
                [e putParameter:QCPARAMETER_PLACEMENT withValue:inPlacementOrNil];
                [e putAppLabels:[QuantcastUtils combineLabels:self.appLabels withLabels:combinedLabels] networkLabels:nil];
            
                
                [self recordEvent:e];
            }
            else {
                QUANTCAST_ERROR(@"logCampaign:withMedia:andNetworkLabels: was called without first calling beginMeasurementSession:");
            }
        }];
    }
}
@end
