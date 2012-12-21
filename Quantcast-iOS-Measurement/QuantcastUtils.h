/*
 * Copyright 2012 Quantcast Corp.
 *
 * This software is licensed under the Quantcast Mobile App Measurement Terms of Service
 * https://www.quantcast.com/learning-center/quantcast-terms/mobile-app-measurement-tos
 * (the “License”). You may not use this file unless (1) you sign up for an account at
 * https://www.quantcast.com and click your agreement to the License and (2) are in
 * compliance with the License. See the License for the specific language governing
 * permissions and limitations under the License.
 *
 */

#import <Foundation/Foundation.h>

/*!
 @class QuantcastUtils
 @internal
 */
@interface QuantcastUtils : NSObject

+(NSString*)quantcastCacheDirectoryPath;
+(NSString*)quantcastCacheDirectoryPathCreatingIfNeeded;

+(NSString*)quantcastDataGeneratingDirectoryPath;
+(NSString*)quantcastDataReadyToUploadDirectoryPath;
+(NSString*)quantcastUploadInProgressDirectoryPath;

+(void)emptyAllQuantcastCaches;

+(NSString*)quantcastHash:(NSString*)inStrToHash;

+(NSData*)gzipData:(NSData*)inData error:(NSError**)outError;


@end
