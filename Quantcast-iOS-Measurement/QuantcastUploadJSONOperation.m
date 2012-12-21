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

#import "QuantcastUploadJSONOperation.h"
#import "QuantcastDataManager.h"
#import "QuantcastUtils.h"
#import "QuantcastMeasurement.h"

@interface QuantcastMeasurement ()
// declare "private" method here
-(void)logUploadLatency:(NSUInteger)inLatencyMilliseconds forUploadId:(NSString*)inUploadID;

@end

@implementation QuantcastUploadJSONOperation
@synthesize successful=_isSuccessful;
@synthesize enableLogging;

-(id)initUploadForJSONFile:(NSString*)inJSONFilePath withUploadID:(NSString*)inUploadID withURLRequest:(NSURLRequest*)inURLRequest dataManager:(QuantcastDataManager*)inDataManager {
    self = [super init];
    
    if (self) {
        _jsonFilePath = [inJSONFilePath retain];
        _uploadID = [inUploadID retain];
        _request = [inURLRequest retain];
        _dataManager = [inDataManager retain];
        
        _isExecuting = NO;
        _isFinished = NO;
        _isSuccessful = NO;
    }
    
    return self;
}

-(void)dealloc {
    [_jsonFilePath release];
    [_uploadID release];
    [_request release];
    [_dataManager release];
    [_connection release];
    [_startTime release];
    
    [super dealloc];
}

-(void)done {
    if ( _isExecuting ) {
        [self willChangeValueForKey:@"isExecuting"];
        _isExecuting = NO;
        [self didChangeValueForKey:@"isExecuting"];
    }
    if ( !_isFinished ) {
        [self willChangeValueForKey:@"isFinished"];
        _isFinished = YES;
        [self didChangeValueForKey:@"isFinished"];
    }
}

-(void)uploadFailed {
    _isSuccessful = NO;
    
    NSString* newFilePath = [[QuantcastUtils quantcastDataReadyToUploadDirectoryPath] stringByAppendingPathComponent:[_jsonFilePath lastPathComponent]];
    
    NSError* error;
    
    if ( ![[NSFileManager defaultManager] moveItemAtPath:_jsonFilePath toPath:newFilePath error:&error] ) {
        // error, will robinson
        if ( self.enableLogging ) {
            NSLog(@"QC Measurement: Could not relocate file '%@' to '%@'. Error = %@", _jsonFilePath, newFilePath, error );
        }
    }
    
}

#pragma mark - Mandatory NSOperation Methods

-(BOOL)isConcurrent {
    return YES;
}

-(BOOL)isExecuting {
    
    return _isExecuting;
}

-(BOOL)isFinished {
    return _isFinished;
}

-(void)start {
    
    if( [self isFinished] || [self isCancelled] ) { 
        //[self done]; 
        return; 
    }
    
    // isExecuting needs to be KVO compliant
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    _startTime = [[NSDate date] retain];
    
    // Create the NSURLConnection--this could have been done in init, but we delayed
    // until no in case the operation was never enqueued or was cancelled before starting
    _connection = [[NSURLConnection alloc] initWithRequest:_request delegate:self startImmediately:NO];
    
    if ( nil == _connection ) {
        [self uploadFailed];
        [self done];
        
        return;
    }
    [_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    
    [_connection start];
}


#pragma mark - NSURLConnectionDelegate Methods

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    // use this as an opportunity to check cancel
    if ([self isCancelled]) {
        if (self.enableLogging) {
            NSLog(@"QC Measurement: Canceling upload of json file = %@",_jsonFilePath);
        }
        [connection cancel];
        [self uploadFailed];
        [self done];
        return;
    }
}


-(void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data {
    // really shouldn't happen
    
    if ([self isCancelled]) {
        if (self.enableLogging) {
            NSLog(@"QC Measurement: Canceling upload of json file = %@",_jsonFilePath);
        }
        [connection cancel];
        [self uploadFailed];
        [self done];
        return;
    }
    
}


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    if (self.enableLogging) {
        NSLog(@"QC Measurement: Failed to upload json file '%@', error = %@", _jsonFilePath, error );
    }
    
    [self uploadFailed];
    [self done];
    
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    _isSuccessful = YES;
    
    if (self.enableLogging) {
        NSLog(@"QC Measurement: Success at uploading json file '%@' to %@", _jsonFilePath, [_request URL] );
    }
    NSError* fileError = nil;
    
    [[NSFileManager defaultManager] removeItemAtPath:_jsonFilePath error:&fileError];
    
    if (fileError != nil && self.enableLogging ) {
        NSLog(@"QC Measurement: Error while eleting upload JSON file '%@', error = %@", _jsonFilePath, fileError );
    }
    
    // record latency
    

    if ( nil != _startTime ) {
        NSTimeInterval delta = [[NSDate date] timeIntervalSinceReferenceDate] - [_startTime timeIntervalSinceReferenceDate];
        
        NSUInteger latency = delta*1000;
        
        [[QuantcastMeasurement sharedInstance] logUploadLatency:latency forUploadId:_uploadID];
        
    }
                             
    [self done];
                             
}

@end
