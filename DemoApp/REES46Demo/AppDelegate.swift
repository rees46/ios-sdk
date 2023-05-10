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
var globalSDKNotificationName = Notification.Name("globalSDK")

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    let gcmMessageIDKey = "gcm.message_id"
    var sdk: PersonalizationSDK!
    var notificationService: NotificationServiceProtocol?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        print("A. Init firebase sdk")
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        print("======")

        print("0. Init SDK")
        sdk = createPersonalizationSDK(shopId: "357382bf66ac0ce2f1722677c59511", enableLogs: true, { error in
            print("Init error = ", error?.localizedDescription ?? "NO INIT ERRORS")
            didToken = self.sdk.getDeviceID()
            globalSDK = self.sdk
            NotificationCenter.default.post(name: globalSDKNotificationName, object: nil)
        })

        print("0.1. Registr push")
        notificationService = NotificationService(sdk: sdk)
        notificationService?.pushActionDelegate = self
        print("======")

        print("1. Testing tracking")

        sdk.trackSource(source: .chain, code: "123123")

        let rec = RecomendedBy(type: .dynamic, code: "beb620922934b6ba2d6a3fb82b8b3271")
        sdk.track(event: .productView(id: "644"), recommendedBy: rec) { trackResponse in
            print("   Product view callback")
            switch trackResponse {
            case let .success(response):
                print("     track product view is success")
            // print("Response: ", response) //uncomment it if you want to see response
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                // fatalError("     track product view is failure")
            }
        }

        print("1. Testing tracking")
//        sdk.track(event: .productView(id: "644")) { trackResponse in
//            print("   Product view callback")
//            switch trackResponse {
//            case let .success(response):
//                print("     track product view is success")
//            // print("Response: ", response) //uncomment it if you want to see response
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    print("Error: ", customError)
//                default:
//                    print("Error: ", error.localizedDescription)
//                }
//                //fatalError("     track product view is failure")
//            }
//        }
//        sdk.track(event: .categoryView(id: "644")) { trackResponse in
//            print("   Category view callback")
//            switch trackResponse {
//            case let .success(response):
//                print("     track category view is success")
//            // print("Response: ", response) //uncomment it if you want to see response
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    print("Error: ", customError)
//                default:
//                    print("Error: ", error.localizedDescription)
//                }
//                //fatalError("    track category view is failure")
//            }
//        }
//        sdk.track(event: .productAddedToFavorities(id: "644")) { trackResponse in
//            print("   Product added to favorities callback")
//            switch trackResponse {
//            case let .success(response):
//                print("     track product add to favorite is success")
//            // print("Response: ", response) //uncomment it if you want to see response
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    print("Error: ", customError)
//                default:
//                    print("Error: ", error.localizedDescription)
//                }
//                //fatalError("    track product add to favorite is failure")
//            }
//        }
//        sdk.track(event: .productRemovedToFavorities(id: "644")) { trackResponse in
//            print("   Product removed from favorities callback")
//            switch trackResponse {
//            case let .success(response):
//                print("     track product removed from favorities is success")
//            // print("Response: ", response) //uncomment it if you want to see response
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    print("Error: ", customError)
//                default:
//                    print("Error: ", error.localizedDescription)
//                }
//                //fatalError("    track product removed from favorities is failure")
//            }
//        }
//        sdk.track(event: .productAddedToCart(id: "644")) { trackResponse in
//            print("   Product added to cart callback")
//            switch trackResponse {
//            case let .success(response):
//                print("     track product added to cart is success")
//            // print("Response: ", response) //uncomment it if you want to see response
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    print("Error: ", customError)
//                default:
//                    print("Error: ", error.localizedDescription)
//                }
//                //fatalError("    track product added to cart is failure")
//            }
//        }
//        sdk.track(event: .productRemovedFromCart(id: "644")) { trackResponse in
//            print("   Product removed from cart callback")
//            switch trackResponse {
//            case let .success(response):
//                print("     track product removed from cart is success")
//            // print("Response: ", response) //uncomment it if you want to see response
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    print("Error: ", customError)
//                default:
//                    print("Error: ", error.localizedDescription)
//                }
//                //fatalError("    track product removed from cart is failure")
//            }
//        }
//        sdk.track(event: .synchronizeCart(items: [CartItem(productId: "784")])) { trackResponse in
//            print("   Cart syncronized callback")
//            switch trackResponse {
//            case let .success(response):
//                print("     track cart syncronized is success")
//            // print("Response: ", response) //uncomment it if you want to see response
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    print("Error: ", customError)
//                default:
//                    print("Error: ", error.localizedDescription)
//                }
//                //fatalError("    track cart syncronized is failure")
//            }
//        }
//        sdk.track(event: .orderCreated(orderId: "123", totalValue: 33.3, products: [(id: "644", amount: 3), (id: "784", amount: 1)])) { trackResponse in
//            print("   Order created callback")
//            switch trackResponse {
//            case let .success(response):
//                print("     track order created is success")
//            // print("Response: ", response) //uncomment it if you want to see response
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    print("Error: ", customError)
//                default:
//                    print("Error: ", error.localizedDescription)
//                }
//                //fatalError("    track order created is failure")
//            }
//        }
        sdk.trackEvent(event: "click", category: "2", label: "None", value: 2) { trackResponse in
            print("   Custom track event callback")
            switch trackResponse {
            case let .success(response):
                print("     Custom track event is success")
            // print("Response: ", response) //uncomment it if you want to see response
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                // fatalError("    track order created is failure")
            }
        }

