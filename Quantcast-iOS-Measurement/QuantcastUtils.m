//
// Copyright (c) 2012, Quantcast Corp.
// This software is licensed under the Quantcast Mobile API Beta Evaluation Agreement and may not be used except as permitted thereunder or copied, modified, or distributed in any case.
//

#ifndef __has_feature
#define __has_feature(x) 0
#endif
#ifndef __has_extension
#define __has_extension __has_feature // Compatibility with pre-3.0 compilers.
#endif

#if __has_feature(objc_arc) && __clang_major__ >= 3
#error "Quantcast Measurement is not designed to be used with ARC. Please add '-fno-objc-arc' to this file's compiler flags"
#endif // __has_feature(objc_arc)

#import "QuantcastUtils.h"
#import "QuantcastParameters.h"

@interface QuantcastUtils ()

+(int64_t)qhash2:(const int64_t)inKey string:(NSString*)inString;

@end

@implementation QuantcastUtils

+(NSString*)quantcastCacheDirectoryPath {
    NSArray* cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    
    if ( [cachePaths count] > 0 ) {
        
        NSString* cacheDir = [cachePaths objectAtIndex:0];
        
        NSString* qcCachePath = [cacheDir stringByAppendingPathComponent:QCMEASUREMENT_CACHE_DIRNAME];
        
        return qcCachePath;
    }

    return nil;
}

+(NSString*)quantcastCacheDirectoryPathCreatingIfNeeded {
    NSString* cacheDir = [QuantcastUtils quantcastCacheDirectoryPath];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:cacheDir]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:nil]){
            NSLog(@"QC Measurement: Unable to create cache director = %@", cacheDir );
            return nil;
        }
    }
    
    return cacheDir;
}

+(NSString*)quantcastDataGeneratingDirectoryPath {
    NSString*  cacheDir = [QuantcastUtils quantcastCacheDirectoryPath];
    
    cacheDir = [cacheDir stringByAppendingPathComponent:@"generating"];   
    
    // determine if directory exists. If it doesn't create it.
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:cacheDir]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:nil]){
            NSLog(@"QC Measurement: Unable to create cache director = %@", cacheDir );
            return nil;
        }
    }
    
    return cacheDir;
}

+(NSString*)quantcastDataReadyToUploadDirectoryPath {
    NSString*  cacheDir = [QuantcastUtils quantcastCacheDirectoryPath];
    
    cacheDir =  [cacheDir stringByAppendingPathComponent:@"ready"];
    // determine if directory exists. If it doesn't create it.
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:cacheDir]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:nil]){
            NSLog(@"QC Measurement: Unable to create cache director = %@", cacheDir );
            return nil;
        }
    }
    
    return cacheDir;
}
+(NSString*)quantcastUploadInProgressDirectoryPath {
    NSString*  cacheDir = [QuantcastUtils quantcastCacheDirectoryPath];
    
    cacheDir = [cacheDir stringByAppendingPathComponent:@"uploading"];
    // determine if directory exists. If it doesn't create it.
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:cacheDir]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:nil]){
            NSLog(@"QC Measurement: Unable to create cache director = %@", cacheDir );
            return nil;
        }
    }
    
    return cacheDir;
}

+(void)emptyAllQuantcastCaches {
    NSFileManager* fileManager = [NSFileManager defaultManager];    
    
    NSString* cacheDir = [QuantcastUtils quantcastCacheDirectoryPath];
    
    NSError* dirError = nil;
    NSArray* dirContents = [fileManager contentsOfDirectoryAtPath:cacheDir error:&dirError];
    
    if ( nil == dirError && [dirContents count] > 0 ) {
        
        NSSet* filesToKeepSet = [NSSet setWithObjects:QCMEASUREMENT_POLICY_FILENAME, nil];
        
        for (NSString* filename in dirContents) {
            if ( ![filesToKeepSet containsObject:filename] ) {
                NSError* error = nil;
                
                [fileManager removeItemAtPath:[[QuantcastUtils quantcastCacheDirectoryPath] stringByAppendingPathComponent:filename] error:&error];
                if (nil != error) {
                    NSLog(@"QC Measurement: Unable to delete Quantcast Cache directory! error = %@", error);
                }

            }
        }
    } 
}

+(int64_t)qhash2:(const int64_t)inKey string:(NSString*)inString {
    
    const char * str = [inString UTF8String];
    
    int64_t h = inKey;
    
    for (NSUInteger i = 0; i < [inString length]; ++i ) {
        int32_t h32 = (int32_t)h; // javascript only does bit shifting on 32 bits, must mimic that here
        
        char character = str[i];
        
        h32 ^= character;
        
        h = h32;
        
        h += (int64_t)(h32 << 1)+(h32 << 4)+(h32 << 7)+(h32 << 8)+(h32 << 24);
    }
    
    return h;
}


