#Quantcast Measure for Apps#
###iOS SDK Changelog###

##Version 1.5.3##
May 13, 2016
* Fixed Reachability to support ipv6 Fixes #21
* Removed some deprecated methods Fixes #23
* Update documentation Fixes #22
* Copywrite update

##Version 1.5.2##
November 10, 2015
* Fixed static analyzer warning Fixes #20
* move library imports out of .h Fixes #19

##Version 1.5.1##
October 2, 2015
* Minor update to upload packet

##Version 1.5.0##
September 17, 2015
* Https now on by default for iOS 9
* Other minor updates for iOS 9 
* Fixes #18  XCode 7.0 warnings

##Version 1.4.9##
May 7, 2015
* Fixes #16  XCode 6.3 warnings

##Version 1.4.8##
March 13, 2015
* Move QC file directory to more permanent location
* Drop support for iOS 4

##Version 1.4.7##
October 10, 2014
* minor message structure update
* code refactor

##Version 1.4.6##
July 28, 2014
* Fixes #13 Optout set before begin
 
##Version 1.4.5##
June 6, 2014
* New Feature - iAd install attribution reporting can be optional activated. See `QuantcastMeasurement+InstallAttribution.h` header in the Optional folder. 
* Corrected location of `zlib.h` import statement. [Fixes #11](https://github.com/quantcast/ios-measurement/issues/11).

##Version 1.4.4##
May 22, 2014
* Added Advertising campaign measurement
* Fixed unexpected database value.  fixes #9

##Version 1.4.3##
May 06, 2014
* Database write bug fixes #7
* Added class forward of UIViewController fixes #5

##Version 1.4.2##
April 22, 2014
* Fixed upgrade vs install issue.

##Version 1.4.1##
March 15, 2014
* Fixed network label issue

##Version 1.4.0##
March 03, 2014
* Updated to support ARC - See README for integration instruction changes
* Added programmatic way to Opt Out users

##Version 1.2.14##
January 31, 2014
* Refactored for performance.
* Persistant session timing.
* Fixed loss of precision warnings on arm64. fixes #2

##Version 1.2.13##
October 25, 2013
* Added new cellular connection type added in iOS7
* Now compatible with UIApplicationExitsOnSuspend
* Added new property "appLabels" to be able to set static labels across all calls.  Convienient for app always passing the same labels to all the calls.

##Version 1.2.12##
October 14, 2013
* Augmented the Networks extension functionality with the ability to create a "network event", which is the network equivalent to an "app event". 

##Version 1.2.11##
October 1, 2013
* Added the optional Networks extension to Quantcast Measure for Apps, which allows app platforms to quantify an entire network of syndicated apps while still allowing individual apps to directly quantify.

##Version 1.2.10##
September 12, 2013

* Fixed compilation issue caused when CoreLocation is not linked to project.

##Version 1.2.9 ##
September 10, 2013
* Refactored geo-location code so that it is completely optional to integrate. The `CoreLocation` framework is now only required if you wish to activate geo-reporting. People who have already activated the geo-location code will need to take the following steps to maintain that activation:
  * Place this macro in your pre-compiled header file: `#define QCMEASUREMENT_ENABLE_GEOMEASUREMENT 1`
  * Add the `QuantcastGeoManager.m` compile unit found in the "Optional" folder of the SDK.
  
  If you have not enabled geo-location in the Quantcast SDK, then you do not need to take any action with this update. However, you may choose to remove `CoreLocation` from your project as it is no longer needed. Previously, `CoreLocation` was needed even if geo-location was no enabled in order to satisfy symbol resolution at link time. 
* New header file `QuantcastEventLogger.h`
* Better handling of apps being launched in the background
* Fixed issue where SDK code would not compile if certain third party library headers were included in a project's pre-compiled header.

## Version 1.2.8 ##
August 30, 2013
* Added the One Step integration option to make SDK integration as simple as one line of code for basic integrations. The original, more advanced integration options still exist.
* Updated JSONKit to improve compatibility with Xcode 5. Note that JSONKit is only required is you want your app to be back-compatible to iOS 4. 
* Added detection of installation time (as evidenced by file system creation times for the app) in order to produce better install vs. upgrade counts when apps initially quantify.
* Added Digital Periodical SDK extension to measure magazine/Newsstand style apps. Find extension in the "Optional" folder of the SDK.

## Version 1.2.7 ##
June 28, 2013
* Corrected SDK error reporting to better escape system-produced error strings being passed back to Quantcast
* Quantcast is migrating its mobile app measurement servers from the quantserve.com domain to the quantcount.com domain. The will enable better service for specific server-side features needed for mobile app measurement.

## Version 1.2.6 ##
June 7, 2013
* Improved the Quantcast SDK integration with app-hosted web views
* Additional changes to support PhoneGap (see [Quantcast PhoneGap Plugin](https://github.com/quantcast/phonegap-measurement))

## Version 1.2.5 ##
May 1, 2013
* Worked around a CoreTelephony bug introduced in iOS 6. Since iOS 6, CoreTelephony has been triggering a callback after CoreTelephony objects have been released.
* Updated minimum event upload count to 2 to prevent upload loops
* Added a debug name to NSOperationsQueue

## Version 1.2.4 ##
February 11, 2013
* Improved the handling of data uploads as the app transitions to the background by securing a background task ID from the OS

##Version 1.2.3 ##
February 5, 2013
* Added the ability to pass multiple labels on each event
* Corrected the "bad date" handling of secure connections
* Other minor code improvements

##Version 1.2.2 ##
January 29, 2013
* Updated SDK to support optionally using secure data transfers
* Data uploads are now handled completely in a background thread
* Limited the number of concurrent background threads that can be created
* Added SDK eror reporting
* Other minor code improvements

##Version 1.2.1 ##
January 7, 2013
* Minor code enhancements

##Version 1.2.0 ##
January 4, 2013

**Initial Public Release**