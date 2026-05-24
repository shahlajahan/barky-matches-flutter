import UIKit
import Flutter
import GoogleMaps
import UserNotifications

import FirebaseCore
import FirebaseMessaging

import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    GMSServices.provideAPIKey("AIzaSyCN_Y8FNV_XI7Ru4S4UKKckrBi7HkI-GcY")
    GMSServices.setMetalRendererEnabled(false)

    print("🌐 FIREBASE INIT START (native AppDelegate)")
    print("🌐 FIREBASE APP COUNT (native before) = \(FirebaseApp.allApps?.count ?? 0)")

    FirebaseApp.configure()

    print("🌐 FIREBASE INIT COMPLETE (native AppDelegate)")
    print("🌐 FIREBASE APP COUNT (native after) = \(FirebaseApp.allApps?.count ?? 0)")

    UNUserNotificationCenter.current().delegate = self

    print("🌐 APNS TOKEN STATE (native) = registering")
    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)

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

    Messaging.messaging().apnsToken = deviceToken

    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {

    print("❌ APNs register failed: \(error)")
  }
}