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

### Code Integration ###

#### Required Code Integration Points ####

The Quantcast iOS Measurement SDK has two points of required code integration. The first is a set of required calls to the SDK to indicate when the iOS app has been launched, paused (put into the background), resumed, and quit. The second is providing a the user access to the Quantcast Measurement Opt-Out dialog. 

In order to implement the required set of SDK calls, do the following:

1.	Import `QuantcastMeasurement.h` into your `UIApplication` delegate class
2.	In your `UIApplication` delegate's `application:didFinishLaunchingWithOptions:` method, place the following:

	```objective-c
	[[QuantcastMeasurement sharedInstance] beginMeasurementSession:@"<*Insert you P-Code Here" withAppleAppId:1234566 labels:nil];
	```
		
	Where the *P-Code* is your Quantcast publisher identifier objected from [the Quantcast website](http://www.quantcast.com "Quantcast.com"), and the Apple App ID is your app's iTunes ID found in [iTunes Connect](http://itunesconnect.apple.com "iTunes Connect"). The labels parameter may be nil and is discussed in more detailed in the Advanced Usage documentation.
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

6.	Quantcast requires that you provide your users a means by which they can access the Quantcast Measurement Opt-Out dialog. This can simply be a button in your app's options view. When the user taps the button you provide, you should call the Quantcast's Measurement SDK's opt-out dialog with the following method:

	```objective-c
	[[QuantcastMeasurement sharedInstance] displayUserPrivacyDialogOver:currentViewController withDelegate:nil];
	```
		
	Where `currentViewController` is exactly that, the current view controller. The SDK needs to know this due to how the iOS SDK present model dialogs (see Apple's docs for `presentModalViewController:animated:`). The delegate is an optional parameter and is explained in the `QuantcastOptOutDelegate` protocol header.
	