+(NSString*)quantcastHash:(NSString*)inStrToHash {
    const int64_t h1 = 0x811c9dc5;
    const int64_t h2 = 0xc9dc5118;
    
    double hash1 = [QuantcastUtils qhash2:h1 string:inStrToHash];
    double hash2 = [QuantcastUtils qhash2:h2 string:inStrToHash];
    
    int64_t value = round( fabs(hash1*hash2)/(double)65536.0 );
    
    NSString* hashStr = [NSString stringWithFormat:@"%qx", value];
    
    return hashStr;
}

#import "zlib.h" 
+(NSData*)gzipData:(NSData*)inData error:(NSError**)outError {
    if (!inData || [inData length] == 0)  
    {  
        if ( NULL != outError ) {
            NSDictionary* errDict = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Could not compress an empty or null NSData object", nil] 
                                                            forKeys:[NSArray arrayWithObjects:NSLocalizedDescriptionKey, nil]];
        
            *outError = [NSError errorWithDomain:@"QuantcastMeasurment" code:-1 userInfo:errDict];
        }
        return nil;  
    }  
    int gzipErr;
    
    z_stream gzipStream;
    
    gzipStream.zalloc = Z_NULL;
    gzipStream.zfree = Z_NULL;
    gzipStream.opaque = Z_NULL;
    gzipStream.total_out = 0;
    gzipStream.next_in = (Bytef*)[inData bytes];
    gzipStream.avail_in = [inData length];
    
    gzipErr = deflateInit2(&gzipStream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15+16, 8, Z_DEFAULT_STRATEGY );
    
    if ( Z_OK != gzipErr ) {
        
        if ( NULL != outError ) {
            NSString* errMsg;
            
            switch (gzipErr) {
                case Z_MEM_ERROR:
                    errMsg = @"Insufficient memory available to init compression library.";
                    break;
                case Z_STREAM_ERROR:
                    errMsg = @"Invalid compression level passed to compression library.";
                    break;
                case Z_VERSION_ERROR:
                    errMsg = @"zlib library version (zlib_version) is incompatible with the version assumed by the caller.";
                    break;
                default:
                    if ( NULL != gzipStream.msg ) {
                        errMsg = [NSString stringWithFormat:@"zlib err = %s", gzipStream.msg];
                    }
                    else {
                        errMsg = @"Unknown compression error.";
                    }
                    break;
            }
            
            NSDictionary* errDict = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:errMsg, nil] 
                                                                forKeys:[NSArray arrayWithObjects:NSLocalizedDescriptionKey, nil]];
            
            *outError = [NSError errorWithDomain:@"QuantcastMeasurment" code:gzipErr userInfo:errDict];
            
        }
        
        return nil;
    }
    
    int compResult = Z_OK;


    
    NSMutableData* compressedResults = [NSMutableData dataWithLength:[inData length]*1.25];
    
    while ( Z_OK == compResult ) {
        
        if (gzipStream.total_out >= [compressedResults length]) {
            [compressedResults increaseLengthBy:[inData length]*0.5];
        }
        
        gzipStream.next_out = [compressedResults mutableBytes] + gzipStream.total_out;
        gzipStream.avail_out = [compressedResults length] - gzipStream.total_out;
        
        
        compResult = deflate(&gzipStream, Z_FINISH );
    }
    
    if ( Z_STREAM_END != compResult ) {
        if ( NULL != outError ) {
            NSString* errMsg;
        
            switch (compResult) {
                case Z_STREAM_ERROR:
                    errMsg = @"stream state was inconsistent (for example if next_in or next_out was NULL)";
                    break;
                default:
                    if ( NULL != gzipStream.msg ) {
                        errMsg = [NSString stringWithFormat:@"zlib err = %s", gzipStream.msg];
                    }
                    else {
                        errMsg = @"Unknown compression error.";
                    }
                    break;
            }
            NSDictionary* errDict = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:errMsg, nil] 
                                                                forKeys:[NSArray arrayWithObjects:NSLocalizedDescriptionKey, nil]];
            
            *outError = [NSError errorWithDomain:@"QuantcastMeasurment" code:gzipErr userInfo:errDict];
            
            deflateEnd(&gzipStream);
        }
        return nil;            
    }    
    
    [compressedResults setLength:gzipStream.total_out];
    
    deflateEnd(&gzipStream);
    
    return [NSData dataWithData:compressedResults];
}

@end
