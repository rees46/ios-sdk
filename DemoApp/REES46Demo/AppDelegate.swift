//
//  AppDelegate.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Firebase
import FirebaseMessaging
import REES46
import UIKit
import UserNotifications

var pushGlobalToken: String = ""
var fcmGlobalToken: String = ""
var didToken: String = ""

var globalSDK: PersonalizationSDK?
var globalSDKNotificationNameMainInit = Notification.Name("globalSDK")

var globalSDKNotificationNameAdditionalInit = Notification.Name("globalSDKAdditionalInit")

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    struct Constants {
        static let actionsKey: String = "ACTIONS_IS_RUNNING"
        static let actionsPositiveValue: String = "true"
        static let actionsNegativeValue: String = "false"
    }
    
    var window: UIWindow?
    
    var sdk: PersonalizationSDK!
    var sdkAdditionalInit: PersonalizationSDK!
    var notificationService: NotificationServiceProtocol?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        initializationMessaging()
        sdkInitialization()
        registerPushNotification()
        
        return true
    }
    
    func sdkInitialization(){
        sdk = createPersonalizationSDK(
            shopId: AppEnvironments.shopId,
            apiDomain: AppEnvironments.apiDomain,
            enableLogs: true,
            parentViewController: (window?.rootViewController)!,
            needReInitialization: true,
            { error in
                globalSDK = self.sdk
                NotificationCenter.default.post(name: globalSDKNotificationNameMainInit, object: nil)
            }
        )
    }
    
    func initializationMessaging(){
        Messaging.messaging().delegate = self
    }
    
    func registerPushNotification(){
        UNUserNotificationCenter.current().delegate = self
        notificationService = NotificationService(sdk: sdk)
        notificationService?.pushActionDelegate = self
    }
    
    func configureFirebase() {
        let ciEnv = ProcessInfo.processInfo.environment[Constants.actionsKey] ?? Constants.actionsNegativeValue
        
        if ciEnv == Constants.actionsPositiveValue {
            print("Skipping Firebase configuration in CI")
        } else {
            FirebaseApp.configure()
            print("Firebase configured successfully")
        }
    }
    
    func getFirebaseToken(){
        Messaging.messaging().token { token, error in
            if let error = error {
                print("Error fetching FCM token: \(error.localizedDescription)")
            } else if let token = token {
                print("FCM Token: \(token)")
                self.sdk.setPushTokenNotification(
                    token: token,
                    isFirebaseNotification: true,
                    completion: {completion in
                    
                }
                )
            }
        }
    }
    
    @available(iOS 13.0, *)
    func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {
        if let url = URLContexts.first?.url{
            print(url)
        }
    }
    
    func removeAllFilesFromTemporaryDirectory() {
        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let fileManager = FileManager.default
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: temporaryDirectoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for fileURL in fileURLs {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            print("Error when deleting files from temporary directory: \(error.localizedDescription)")
        }
    }
    
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void) {
        }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        fcmGlobalToken = fcmToken ?? ""
        print("Push Token Firebase:\(String(describing: fcmToken)) ")
        UserDefaults.standard.set(fcmToken, forKey: "fcmGlobalToken")
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data -> String in
            String(format: "%02.2hhx", data)
        }
        
        let token = tokenParts.joined()
        pushGlobalToken = token
        print("Push Token APN:", pushGlobalToken)
        UserDefaults.standard.set(token, forKey: "pushGlobalToken")
        
        Messaging.messaging().apnsToken = deviceToken
        // END TEST
        
        notificationService?.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: deviceToken)
        
        getFirebaseToken()
        
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.alert, .badge, .sound])
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        notificationService?.didReceiveRemoteNotifications(application, didReceiveRemoteNotification: userInfo) { backgroundResult, _ in
            completionHandler(backgroundResult)
        }
    }
    
    func application(
        _ application: UIApplication,
        open url: URL,
        sourceApplication: String?,
        annotation: Any
    ) -> Bool {
        notificationService?.didReceiveDeepLink(url: url)
        return true
    }
    
    func getDeliveredNotifications() {
        UNUserNotificationCenter.current().getDeliveredNotifications { (notifications) in
            print(notifications)
        }
    }
}


extension AppDelegate: NotificationActionsProtocol {
    func openCustom(url: String) {
        print("Open custom url \(url)")
        openPushVC(title: "Custom push with url = \(url)")
    }
    
    func openCategory(categoryId: String) {
        print("Open category. CategoryId = \(categoryId)")
        openPushVC(title: "Category with id = \(categoryId)")
    }
    
    func openProduct(productId: String) {
        print("Open product. ProductId = \(productId)")
        openPushVC(title: "Product with id = \(productId)")
    }
    
    func openWeb(url: String) {
        print("Open web url \(url)")
        openPushVC(title: "Web url = \(url)")
    }
    
    private func openPushVC(title: String) {
        let pushVC = PushPresentViewController()
        pushVC.pushTitle = title
        let navigationController = UINavigationController(rootViewController: pushVC)
        window?.rootViewController?.present(navigationController, animated: true)
    }
}
