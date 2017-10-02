/*
 * © Copyright 2012-2017 Quantcast Corp.
 *
 * This software is licensed under the Quantcast Mobile App Measurement Terms of Service
 * https://www.quantcast.com/learning-center/quantcast-terms/mobile-app-measurement-tos
 * (the “License”). You may not use this file unless (1) you sign up for an account at
 * https://www.quantcast.com and click your agreement to the License and (2) are in
 * compliance with the License. See the License for the specific language governing
 * permissions and limitations under the License. Unauthorized use of this file constitutes
 * copyright infringement and violation of law.
 */
#if !__has_feature(objc_arc)
#error "Quantcast Measurement is designed to be used with ARC. Please turn on ARC or add '-fobjc-arc' to this file's compiler flags"
#endif // !__has_feature(objc_arc)

#import "QuantcastMeasurement+Periodicals.h"
#import "QuantcastEvent.h"
#import "QuantcastDataManager.h"
#import "QuantcastParameters.h"
#import "QuantcastUtils.h"
#import "QuantcastEventLogger.h"

#define QCMEASUREMENT_EVENT_PERIODICALOPENISSUE     @"periodical-issue-open"
#define QCMEASUREMENT_EVENT_PERIODICALCLOSEISSUE    @"periodical-issue-close"
#define QCMEASUREMENT_EVENT_PERIODICALPAGEVIEW      @"periodical-page-view"
#define QCMEASUREMENT_EVENT_PERIODICALARTICLEVIEW   @"periodical-article-view"
#define QCMEASUREMENT_EVENT_PERIODICALDOWNLOAD      @"periodical-download"

#define QCPARAMETER_PERIODICAL_PERIODICALNAME   @"periodical-name"
#define QCPARAMETER_PERIODICAL_ISSUENAME        @"issue-name"
#define QCPARAMETER_PERIODICAL_ISSUEDATE        @"issue-date"
#define QCPARAMETER_PERIODICAL_ARTICLE          @"article"
#define QCPARAMETER_PERIODICAL_AUTHOR           @"authors"
#define QCPARAMETER_PERIODICAL_PAGE             @"pagenum"



@interface QuantcastMeasurement ()<QuantcastEventLogger>
@property (readonly,nonatomic) BOOL isMeasurementActive;
@end

@implementation QuantcastMeasurement (Periodicals)

-(void)logAssetDownloadCompletedWithPeriodicalNamed:(NSString*)inPeriodicalName issueNamed:(NSString*)inIssueName issuePublicationDate:(NSDate*)inPublicationDate withLabels:(id<NSObject>)inLabelsOrNil {
    [self logAssetDownloadCompletedWithPeriodicalNamed:inPeriodicalName issueNamed:inIssueName issuePublicationDate:inPublicationDate withAppLabels:inLabelsOrNil networkLabels:nil];
}

-(void)logAssetDownloadCompletedWithPeriodicalNamed:(NSString*)inPeriodicalName issueNamed:(NSString*)inIssueName issuePublicationDate:(NSDate*)inPublicationDate withAppLabels:(id<NSObject>)inAppLabelsOrNil networkLabels:(id<NSObject>)inNetworkLabelsOrNil {
    
    if ( nil == inPeriodicalName ) {
       QUANTCAST_ERROR(@"The inPeriodicalName parameter cannot be nil");
        return;
    }
    
    if ( nil == inIssueName ) {
       QUANTCAST_ERROR(@"The inIssueName parameter cannot be nil");
        return;
    }
    
    if ( nil == inPublicationDate ) {
       QUANTCAST_ERROR(@"The inPublicationDate parameter cannot be nil");
        return;
    }

    
    if ( !self.isOptedOut ) {
        [self launchOnQuantcastThread:^(NSDate *timestamp) {
            if (self.isMeasurementActive) {
                
                NSString* issueTimeStamp = issueTimeStamp = [NSString stringWithFormat:@"%qi",(int64_t)[inPublicationDate timeIntervalSince1970]];
                NSDictionary* params = @{QCPARAMETER_EVENT: QCMEASUREMENT_EVENT_PERIODICALDOWNLOAD,
                                         QCPARAMETER_PERIODICAL_PERIODICALNAME: inPeriodicalName,
                                         QCPARAMETER_PERIODICAL_ISSUENAME: inIssueName,
                                         QCPARAMETER_PERIODICAL_ISSUEDATE: issueTimeStamp};
                QuantcastEvent* e = [QuantcastEvent customEventWithSession:self.currentSessionID eventTimestamp:timestamp applicationInstallID:self.appInstallIdentifier parameterMap:params eventAppLabels:inAppLabelsOrNil eventNetworkLabels:inNetworkLabelsOrNil];
                
                [self recordEvent:e];
                
            }
            else {
               QUANTCAST_ERROR(@"logCompletedDownloadingIssueName: was called without first calling beginMeasurementSession:");
            }
        }];
    }
}

