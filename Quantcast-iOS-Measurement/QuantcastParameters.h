//
// Copyright (c) 2012, Quantcast Corp.
// This software is licensed under the Quantcast Mobile API Beta Evaluation Agreement and may not be used except as permitted thereunder or copied, modified, or distributed in any case.
//

#import <Foundation/Foundation.h>

#pragma mark - Event Constants

// Base event parameters
#define QCPARAMETER_SID               @"sid"
#define QCPARAMETER_ET                @"et"


// Typed event
#define QCPARAMETER_EVENT             @"event"
#define QCPARAMETER_LABELS            @"labels"
#define QCPARAMETER_APPEVENT          @"appevent"

// Typed event parameters
#define QCMEASUREMENT_EVENT_LOAD        @"load"
#define QCMEASUREMENT_EVENT_REFRESH     @"refresh"
#define QCMEASUREMENT_EVENT_UPDATE      @"update"
#define QCMEASUREMENT_EVENT_FINISHED    @"finished"
#define QCMEASUREMENT_EVENT_PAUSE       @"pause"
#define QCMEASUREMENT_EVENT_RESUME      @"resume"

#define QCMEASUREMENT_EVENT_APPEVENT    @"appevent"
#define QCMEASUREMENT_EVENT_LOCATION    @"location"
#define QCMEASUREMENT_EVENT_LATENCY     @"latency"
#define QCMEASUREMENT_EVENT_NETINFO     @"netinfo"


// Open session event
#define QCPARAMETER_A                 @"a"
#define QCPARAMETER_AID               @"aid"
#define QCPARAMETER_ALT               @"alt"
#define QCPARAMETER_ANAME             @"aname"
#define QCPARAMETER_ASID              @"asid"
#define QCPARAMETER_AVER              @"aver"
#define QCPARAMETER_LOCALITY          @"l"
#define QCPARAMETER_COUNTRY           @"c"
#define QCPARAMETER_CT                @"ct"
#define QCPARAMETER_DG                @"dg"
#define QCPARAMETER_DID               @"did"
#define QCPARAMETER_DM                @"dm"
#define QCPARAMETER_DMOD              @"dmod"
#define QCPARAMETER_DOS               @"dos"
#define QCPARAMETER_DOSV              @"dosv"
#define QCPARAMETER_DST               @"dst"
#define QCPARAMETER_DTYPE             @"dtype"
#define QCPARAMETER_HAC               @"hac"
#define QCPARAMETER_IVER              @"iver"
#define QCPARAMETER_LC                @"lc"
#define QCPARAMETER_LL                @"ll"
#define QCPARAMETER_MCC               @"mcc"
#define QCPARAMETER_MEDIA             @"media"
#define QCPARAMETER_MNC               @"mnc"
#define QCPARAMETER_MNN               @"mnn"
#define QCPARAMATER_PKID              @"pkid"
#define QCPARAMETER_SR                @"sr"
#define QCPARAMETER_STATE             @"st"
#define QCPARAMETER_TZO               @"tzo"
#define QCPARAMETER_UH                @"uh"
#define QCPARAMETER_VAC               @"vac"
#define QCPARAMETER_OPTOUT            @"optout"
#define QCPARAMETER_REASON            @"nsr"

// Latency event
#define QCPARAMETER_LATENCY           @"latency"
#define QCPARAMETER_LATENCY_VALUE     @"value"
#define QCPARAMETER_LATENCY_UPLID     @"uplid"

// Load event types
#define QCPARAMETER_REASONTYPE_LAUNCH       @"launch"
#define QCPARAMETER_REASONTYPE_RESUME       @"resume"
#define QCPARAMETER_REASONTYPE_USERHASH     @"userhash"
#define QCPARAMETER_REASONTYPE_ADPREFCHANGE @"adprefchange"

// 
// Quantcast Measurement SDK
//

#define QCMEASUREMENT_API_VERSION               @"1_0_0"
#define QCMEASUREMENT_API_IDENTIFIER            @"iOS_1.0.0"
#define QCMEASUREMENT_CONN_TIMEOUT_SECONDS      60

#ifndef QCMEASUREMENT_UPLOAD_URL
    #define QCMEASUREMENT_UPLOAD_URL            @"http://m.quantserve.com/mobile"
#endif
#ifndef QCMEASUREMENT_POLICY_URL_FORMAT
    #define QCMEASUREMENT_POLICY_URL_FORMAT     @"http://m.quantserve.com/policy.json?a=%@&v=%@&t=%@&c=%@"
#endif

#define QCMEASUREMENT_CACHE_DIRNAME             @"qc-measurement-cache"
#define QCMEASUREMENT_POLICY_FILENAME           @"qc-policy.json"
#define QCMEASUREMENT_DATABASE_FILENAME         @"qcmeasurement.db"
#define QCMEASUREMENT_IDENTIFIER_FILENAME       @"qc-identifier.txt"
#define QCMEASUREMENT_ADIDPREF_FILENAME         @"ad-id-pref.txt"

#define QCMEASUREMENT_OPTOUT_PASTEBOARD         @"com.quantcast.measurement.optout"
#define QCMEASUREMENT_OPTOUT_STRING             @"QC-OPT-OUT"

#ifndef QCMEASUREMENT_DEFAULT_MAX_SESSION_PAUSE_SECOND
    #define QCMEASUREMENT_DEFAULT_MAX_SESSION_PAUSE_SECOND  600
#endif
