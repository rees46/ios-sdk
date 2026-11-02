//
//  AppDelegate.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2023. All rights reserved.
//

import Firebase
import FirebaseMessaging
@_spi(PersonalizationUI) import REES46
import SwiftUI
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
        
        installTabBar()
        initializationMessaging()
        sdkInitialization()
        registerPushNotification()

        return true
    }

    /// Wraps the storyboard screen into a tab bar: the existing screen keeps demoing the SDK
    /// methods, "UI Kit" shows the design system (with the SwiftUI stories block as one of its
    /// segments) and "Legacy UI" the UIKit stories view, so both integration styles can be compared.
    /// "Shop" is a small store built from the kit's widgets and the SDK's public methods.
    ///
    /// Runs before `sdkInitialization()`, which passes the root controller to the SDK.
    private func installTabBar() {
        guard let apiScreen = window?.rootViewController else { return }

        apiScreen.tabBarItem = UITabBarItem(
            title: "API",
            image: tabImage(systemName: "list.bullet"),
            tag: 0
        )

        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [apiScreen, makeUIKitTab(), makeLegacyUITab(), makeShopTab()]
        window?.rootViewController = tabBarController
    }

    private func makeUIKitTab() -> UIViewController {
        let controller = UIKitShowcaseViewController()
        controller.tabBarItem = UITabBarItem(
            title: "UI Kit",
            image: tabImage(systemName: "square.grid.2x2"),
            tag: 1
        )
        return controller
    }

    private func makeLegacyUITab() -> UIViewController {
        let controller = LegacyStoriesViewController()
        controller.tabBarItem = UITabBarItem(
            title: "Legacy UI",
            image: tabImage(systemName: "rectangle.stack"),
            tag: 2
        )
        return controller
    }

    /// The shop keeps its own navigation stack: Home → category → product, back with the bar.
    private func makeShopTab() -> UIViewController {
        let navigation = UINavigationController(rootViewController: ShopHomeViewController())
        navigation.tabBarItem = UITabBarItem(
            title: "Shop",
            image: tabImage(systemName: "bag"),
            tag: 3
        )
        return navigation
    }

    private func tabImage(systemName: String) -> UIImage? {
        UIImage(systemName: systemName)
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
      let notificationLogger = NotificationLogger()
      let notififcationServices = NotificationService(sdk: sdk, notificationLogger: notificationLogger)
      let notificationTracker = NotificationTracker(notificationLogger: notificationLogger, notificationService: notififcationServices)
      notificationService = notififcationServices
      
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
    
    /// Links of the `rees46` scheme, both on a cold start and into the running app (the demo has
    /// no scene manifest, so `scene(_:openURLContexts:)` above never fires). A stories link —
    /// any host and path with `r46_stories` — opens its campaign; the rest goes to the SDK's
    /// deep links as before.
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        let stories = openStoriesLink(url)
        NSLog("REES46Demo: open url %@ (%@)", url.absoluteString, stories ? "stories" : "deep link")
        if stories { return true }
        notificationService?.didReceiveDeepLink(url: url)
        return true
    }

    private func openStoriesLink(_ url: URL) -> Bool {
        // The presenter is passed explicitly. Without it the SDK shows over the window of the
        // scene on screen, and on a cold start from a link it waits for that scene to activate.
        guard DemoStoriesLinks.isStoriesLink(url), DemoStoriesLinks.open(url, from: window?.rootViewController) else { return false }
        // A demo screen over the tabs (a push screen and the like) goes, so the stories open over
        // the tabs, as from the "Open" button; an open stories viewer is the SDK's to close.
        if let root = window?.rootViewController, var top = root.presentedViewController {
            while let next = top.presentedViewController { top = next }
            if !(top is PersonalizationStoriesViewController) { root.dismiss(animated: false) }
        }
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
