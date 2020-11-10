//
//  AppDelegate.swift
//  REES46
//
//  Created by Avsi222 on 08/06/2020.
//  Copyright (c) 2020 Avsi222. All rights reserved.
//

import REES46
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    var sdk: PersonalizationSDK!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // sdk = createPersonalizationSDK(shopId: "357382bf66ac0ce2f1722677c59511")
        
        print("0. Init SDK")
        sdk = createPersonalizationSDK(shopId: "357382bf66ac0ce2f1722677c59511", { error in
            print(error)
        })
        
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
                case .custom(let customError):
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
                case .custom(let customError):
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
                case .custom(let customError):
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
                case .custom(let customError):
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
                case .custom(let customError):
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
                case .custom(let customError):
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
                case .custom(let customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    track product removed from cart is failure")
            }
        }
        sdk.track(event: .synchronizeCart(ids: ["644", "784"])) { trackResponse in
            print("   Cart syncronized callback")
            switch trackResponse {
            case let .success(response):
                print("     track cart syncronized is success")
            // print("Response: ", response) //uncomment it if you want to see response
            case let .failure(error):
                switch error {
                case .custom(let customError):
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
                case .custom(let customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    track order created is failure")
            }
        }

        print("===")

        print("2. Testing product recommendations")

        sdk.recommend(blockId: "11118fd6807a70903de3553ad480e172", currentProductId: "644") { recomendResponse in
            print("   Recommendations requested callback")
            switch recomendResponse {
            case let .success(response):
                print("     recommend with prodcut id is success")
            // print("Response: ", response) //uncomment it if you want to see response
            case let .failure(error):
                switch error {
                case .custom(let customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    recommend with prodcut id is failure")
            }
        }
        

        sdk.recommend(blockId: "11118fd6807a70903de3553ad480e172", timeOut: 0.5 ) { recomendResponse in
            print("   Recommendations requested callback")
            switch recomendResponse {
            case let .success(response):
                print("     recommend is success")
            // print("Response: ", response) //uncomment it if you want to see response
            case let .failure(error):
                switch error {
                case .custom(let customError):
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
                case .custom(let customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    instant search is failure")
            }
        }
        sdk.search(query: "coat", sortBy: "popular", locations: "10", filters: ["Screen size, inch": ["15.6"]], timeOut: 0.2) { searchResponse in
            print("   Full search callback")
            switch searchResponse {
            case let .success(response):
                print("     full search is success")
            // print("Response: ", response) //uncomment it if you want to see response
            case let .failure(error):
                switch error {
                case .custom(let customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    full search is failure")
            }
        }
        print("===")

        print("4. Set user Settings")

        sdk.setProfileData(userEmail: "email") { profileResponse in
            print("   Profile data set callback")
            switch profileResponse {
            case .success():
                print("     setProfileData is success")
            case let .failure(error):
                switch error {
                case .custom(let customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    setProfileData is failure")
            }
        }

        print("===")

        print("5. Set push token")

        sdk.setPushTokenNotification(token: "testToken") { tokenResponse in
            print("   Token set response")
            switch tokenResponse {
            case .success():
                print("     setPushTokenNotification is success")
            case let .failure(error):
                switch error {
                case .custom(let customError):
                    print("Error: ", customError)
                default:
                    print("Error: ", error.localizedDescription)
                }
                fatalError("    setPushTokenNotification is failure")
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
                case .custom(let customError):
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

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}
