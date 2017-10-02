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

#import "QuantcastMeasurement.h"

/*!
 QuantcastMeasurement+Advertising
 @abstract This extension to QuantcastMeasurement provides you with standardized in-app ad campaign reporting.
 @discussion The Advertising extension can be used anybody looking to generate standardized audience exposure reports for ad campaigns ran within your app.
 
 Requires the following frameworks:
 <ul>
 <li>AdSupport.framework</li>
 </ul>
 */
@interface QuantcastMeasurement (Advertising)

/*!
 @method logAdImpresionForCampaign:media:placement:networkLabels:
 @abstract Logs a campaign event to the Quantcast Measurement SDK.
 @discussion This is the primarily means for logging campaigns with Quantcast Measurement.
 @param inCampaignNameOrNil A string that identifies the campaign being logged.   This can be nil
 @param inMediaOrNil         A String that identifies the media of this campaign.  This can be nil
 @param inPlacementOrNil      A String that identifies the placement of the media.  This can be nil
 @param inAppLabelsOrNil  Either an NSString object or NSArray object containing one or more NSString objects, each of which are a distinct label to be applied to this event. A label is any arbitrary string that you want to be ascociated with this event, and will create a second dimension in Quantcast Measurement reporting. Nominally, this is a "user class" indicator. For example, you might use one of two labels in your app: one for user who ave not purchased an app upgrade, and one for users who have purchased an upgrade.
 */
-(void)logAdImpressionForCampaign:(NSString*)inCampaignNameOrNil media:(NSString*)inMediaOrNil placement:(NSString*)inPlacementOrNil withAppLabels:(id<NSObject>)inAppLabelsOrNil;
@end
