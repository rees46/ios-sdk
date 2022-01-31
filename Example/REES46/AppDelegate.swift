//
//  AppDelegate.swift
//  REES46
//
//  Created by Avsi222 on 08/06/2020.
//  Copyright (c) 2020 Avsi222. All rights reserved.
//

import REES46
import UIKit
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    var sdk: PersonalizationSDK!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        print("0. Init SDK")
        sdk = createPersonalizationSDK(shopId: "357382bf66ac0ce2f1722677c59511", { error in
            print(error ?? .initializationFailed)
        })

        print("0.1. Registr push")

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.badge, .alert, .sound]) { _, _ in }
        UIApplication.shared.registerForRemoteNotifications()
        let options: UNAuthorizationOptions = [.alert]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { authorized, _ in
            if authorized {
                let categoryIdentifier = "carousel"
                let carouselNext = UNNotificationAction(identifier: "carousel.next", title: "След", options: [])
                let carouselPrevious = UNNotificationAction(identifier: "carousel.previous", title: "Пред", options: [])

                let carouselCategory = UNNotificationCategory(identifier: categoryIdentifier, actions: [carouselNext, carouselPrevious], intentIdentifiers: [], options: [])
                UNUserNotificationCenter.current().setNotificationCategories([carouselCategory])
            }
        }
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
                fatalError("     track product view is failure")
            }
        }

        print("1. Testing tracking")
        sdk.track(event: .productView(id: "644")) { trackResponse in
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
                fatalError("     track product view is failure")
            }
        }
        sdk.track(event: .categoryView(id: "644")) { trackResponse in
            print("   Category view callback")
            switch trackResponse {
            case let .success(response):
                print("     track category view is success")
            // print("Response: ", response) //uncomment it if you want to see response
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    track category view is failure")
            }
        }
        sdk.track(event: .productAddedToFavorities(id: "644")) { trackResponse in
            print("   Product added to favorities callback")
            switch trackResponse {
            case let .success(response):
                print("     track product add to favorite is success")
            // print("Response: ", response) //uncomment it if you want to see response
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    track product add to favorite is failure")
            }
        }
        sdk.track(event: .productRemovedToFavorities(id: "644")) { trackResponse in
            print("   Product removed from favorities callback")
            switch trackResponse {
            case let .success(response):
                print("     track product removed from favorities is success")
            // print("Response: ", response) //uncomment it if you want to see response
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    track product removed from favorities is failure")
            }
        }
        sdk.track(event: .productAddedToCart(id: "644")) { trackResponse in
            print("   Product added to cart callback")
            switch trackResponse {
            case let .success(response):
                print("     track product added to cart is success")
            // print("Response: ", response) //uncomment it if you want to see response
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    track product added to cart is failure")
            }
        }
        sdk.track(event: .productRemovedFromCart(id: "644")) { trackResponse in
            print("   Product removed from cart callback")
            switch trackResponse {
            case let .success(response):
                print("     track product removed from cart is success")
            // print("Response: ", response) //uncomment it if you want to see response
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    track product removed from cart is failure")
            }
        }
        sdk.track(event: .synchronizeCart(items: [CartItem(productId: "784")])) { trackResponse in
            print("   Cart syncronized callback")
            switch trackResponse {
            case let .success(response):
                print("     track cart syncronized is success")
            // print("Response: ", response) //uncomment it if you want to see response
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    track cart syncronized is failure")
            }
        }
        sdk.track(event: .orderCreated(orderId: "123", totalValue: 33.3, products: [(id: "644", amount: 3), (id: "784", amount: 1)])) { trackResponse in
            print("   Order created callback")
            switch trackResponse {
            case let .success(response):
                print("     track order created is success")
            // print("Response: ", response) //uncomment it if you want to see response
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    track order created is failure")
            }
        }
        print("===")
        print("2. Testing product recommendations")
        sdk.recommend(blockId: "977cb67194a72fdc7b424f49d69a862d", currentProductId: "1") { recomendResponse in
            print("   Recommendations requested callback")
            switch recomendResponse {
            case let .success(response):
                print("     recommend with prodcut id is success")
            // print("Response: ", response) //uncomment it if you want to see response
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    recommend with prodcut id is failure")
            }
        }

        sdk.recommend(blockId: "977cb67194a72fdc7b424f49d69a862d", timeOut: 0.5) { recomendResponse in
            print("   Recommendations requested callback")
            switch recomendResponse {
            case let .success(response):
                print("     recommend is success")
            // print("Response: ", response) //uncomment it if you want to see response
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    recommend is failure")
            }
        }
        print("===")
        print("3. Testing search")
        sdk.suggest(query: "iphone") { searchResponse in
            print("   Instant search callback")
            switch searchResponse {
            case let .success(response):
                print("     instant search is success")
            // print("Response: ", response) //uncomment it if you want to see response
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    instant search is failure")
            }
        }
        print("===")

        sdk.search(query: "coat", sortBy: "popular", locations: "10", filters: ["Screen size, inch": ["15.6"]], timeOut: 0.2) { searchResponse in
            print("   Full search callback")
            switch searchResponse {
            case let .success(response):
                print("     full search is success")
            // print("Response: ", response) //uncomment it if you want to see response
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    full search is failure")
            }
        }

        sdk.searchBlank { searchResponse in
            print("   Search blank callback")
            switch searchResponse {
            case let .success(response):
                print("     Search blank is success")
            // print("Response: ", response) //uncomment it if you want to see response
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    Search blank is failure")
            }
        }

        print("4. Set user Settings")

        sdk.setProfileData(userEmail: "arseniydor@yandex.ru") { profileResponse in
            print("   Profile data set callback")
            switch profileResponse {
            case .success():
                print("     setProfileData is success")
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    setProfileData is failure")
            }
        }

        print("===")


        print("6. Send review")

        sdk.review(rate: 1, channel: "ios_app", category: "delivery", comment: "Nice application, thank you!") { reviewResponse in
            print("   Send review response")
            switch reviewResponse {
            case .success():
                print("     review is success")
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    review is failure")
            }
        }

        print("===")

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data -> String in
            String(format: "%02.2hhx", data)
        }

        let token = tokenParts.joined()
        print("Device Token: \(token)")

        print("5. Set push token")
        sdk.setPushTokenNotification(token: token) { tokenResponse in
            print("   Token set response")
            switch tokenResponse {
            case .success():
                print("     setPushTokenNotification is success")
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                // fatalError("    setPushTokenNotification is failure")
            }
        }

        print("===")
    }
}