//        print("===")
//        print("2. Testing product recommendations")
//        sdk.recommend(blockId: "977cb67194a72fdc7b424f49d69a862d", currentProductId: "1") { recomendResponse in
//            print("   Recommendations requested callback")
//            switch recomendResponse {
//            case let .success(response):
//                print("     recommend with prodcut id is success")
//            // print("Response: ", response) //uncomment it if you want to see response
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    print("Error: ", customError)
//                default:
//                    print("Error: ", error.localizedDescription)
//                }
//                //fatalError("    recommend with prodcut id is failure")
//            }
//        }
//
//        sdk.recommend(blockId: "977cb67194a72fdc7b424f49d69a862d", timeOut: 0.5) { recomendResponse in
//            print("   Recommendations requested callback")
//            switch recomendResponse {
//            case let .success(response):
//                print("     recommend is success")
//            // print("Response: ", response) //uncomment it if you want to see response
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    print("Error: ", customError)
//                default:
//                    print("Error: ", error.localizedDescription)
//                }
//                //fatalError("    recommend is failure")
//            }
//        }
//        print("===")
//        print("3. Testing search")
//        sdk.suggest(query: "iphone") { searchResponse in
//            print("   Instant search callback")
//            switch searchResponse {
//            case let .success(response):
//                print("     instant search is success")
//            // print("Response: ", response) //uncomment it if you want to see response
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    print("Error: ", customError)
//                default:
//                    print("Error: ", error.localizedDescription)
//                }
//                //fatalError("    instant search is failure")
//            }
//        }
//        print("===")
//
//        sdk.search(query: "coat", sortBy: "popular", locations: "10", filters: ["Screen size, inch": ["15.6"]], timeOut: 0.2) { searchResponse in
//            print("   Full search callback")
//            switch searchResponse {
//            case let .success(response):
//                print("     full search is success")
//            // print("Response: ", response) //uncomment it if you want to see response
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    print("Error: ", customError)
//                default:
//                    print("Error: ", error.localizedDescription)
//                }
//                //fatalError("    full search is failure")
//            }
//        }
//
//        sdk.searchBlank { searchResponse in
//            print("   Search blank callback")
//            switch searchResponse {
//            case let .success(response):
//                print("     Search blank is success")
//            // print("Response: ", response) //uncomment it if you want to see response
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    print("Error: ", customError)
//                default:
//                    print("Error: ", error.localizedDescription)
//                }
//                //fatalError("    Search blank is failure")
//            }
//        }
//
//        print("4. Set user Settings")
//
//        sdk.setProfileData(userEmail: "arseniydor@yandex.ru") { profileResponse in
//            print("   Profile data set callback")
//            switch profileResponse {
//            case .success():
//                print("     setProfileData is success")
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    print("Error: ", customError)
//                default:
//                    print("Error: ", error.localizedDescription)
//                }
//                //fatalError("    setProfileData is failure")
//            }
//        }
//
//        print("===")
//
//
//        print("6. Send review")
//
//        sdk.review(rate: 1, channel: "ios_app", category: "delivery", comment: "Nice application, thank you!") { reviewResponse in
//            print("   Send review response")
//            switch reviewResponse {
//            case .success():
//                print("     review is success")
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    print("Error: ", customError)
//                default:
//                    print("Error: ", error.localizedDescription)
//                }
//                //fatalError("    review is failure")
//            }
//        }

        print("===")

        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
//        removeAllFilesFromTemporaryDirectory()
    }
    
    @available(iOS 13.0, *)
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
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

}

// Firebase notifications
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // FOR TEST
        fcmGlobalToken = fcmToken ?? ""
        // END TEST
        notificationService?.didReceiveRegistrationFCMToken(fcmToken: fcmToken)
    }
}

extension AppDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // FOR TEST
        let tokenParts = deviceToken.map { data -> String in
            String(format: "%02.2hhx", data)
        }

        let token = tokenParts.joined()
        pushGlobalToken = token
        print(pushGlobalToken)
        Messaging.messaging().apnsToken = deviceToken
        // END TEST
        notificationService?.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        notificationService?.didReceiveRemoteNotifications(application, didReceiveRemoteNotification: userInfo) { backgroundResult, _ in
            completionHandler(backgroundResult)
        }
    }

    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        notificationService?.didReceiveDeepLink(url: url)
        return true
    }
}

extension AppDelegate: NotificationServicePushDelegate {
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
        let navVC = UINavigationController(rootViewController: pushVC)
        window?.rootViewController?.present(navVC, animated: true)
    }
}
