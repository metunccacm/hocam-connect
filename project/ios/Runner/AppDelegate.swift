import Flutter
import UIKit
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase is automatically configured by FlutterFire plugins
    GeneratedPluginRegistrant.register(with: self)
    
    // Register for remote notifications to get APNs token
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { granted, error in
          print("🔔 Push notification permission granted: \(granted)")
          if let error = error {
            print("❌ Push notification permission error: \(error)")
          }
        }
      )
    }
    
    application.registerForRemoteNotifications()
    print("📱 Registered for remote notifications")
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Called when APNs successfully registered
  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("✅ APNs device token received: \(token)")
    
    // Pass to parent to handle Firebase registration
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // Called when APNs registration fails
  override func application(_ application: UIApplication,
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
