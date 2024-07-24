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

var globalSDKAdditionalInit: PersonalizationSDK?
var globalSDKNotificationNameAdditionalInit = Notification.Name("globalSDKAdditionalInit")

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    let gcmMessageIDKey = "gcm.message_id"
    var sdk: PersonalizationSDK!
    var sdkAdditionalInit: PersonalizationSDK!
    var notificationService: NotificationServiceProtocol?
    
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        print("A. Init firebase sdk")
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        print("======")
        
        print("0. Init SDK")
        sdk = createPersonalizationSDK(
            shopId: "357382bf66ac0ce2f1722677c59511", enableLogs: true, { error in
                didToken = self.sdk.getDeviceId()
                globalSDK = self.sdk
                NotificationCenter.default.post(name: globalSDKNotificationNameMainInit, object: nil)
            }
        )

        print("2. Register push")
        notificationService = NotificationService(sdk: sdk)
        notificationService?.pushActionDelegate = self
        print("======")

        exampleUsageSdk()
        return true
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
    
    private func exampleUsageSdk(){
        
        //        print("1. Init additional SDK if needed")
        //        sdkAdditionalInit = createPersonalizationSDK(shopId: "357382bf66ac0ce2f1722677c59511", enableLogs: true, { error in
        //            //print("SDK Init status =", error?.description ?? SDKError.noError, "with shop_id", self.sdkAdditionalInit.getShopId())
        //            didToken = self.sdkAdditionalInit.getDeviceId()
        //            globalSDKAdditionalInit = self.sdkAdditionalInit
        //            NotificationCenter.default.post(name: globalSDKNotificationNameAdditionalInit, object: nil)
        //        })
        
        //        //SDK Configuration init Font first
        //        sdk.configuration().stories.registerFont(fileName: "Inter", fileExtension: FontExtension.ttf.rawValue) //ttf or otf
        
        //        //SDK Configuration settings
        //        sdk.configuration().stories.setStoriesBlock(fontName: "Inter",
        //                                                    fontSize: 15.0,
        //                                                    textColor: "#5ec169",
        //                                                    textColorDarkMode: "#5ec169",
        //                                                    backgroundColor: "#ffffff",
        //                                                    backgroundColorDarkMode: "#000000",
        //                                                    iconSize: 76,
        //                                                    iconBorderWidth: 2.3,
        //                                                    iconMarginX: 18,
        //                                                    iconMarginBottom: 8,
        //                                                    iconNotViewedBorderColor: "#fd7c50",
        //                                                    iconNotViewedBorderColorDarkMode: "#fd7c50",
        //                                                    iconViewedBorderColor: "#fdc2a1",
        //                                                    iconViewedBorderColorDarkMode: "#fdc2a1",
        //                                                    iconViewedTransparency: 1.0,
        //                                                    iconAnimatedLoaderColor: "#5ec169",
        //                                                    iconPlaceholderColor: "#d6d6d6",
        //                                                    iconPlaceholderColorDarkMode: "#d6d6d6",
        //                                                    iconDisplayFormatSquare: false,
        //                                                    labelWidth: 76,
        //                                                    pinColor: "#fd7c50",
        //                                                    pinColorDarkMode: "#fd7c50",
        //                                                    closeIconColor: "#5ec169")
        
        //        sdk.configuration().stories.setSlideDefaultButton(fontName: "Inter",
        //                                                          fontSize: 17.0,
        //                                                          textColor: "#ffffff",
        //                                                          backgroundColor: "#5ec169",
        //                                                          textColorDarkMode: "#000000",
        //                                                          backgroundColorDarkMode: "#ffffff",
        //                                                          cornerRadius: 5)
        
        //        sdk.configuration().stories.setSlideProductsButton(fontName: "Inter",
        //                                                           fontSize: 17.0,
        //                                                           textColor: "#ffffff",
        //                                                           backgroundColor: "#5ec169",
        //                                                           textColorDarkMode: "#000000",
        //                                                           backgroundColorDarkMode: "#ffffff",
        //                                                           cornerRadius: 5)
        
        //        sdk.configuration().stories.setProductsCard(fontName: "Inter",
        //                                                    showProductsButtonText: "See all products",
        //                                                    hideProductsButtonText: "Hide products")
        
        //        sdk.configuration().stories.setPromocodeCard(productBannerFontName: "Inter",
        //                                                     productTitleFontSize: 16.0,
        //                                                     productTitleTextColor: "#5ec169",
        //                                                     productTitleTextColorDarkMode: "#5ec169",
        //                                                     productBannerOldPriceSectionFontColor: "#5ec169",
        //                                                     productBannerPriceSectionFontColor: "#5ec169",
        //                                                     productBannerPriceSectionBackgroundColor: "#ffffff",
        //                                                     productBannerPromocodeSectionFontColor: "#ff0000",
        //                                                     productBannerPromocodeSectionBackgroundColor: "#5ec169",
        //                                                     productBannerDiscountSectionBackgroundColor: "#5ec169",
        //                                                     productBannerPromocodeCopyToClipboardMessage: "Copied")
        
        //        //SDK Recommendations Widget settings
        //        sdk.configuration().recommendations.setWidgetBlock(widgetFontName: "Inter",
        //                                                           widgetBackgroundColor: "#ffffff",
        //                                                           widgetBackgroundColorDarkMode: "#000000",
        //                                                           widgetCellBackgroundColor: "#ffffff",
        //                                                           widgetCellBackgroundColorDarkMode: "#000000",
        //                                                           widgetBorderWidth: 1,
        //                                                           widgetBorderColor: "#c3c3c3",
        //                                                           widgetBorderColorDarkMode: "#c3c3c3",
        //                                                           widgetBorderTransparent: 0.4,
        //                                                           widgetCornerRadius: 9,
        //                                                           widgetStarsColor: "#ff9500",
        //                                                           widgetAddToCartButtonText: "Add to cart",
        //                                                           widgetRemoveFromCartButtonText: "Remove from cart",
        //                                                           widgetAddToCartButtonFontSize: 17,
        //                                                           widgetRemoveFromCartButtonFontSize: 14,
        //                                                           widgetCartButtonTextColor: "#ffffff",
        //                                                           widgetCartButtonTextColorDarkMode: "#ffffff",
        //                                                           widgetCartButtonBackgroundColor: "#000000",
        //                                                           widgetCartButtonBackgroundColorDarkMode: "#ffffff",
        //                                                           widgetCartButtonNeedOpenWebUrl: false,
        //                                                           widgetFavoritesIconColor: "#000000",
        //                                                           widgetFavoritesIconColorDarkMode: "#ffffff",
        //                                                           widgetPreloadIndicatorColor: "#ffffff",
        //                                                           widgetNoReviewDefaultMessage: "No reviews")
        
        //        //SDK Stories block collection cell indicator
        //        sdk.configuration().stories.storiesBlockPreloadIndicatorDisabled = true //default false - cell indicator enabled
        
        //        //SDK Stories Slide default indicator
        //        sdk.configuration().stories.storiesSlideReloadIndicatorDisabled = true //default false - slide indicator enabled
        //        sdk.configuration().stories.storiesSlideReloadIndicatorBackgroundColor = "#ffffff"
        //        sdk.configuration().stories.storiesSlideReloadIndicatorSize = 76.0
        //        sdk.configuration().stories.storiesSlideReloadIndicatorBorderLineWidth = 3
        //        sdk.configuration().stories.storiesSlideReloadIndicatorSegmentCount = 9
        //        sdk.configuration().stories.storiesSlideReloadIndicatorAnimationDuration = 1
        //        sdk.configuration().stories.storiesSlideReloadIndicatorRotationDuration = 17
        //
        //        //SDK Stories block autoreload settings
        //        sdk.configuration().stories.storiesSlideReloadManually = false //default false - autoreload enabled
        //        sdk.configuration().stories.storiesSlideReloadTimeoutInterval = 10 //default infinity
        //
        //        //SDK Alert popup connection settings
        //        sdk.configuration().stories.storiesSlideReloadPopupMessageError = "Failed to retrieve data. Please check your connection and try again."
        //        sdk.configuration().stories.storiesSlideReloadPopupMessageFontSize = 17.0
        //        sdk.configuration().stories.storiesSlideReloadPopupMessageFontWeight = .medium
        //        sdk.configuration().stories.storiesSlideReloadPopupMessageDisplayTime = 4
        //        sdk.configuration().stories.storiesSlideReloadPopupPositionY = 120 //default constant
        
        //        //SDK Stories block text label characters wrapping settings
        //        sdk.configuration().stories.storiesBlockNumberOfLines = 0
        //        sdk.configuration().stories.storiesBlockCharWrapping = false
        //        sdk.configuration().stories.storiesBlockCharCountWrap = 15
        
        
        //        print("3. Testing tracking")
        //        sdk.trackSource(source: .chain, code: "123123")
        //
        //        let rec = RecomendedBy(type: .dynamic, code: "beb620922934b6ba2d6a3fb82b8b3271")
        //        sdk.track(event: .productView(id: "644"), recommendedBy: rec) { trackResponse in
        //            print("   Product view callback")
        //            switch trackResponse {
        //            case let .success(response):
        //                print("     track product view is success")
        //                withExtendedLifetime(response) {
        //                    //print("Response:", response) //Uncomment it if you want to see response
        //                }
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                // fatalError("     track product view is failure")
        //            }
        //        }
        //
        //        print("4. Testing tracking")
        //        sdk.track(event: .productView(id: "644")) { trackResponse in
        //            print("   Product view callback")
        //            switch trackResponse {
        //            case let .success(response):
        //                print("     track product view is success")
        //                withExtendedLifetime(response) {
        //                    //print("Response:", response) //Uncomment it if you want to see response
        //                }
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                //fatalError("     track product view is failure")
        //            }
        //        }
        //
        //        sdk.track(event: .categoryView(id: "644")) { trackResponse in
        //            print("   Category view callback")
        //            switch trackResponse {
        //            case let .success(response):
        //                print("     track category view is success")
        //                withExtendedLifetime(response) {
        //                    //print("Response:", response) //Uncomment it if you want to see response
        //                }
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                //fatalError("    track category view is failure")
        //            }
        //        }
        //
        //        sdk.track(event: .productAddedToFavorites(id: "644")) { trackResponse in
        //            print("   Product added to favorites callback")
        //            switch trackResponse {
        //            case let .success(response):
        //                print("     track product add to favorite is success")
        //                withExtendedLifetime(response) {
        //                    //print("Response:", response) //Uncomment it if you want to see response
        //                }
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                //fatalError("    track product add to favorite is failure")
        //            }
        //        }
        //
        //        sdk.track(event: .productRemovedFromFavorites(id: "644")) { trackResponse in
        //            print("   Product removed from favorites callback")
        //            switch trackResponse {
        //            case let .success(response):
        //                print("     track product removed from favorites is success")
        //                withExtendedLifetime(response) {
        //                    //print("Response:", response) //Uncomment it if you want to see response
        //                }
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                //fatalError("    track product removed from favorites is failure")
        //            }
        //        }
        //
        //        sdk.track(event: .productAddedToCart(id: "644")) { trackResponse in
        //            print("   Product added to cart callback")
        //            switch trackResponse {
        //            case let .success(response):
        //                print("     track product added to cart is success")
        //                withExtendedLifetime(response) {
        //                    //print("Response:", response) //Uncomment it if you want to see response
        //                }
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                //fatalError("    track product added to cart is failure")
        //            }
        //        }
        //
        //        sdk.track(event: .productRemovedFromCart(id: "644")) { trackResponse in
        //            print("   Product removed from cart callback")
        //            switch trackResponse {
        //            case let .success(response):
        //                print("     track product removed from cart is success")
        //                withExtendedLifetime(response) {
        //                    //print("Response:", response) //Uncomment it if you want to see response
        //                }
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                //fatalError("    track product removed from cart is failure")
        //            }
        //        }
        //
        //        sdk.track(event: .synchronizeCart(items: [CartItem(productId: "784")])) { trackResponse in
        //            print("   Cart syncronized callback")
        //            switch trackResponse {
        //            case let .success(response):
        //                print("     track cart syncronized is success")
        //                withExtendedLifetime(response) {
        //                    //print("Response:", response) //Uncomment it if you want to see response
        //                }
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                //fatalError("    track cart syncronized is failure")
        //            }
        //        }
        //       sdk.track(event: .synchronizeFavorites(ids: ["784"])) { trackResponse in
        //            print("   favorites syncronized callback")
        //            switch trackResponse {
        //            case let .success(response):
        //                print("     track favorites syncronized is success")
        //                withExtendedLifetime(response) {
        //                    //print("Response:", response) //Uncomment it if you want to see response
        //                }
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                //fatalError("    track favorites syncronized is failure")
        //            }
        //        }
        //
        //        sdk.track(event: .orderCreated(orderId: "123", totalValue: 33.3, products: [(id: "644", amount: 3, price: 500)], deliveryAddress: "Address" , deliveryType: "post", promocode: "999", paymentType: "cash", taxFree: true)) { trackResponse in
        //            print("   Order created callback")
        //            switch trackResponse {
        //            case let .success(response):
        //                print("     track order created is success")
        //                withExtendedLifetime(response) {
        //                    //print("Response:", response) //Uncomment it if you want to see response
        //                }
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                //fatalError("    track order created is failure")
        //            }
        //        }
        //
        //        sdk.trackEvent(event: "click", category: "2", label: "None", value: 2) { trackResponse in
        //            print("   Custom track event callback")
        //            switch trackResponse {
        //            case let .success(response):
        //                print("     custom track event is success")
        //                withExtendedLifetime(response) {
        //                    //print("Response:", response) //Uncomment it if you want to see response
        //                }
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                // fatalError("    track order created is failure")
        //            }
        //        }
        //
        //        print("5. Testing product recommendations")
        //        sdk.recommend(blockId: "977cb67194a72fdc7b424f49d69a862d", currentProductId: "644") { recomendResponse in
        //            print("   Recommendations product requested callback")
        //            switch recomendResponse {
        //            case let .success(response):
        //                print("     recommend with product id is success")
        //                withExtendedLifetime(response) {
        //                    //print("Response:", response) //Uncomment it if you want to see response
        //                }
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.localizedDescription)
        //                }
        //                //fatalError("    recommend with product id is failure")
        //            }
        //        }
        //
        //        print("6. Testing recommendations")
        //        sdk.recommend(blockId: "977cb67194a72fdc7b424f49d69a862d", currentProductId: "644", timeOut: 0.5) { recomendResponse in
        //            print("   Recommendations requested callback")
        //            switch recomendResponse {
        //            case let .success(response):
        //                print("     recommend is success")
        //                withExtendedLifetime(response) {
        //                    //print("Response:", response) //Uncomment it if you want to see response
        //                }
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                //fatalError("    recommend is failure")
        //            }
        //        }
        //
        //        print("7. Testing products list")
        //        sdk.getProductsList(brands: "Hasbro", categories: "Toys", locations: "Shops", filters: ["Screen size, inch": ["15.6"]]) { productsListResponse in
        //            print("   Testing get products list callback")
        //            switch productsListResponse {
        //            case let .success(response):
        //                print("     get products list is success")
        //                withExtendedLifetime(response) {
        //                    //print("Response:", response) //Uncomment it if you want to see response
        //                }
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                //fatalError("    get products list is failure")
        //            }
        //        }
        //        sdk.getProductsFromCart { result in
        //            switch result {
        //            case .success(let items):
        //                print("cart items: \n \(items)")
        //            case .failure(let error):
        //                print("error: \(error)")
        //            }
        //        }
        //
        //        print("8. Testing product info by item_id")
        //        sdk.getProductInfo(id: "1930") { productInfoResponse in
        //            print("   Testing get product info callback")
        //            switch productInfoResponse {
        //            case let .success(response):
        //                print("     get product info is success")
        //                withExtendedLifetime(response) {
        //                    //print("Response:", response) //Uncomment it if you want to see response
        //                }
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                //fatalError("    get product info is failure")
        //            }
        //        }
        //
        //        print("9. Testing search")
        //        sdk.suggest(query: "iphone") { searchResponse in
        //            print("   Instant search callback")
        //            switch searchResponse {
        //            case let .success(response):
        //                print("     instant search is success")
        //                withExtendedLifetime(response) {
        //                    //print("Response:", response) //Uncomment it if you want to see response
        //                }
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                //fatalError("    instant search is failure")
        //            }
        //        }
        //
        //        print("10. Testing detail search")
        //        sdk.search(query: "shoes", sortBy: "popular", locations: "10", filters: ["Screen size, inch": ["15.6"]], colors: ["white", "black"], fashionSizes: ["36", "37", "38", "39", "40"], timeOut: 0.2) { searchResponse in
        //            print("   Full search callback")
        //            switch searchResponse {
        //            case let .success(response):
        //                print("     full search is success")
        //                withExtendedLifetime(response) {
        //                    //print("Response:", response) //Uncomment it if you want to see response
        //                }
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                //fatalError("    full search is failure")
        //            }
        //        }
        //
        //        print("11. Testing blank search")
        //        sdk.searchBlank { searchResponse in
        //            print("   Search blank callback")
        //            switch searchResponse {
        //            case let .success(response):
        //                print("     search blank is success")
        //                withExtendedLifetime(response) {
        //                    //print("Response:", response) //Uncomment it if you want to see response
        //                }
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                //fatalError("    Search blank is failure")
        //            }
        //        }
        //
        //        print("12. Set user profile Settings")
        //        sdk.setProfileData(userEmail: "mail@example.com") { profileResponse in
        //            print("   Profile data set callback")
        //            switch profileResponse {
        //            case .success():
        //                print("     setProfileData is success")
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                //fatalError("    setProfileData is failure")
        //            }
        //        }
        //
        //        print("13. Send review")
        //        sdk.review(rate: 1, channel: "ios_app", category: "delivery", comment: "Nice application, thank you!") { reviewResponse in
        //            print("   Send review response")
        //            switch reviewResponse {
        //            case .success():
        //                print("     review is success")
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.description)
        //                }
        //                //fatalError("    review is failure")
        //            }
        //        }
        //
        //        print("===END===")
        
        //        sdk.unsubscribeForBackInStock(
        //            itemIds: ["784"],
        //            email: "mail@example.com",
        //            phone: "+19999999999"
        //        ) { unsubscribeResponse in
        //            print("Unsubscribe response received")
        //            switch unsubscribeResponse {
        //            case .success():
        //                print("Successfully unsubscribed from back in stock notifications.")
        //                print("Response: \(unsubscribeResponse)")
        //            case let .failure(error):
        //                print("Unsubscribe failed with error: \(error)")
        //                switch error {
        //                case let .custom(customError):
        //                    print("Error:", customError)
        //                default:
        //                    print("Error:", error.localizedDescription)
        //                }
        //            }
        //        }
        
        //        sdk.subscribeForBackInStock(
        //            id: "757",
        //            email: "borislogintrub@gamil.com",
        //            phone: nil,
        //            fashionSize: nil,
        //            fashionColor: nil,
        //            barcode: nil
        //        ) { subscribeResponse in
        //            switch subscribeResponse {
        //            case .success():
        //                print("!!!!! Successfully subscribed from back in stock notifications.")
        //                print("!!!!! Response: \(subscribeResponse)")
        //            case let .failure(error):
        //                switch error {
        //                case let .custom(customError):
        //                    print("!!!!! Error:", customError)
        //                default:
        //                    print("!!!!! Error:", error.localizedDescription)
        //                }
        //            }
        //        }
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // FIREBASE TOKEN FOR TEST
        fcmGlobalToken = fcmToken ?? ""
        UserDefaults.standard.set(fcmToken, forKey: "fcmGlobalToken")
        // FIREBASE TOKEN SEND TEST
        // notificationService?.didReceiveRegistrationFCMToken(fcmToken: fcmToken)
        // FIREBASE TOKEN END TEST
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // FOR TEST
        let tokenParts = deviceToken.map { data -> String in
            String(format: "%02.2hhx", data)
        }
        
        let token = tokenParts.joined()
        pushGlobalToken = token
        print("Push Token:", pushGlobalToken)
        UserDefaults.standard.set(token, forKey: "pushGlobalToken")
        
        Messaging.messaging().apnsToken = deviceToken
        // END TEST
        
        notificationService?.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: deviceToken)
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
        let navigationController = UINavigationController(rootViewController: pushVC)
        window?.rootViewController?.present(navigationController, animated: true)
    }
}
