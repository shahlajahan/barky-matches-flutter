import UIKit
import Flutter
import GoogleMaps
import UserNotifications

import FirebaseCore
import FirebaseMessaging

import google_mobile_ads
import FirebaseAuth

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
  _ application: UIApplication,
  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {

    GMSServices.provideAPIKey("AIzaSyCN_Y8FNV_XI7Ru4S4UKKckrBi7HkI-GcY")
    GMSServices.setMetalRendererEnabled(false)

    GeneratedPluginRegistrant.register(with: self)

    print("🌐 Firebase initialization delegated to FlutterFire/Dart")

    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
        self,
        factoryId: "listTile",
        nativeAdFactory: NativeAdFactoryExample()
    )

    return super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
}

  override func application(
_ application: UIApplication,
didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {

print("🌐 APNS TOKEN STATE (native) = received")

super.application(
application,
didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
)

if FirebaseApp.app() != nil {
  Messaging.messaging().apnsToken = deviceToken
  Auth.auth().setAPNSToken(
    deviceToken,
    type: .unknown
  )
}

}

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {

    print("❌ APNs register failed: \(error)")
  }
}