-(void)logOpenIssueWithPeriodicalNamed:(NSString*)inPeriodicalName issueNamed:(NSString*)inIssueName issuePublicationDate:(NSDate*)inPublicationDate withLabels:(id<NSObject>)inLabelsOrNil {
    [self logOpenIssueWithPeriodicalNamed:inPeriodicalName issueNamed:inIssueName issuePublicationDate:inPublicationDate withAppLabels:inLabelsOrNil networkLabels:nil];
}
-(void)logOpenIssueWithPeriodicalNamed:(NSString*)inPeriodicalName issueNamed:(NSString*)inIssueName issuePublicationDate:(NSDate*)inPublicationDate withAppLabels:(id<NSObject>)inAppLabelsOrNil networkLabels:(id<NSObject>)inNetworkLabelsOrNil {

    if ( nil == inPeriodicalName ) {
       QUANTCAST_ERROR(@"The inPeriodicalName parameter cannot be nil");
        return;
    }
    
    if ( nil == inIssueName ) {
       QUANTCAST_ERROR(@"The inIssueName parameter cannot be nil");
        return;
    }
    
    if ( nil == inPublicationDate ) {
       QUANTCAST_ERROR(@"The inPublicationDate parameter cannot be nil");
        return;
    }

    if ( !self.isOptedOut ) {
        [self launchOnQuantcastThread:^(NSDate *timestamp) {
            if (self.isMeasurementActive) {
                
                NSString* issueTimeStamp = issueTimeStamp = [NSString stringWithFormat:@"%qi",(int64_t)[inPublicationDate timeIntervalSince1970]];
                NSDictionary* params = @{QCPARAMETER_EVENT: QCMEASUREMENT_EVENT_PERIODICALOPENISSUE,
                                         QCPARAMETER_PERIODICAL_PERIODICALNAME: inPeriodicalName,
                                         QCPARAMETER_PERIODICAL_ISSUENAME: inIssueName,
                                         QCPARAMETER_PERIODICAL_ISSUEDATE: issueTimeStamp};
                QuantcastEvent* e = [QuantcastEvent customEventWithSession:self.currentSessionID eventTimestamp:timestamp applicationInstallID:self.appInstallIdentifier parameterMap:params eventAppLabels:inAppLabelsOrNil eventNetworkLabels:inNetworkLabelsOrNil];
                
                [self recordEvent:e];
                
            }
            else {
               QUANTCAST_ERROR(@"logPeriodicalOpenIssueNamed: was called without first calling beginMeasurementSession:");
            }
        }];
    }
}

-(void)logCloseIssueWithPeriodicalNamed:(NSString*)inPeriodicalName issueNamed:(NSString*)inIssueName issuePublicationDate:(NSDate*)inPublicationDate withLabels:(id<NSObject>)inLabelsOrNil {
    [self logCloseIssueWithPeriodicalNamed:inPeriodicalName issueNamed:inIssueName issuePublicationDate:inPublicationDate withAppLabels:inLabelsOrNil networkLabels:nil];
}

