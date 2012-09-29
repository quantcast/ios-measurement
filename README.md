Quantcast iOS Measurement SDK
=============================


Integrating Quantcast Measurement
---------------------------------

### Project Setup ###

To integrate Quantcast Measurement into your iOS app, you must first be using *Xcode 4.5* or later. Please ensure that you are using the latest version of Xcode before you begin integration.

The first step towards integration is to clone the Quantcast iOS Measurement SDK's git repository and initialize all of its submodules. To do this, in your Mac's Terminal application, issue the following commands:

``` bash
git clone https://github.com/quantcast/ios-measurement.git ./quantcast-ios-measurement
cd ./quantcast-ios-measurement/
git submodule update --init
```

Once you have downloaded the SDK's code, should perform the following steps:

1.	Import the code from the Quantcast-iOS-Measurement folder in the Quantcast Measurement repository you just created into your project.
2.	If you do not already have the latest version of JSONKit integrated into your project, import the code from the JSONKit folder in the Quantcast Measurement repository into your project.
3.	Link the following iOS frameworks to your project (if they aren't already):
	*	`SystemConfiguration`
	*	`Foundation`
	*	`UIKit`
4.	Weak-link the following iOS frameworks to your project (if they aren't already):
	*	`CoreLocation`
	*	`CoreTelephony`
	*	`AdSupport`
5.	Link the following libraries to your project (if they aren't already):
	*	`libz`
	*	`libsqlite3`

### Required Code Integration ###

The Quantcast iOS Measurement SDK has two points of required code integration. The first is a set of required calls to the SDK to indicate when the iOS app has been launched, paused (put into the background), resumed, and quit. The second is providing a the user access to the Quantcast Measurement Opt-Out dialog. 

In order to implement the required set of SDK calls, do the following:

1.	Import `QuantcastMeasurement.h` into your `UIApplication` delegate class
2.	In your `UIApplication` delegate's `application:didFinishLaunchingWithOptions:` method, place the following:

	```objective-c
	[[QuantcastMeasurement sharedInstance] beginMeasurementSession:@"<*Insert your P-Code Here*>" withAppleAppId:1234566 labels:nil];
	```
		
	Replacing "<*Insert your P-Code Here*>" with your Quantcast publisher identifier objected from your account homepage on [the Quantcast website](http://www.quantcast.com "Quantcast.com"), and the Apple App ID is your app's iTunes ID found in [iTunes Connect](http://itunesconnect.apple.com "iTunes Connect"). Note that your Quantcast publisher identifier is a string that begins with "p-" followed by 13 characters. The labels parameter may be nil and is discussed in more detailed in the Advanced Usage documentation.
3.	In your `UIApplication` delegate's `applicationWillTerminate:` method, place the following:

	```objective-c
	[[QuantcastMeasurement sharedInstance] endMeasurementSessionWithLabels:nil];
	```
		
4.	In your `UIApplication` delegate's `applicationDidEnterBackground:` method, place the following:

	```objective-c
	[[QuantcastMeasurement sharedInstance] pauseSessionWithLabels:nil];
	```

5.	In your `UIApplication` delegate's `applicationWillEnterForeground:` method, place the following:

	```objective-c
	[[QuantcastMeasurement sharedInstance] resumeSessionWithLabels:nil];
	```

6.	Quantcast requires that you provide your users a means by which they can access the Quantcast Measurement Opt-Out dialog. This should be a button or a table view cell (if your options is based on a grouped table view) in your app's options view with the title "Opt Out". When the user taps the button you provide, you should call the Quantcast's Measurement SDK's opt-out dialog with the following method:

	```objective-c
	[[QuantcastMeasurement sharedInstance] displayUserPrivacyDialogOver:currentViewController withDelegate:nil];
	```
		
	Where `currentViewController` is exactly that, the current view controller. The SDK needs to know this due to how the iOS SDK present model dialogs (see Apple's docs for `presentModalViewController:animated:`). The delegate is an optional parameter and is explained in the `QuantcastOptOutDelegate` protocol header.
	
	Note that when a user opts-out of Quantcast Measurement, it causes the SDK to immediately stop transmitting information to or from the user's device and it deletes any cached information that the SDK may have retained. Furthermore, when a user opts-out of a single app on a device, it affects all apps on the device that are using Quantcast Measurement. 

### Optional Code Integrations ###

#### Tracking App Events ####
You may use Quantcast App Measurement to measure the audiences that engage in certain activities within your app. In order to log the occurrence of an app event or activity, simply call the following method:

```objective-c
[[QuantcastMeasurement sharedInstance] logEvent:theEventStr withLabels:nil];
```
Here `theEventStr` is a string that is meaningful to you and is associated with the event you are logging. Note that hierarchical information can be indicated by using a left-to-right notation with a period as a seperator. For example, logging one event named "button.left" and another named "button.right" will create three reportable items in Quantcast App Measurement: "button.left", "button.right", and "button". There is no limit on the cardinality that this hierarchal scheme can create, though low-frequency events may not have an audience report on due to the lack of a statistically significant population.

#### Event Labels ####
Most of Quantcast App Measurement SDK's public methods have an option to provide a label, or `nil` if no label is desired. A label is any arbitrary string that you want to be ascociated with an event, and will create a second dimension in Quantcast Measurement audience reporting. Normally, this dimension is a "user class" indicator. For example, you might use one of two labels in your app: one for user who have not purchased an app upgrade, and one for users who have purchased an upgrade.

While there is no specific constraint on the intended use of the label dimension, it is not recommended that you use it to indicate discrete events. You should use the `logEvent:withLabels:` method to do that.

#### Geo-Location Measurement ####
If you would like to get geo-location aware reporting, you must turn on geo-tracking in the Measurement SDK. You do this in your `UIApplication` delegate's `application:didFinishLaunchingWithOptions:` method after you call either form of the `beginMeasurementSession:` methods by making the following call:

```objective-c
[QuantcastMeasurement sharedInstance].geoLocationEnabled = YES;
```
Note that you should only enable geo-tracking if your app has some location-aware purpose.

The Quantcast Measurement SDK will automatically pause geo-tracking while your app is in the background. This is done for both battery-life and privacy considerations.

#### Combined Web/App Audiences ####
Quantcast App Measurement enables you to measure your web and app audience. This allows you to use Quantcast Measurement to understand the differences and similarities of your online and app audiences, or even between different apps that you publish. In order to enable this feature, your will need to provide a user identifier, which Quantcast will always anonymize with a 1-way hash before it is transmitted off the user's device. This user identifier also needs to be provided in your website(s); please see Quantcast's web measurement documentation for specific instructions on how to provide an user identifier for your website.

In order to provide Quantcast Measurement with the user identifier, call the following method:

```objective-c
[[QuantcastMeasurement sharedInstance] recordUserIdentifier: userIdentifierStr withLabels:nil];
```
Where `userIdentifierStr` is the user identifier that you use. The SDK will immediately 1-way hash the passed identifier, and return the hashed value for your reference. You do not need to take any action with the hashed value. 

*Important*: Use of this feature requires certain notice and disclosures to your website and app users. Please see Quantcast's terms of service for more details.

#### Logging and Debugging ####
You may enable logging within the SDK for debugging purposes. By default, logging is turned off. To enable logging, call the following method at any time, including prior to calling either of the `beginMeasurementSession:` methods:

```objective-c
[QuantcastMeasurement sharedInstance].enableLogging = YES;
```
You should not release an app with logging enabled.

### License ###

This software is licensed under the Quantcast Mobile API Beta Evaluation Agreement and may not be used except as permitted thereunder or copied, modified, or distributed in any case.