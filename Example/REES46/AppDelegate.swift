//
//  AppDelegate.swift
//  REES46
//
//  Created by Avsi222 on 08/06/2020.
//  Copyright (c) 2020 Avsi222. All rights reserved.
//

import UIKit
import REES46

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var sdk: PersonalizationSDK!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        sdk = createPersonalizationSDK(shopId: "74fd3b613553b97107bc4502752749")
        
        print("1. Testing tracking")
        sdk.track(event: .productView(id: "123")) { trackResponse in
            print("   Product view callback")
            switch trackResponse{
            case .success(let response):
                print("     track product view is success")
                //print("Response: ", response) //uncomment it if you want to see response
            case .failure(let error):
                print("Error: ", error.localizedDescription)
                fatalError("     track product view is failure")
            }
        }
        sdk.track(event: .categoryView(id: "123")) { trackResponse in
            print("   Category view callback")
            switch trackResponse{
            case .success(let response):
                print("     track category view is success")
                //print("Response: ", response) //uncomment it if you want to see response
            case .failure(let error):
                print("Error: ", error.localizedDescription)
                fatalError("    track category view is failure")
            }
        }
        sdk.track(event: .productAddedToFavorities(id: "123")) { trackResponse in
            print("   Product added to favorities callback")
            switch trackResponse{
            case .success(let response):
                print("     track product add to favorite is success")
                //print("Response: ", response) //uncomment it if you want to see response
            case .failure(let error):
                print("Error: ", error.localizedDescription)
                fatalError("    track product add to favorite is failure")
            }
        }
        sdk.track(event: .productRemovedToFavorities(id: "123")) { trackResponse in
            print("   Product removed from favorities callback")
            switch trackResponse{
            case .success(let response):
                print("     track product removed from favorities is success")
                //print("Response: ", response) //uncomment it if you want to see response
            case .failure(let error):
                print("Error: ", error.localizedDescription)
                fatalError("    track product removed from favorities is failure")
            }
        }
        sdk.track(event: .productAddedToCart(id: "123")) { trackResponse in
            print("   Product added to cart callback")
            switch trackResponse{
            case .success(let response):
                print("     track product added to cart is success")
                //print("Response: ", response) //uncomment it if you want to see response
            case .failure(let error):
                print("Error: ", error.localizedDescription)
                fatalError("    track product added to cart is failure")
            }
        }
        sdk.track(event: .productRemovedFromCart(id: "123")) { trackResponse in
            print("   Product removed from cart callback")
            switch trackResponse{
            case .success(let response):
                print("     track product removed from cart is success")
                //print("Response: ", response) //uncomment it if you want to see response
            case .failure(let error):
                print("Error: ", error.localizedDescription)
                fatalError("    track product removed from cart is failure")
            }
        }
        sdk.track(event: .synchronizeCart(ids: ["1", "2"])) { trackResponse in
            print("   Cart syncronized callback")
            switch trackResponse{
            case .success(let response):
                print("     track cart syncronized is success")
                //print("Response: ", response) //uncomment it if you want to see response
            case .failure(let error):
                print("Error: ", error.localizedDescription)
                fatalError("    track cart syncronized is failure")
            }
        }
        sdk.track(event: .orderCreated(orderId: "123", totalValue: 33.3, products: [(id: "1", amount: 3), (id: "2", amount: 1)])) { trackResponse in
            print("   Order created callback")
            switch trackResponse{
            case .success(let response):
                print("     track order created is success")
                //print("Response: ", response) //uncomment it if you want to see response
            case .failure(let error):
                print("Error: ", error.localizedDescription)
                fatalError("    track order created is failure")
            }
        }

        print("===")

        print("2. Testing product recommendations")
        
        sdk.recommend(blockId: "928f0061e9b548f96d16917390ab6732", currentProductId: "1") { recomendResponse in
            print("   Recommendations requested callback")
            switch recomendResponse{
            case .success(let response):
                print("     recommend with prodcut id is success")
                //print("Response: ", response) //uncomment it if you want to see response
            case .failure(let error):
                print("Error: ", error.localizedDescription)
                fatalError("    recommend with prodcut id is failure")
            }
        }
        
        sdk.recommend(blockId: "1b51f5790e8cf2db2b94571c99e1ea12") { recomendResponse in
            print("   Recommendations requested callback")
            switch recomendResponse{
            case .success(let response):
                print("     recommend is success")
                //print("Response: ", response) //uncomment it if you want to see response
            case .failure(let error):
                print("Error: ", error.localizedDescription)
                fatalError("    recommend is failure")
            }
        }
        
        print("===")

        print("3. Testing search")
        sdk.suggest(query: "iphone") { searchResponse in
            print("   Instant search callback")
            switch searchResponse{
            case .success(let response):
                print("     instant search is success")
                //print("Response: ", response) //uncomment it if you want to see response
            case .failure(let error):
                print("Error: ", error.localizedDescription)
                fatalError("    instant search is failure")
            }
        }
        sdk.search(query: "ноутбук",sortBy: "popular", locations: "10",filters: ["максимальная диагональ ноутбука, дюйм":["15.6"]]) { searchResponse in
            print("   Full search callback")
            switch searchResponse{
            case .success(let response):
                print("     full search is success")
                //print("Response: ", response) //uncomment it if you want to see response
            case .failure(let error):
                print("Error: ", error.localizedDescription)
                fatalError("    full search is failure")
            }
        }
        print("===")
        
        
        print("4. Set user Settings")
        
        sdk.setProfileData(userEmail: "email") { (profileResponse) in
            print("   Profile data set callback")
            switch profileResponse{
            case .success():
                print("     setProfileData is success")
            case .failure(let error):
                print("Error: ", error.localizedDescription)
                fatalError("    setProfileData is failure")
            }
        }
        
        print("===")
        
        print("5. Set push token")
        
        sdk.setPushTokenNotification(token: "testToken") { (tokenResponse) in
            print("   Token set response")
            switch tokenResponse{
            case .success():
                print("     setPushTokenNotification is success")
            case .failure(let error):
                print("Error: ", error.localizedDescription)
                fatalError("    setPushTokenNotification is failure")
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

