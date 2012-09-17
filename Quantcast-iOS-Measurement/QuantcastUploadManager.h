//
// Copyright (c) 2012, Quantcast Corp.
// This software is licensed under the Quantcast Mobile API Beta Evaluation Agreement and may not be used except as permitted thereunder or copied, modified, or distributed in any case.
//

#import <UIKit/UIKit.h>
#import "QuantcastNetworkReachability.h"

@class QuantcastDataManager;

/*!
 @class QuantcastUploadManager
 @internal
 */
@interface QuantcastUploadManager : NSObject {
    BOOL _ableToUpload;
}

+(NSString*)generateUploadID;

-(id)initWithReachability:(id<QuantcastNetworkReachability>)inNetworkReachabilityOrNil;




#pragma mark - Upload Management

/*!
 @internal
 @method initiateUploadForReadyJSONFilesWithDataManager:
 @abstract scans for the ready directory for JSON files, then initiates a transfer for each, subject to a rate limit
 @param inDataManager the data manger that latency tracking events should be posted to.
 */
-(void)initiateUploadForReadyJSONFilesWithDataManager:(QuantcastDataManager*)inDataManager;

/*!
 @internal
 @method urlRequestForJSONFile:
 @abstract creates a NSURLRequest that is ready to be uploaded with the contents of the passed file, then relocates
    the file to the uploading directory.
 @param inJSONFilePath file path to the location of where the json file currently resides.
 @param outUploadID a pointer to a NSString* which will be assigned to a string containing the upload ID found in the JSON file
 @param outNewFilePath a pointer to a NSString* which will be assigned to a string containing the new file path to the previously passed JSON file.
 @result a NSURLRequest configured to properly post the json data
 */
-(NSURLRequest*)urlRequestForJSONFile:(NSString*)inJSONFilePath 
                    reportingUploadID:(NSString**)outUploadID 
                          newFilePath:(NSString**)outNewFilePath;


#pragma mark - Debugging
@property (assign,nonatomic) BOOL enableLogging;

- (NSString *)description;


@end
