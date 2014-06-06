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

#import <Foundation/Foundation.h>
#import "QuantcastMeasurement.h"

/*!
 @class QuantcastMeasurement+InstallAttribution
 @abstract This extension to QuantcastMeasurement provides you with standardized install attribution and install cohorts reports.
 @discussion The InstallAttribution extension can be used anybody looking to incorporate install source cohort analysis into the Quantcast Measure for Apps profiles. 
 
    Requires the following frameworks:
    <ul>
    <li>iAd.framework</li>
    <li>AdSupport.framework</li>
    </ul>
 */
@interface QuantcastMeasurement (InstallAttribution)

/*!
 @method logiAdAttribution
 @abstract Captures and logs iAd attribution
 @discussion Call this method to capture the iAd install attribution for this app. The method will log the iAd attribution information such that you will get an install cohort audience report on Quantcast.com. Reports will be listed under your network's audience segments and organized by your app's API Key.
 
     This method should be called prior to or as soon as QuantcastMeasure is initialized.
 */
-(void)logiAdAttribution;

@end
