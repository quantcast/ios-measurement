//
// Copyright (c) 2012, Quantcast Corp.
// This software is licensed under the Quantcast Mobile API Beta Evaluation Agreement and may not be used except as permitted thereunder or copied, modified, or distributed in any case.
//

#import <UIKit/UIKit.h>

@class QuantcastMeasurement;
@protocol QuantcastOptOutDelegate;

/*!
 @class QuantcastOptOutViewController
 @internal
 */
@interface QuantcastOptOutViewController : UIViewController {
    BOOL _originalOptOutStatus;
}

-(id)initWithMeasurement:(QuantcastMeasurement*)inMeasurement delegate:(id<QuantcastOptOutDelegate>)inDelegate;

-(IBAction)optOutStatusChanged:(id)inSender;
-(IBAction)reviewPrivacyPolicy:(id)inSender;
-(IBAction)done:(id)inSender;

@end

@interface QuantcastRoundedRectView : UIView {
    
}

@end
