//
//  FakeSDK.swift
//  REES46Tests
//
//  A minimal `PersonalizationSDK` conformer for the multi-instance registry tests.
//
//  The registry never calls into an instance — it only stores and resolves references by identity —
//  so every method here is a no-op and every getter returns a stored/placeholder value. This is the
//  iOS analog of the Android `SdkRegistryTest` using bare `SDK()` instances, but offline and with no
//  background retention (a real `SimplePersonalizationSDK` would spawn an init request that keeps the
//  instance alive, defeating the weak-reference / dealloc tests).
//

import Foundation
import UIKit
@testable import REES46

final class FakeSDK: PersonalizationSDK {

    var shopId: String
    var deviceId: String = "fake-device-id"
    var userSeance: String = "fake-seance"
    var segment: String = "A"
    var storiesCode: String?
    let sessionQueue: SessionQueue = SessionQueue.manager
    var parentViewController: UIViewController?
    var urlSession: URLSession = .shared
    var popupPresentationDelegate: PopupPresentationDelegate?
    var enableAutoPopupPresentation: Bool = true
    lazy var popupPresenter: PopupPresenter = PopupPresenter(sdk: self)

    init(shopId: String = "fake-shop") {
        self.shopId = shopId
    }

    func postRequest(path: String, params: [String: Any], completion: @escaping (Result<[String: Any], SdkError>) -> Void) {}
    func getRequest(path: String, params: [String: String], _ isInit: Bool, completion: @escaping (Result<[String: Any], SdkError>) -> Void) {}
    func configureURLSession(configuration: URLSessionConfiguration) {}
    func generateString(array: [String]) -> String { "" }
    func setProfileData(userEmail: String?, userPhone: String?, userLoyaltyId: String?, birthday: Date?, age: Int?, firstName: String?, lastName: String?, location: String?, gender: Gender?, advertisingId: String?, fbID: String?, vkID: String?, telegramId: String?, loyaltyCardLocation: String?, loyaltyStatus: String?, loyaltyBonuses: Int?, loyaltyBonusesToNextLevel: Int?, boughtSomething: Bool?, userId: String?, customProperties: [String: Any?]?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func trackPurchase(_ request: PurchaseTrackingRequest, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func trackSource(source: RecommendedByCase, code: String) {}
    func trackEvent(event: String, time: Int?, category: String?, label: String?, value: Int?, customFields: [String: Any]?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func trackPopupShown(popupId: Int, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func recommend(blockId: String, currentProductId: String?, currentCategoryId: String?, locations: String?, imageSize: String?, timeOut: Double?, withLocations: Bool, extended: Bool, completion: @escaping (Result<RecommenderResponse, SdkError>) -> Void) {}
    func suggest(query: String, locations: String?, excludedMerchants: [String]?, excludedBrands: [String]?, timeOut: Double?, extended: String?, completion: @escaping (Result<SearchResponse, SdkError>) -> Void) {}
    func getProductsList(brands: String?, merchants: String?, categories: String?, locations: String?, limit: Int?, page: Int?, filters: [String: Any]?, completion: @escaping (Result<ProductsListResponse, SdkError>) -> Void) {}
    func getProductsFromCart(completion: @escaping (Result<[CartItem], SdkError>) -> Void) {}
    func getProductInfo(id: String, completion: @escaping (Result<ProductInfo, SdkError>) -> Void) {}
    func getLastOrderProducts(completion: @escaping (Result<LastOrderProductsResponse, SdkError>) -> Void) {}
    func getUserOrders(shopSecret: String, did: String?, email: String?, phone: String?, loyaltyId: String?, externalId: String?, dateFrom: String?, completion: @escaping (Result<[Order], SdkError>) -> Void) {}
    func joinLoyalty(phone: String, email: String?, firstName: String?, lastName: String?, completion: @escaping (Result<LoyaltyJoinResponse, SdkError>) -> Void) {}
    func getLoyaltyStatus(identifier: String, completion: @escaping (Result<LoyaltyStatusResponse, SdkError>) -> Void) {}
    func getProfile(completion: @escaping (Result<GetProfileResponse, SdkError>) -> Void) {}
    func getProductCounters(item: String, completion: @escaping (Result<ProductCountersResponse, SdkError>) -> Void) {}
    func getCategory(category: String, limit: Int?, page: Int?, brands: String?, locations: String?, filters: [String: Any]?, completion: @escaping (Result<CategoryResponse, SdkError>) -> Void) {}
    func getCollection(collectionId: String, location: String?, email: String?, phone: String?, externalId: String?, loyaltyId: String?, completion: @escaping (Result<CollectionResponse, SdkError>) -> Void) {}
    func getDeviceId() -> String { deviceId }
    func setParentViewController(controller: UIViewController, completion: @escaping () -> Void) {}
    func getNotificationWidget() -> NotificationWidget? { nil }
    func getSession() -> String { userSeance }
    func getCurrentSegment() -> String { segment }
    func getShopId() -> String { shopId }
    func setPushTokenNotification(token: String, isFirebaseNotification: Bool, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func review(rate: Int, channel: String, category: String, orderId: String?, comment: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func searchBlank(completion: @escaping (Result<SearchBlankResponse, SdkError>) -> Void) {}
    func search(query: String, limit: Int?, offset: Int?, categoryLimit: Int?, brandLimit: Int?, categories: [Int]?, extended: String?, sortBy: String?, sortDir: String?, locations: String?, excludedMerchants: [String]?, excludedBrands: [String]?, brands: String?, filters: [String: Any]?, priceMin: Double?, priceMax: Double?, colors: [String]?, fashionSizes: [String]?, exclude: String?, email: String?, timeOut: Double?, disableClarification: Bool?, completion: @escaping (Result<SearchResponse, SdkError>) -> Void) {}
    func notificationClicked(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func notificationDelivered(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func notificationReceived(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func subscribeForBackInStock(id: String, email: String?, phone: String?, fashionSize: String?, fashionColor: String?, barcode: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func unsubscribeForBackInStock(itemIds: [String], email: String?, phone: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func subscribeForPriceDrop(id: String, currentPrice: Double, email: String?, phone: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func unsubscribeForPriceDrop(itemIds: [String], currentPrice: Double, email: String?, phone: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func getStories(code: String, completion: @escaping (Result<StoryContent, SdkError>) -> Void) {}
    func getProbabilityToPurchase(params: PurchasePredictParams, completion: @escaping (Result<ProbabilityToPurchaseResponse, SdkError>) -> Void) {}
    func addToSegment(segmentId: String, email: String?, phone: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func removeFromSegment(segmentId: String, email: String?, phone: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func manageSubscription(email: String?, phone: String?, userExternalId: String?, userLoyaltyId: String?, telegramId: String?, emailBulk: Bool?, emailChain: Bool?, emailTransactional: Bool?, smsBulk: Bool?, smsChain: Bool?, smsTransactional: Bool?, webPushBulk: Bool?, webPushChain: Bool?, webPushTransactional: Bool?, mobilePushBulk: Bool?, mobilePushChain: Bool?, mobilePushTransactional: Bool?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func configuration() -> SdkConfiguration.Type { SdkConfiguration.self }
    func sendIDFARequest(idfa: UUID, completion: @escaping (Result<InitResponse, SdkError>) -> Void) {}
    func deleteUserCredentials() {}
}
