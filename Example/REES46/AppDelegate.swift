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
        
        sdk = createPersonalizationSDK(shopId: "357382bf66ac0ce2f1722677c59511")
        
        print("1. Testing tracking")
        sdk.track(event: .productView(id: "123")) { _ in
            print("   Product view callback")
        }
        sdk.track(event: .categoryView(id: "123")) { _ in
            print("   Category view callback")
        }
        sdk.track(event: .productAddedToFavorities(id: "123")) { _ in
            print("   Product added to favorities callback")
        }
        sdk.track(event: .productRemovedToFavorities(id: "123")) { _ in
            print("   Product removed from favorities callback")
        }
        sdk.track(event: .productAddedToCart(id: "123")) { _ in
            print("   Product added to cart callback")
        }
        sdk.track(event: .productRemovedFromCart(id: "123")) { _ in
            print("   Product removed from cart callback")
        }
        sdk.track(event: .syncronizeCart(ids: ["1", "2"])) { _ in
            print("   Cart syncronized callback")
        }
        sdk.track(event: .orderCreated(orderId: "123", totalValue: 33.3, products: [(id: "1", amount: 3), (id: "2", amount: 1)])) { _ in
            print("   Order created callback")
        }

        print("===")

        print("2. Testing product recommendations")
        sdk.recommend(blockId: "11118fd6807a70903de3553ad480e172", currentProductId: "1") { recomendResult in
            print("   Recommendations requested callback")
        }
        
        sdk.recommend(blockId: "11118fd6807a70903de3553ad480e172") { recomendResult in
            print("   Recommendations requested callback")
        }
        
        print("===")

        print("3. Testing search")
        sdk.search(query: "iphone", searchType: .instant) { searchResult in
            print("   Instant search callback")
        }
        sdk.search(query: "iphone", searchType: .full) { searchResult in
            print("   Full search callback")
        }
        print("===")
        
        
        print("4. Set user Settings")
        
        sdk.setProfileData(userEmail: "email") { (profileresponse) in
            print("   Profile data set callback")
        }
        
        print("===")
        
        print("5. Set push token")
        
        sdk.setPushTokenNotification(token: "testToken") { (tokenResponse) in
            print("     Token set response")
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

