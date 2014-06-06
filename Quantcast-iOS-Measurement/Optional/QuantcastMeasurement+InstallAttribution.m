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

#import <iAd/iAd.h>
#import "QuantcastMeasurement+InstallAttribution.h"
#import "QuantcastMeasurement+Internal.h"
#import "QuantcastUtils.h"

@interface QuantcastMeasurement (){
 }
@property (strong, nonatomic) NSString* quantcastAPIKey;

@end

#define QCMEASUREMENT_IAD_ATTRIBUTED_INSTALL_DEFAULTS   @"com.quantcast.measure.pref.attribution.iad-attributed-install"
#define QCMEASUREMENT_IAD_APP_INSTALL_DATE_DEFAULTS     @"com.quantcast.measure.pref.attribution.iad-install-date"
#define QCMEASUREMENT_IAD_ATTRIBUTION_VERSION_DEFAULTS  @"com.quantcast.measure.pref.attribution.iad-attribution-version"

@implementation QuantcastMeasurement (InstallAttribution)

-(void)logiAdAttribution {
    
    Class adClientClass = NSClassFromString(@"ADClient");
    
    if ( nil == adClientClass ) {
        
        return;
    }
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
   
    BOOL shouldFetchiAdAttribution = ( nil == [defaults objectForKey:QCMEASUREMENT_IAD_ATTRIBUTED_INSTALL_DEFAULTS] );
    
    // first check to see if we've gathered atttribution before
    if ( shouldFetchiAdAttribution ) {
        QUANTCAST_LOG(@"Fetching this app's iAd attribution status.");
        
        // the iOS 7.1 way
        [[ADClient sharedClient] determineAppInstallationAttributionWithCompletionHandler:^(BOOL appInstallationWasAttributedToiAd) {
            [defaults setBool:appInstallationWasAttributedToiAd forKey:QCMEASUREMENT_IAD_ATTRIBUTED_INSTALL_DEFAULTS];
            [defaults setObject:[NSNumber numberWithInt:1] forKey:QCMEASUREMENT_IAD_ATTRIBUTION_VERSION_DEFAULTS];
            
            if ( appInstallationWasAttributedToiAd ) {
                NSDate* installDate = [QuantcastUtils appInstallTime];
                [defaults setObject:installDate forKey:QCMEASUREMENT_IAD_APP_INSTALL_DATE_DEFAULTS];
            }
            
            [defaults synchronize];
            [self setiAdAttributionLabels];
        }];
    }
    else {
        [self setiAdAttributionLabels];
    }
}

-(void)setiAdAttributionLabels {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    if ( [defaults boolForKey:QCMEASUREMENT_IAD_ATTRIBUTED_INSTALL_DEFAULTS]) {
        NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd"];
        
        NSDate* installDate = [defaults objectForKey:QCMEASUREMENT_IAD_APP_INSTALL_DATE_DEFAULTS];
        
        NSString* appIDString = self.quantcastAPIKey;
        if ( nil == appIDString ) {
            appIDString = [[NSBundle mainBundle] bundleIdentifier];
            appIDString = [appIDString stringByReplacingOccurrencesOfString:@"." withString:@"%2E"];
        }
        
        NSString* iAdLabel = [NSString stringWithFormat:@"iAd Install Cohort.%@", appIDString];
        
        if ( nil != installDate ) {
            iAdLabel = [NSString stringWithFormat:@"%@.Installed %@", iAdLabel, [formatter stringFromDate:installDate]];
        }
        
        QUANTCAST_LOG(@"Setting iAd attribution label to '%@'", iAdLabel);

        [self addInternalSDKAppLabels:@[iAdLabel] networkLabels:nil];
    }

}


@end
