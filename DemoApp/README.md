# REES46 iOS SDK

## Overview

REES46 SDK for iOS is a powerful tool for integrating e-commerce functionality into your applications. It includes a personalization engine, product recommendations, search engine, notifications, and more.

## Requirements

- iOS 12.0+
- Swift 5

## Installation

### CocoaPods

To integrate the REES46 SDK into your Xcode project using CocoaPods, add the following line to your `Podfile`:

```ruby
pod 'REES46', '~> 3.6.13'
```

Then, run the following command:

```bash
$ pod install
```

## Configuration

1. **Firebase Setup**:

   - Set up Firebase in your project and configure `GoogleService-Info.plist`.
   - Ensure Firebase Cloud Messaging (FCM) is enabled and configured for push notifications.

2. **SDK Initialization**:

   Initialize the REES46 SDK in your `AppDelegate.swift`:

   ```swift
   import UIKit
   import REES46

   @UIApplicationMain
   class AppDelegate: UIResponder, UIApplicationDelegate {

       func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
           
           // Initialize REES46 SDK
           let sdk = REES46.getInstance()
           sdk.initialize(shopId: "YOUR_SHOP_ID")

           // Register for push notifications
           registerForPushNotifications()

           return true
       }

       func registerForPushNotifications() {
           UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
               guard granted else { return }
               DispatchQueue.main.async {
                   UIApplication.shared.registerForRemoteNotifications()
               }
           }
       }

       // Handle registration for remote notifications
       func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
           let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
           print("Device Token:", token)
           
           // Pass device token to REES46 SDK for registration
           REES46.getInstance().setPushToken(token)
       }

       // Handle receiving remote notifications
       func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
           REES46.getInstance().handlePushNotification(userInfo)
           completionHandler(.newData)
       }
   }
   ```

## Push Notifications

### Handling Push Notifications

To handle push notifications and track events with the REES46 SDK, use the following methods:

1. **Registering for Remote Notifications**:

   Ensure your application is registered to receive remote notifications. Typically done in `AppDelegate.swift` as shown above.

2. **Handling Registration Token**:

   Implement `didRegisterForRemoteNotificationsWithDeviceToken` to pass the device token to the REES46 SDK for registration for push notifications.

3. **Handling Remote Notifications**:

   Implement `didReceiveRemoteNotification` to handle incoming push notifications and pass them to the REES46 SDK for processing.

4. **Handling Push Notification Clicks**:

   To handle user interactions with push notifications, implement the following methods:

   ```swift
   import REES46
   import UIKit

   class NotificationService: NSObject, UNUserNotificationCenterDelegate {

       let sdk = REES46.getInstance()

       // Handle user interaction with a notification
       func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
           let userInfo = response.notification.request.content.userInfo
           
           if let type = userInfo["type"] as? String {
               if let id = userInfo["id"] as? String {
                   // Handle notification click
                   sdk.notificationClicked(type: type, code: id) { _ in
                       // Handle completion if needed
                   }
               }
           }
           
           completionHandler()
       }

       // Handle notifications when app is in foreground
       func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
           let userInfo = notification.request.content.userInfo
           
           // Handle notification display
           if let type = userInfo["type"] as? String {
               if let id = userInfo["id"] as? String {
                   // Handle notification received
                   sdk.notificationReceived(type: type, code: id) { _ in
                       // Handle completion if needed
                   }
               }
           }
           
           completionHandler([.alert, .sound, .badge])
       }
   }
   ```
