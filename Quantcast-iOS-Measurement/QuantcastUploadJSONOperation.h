//
// Copyright (c) 2012, Quantcast Corp.
// This software is licensed under the Quantcast Mobile API Beta Evaluation Agreement and may not be used except as permitted thereunder or copied, modified, or distributed in any case.
//

#import <Foundation/Foundation.h>

@class QuantcastDataManager;

/*!
 @class QuantcastUploadJSONOperation
 @internal
 */
@interface QuantcastUploadJSONOperation : NSOperation <NSURLConnectionDelegate> {
    QuantcastDataManager* _dataManager;
    NSURLRequest* _request;
    NSURLConnection* _connection;
    
    NSString* _jsonFilePath;
    NSString* _uploadID;
    
    BOOL _isExecuting;
    BOOL _isFinished;
    BOOL _isSuccessful;
    
    NSDate* _startTime;

}
@property(nonatomic, readonly ) BOOL successful;
@property(nonatomic, assign) BOOL enableLogging;

-(id)initUploadForJSONFile:(NSString*)inJSONFilePath withUploadID:(NSString*)inUploadID withURLRequest:(NSURLRequest*)inURLRequest dataManager:(QuantcastDataManager*)inDataManager;

// these methods are "private"
-(void)done;
-(void)uploadFailed;

@end
