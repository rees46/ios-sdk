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

    /// Events the `tracking` namespace was asked to send, in order. Nothing goes out: `tracking`
    /// runs over a recorder instead of the event service.
    var trackedEvents: [Event] { trackRecorder.events }
    private let trackRecorder = RecordingTrackService()

    var tracking: TrackingAPI {
        TrackingAPIImpl(trackService: trackRecorder, sourceService: TrackSourceServiceImpl(store: sourceRecorder))
    }

    /// Sources `tracking.setSource` stored, in order. Kept here rather than in `UserDefaults`.
    var storedSources: [(type: String, code: String)] { sourceRecorder.sources }
    private let sourceRecorder = RecordingSourceStore()

    /// Stories the fake hands back from `getStories`, so the stories block tests can drive an empty
    /// and a filled load. Left `nil` the call never completes, as before.
    var storiesResult: Result<StoryContent, SdkError>?

    /// How long the stories result stays in flight. The real SDK answers from its session queue, so
    /// the fake answers off the main queue too — raise this to keep a load pending while the test
    /// drives main-thread work against the block.
    var storiesResultDelay: TimeInterval = 0

    /// Stands in for the SDK's session queue: whatever `getStories` reports comes from here, never
    /// from the caller's thread.
    private let storiesQueue = DispatchQueue(label: "FakeSDK.stories")

    /// Answers `search` hands back in order, so the search results screen tests can fail a page
    /// and serve it on retry. The answer comes synchronously; the screen hops to the main queue
    /// on its own. Nothing left — the call never completes, as before.
    var searchResults: [Result<SearchResponse, SdkError>] = []

    /// `offset` of every `search` call, in order.
    private(set) var searchOffsets: [Int?] = []

    /// Answers `getCategory` (the one with price and sorting) hands back in order, synchronously,
    /// so the category screen tests can fail a page and serve it on retry. Nothing left — the call
    /// never completes.
    var categoryResults: [Result<CategoryResponse, SdkError>] = []

    /// Arguments of a `getCategory` call with price and sorting.
    struct CategoryCall {
        var category: String
        var limit: Int?
        var page: Int?
        var brands: String?
        var locations: String?
        var filters: [String: [String]]?
        var priceMin: Double?
        var priceMax: Double?
        var sortBy: String?
        var sortDir: String?
    }

    /// Every `getCategory` call with price and sorting, in order.
    private(set) var categoryCalls: [CategoryCall] = []

    /// Answers `recommend` hands back in order, synchronously, so the recommender block tests can
    /// script a filled, an empty and a failed block. Nothing left — the call never completes.
    var recommendResults: [Result<RecommenderResponse, SdkError>] = []

    /// While on, `recommend` keeps its completion in `heldRecommend` instead of answering, so a
    /// test can look at the block mid-load and answer by hand.
    var holdsRecommend = false
    private(set) var heldRecommend: [(Result<RecommenderResponse, SdkError>) -> Void] = []

    /// Arguments of every `recommend` call, in order.
    private(set) var recommendCalls: [(blockId: String, itemId: String?, categoryId: String?, locations: String?, extended: Bool)] = []

    /// Answers `getCollection` hands back in order, synchronously. Nothing left — never completes.
    var collectionResults: [Result<CollectionResponse, SdkError>] = []

    /// `collectionId` of every `getCollection` call, in order.
    private(set) var collectionCalls: [String] = []

    /// Called with every `getRequest`, from whatever queue the caller is on, so tests can check
    /// what an SDK service would send. The request itself never completes, as before.
    var onGetRequest: ((_ path: String, _ params: [String: String]) -> Void)?

    /// Records notification-track calls so tests can assert push routing hit the right instance.
    private(set) var deliveredTracks: [(type: String, code: String)] = []
    private(set) var receivedTracks: [(type: String, code: String)] = []
    private(set) var clickedTracks: [(type: String, code: String)] = []

    init(shopId: String = "fake-shop") {
        self.shopId = shopId
    }

    func postRequest(path: String, params: [String: Any], completion: @escaping (Result<[String: Any], SdkError>) -> Void) {}
    func getRequest(path: String, params: [String: String], _ isInit: Bool, completion: @escaping (Result<[String: Any], SdkError>) -> Void) {
        onGetRequest?(path, params)
    }
    func configureURLSession(configuration: URLSessionConfiguration) {}
    func generateString(array: [String]) -> String { "" }
    func setProfileData(userEmail: String?, userPhone: String?, userLoyaltyId: String?, birthday: Date?, age: Int?, firstName: String?, lastName: String?, location: String?, gender: Gender?, advertisingId: String?, fbID: String?, vkID: String?, telegramId: String?, loyaltyCardLocation: String?, loyaltyStatus: String?, loyaltyBonuses: Int?, loyaltyBonusesToNextLevel: Int?, boughtSomething: Bool?, userId: String?, customProperties: [String: Any?]?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func trackPurchase(_ request: PurchaseTrackingRequest, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func trackSource(source: RecommendedByCase, code: String) {}
    func trackEvent(event: String, time: Int?, category: String?, label: String?, value: Int?, customFields: [String: Any]?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func trackPopupShown(popupId: Int, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func recommend(blockId: String, currentProductId: String?, currentCategoryId: String?, locations: String?, imageSize: String?, timeOut: Double?, withLocations: Bool, extended: Bool, completion: @escaping (Result<RecommenderResponse, SdkError>) -> Void) {
        recommendCalls.append((blockId, currentProductId, currentCategoryId, locations, extended))
        if holdsRecommend { return heldRecommend.append(completion) }
        guard !recommendResults.isEmpty else { return }
        completion(recommendResults.removeFirst())
    }
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
    func getCategory(category: String, limit: Int?, page: Int?, brands: String?, locations: String?, filters: [String: Any]?, priceMin: Double?, priceMax: Double?, sortBy: String?, sortDir: String?, completion: @escaping (Result<CategoryResponse, SdkError>) -> Void) {
        categoryCalls.append(CategoryCall(
            category: category, limit: limit, page: page, brands: brands, locations: locations,
            filters: filters as? [String: [String]], priceMin: priceMin, priceMax: priceMax, sortBy: sortBy, sortDir: sortDir
        ))
        guard !categoryResults.isEmpty else { return }
        completion(categoryResults.removeFirst())
    }
    func getCollection(collectionId: String, location: String?, email: String?, phone: String?, externalId: String?, loyaltyId: String?, completion: @escaping (Result<CollectionResponse, SdkError>) -> Void) {
        collectionCalls.append(collectionId)
        guard !collectionResults.isEmpty else { return }
        completion(collectionResults.removeFirst())
    }
    func getDeviceId() -> String { deviceId }
    func setParentViewController(controller: UIViewController, completion: @escaping () -> Void) {}
    func getNotificationWidget() -> NotificationWidget? { nil }
    func getSession() -> String { userSeance }
    func getCurrentSegment() -> String { segment }
    func getShopId() -> String { shopId }
    func setPushTokenNotification(token: String, isFirebaseNotification: Bool, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func review(rate: Int, channel: String, category: String, orderId: String?, comment: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func searchBlank(completion: @escaping (Result<SearchBlankResponse, SdkError>) -> Void) {}
    func search(query: String, limit: Int?, offset: Int?, categoryLimit: Int?, brandLimit: Int?, categories: [Int]?, extended: String?, sortBy: String?, sortDir: String?, locations: String?, excludedMerchants: [String]?, excludedBrands: [String]?, brands: String?, filters: [String: Any]?, priceMin: Double?, priceMax: Double?, colors: [String]?, fashionSizes: [String]?, exclude: String?, email: String?, timeOut: Double?, disableClarification: Bool?, completion: @escaping (Result<SearchResponse, SdkError>) -> Void) {
        searchOffsets.append(offset)
        guard !searchResults.isEmpty else { return }
        completion(searchResults.removeFirst())
    }
    func notificationClicked(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {
        clickedTracks.append((type, code))
    }
    func notificationDelivered(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {
        deliveredTracks.append((type, code))
    }
    func notificationReceived(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {
        receivedTracks.append((type, code))
    }
    func subscribeForBackInStock(id: String, email: String?, phone: String?, fashionSize: String?, fashionColor: String?, barcode: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func unsubscribeForBackInStock(itemIds: [String], email: String?, phone: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func subscribeForPriceDrop(id: String, currentPrice: Double, email: String?, phone: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func unsubscribeForPriceDrop(itemIds: [String], currentPrice: Double, email: String?, phone: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func getStories(code: String, completion: @escaping (Result<StoryContent, SdkError>) -> Void) {
        guard let storiesResult = storiesResult else { return }
        storiesQueue.asyncAfter(deadline: .now() + storiesResultDelay) {
            completion(storiesResult)
        }
    }
    func getProbabilityToPurchase(params: PurchasePredictParams, completion: @escaping (Result<ProbabilityToPurchaseResponse, SdkError>) -> Void) {}
    func addToSegment(segmentId: String, email: String?, phone: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func removeFromSegment(segmentId: String, email: String?, phone: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func manageSubscription(email: String?, phone: String?, userExternalId: String?, userLoyaltyId: String?, telegramId: String?, emailBulk: Bool?, emailChain: Bool?, emailTransactional: Bool?, smsBulk: Bool?, smsChain: Bool?, smsTransactional: Bool?, webPushBulk: Bool?, webPushChain: Bool?, webPushTransactional: Bool?, mobilePushBulk: Bool?, mobilePushChain: Bool?, mobilePushTransactional: Bool?, telegramBulk: Bool?, telegramChain: Bool?, telegramTransactional: Bool?, whatsappBulk: Bool?, whatsappChain: Bool?, whatsappTransactional: Bool?, maxBulk: Bool?, maxChain: Bool?, maxTransactional: Bool?, walletBulk: Bool?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func configuration() -> SdkConfiguration.Type { SdkConfiguration.self }
    func sendIDFARequest(idfa: UUID, completion: @escaping (Result<InitResponse, SdkError>) -> Void) {}
    func deleteUserCredentials() {}
}

/// Event service behind `FakeSDK.tracking`: records what would be sent and never completes,
/// as the fake's own requests never do.
final class RecordingTrackService: TrackEventServiceProtocol {
    private(set) var events: [Event] = []

    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        events.append(event)
    }
    func track(event: Event, source: TrackingSourceWire?, details: TrackEventDetails, completion: @escaping (Result<Void, SdkError>) -> Void) {
        events.append(event)
    }
    func trackPurchase(_ request: PurchaseTrackingRequest, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func trackPurchase(_ request: PurchaseTrackingRequest, source: TrackingSourceWire?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func trackEvent(event: String, time: Int?, category: String?, label: String?, value: Int?, customFields: [String: Any]?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func trackPopupShown(popupId: Int, completion: @escaping (Result<Void, SdkError>) -> Void) {}
}

/// Source store behind `FakeSDK.tracking`: records what `setSource` would keep.
final class RecordingSourceStore: TrackingSourceStore {
    private(set) var sources: [(type: String, code: String)] = []

    func store(type: String, code: String) {
        sources.append((type, code))
    }

    func currentSource() -> (type: String, code: String)? {
        sources.last
    }
}
