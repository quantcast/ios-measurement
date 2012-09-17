//
// Copyright (c) 2012, Quantcast Corp.
// This software is licensed under the Quantcast Mobile API Beta Evaluation Agreement and may not be used except as permitted thereunder or copied, modified, or distributed in any case.
//

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