-(void)logCloseIssueWithPeriodicalNamed:(NSString*)inPeriodicalName issueNamed:(NSString*)inIssueName issuePublicationDate:(NSDate*)inPublicationDate withAppLabels:(id<NSObject>)inAppLabelsOrNil networkLabels:(id<NSObject>)inNetworkLabelsOrNil {
    if ( nil == inPeriodicalName ) {
       QUANTCAST_ERROR(@"The inPeriodicalName parameter cannot be nil");
        return;
    }
    
    if ( nil == inIssueName ) {
       QUANTCAST_ERROR(@"The inIssueName parameter cannot be nil");
        return;
    }
    
    if ( nil == inPublicationDate ) {
       QUANTCAST_ERROR(@"The inPublicationDate parameter cannot be nil");
        return;
    }
    
    if ( !self.isOptedOut ) {
        [self launchOnQuantcastThread:^(NSDate *timestamp) {
            if (self.isMeasurementActive) {
                NSString* issueTimeStamp = issueTimeStamp = [NSString stringWithFormat:@"%qi",(int64_t)[inPublicationDate timeIntervalSince1970]];
                NSDictionary* params = @{QCPARAMETER_EVENT: QCMEASUREMENT_EVENT_PERIODICALCLOSEISSUE,
                                         QCPARAMETER_PERIODICAL_PERIODICALNAME: inPeriodicalName,
                                         QCPARAMETER_PERIODICAL_ISSUENAME: inIssueName,
                                         QCPARAMETER_PERIODICAL_ISSUEDATE: issueTimeStamp};
                QuantcastEvent* e = [QuantcastEvent customEventWithSession:self.currentSessionID eventTimestamp:timestamp applicationInstallID:self.appInstallIdentifier parameterMap:params eventAppLabels:inAppLabelsOrNil eventNetworkLabels:inNetworkLabelsOrNil];
                
                [self recordEvent:e];
            }
            else {
               QUANTCAST_ERROR(@"logPeriodicalCloseIssueNamed: was called without first calling beginMeasurementSession:");
            }
        }];
        
    }
}

-(void)logPeriodicalPageView:(NSUInteger)inPageNumber withPeriodicalNamed:(NSString*)inPeriodicalName issueNamed:(NSString*)inIssueName issuePublicationDate:(NSDate*)inPublicationDate withLabels:(id<NSObject>)inLabelsOrNil {
    [self logPeriodicalPageView:inPageNumber withPeriodicalNamed:inPeriodicalName issueNamed:inIssueName issuePublicationDate:inPublicationDate withAppLabels:inLabelsOrNil networkLabels:nil];
}

-(void)logPeriodicalPageView:(NSUInteger)inPageNumber withPeriodicalNamed:(NSString*)inPeriodicalName issueNamed:(NSString*)inIssueName issuePublicationDate:(NSDate*)inPublicationDate withAppLabels:(id<NSObject>)inAppLabelsOrNil networkLabels:(id<NSObject>)inNetworkLabelsOrNil {
    if ( nil == inPeriodicalName ) {
       QUANTCAST_ERROR(@"The inPeriodicalName parameter cannot be nil");
        return;
    }
    
    if ( nil == inIssueName ) {
       QUANTCAST_ERROR(@"The inIssueName parameter cannot be nil");
        return;
    }
    
    if ( nil == inPublicationDate ) {
       QUANTCAST_ERROR(@"The inPublicationDate parameter cannot be nil");
        return;
    }
    
    if ( !self.isOptedOut ) {
        [self launchOnQuantcastThread:^(NSDate *timestamp) {
            if (self.isMeasurementActive) {
                NSString* issueTimeStamp = issueTimeStamp = [NSString stringWithFormat:@"%qi",(int64_t)[inPublicationDate timeIntervalSince1970]];
                NSDictionary* params = @{QCPARAMETER_EVENT: QCMEASUREMENT_EVENT_PERIODICALPAGEVIEW,
                                         QCPARAMETER_PERIODICAL_PERIODICALNAME: inPeriodicalName,
                                         QCPARAMETER_PERIODICAL_ISSUENAME: inIssueName,
                                         QCPARAMETER_PERIODICAL_ISSUEDATE: issueTimeStamp,
                                         QCPARAMETER_PERIODICAL_PAGE: [NSNumber numberWithUnsignedInteger:inPageNumber]};
                QuantcastEvent* e = [QuantcastEvent customEventWithSession:self.currentSessionID eventTimestamp:timestamp applicationInstallID:self.appInstallIdentifier parameterMap:params eventAppLabels:inAppLabelsOrNil eventNetworkLabels:inNetworkLabelsOrNil];
                
                [self recordEvent:e];
                
            }
            else {
               QUANTCAST_ERROR(@"logPeriodicalPageViewWithIssueNamed: was called without first calling beginMeasurementSession:");
            }
        }];
    }
}


