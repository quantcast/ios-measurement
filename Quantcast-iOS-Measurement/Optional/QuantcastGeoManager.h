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

#if QCMEASUREMENT_ENABLE_GEOMEASUREMENT

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "QuantcastEventLogger.h"

/*!
 @class QuantcastGeoManager
 @internal
 */

@interface QuantcastGeoManager : NSObject <CLLocationManagerDelegate>
@property (assign,nonatomic) BOOL geoLocationEnabled;
@property (readonly,nonatomic) BOOL isGeoMonitoringActive;

-(id)initWithEventLogger:(id<QuantcastEventLogger>)inEventLogger;

-(void)privacyPolicyUpdate:(NSNotification*)inNotification;

@end

#endif