-(void)logPeriodicalArticleView:(NSString*)inArticleName withPeriodicalNamed:(NSString*)inPeriodicalName issueNamed:(NSString*)inIssueName issuePublicationDate:(NSDate*)inPublicationDate articleAuthors:(NSArray*)inAuthorListOrNil withLabels:(id<NSObject>)inLabelsOrNil {
    [self logPeriodicalArticleView:inArticleName withPeriodicalNamed:inPeriodicalName issueNamed:inIssueName issuePublicationDate:inPublicationDate articleAuthors:inAuthorListOrNil withAppLabels:inLabelsOrNil networkLabels:nil];
}

-(void)logPeriodicalArticleView:(NSString*)inArticleName withPeriodicalNamed:(NSString*)inPeriodicalName issueNamed:(NSString*)inIssueName issuePublicationDate:(NSDate*)inPublicationDate articleAuthors:(NSArray*)inAuthorListOrNil withAppLabels:(id<NSObject>)inAppLabelsOrNil networkLabels:(id<NSObject>)inNetworkLabelsOrNil {
    
    if ( nil == inPeriodicalName ) {
       QUANTCAST_ERROR(@"The inPeriodicalName parameter cannot be nil");
        return;
    }
    
    if ( nil == inIssueName ) {
       QUANTCAST_ERROR(@"The inIssueName parameter cannot be nil");
        return;
    }
    
    if ( nil == inPublicationDate ) {
       QUANTCAST_ERROR(@"The inPublicationDate parameter cannot be nil");
        return;
    }
    
    if ( nil == inArticleName ) {
       QUANTCAST_ERROR(@"The inArticleName parameter cannot be nil");
        return;
    }
    
    
    if ( !self.isOptedOut ) {
        [self launchOnQuantcastThread:^(NSDate *timestamp) {
            if (self.isMeasurementActive) {
                NSString* issueTimeStamp = issueTimeStamp = [NSString stringWithFormat:@"%qi",(int64_t)[inPublicationDate timeIntervalSince1970]];
                
                NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:QCMEASUREMENT_EVENT_PERIODICALARTICLEVIEW, QCPARAMETER_EVENT,
                                        inPeriodicalName, QCPARAMETER_PERIODICAL_PERIODICALNAME,
                                        inIssueName, QCPARAMETER_PERIODICAL_ISSUENAME,
                                        issueTimeStamp, QCPARAMETER_PERIODICAL_ISSUEDATE,
                                        inArticleName, QCPARAMETER_PERIODICAL_ARTICLE,
                                        inAuthorListOrNil, QCPARAMETER_PERIODICAL_AUTHOR, nil];
                
                QuantcastEvent* e = [QuantcastEvent customEventWithSession:self.currentSessionID eventTimestamp:timestamp applicationInstallID:self.appInstallIdentifier parameterMap:params eventAppLabels:inAppLabelsOrNil eventNetworkLabels:inNetworkLabelsOrNil];
                
                [self recordEvent:e];
            }
            else {
               QUANTCAST_ERROR(@"logPeriodicalPageViewWithIssueName: was called without first calling beginMeasurementSession:");
            }
        }];
    }
}


@end
