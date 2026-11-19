import XCTest
@_spi(Bridge) @testable import REES46

/// Covers the `tracking` namespace: that every method maps onto the event the API expects, and
/// that the two fields added with the namespace (cart price, search results) reach the wire.
final class TrackingNamespaceTests: XCTestCase {

    // MARK: - Mapping onto events

    func test_productView_mapsToProductViewEvent() {
        let spy = TrackEventServiceSpy()
        let tracking = TrackingAPIImpl(trackService: spy, sourceService: TrackSourceServiceSpy())

        tracking.productView(itemId: "sku-1")

        guard case let .productView(id) = spy.lastEvent else {
            return XCTFail("Expected .productView, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(id, "sku-1")
        XCTAssertNil(spy.lastSource)
    }

    func test_categoryView_mapsToCategoryViewEvent() {
        let spy = TrackEventServiceSpy()
        let tracking = TrackingAPIImpl(trackService: spy, sourceService: TrackSourceServiceSpy())

        tracking.categoryView(categoryId: "women-shoes")

        guard case let .categoryView(id) = spy.lastEvent else {
            return XCTFail("Expected .categoryView, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(id, "women-shoes")
    }

    func test_search_carriesQueryAndResults() {
        let spy = TrackEventServiceSpy()
        let tracking = TrackingAPIImpl(trackService: spy, sourceService: TrackSourceServiceSpy())

        tracking.search(query: "boots", results: ["sku-1", "sku-2"])

        guard case let .search(query) = spy.lastEvent else {
            return XCTFail("Expected .search, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(query, "boots")
        XCTAssertEqual(spy.lastDetails?.results, ["sku-1", "sku-2"])
    }

    func test_addToCart_carriesQuantityAndPrice() {
        let spy = TrackEventServiceSpy()
        let tracking = TrackingAPIImpl(trackService: spy, sourceService: TrackSourceServiceSpy())

        tracking.addToCart(item: TrackingItem(id: "sku-1", quantity: 3, price: 49.9))

        guard case let .productAddedToCart(id, amount) = spy.lastEvent else {
            return XCTFail("Expected .productAddedToCart, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(id, "sku-1")
        XCTAssertEqual(amount, 3)
        XCTAssertEqual(spy.lastDetails?.price, 49.9)
    }

    func test_syncCart_mapsItemsAndKeepsPrice() {
        let spy = TrackEventServiceSpy()
        let tracking = TrackingAPIImpl(trackService: spy, sourceService: TrackSourceServiceSpy())

        tracking.syncCart(items: [
            TrackingItem(id: "sku-1", quantity: 2, price: 10),
            TrackingItem(id: "sku-2"),
        ])

        guard case let .synchronizeCart(items) = spy.lastEvent else {
            return XCTFail("Expected .synchronizeCart, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].productId, "sku-1")
        XCTAssertEqual(items[0].quantity, 2)
        XCTAssertEqual(items[0].price, 10)
        XCTAssertEqual(items[1].quantity, 1)
        XCTAssertNil(items[1].price)
    }

    func test_removeFromCart_mapsToRemoveEvent() {
        let spy = TrackEventServiceSpy()
        let tracking = TrackingAPIImpl(trackService: spy, sourceService: TrackSourceServiceSpy())

        tracking.removeFromCart(itemId: "sku-1")

        guard case let .productRemovedFromCart(id) = spy.lastEvent else {
            return XCTFail("Expected .productRemovedFromCart, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(id, "sku-1")
    }

    func test_favorites_mapToWishEvents() {
        let spy = TrackEventServiceSpy()
        let tracking = TrackingAPIImpl(trackService: spy, sourceService: TrackSourceServiceSpy())

        tracking.addToFavorites(itemId: "sku-1")
        guard case let .productAddedToFavorites(addedId) = spy.lastEvent else {
            return XCTFail("Expected .productAddedToFavorites, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(addedId, "sku-1")

        tracking.removeFromFavorites(itemId: "sku-2")
        guard case let .productRemovedFromFavorites(removedId) = spy.lastEvent else {
            return XCTFail("Expected .productRemovedFromFavorites, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(removedId, "sku-2")

        tracking.syncFavorites(itemIds: ["sku-1", "sku-3"])
        guard case let .synchronizeFavorites(ids) = spy.lastEvent else {
            return XCTFail("Expected .synchronizeFavorites, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(ids, ["sku-1", "sku-3"])
    }

    func test_storyEvents_mapToSlideEvents() {
        let spy = TrackEventServiceSpy()
        let tracking = TrackingAPIImpl(trackService: spy, sourceService: TrackSourceServiceSpy())

        tracking.storyView(storyId: "42", slideId: "3", code: "main_stories")
        guard case let .slideView(viewedStory, viewedSlide) = spy.lastEvent else {
            return XCTFail("Expected .slideView, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(viewedStory, "42")
        XCTAssertEqual(viewedSlide, "3")
        XCTAssertEqual(spy.lastDetails?.storiesCode, "main_stories")

        tracking.storyClick(storyId: "42", slideId: "3")
        guard case let .slideClick(clickedStory, clickedSlide) = spy.lastEvent else {
            return XCTFail("Expected .slideClick, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(clickedStory, "42")
        XCTAssertEqual(clickedSlide, "3")
        XCTAssertNil(spy.lastDetails?.storiesCode, "omitted code must fall back to the SDK's loaded block")
    }

    // MARK: - Attribution

    func test_source_isForwardedAsRecommendedBy() {
        let spy = TrackEventServiceSpy()
        let tracking = TrackingAPIImpl(trackService: spy, sourceService: TrackSourceServiceSpy())

        tracking.productView(itemId: "sku-1", source: TrackingSource(type: .dynamic, code: "popular"))

        XCTAssertEqual(spy.lastSource?.type, TrackingSourceType.dynamic.rawValue)
        XCTAssertEqual(spy.lastSource?.code, "popular")
    }

    func test_setSource_isForwardedToSourceService() {
        let sourceSpy = TrackSourceServiceSpy()
        let tracking = TrackingAPIImpl(trackService: TrackEventServiceSpy(), sourceService: sourceSpy)

        tracking.setSource(TrackingSource(type: .fullSearch, code: "boots"))

        XCTAssertEqual(sourceSpy.lastType, TrackingSourceType.fullSearch.rawValue)
        XCTAssertEqual(sourceSpy.lastCode, "boots")
    }

    // MARK: - Purchase and custom events delegate unchanged

    func test_purchase_delegatesRequestAndSource() {
        let spy = TrackEventServiceSpy()
        let tracking = TrackingAPIImpl(trackService: spy, sourceService: TrackSourceServiceSpy())
        let request = PurchaseTrackingRequest(
            orderId: "order-1",
            orderPrice: 100,
            items: [PurchaseItemRequest(id: "sku-1", amount: 1, price: 100)]
        )

        tracking.purchase(request, source: TrackingSource(type: .chain, code: "welcome"))

        XCTAssertEqual(spy.lastPurchase?.orderId, "order-1")
        XCTAssertEqual(spy.lastSource?.type, TrackingSourceType.chain.rawValue)
    }

    func test_custom_delegatesEveryField() {
        let spy = TrackEventServiceSpy()
        let tracking = TrackingAPIImpl(trackService: spy, sourceService: TrackSourceServiceSpy())

        tracking.custom(
            event: "checkout_step",
            time: 1000,
            category: "checkout",
            label: "delivery",
            value: 2,
            customFields: ["delivery_type": "courier"]
        )

        XCTAssertEqual(spy.lastCustomEvent, "checkout_step")
        XCTAssertEqual(spy.lastCustomTime, 1000)
        XCTAssertEqual(spy.lastCustomCategory, "checkout")
        XCTAssertEqual(spy.lastCustomLabel, "delivery")
        XCTAssertEqual(spy.lastCustomValue, 2)
        XCTAssertEqual(spy.lastCustomFields?["delivery_type"] as? String, "courier")
    }

    // MARK: - Wire shape of the fields added with the namespace

    func test_addToCartWithPrice_reachesTheWire() {
        let sdk = MockPersonalizationSDK()
        let service = TrackEventServiceImpl(sdk: sdk)
        let expectation = expectation(description: "cart tracked")

        TrackingAPIImpl(trackService: service, sourceService: TrackSourceServiceSpy())
            .addToCart(item: TrackingItem(id: "sku-1", quantity: 2, price: 49.9)) { _ in
                expectation.fulfill()
            }

        waitForExpectations(timeout: 2.0)

        XCTAssertEqual(sdk.lastPostPath, "push")
        XCTAssertEqual(sdk.lastPostParams?["event"] as? String, "cart")
        let items = sdk.lastPostParams?["items"] as? [[String: Any]]
        XCTAssertEqual(items?.first?["id"] as? String, "sku-1")
        XCTAssertEqual(items?.first?["amount"] as? Int, 2)
        XCTAssertEqual(items?.first?["price"] as? Double, 49.9)
    }

    func test_purchaseGiftPackage_reachesTheWire() {
        let sdk = MockPersonalizationSDK()
        let service = TrackEventServiceImpl(sdk: sdk)
        let expectation = expectation(description: "purchase tracked")

        TrackingAPIImpl(trackService: service, sourceService: TrackSourceServiceSpy())
            .purchase(Self.purchaseRequest(isGiftPackage: true)) { _ in
                expectation.fulfill()
            }

        waitForExpectations(timeout: 2.0)

        XCTAssertEqual(sdk.lastPostPath, "push")
        XCTAssertEqual(sdk.lastPostParams?["event"] as? String, "purchase")
        XCTAssertEqual(sdk.lastPostParams?["gift_package"] as? Bool, true)
    }

    func test_purchaseWithoutGiftPackage_omitsTheKey() {
        let sdk = MockPersonalizationSDK()
        let service = TrackEventServiceImpl(sdk: sdk)
        let expectation = expectation(description: "purchase tracked")

        TrackingAPIImpl(trackService: service, sourceService: TrackSourceServiceSpy())
            .purchase(Self.purchaseRequest(isGiftPackage: false)) { _ in
                expectation.fulfill()
            }

        waitForExpectations(timeout: 2.0)

        XCTAssertEqual(sdk.postCallCount, 1)
        XCTAssertEqual(sdk.lastPostParams?["event"] as? String, "purchase")
        XCTAssertNil(sdk.lastPostParams?["gift_package"])
    }

    private static func purchaseRequest(isGiftPackage: Bool) -> PurchaseTrackingRequest {
        PurchaseTrackingRequest(
            orderId: "order-1",
            orderPrice: 100,
            items: [PurchaseItemRequest(id: "sku-1", amount: 1, price: 100)],
            isGiftPackage: isGiftPackage
        )
    }

    func test_searchResults_reachTheWireAsCommaSeparatedList() {
        let sdk = MockPersonalizationSDK()
        let service = TrackEventServiceImpl(sdk: sdk)
        let expectation = expectation(description: "search tracked")

        TrackingAPIImpl(trackService: service, sourceService: TrackSourceServiceSpy())
            .search(query: "boots", results: ["sku-1", "sku-2"]) { _ in
                expectation.fulfill()
            }

        waitForExpectations(timeout: 2.0)

        XCTAssertEqual(sdk.lastPostParams?["event"] as? String, "search")
        XCTAssertEqual(sdk.lastPostParams?["search_query"] as? String, "boots")
        XCTAssertEqual(sdk.lastPostParams?["results"] as? String, "sku-1,sku-2")
    }

    func test_storyView_reachesTheStoriesEndpoint() {
        let sdk = MockPersonalizationSDK()
        let service = TrackEventServiceImpl(sdk: sdk)
        let expectation = expectation(description: "story view tracked")

        TrackingAPIImpl(trackService: service, sourceService: TrackSourceServiceSpy())
            .storyView(storyId: "42", slideId: "3", code: "main_stories") { _ in
                expectation.fulfill()
            }

        waitForExpectations(timeout: 2.0)

        XCTAssertEqual(sdk.lastPostPath, "track/stories")
        XCTAssertEqual(sdk.lastPostParams?["event"] as? String, "view")
        XCTAssertEqual(sdk.lastPostParams?["story_id"] as? String, "42")
        XCTAssertEqual(sdk.lastPostParams?["slide_id"] as? String, "3")
        XCTAssertEqual(sdk.lastPostParams?["code"] as? String, "main_stories")
    }

    func test_storyView_withoutCode_fallsBackToTheLoadedBlock() {
        let sdk = MockPersonalizationSDK()
        sdk.storiesCode = "loaded_block"
        let service = TrackEventServiceImpl(sdk: sdk)
        let expectation = expectation(description: "story view tracked")

        TrackingAPIImpl(trackService: service, sourceService: TrackSourceServiceSpy())
            .storyClick(storyId: "42", slideId: "3") { _ in expectation.fulfill() }

        waitForExpectations(timeout: 2.0)

        XCTAssertEqual(sdk.lastPostParams?["event"] as? String, "click")
        XCTAssertEqual(sdk.lastPostParams?["code"] as? String, "loaded_block")
    }

    func test_productViewWithoutNewFields_wireIsUnchanged() {
        let sdk = MockPersonalizationSDK()
        let service = TrackEventServiceImpl(sdk: sdk)
        let expectation = expectation(description: "view tracked")

        TrackingAPIImpl(trackService: service, sourceService: TrackSourceServiceSpy())
            .productView(itemId: "sku-1") { _ in
                expectation.fulfill()
            }

        waitForExpectations(timeout: 2.0)

        XCTAssertEqual(sdk.lastPostParams?["event"] as? String, "view")
        let items = sdk.lastPostParams?["items"] as? [[String: Any]]
        XCTAssertEqual(items?.count, 1)
        XCTAssertEqual(items?.first?["id"] as? String, "sku-1")
        XCTAssertNil(items?.first?["price"])
    }
}

// MARK: - Spies

private final class TrackEventServiceSpy: TrackEventServiceProtocol {
    var lastEvent: Event?
    var lastSource: TrackingSourceWire?
    var lastDetails: TrackEventDetails?
    var lastPurchase: PurchaseTrackingRequest?
    var lastCustomEvent: String?
    var lastCustomTime: Int?
    var lastCustomCategory: String?
    var lastCustomLabel: String?
    var lastCustomValue: Int?
    var lastCustomFields: [String: Any]?

    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        track(
            event: event,
            source: recommendedBy.map(TrackingSourceWire.init),
            details: .none,
            completion: completion
        )
    }

    func track(event: Event, source: TrackingSourceWire?, details: TrackEventDetails, completion: @escaping (Result<Void, SdkError>) -> Void) {
        lastEvent = event
        lastSource = source
        lastDetails = details
        completion(.success(()))
    }

    func trackPurchase(_ request: PurchaseTrackingRequest, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        trackPurchase(request, source: recommendedBy.map(TrackingSourceWire.init), completion: completion)
    }

    func trackPurchase(_ request: PurchaseTrackingRequest, source: TrackingSourceWire?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        lastPurchase = request
        lastSource = source
        completion(.success(()))
    }

    func trackEvent(event: String, time: Int?, category: String?, label: String?, value: Int?, customFields: [String: Any]?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        lastCustomEvent = event
        lastCustomTime = time
        lastCustomCategory = category
        lastCustomLabel = label
        lastCustomValue = value
        lastCustomFields = customFields
        completion(.success(()))
    }

    func trackPopupShown(popupId: Int, completion: @escaping (Result<Void, SdkError>) -> Void) {
        completion(.success(()))
    }
}

private final class TrackSourceServiceSpy: TrackSourceServiceProtocol {
    var lastType: String?
    var lastCode: String?

    func trackSource(source: RecommendedByCase, code: String) {
        trackSource(type: source.rawValue, code: code)
    }

    func trackSource(type: String, code: String) {
        lastType = type
        lastCode = code
    }
}

/// The attribution `tracking.setSource(_:)` stores used to sit in `UserDefaults.standard` under bare
/// keys, so two shops in one app shared one source. It now lives in the shop's partition.
final class TrackingSourceStoreTests: XCTestCase {

    private let suiteA = "personalization_sdk_test_shop_a"
    private let suiteB = "personalization_sdk_test_shop_b"
    private let legacySuite = "personalization_sdk_test_legacy"

    /// Suites created through the real partition factory, removed in tearDown.
    private var suiteNames: [String] = []

    private func uniqueShop(_ label: String) -> String {
        let shopId = "\(label)-\(UUID().uuidString)"
        suiteNames.append(StoragePartition.suiteName(for: shopId))
        return shopId
    }

    override func tearDown() {
        for suite in Set([suiteA, suiteB, legacySuite] + suiteNames) {
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        suiteNames.removeAll()
        super.tearDown()
    }

    private func defaults(_ name: String) -> UserDefaults {
        let store = UserDefaults(suiteName: name)!
        store.removePersistentDomain(forName: name)
        return store
    }

    func test_sourceSetForOneShop_isNotVisibleToAnother() {
        let legacy = defaults(legacySuite)
        let shopA = TrackingSourceStoreImpl(store: defaults(suiteA), legacy: legacy)
        let shopB = TrackingSourceStoreImpl(store: defaults(suiteB), legacy: legacy)

        shopA.store(type: TrackingSourceType.dynamic.rawValue, code: "popular")

        let stored = shopA.currentSource()
        XCTAssertEqual(stored?.type, "dynamic")
        XCTAssertEqual(stored?.code, "popular")
        XCTAssertNil(shopB.currentSource(), "a source set for one shop must not colour another's events")
    }

    func test_upgradingInstall_stillSeesTheSourceItWasGivenBeforePartitioning() {
        let legacy = defaults(legacySuite)
        legacy.setValue(Date().timeIntervalSince1970, forKey: "timeStartSave")
        legacy.setValue("legacy-code", forKey: "recomendedCode")
        legacy.setValue("chain", forKey: "recomendedType")

        let store = TrackingSourceStoreImpl(store: defaults(suiteA), legacy: legacy)

        let stored = store.currentSource()
        XCTAssertEqual(stored?.type, "chain")
        XCTAssertEqual(stored?.code, "legacy-code")
    }

    func test_sourceOlderThan48Hours_isDropped() {
        let store = defaults(suiteA)
        store.setValue(Date().timeIntervalSince1970 - (49 * 60 * 60), forKey: "timeStartSave")
        store.setValue("stale-code", forKey: "recomendedCode")
        store.setValue("dynamic", forKey: "recomendedType")

        let subject = TrackingSourceStoreImpl(store: store, legacy: defaults(legacySuite))

        XCTAssertNil(subject.currentSource())
        XCTAssertNil(store.string(forKey: "recomendedCode"), "an expired source is cleared, not re-read")
    }

    // MARK: - Multi-instance

    /// The isolation the previous test shows, but reached the way an SDK instance reaches it:
    /// through `StoragePartition.store(for: shopId)`, so the derivation from shop id to suite is
    /// what is under test rather than two hand-picked suite names. Mirrors the Android
    /// `TrackingSourceMultiInstanceTest`.
    func test_twoShops_derivedFromTheirIds_haveIsolatedSources() {
        let shopA = uniqueShop("shop-a")
        let shopB = uniqueShop("shop-b")
        let storeA = TrackingSourceStoreImpl(store: StoragePartition.store(for: shopA), legacy: defaults(legacySuite))
        let storeB = TrackingSourceStoreImpl(store: StoragePartition.store(for: shopB), legacy: defaults(legacySuite))

        storeA.store(type: "dynamic", code: "block-a")
        storeB.store(type: "stories", code: "block-b")

        XCTAssertEqual(storeA.currentSource()?.type, "dynamic")
        XCTAssertEqual(storeA.currentSource()?.code, "block-a")
        XCTAssertEqual(storeB.currentSource()?.type, "stories")
        XCTAssertEqual(storeB.currentSource()?.code, "block-b")
    }

    /// Written to the shop's suite, so a later instance for the same shop still sees it.
    func test_aSourceSurvivesTheInstanceThatSetIt() {
        let shop = uniqueShop("shop-a")

        TrackingSourceStoreImpl(store: StoragePartition.store(for: shop), legacy: defaults(legacySuite))
            .store(type: "chain", code: "block-a")

        let freshInstance = TrackingSourceStoreImpl(
            store: StoragePartition.store(for: shop),
            legacy: defaults(legacySuite)
        )
        XCTAssertEqual(freshInstance.currentSource()?.type, "chain")
        XCTAssertEqual(freshInstance.currentSource()?.code, "block-a")
    }

    /// A host passing its own `storageKey` gets its own prefix of the shop's partition (decision 5):
    /// the source lands there, not in the default partition.
    func test_aHostSuppliedStorageKey_prefixesThePartition() {
        let hostKey = "host_own_key_\(UUID().uuidString)_"
        let shop = uniqueShop("shop-a")
        suiteNames.append(StoragePartition.suiteName(for: shop, storageKey: hostKey))

        TrackingSourceStoreImpl(
            store: StoragePartition.store(for: shop, storageKey: hostKey),
            legacy: defaults(legacySuite)
        ).store(type: "dynamic", code: "shared")

        let onHostKey = TrackingSourceStoreImpl(
            store: StoragePartition.store(for: shop, storageKey: hostKey),
            legacy: defaults(legacySuite)
        )
        let onPartition = TrackingSourceStoreImpl(
            store: StoragePartition.store(for: shop),
            legacy: defaults(legacySuite)
        )
        XCTAssertEqual(onHostKey.currentSource()?.code, "shared")
        XCTAssertNil(onPartition.currentSource(), "the per-shop partition must stay clean")
    }

    func test_neverSetSource_addsNothingToTheRequest() {
        let subject = TrackingSourceStoreImpl(store: defaults(suiteA), legacy: defaults(legacySuite))

        XCTAssertNil(subject.currentSource())
    }
}

/// A story slide attributes the events that follow it to its block — the behaviour Android has always
/// had in `StoriesManager.trackStory`, now matched here.
final class StoryAttributionTests: XCTestCase {

    private let sourceKeys = ["recomendedCode", "recomendedType", "timeStartSave"]

    override func setUp() {
        super.setUp()
        sourceKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() {
        sourceKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        super.tearDown()
    }

    func test_storyView_makesTheBlockTheSourceOfTheNextEvent() {
        let sdk = MockPersonalizationSDK()
        let tracking = TrackingAPIImpl(sdk: sdk)
        let storyTracked = expectation(description: "story tracked")

        tracking.storyView(storyId: "42", slideId: "3", code: "main_stories") { _ in
            storyTracked.fulfill()
        }
        wait(for: [storyTracked], timeout: 2.0)

        let viewTracked = expectation(description: "view tracked")
        tracking.productView(itemId: "sku-1") { _ in viewTracked.fulfill() }
        wait(for: [viewTracked], timeout: 2.0)

        let source = sdk.lastPostParams?["source"] as? [String: Any]
        XCTAssertEqual(source?["from"] as? String, "stories")
        XCTAssertEqual(source?["code"] as? String, "main_stories")
    }
}

/// What a stored source actually does to the requests that follow it. Written because a tester
/// reported `setSource` "not working": the answer depends entirely on which request you look at,
/// and on which platform.
final class StoredSourceOnFollowingRequestsTests: XCTestCase {

    private let sourceKeys = ["recomendedCode", "recomendedType", "timeStartSave"]

    override func setUp() {
        super.setUp()
        sourceKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() {
        sourceKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        super.tearDown()
    }

    private func track(_ sdk: MockPersonalizationSDK, _ body: (TrackingAPI, @escaping (Result<Void, SdkError>) -> Void) -> Void) -> [String: Any] {
        let done = expectation(description: "tracked")
        body(sdk.tracking) { _ in done.fulfill() }
        wait(for: [done], timeout: 2.0)
        return sdk.lastPostParams ?? [:]
    }

    func test_storedSource_staysOnEveryFollowingRequest() {
        let sdk = MockPersonalizationSDK()
        sdk.tracking.setSource(TrackingSource(type: .dynamic, code: "block-1"))

        let first = track(sdk) { $0.productView(itemId: "sku-1", completion: $1) }
        let second = track(sdk) { $0.categoryView(categoryId: "cat-1", completion: $1) }
        let third = track(sdk) { $0.addToFavorites(itemId: "sku-2", completion: $1) }

        for (name, body) in [("first", first), ("second", second), ("third", third)] {
            let source = body["source"] as? [String: Any]
            XCTAssertEqual(source?["from"] as? String, "dynamic", "\(name) request lost the source")
            XCTAssertEqual(source?["code"] as? String, "block-1", "\(name) request lost the code")
        }
    }

    func test_storedSource_reachesAPurchase() {
        let sdk = MockPersonalizationSDK()
        sdk.tracking.setSource(TrackingSource(type: .dynamic, code: "block-1"))
        let request = PurchaseTrackingRequest(
            orderId: "order-1",
            orderPrice: 100,
            items: [PurchaseItemRequest(id: "sku-1", amount: 1, price: 100)]
        )

        let body = track(sdk) { $0.purchase(request, completion: $1) }

        let source = body["source"] as? [String: Any]
        XCTAssertEqual(source?["from"] as? String, "dynamic")
        XCTAssertEqual(source?["code"] as? String, "block-1")
    }

    func test_storedSource_reachesACustomEvent() {
        let sdk = MockPersonalizationSDK()
        sdk.tracking.setSource(TrackingSource(type: .bulk, code: "newsletter"))

        let body = track(sdk) { $0.custom(event: "shared", completion: $1) }

        XCTAssertEqual(sdk.lastPostPath, "push/custom")
        let source = body["source"] as? [String: Any]
        XCTAssertEqual(source?["from"] as? String, "bulk")
        XCTAssertEqual(source?["code"] as? String, "newsletter")
    }

    /// `popup/showed` carries no attribution — the one send path left alone, on both platforms.
    func test_storedSource_doesNotReachPopupShown() {
        let sdk = MockPersonalizationSDK()
        sdk.tracking.setSource(TrackingSource(type: .dynamic, code: "block-1"))

        let done = expectation(description: "popup tracked")
        sdk.trackPopupShown(popupId: 7) { _ in done.fulfill() }
        wait(for: [done], timeout: 2.0)

        XCTAssertEqual(sdk.lastPostPath, "popup/showed")
        XCTAssertNil(sdk.lastPostParams?["source"])
    }

    func test_withNoSourceStored_requestsCarryNoSourceField() {
        let sdk = MockPersonalizationSDK()

        let body = track(sdk) { $0.productView(itemId: "sku-1", completion: $1) }

        XCTAssertNil(body["source"])
    }

    func test_anExpiredSource_neverReachesTheWire() {
        let sdk = MockPersonalizationSDK()
        sdk.tracking.setSource(TrackingSource(type: .dynamic, code: "stale"))
        // Push the window shut; the store drops the values on the next read.
        UserDefaults.standard.setValue(
            Date().timeIntervalSince1970 - (49 * 60 * 60),
            forKey: "timeStartSave"
        )

        let body = track(sdk) { $0.productView(itemId: "sku-1", completion: $1) }

        XCTAssertNil(body["source"])
    }

    func test_storyClick_alsoMakesItsBlockTheSource() {
        let sdk = MockPersonalizationSDK()

        let clicked = expectation(description: "story tracked")
        sdk.tracking.storyClick(storyId: "42", slideId: "3", code: "main_stories") { _ in
            clicked.fulfill()
        }
        wait(for: [clicked], timeout: 2.0)

        let body = track(sdk) { $0.productView(itemId: "sku-1", completion: $1) }

        let source = body["source"] as? [String: Any]
        XCTAssertEqual(source?["from"] as? String, "stories")
        XCTAssertEqual(source?["code"] as? String, "main_stories")
    }

    func test_aRawSourceTypeTheLegacyEnumLacks_survivesTheRoundTrip() {
        let sdk = MockPersonalizationSDK()
        sdk.tracking.setSource(TrackingSource(type: .stories, code: "main_stories"))

        let body = track(sdk) { $0.productView(itemId: "sku-1", completion: $1) }

        let source = body["source"] as? [String: Any]
        XCTAssertEqual(source?["from"] as? String, "stories", "RecommendedByCase has no stories case")
        XCTAssertEqual(source?["code"] as? String, "main_stories")
    }

    /// The stored source and a per-call `source:` do not use the same fields. Pinning it so the
    /// difference is visible rather than discovered against the backend.
    func test_storedSourceAndPerCallSource_useDifferentWireFields() {
        let sdk = MockPersonalizationSDK()

        sdk.tracking.setSource(TrackingSource(type: .dynamic, code: "stored-block"))
        let stored = track(sdk) { $0.productView(itemId: "sku-1", completion: $1) }

        XCTAssertNotNil(stored["source"], "a stored source travels in the `source` object")
        XCTAssertNil(stored["recommended_by"], "…and not as recommended_by")

        let perCall = track(sdk) {
            $0.productView(
                itemId: "sku-1",
                source: TrackingSource(type: .chain, code: "call-block"),
                completion: $1
            )
        }
        XCTAssertEqual(perCall["recommended_by"] as? String, "chain")
        XCTAssertEqual(perCall["recommended_code"] as? String, "call-block")
    }
}

/// The contract's additions to `tracking` (`sdk/contract/tracking.md`) over the stub server, on both cores:
/// `popupShown`, the `async` forms under `tracking.async`, the sources of a mailing an event refuses, and
/// the slides `track/stories` takes.
final class TrackingContractTests: CoreScenarioTestCase {

    // MARK: - Helpers

    /// Runs `body` in a task while this thread waits: what it threw, `.some(nil)` when nothing.
    private func run(timeout: TimeInterval = 5, _ body: @escaping () async throws -> Void) -> Error?? {
        let done = expectation(description: "async call")
        let outcome = Locked<Error??>(nil)
        _Concurrency.Task {
            do {
                try await body()
                outcome.current = .some(nil)
            } catch {
                outcome.current = .some(error)
            }
            done.fulfill()
        }
        wait(for: [done], timeout: timeout)
        return outcome.current
    }

    private func popupShown(_ tracking: TrackingAPI, _ popupId: Int) -> Result<Void, Rees46.SdkError>? {
        let done = expectation(description: "popupShown")
        let outcome = Locked<Result<Void, Rees46.SdkError>?>(nil)
        tracking.popupShown(popupId: popupId) { result in
            XCTAssertTrue(Thread.isMainThread)
            outcome.current = result
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return outcome.current
    }

    private func failure(_ result: Result<Void, Rees46.SdkError>?) -> Rees46.SdkError? {
        guard case .failure(let error)? = result else { return nil }
        return error
    }

    /// What the old completion of a call heard, with the whole error behind it.
    private func completion(_ call: (@escaping (Result<Void, SdkError>) -> Void) -> Void) -> Result<Void, Rees46.SdkError>? {
        let done = expectation(description: "completion")
        let outcome = Locked<Result<Void, Rees46.SdkError>?>(nil)
        call(Rees46.BridgeErrors.completion { outcome.current = $0; done.fulfill() })
        wait(for: [done], timeout: 5)
        return outcome.current
    }

    // MARK: - popupShown

    func test_popupShown_queues_popup_showed_and_completes_on_the_main_thread_once_the_queue_took_it() {
        let shop = newShop()
        let sdk = makeV2(shop)
        hold("/popup/showed")

        guard case .success? = popupShown(sdk.tracking, 7) else { return XCTFail("the queue took it") }
        XCTAssertEqual(files(sdk.storage).count, 1, "accepted: on disk, its answer still held")

        release("/popup/showed")
        XCTAssertTrue(eventually { self.requests("/popup/showed", shop).count == 1 })
        let body = requests("/popup/showed", shop).first?.body ?? [:]
        XCTAssertEqual(body["popup"] as? Int, 7)
        XCTAssertEqual(body["did"] as? String, "d")
        XCTAssertNotNil(body["sid"])
        XCTAssertNil(body["source"], "popup/showed reads no source")
        XCTAssertTrue(eventually { self.files(sdk.storage).isEmpty })
    }

    func test_popupShown_of_a_released_instance_is_notInitialized_and_sends_nothing() {
        let shop = newShop()
        let sdk = makeV2(shop)
        sdk.release()

        XCTAssertEqual(failure(popupShown(sdk.tracking, 7)), .notInitialized)
        XCTAssertEqual(run { try await sdk.tracking.async.popupShown(popupId: 7) } as? Rees46.SdkError, .notInitialized)
        XCTAssertTrue(requests("/popup/showed", shop).isEmpty)
    }

    func test_popupShown_on_the_old_core_sends_at_once_and_hears_the_servers_answer() {
        let shop = newShop()
        let sdk = makeLegacy(shop)

        guard case .success? = popupShown(sdk.tracking, 9) else { return XCTFail("the server took it") }
        let body = requests("/popup/showed", shop).last?.body ?? [:]
        XCTAssertEqual(body["popup"] as? Int, 9)
        XCTAssertEqual(body["shop_id"] as? String, shop)

        answer("/popup/showed", StubReply(500, json: #"{"status":"error","message":"boom"}"#))
        XCTAssertEqual(failure(popupShown(sdk.tracking, 9)), .http(code: 500, serverCode: nil))
    }

    func test_popupShown_of_a_tracking_the_sdk_did_not_make_is_notInitialized() {
        XCTAssertEqual(failure(popupShown(AppTracking(), 7)), .notInitialized)
    }

    // MARK: - The async forms

    func test_an_async_form_returns_once_the_queue_took_the_event_not_once_it_was_sent() {
        let shop = newShop()
        let sdk = makeV2(shop)
        hold("/push")

        XCTAssertNil(run { try await sdk.tracking.async.productView(itemId: "37") } ?? .some(TestError.noOutcome), "returned while its request is held")
        XCTAssertNil(run { try await sdk.tracking.async.custom(event: "flutter_example", category: "c") } ?? .some(TestError.noOutcome))
        XCTAssertNil(run { try await sdk.tracking.async.storyView(storyId: "12", slideId: "34", code: "main") } ?? .some(TestError.noOutcome))

        release("/push")
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 && self.requests("/push/custom", shop).count == 1 })
        XCTAssertTrue(eventually { self.requests("/track/stories", shop).count == 1 })
        XCTAssertEqual(itemIds(requests("/push", shop)), ["37"])
        XCTAssertEqual(requests("/push/custom", shop).first?.body["event"] as? String, "flutter_example")
    }

    func test_every_async_form_sends_its_event() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let tracking = sdk.tracking.async
        let purchase = PurchaseTrackingRequest(orderId: "o-1", orderPrice: 10, items: [PurchaseItemRequest(id: "1", amount: 1, price: 10)])
        let calls: [() async throws -> Void] = [
            { try await tracking.productView(itemId: "1", source: TrackingSource(type: .dynamic, code: "b")) },
            { try await tracking.categoryView(categoryId: "c-1") },
            { try await tracking.search(query: "boots") },
            { try await tracking.addToCart(item: TrackingItem(id: "2", quantity: 2)) },
            { try await tracking.syncCart(items: []) },
            { try await tracking.removeFromCart(itemId: "2") },
            { try await tracking.addToFavorites(itemId: "3") },
            { try await tracking.syncFavorites(itemIds: ["3"]) },
            { try await tracking.removeFromFavorites(itemId: "3") },
            { try await tracking.purchase(purchase) },
            { try await tracking.storyClick(storyId: "12", slideId: "34", code: "b") },
            { try await tracking.popupShown(popupId: 5) },
        ]
        for call in calls {
            XCTAssertNil(run(call) ?? .some(TestError.noOutcome))
        }

        XCTAssertTrue(queueIdle(sdk))
        let events = requests("/push", shop).compactMap { $0.body["event"] as? String }
        XCTAssertEqual(events, ["view", "category", "search", "cart", "cart", "remove_from_cart", "wish", "wish", "remove_wish", "purchase"])
        XCTAssertEqual(requests("/track/stories", shop).first?.body["event"] as? String, "click")
        XCTAssertEqual(requests("/popup/showed", shop).first?.body["popup"] as? Int, 5)
    }

    func test_an_async_form_throws_the_refusal_and_sends_nothing() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let empty = PurchaseTrackingRequest(orderId: "o-1", orderPrice: 10, items: [])

        guard case .invalidArgument? = run({ try await sdk.tracking.async.productView(itemId: " ") }) as? Rees46.SdkError else {
            return XCTFail("an empty item id")
        }
        guard case .invalidArgument? = run({ try await sdk.tracking.async.purchase(empty) }) as? Rees46.SdkError else {
            return XCTFail("a purchase without items")
        }
        guard case .invalidArgument? = run({ try await sdk.tracking.async.custom(event: "e", customFields: ["did": "x"]) }) as? Rees46.SdkError else {
            return XCTFail("a reserved key")
        }
        XCTAssertNil(run { try await sdk.tracking.async.storyView(storyId: "12_1", slideId: "1") } ?? .some(TestError.noOutcome), "a virtual slide is no error")

        sdk.release()
        XCTAssertEqual(run { try await sdk.tracking.async.categoryView(categoryId: "c") } as? Rees46.SdkError, .notInitialized)
        XCTAssertTrue(queueIdle(sdk))
        XCTAssertTrue(requests("/push", shop).isEmpty)
        XCTAssertTrue(requests("/push/custom", shop).isEmpty)
        XCTAssertTrue(requests("/track/stories", shop).isEmpty)
    }

    func test_an_async_form_on_the_old_core_returns_once_the_server_answered() {
        let shop = newShop()
        let sdk = makeLegacy(shop)
        hold("/push")
        let returned = Locked(false)
        let done = expectation(description: "returned")
        _Concurrency.Task {
            try? await sdk.tracking.async.addToFavorites(itemId: "5")
            returned.current = true
            done.fulfill()
        }
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 })
        XCTAssertFalse(eventually(timeout: 0.3) { returned.current }, "no queue: it waits for the answer")
        release("/push")
        wait(for: [done], timeout: 5)

        answer("/push", StubReply(json: #"{"status":"error"}"#))
        XCTAssertEqual(run { try await sdk.tracking.async.removeFromFavorites(itemId: "5") } as? Rees46.SdkError, .decoding, "an answer that is not success")
    }

    func test_an_async_form_of_a_tracking_the_sdk_did_not_make_hears_its_completion() {
        let app = AppTracking()
        XCTAssertNil(run { try await app.async.categoryView(categoryId: "c") } ?? .some(TestError.noOutcome))
        XCTAssertEqual(app.calls, ["categoryView c"])
        app.refusal = .custom(error: "no such category")
        XCTAssertEqual(run { try await app.async.categoryView(categoryId: "x") } as? Rees46.SdkError, .invalidArgument("no such category"))
        app.refusal = .networkOfflineError
        XCTAssertEqual(run { try await app.async.categoryView(categoryId: "y") } as? Rees46.SdkError, .network)
    }

    /// The calls an app made before the `async` forms came still compile from `async` code, without
    /// `await`: a form by the same name beside them would take them over.
    func test_the_calls_without_a_completion_still_compile_from_async_code() async {
        let tracking: TrackingAPI = AppTracking()
        tracking.productView(itemId: "1")
        tracking.productView(itemId: "1", source: TrackingSource(type: .dynamic, code: "b"))
        tracking.categoryView(categoryId: "c")
        tracking.search(query: "q")
        tracking.search(query: "q", results: ["1"])
        tracking.addToCart(item: TrackingItem(id: "1"))
        tracking.syncCart(items: [])
        tracking.removeFromCart(itemId: "1")
        tracking.addToFavorites(itemId: "1")
        tracking.syncFavorites(itemIds: [])
        tracking.removeFromFavorites(itemId: "1")
        tracking.storyView(storyId: "1", slideId: "2")
        tracking.storyClick(storyId: "1", slideId: "2", code: "c")
        tracking.purchase(PurchaseTrackingRequest(orderId: "o", orderPrice: 1, items: []))
        tracking.custom(event: "e")
        tracking.popupShown(popupId: 1)
        tracking.setSource(TrackingSource(type: .chain, code: "c"))
        XCTAssertEqual((tracking as? AppTracking)?.calls.count, 15)
    }

    // MARK: - A source of a mailing

    func test_an_event_with_a_source_of_a_mailing_is_refused_and_setSource_takes_it_on_the_new_core() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let request = PurchaseTrackingRequest(orderId: "o-1", orderPrice: 10, items: [PurchaseItemRequest(id: "1", amount: 1, price: 10)])
        for type in [TrackingSourceType.transactional, .webPushDigest] {
            let source = TrackingSource(type: type, code: "m-1")
            let refusals = [
                completion { sdk.tracking.productView(itemId: "1", source: source, completion: $0) },
                completion { sdk.tracking.addToCart(item: TrackingItem(id: "1"), source: source, completion: $0) },
                completion { sdk.tracking.addToFavorites(itemId: "1", source: source, completion: $0) },
                completion { sdk.tracking.purchase(request, source: source, completion: $0) },
            ]
            for refusal in refusals {
                guard case .invalidArgument(let what)? = failure(refusal) else { return XCTFail("\(String(describing: refusal))") }
                XCTAssertTrue(what.contains(type.rawValue), what)
            }
            guard case .invalidArgument? = run({ try await sdk.tracking.async.productView(itemId: "1", source: source) }) as? Rees46.SdkError else {
                return XCTFail("the async form throws it")
            }
        }
        XCTAssertTrue(waitForLog(shop, "invalid_argument"))
        XCTAssertTrue(queueIdle(sdk))
        XCTAssertTrue(requests("/push", shop).isEmpty, "nothing sent")

        sdk.tracking.setSource(TrackingSource(type: .webPushDigest, code: "d-1"))
        XCTAssertNil(run { try await sdk.tracking.async.productView(itemId: "2", source: TrackingSource(type: .dynamic, code: "b")) } ?? .some(TestError.noOutcome))
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 })
        let body = requests("/push", shop).first?.body ?? [:]
        XCTAssertEqual(body["recommended_by"] as? String, "dynamic")
        XCTAssertEqual((body["source"] as? [String: Any])?["from"] as? String, "web_push_digest", "the stored one goes as before")
    }

    func test_an_event_with_a_source_of_a_mailing_is_refused_on_the_old_core_too() {
        let shop = newShop()
        let sdk = makeLegacy(shop)
        let refused = completion { sdk.tracking.productView(itemId: "1", source: TrackingSource(type: .transactional, code: "m-1"), completion: $0) }
        guard case .invalidArgument? = failure(refused) else { return XCTFail("\(String(describing: refused))") }
        guard case .success? = completion({ sdk.tracking.productView(itemId: "1", source: TrackingSource(type: .bulk, code: "m-1"), completion: $0) }) else {
            return XCTFail("a bulk mailing is a source of an event")
        }
        XCTAssertEqual(requests("/push", shop).count, 1)
        XCTAssertEqual(requests("/push", shop).first?.body["recommended_by"] as? String, "bulk")
    }

    // MARK: - Slides

    func test_track_stories_takes_a_story_and_a_slide_that_are_positive_whole_numbers_on_the_new_core() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let skipped = [("12_1", "1"), ("+12", "1"), (" 12", "1"), ("012", "1"), ("0", "1"), ("12", "+5"), ("12", " 5"), ("12", "0"), ("12", "5a")]
        for (story, slide) in skipped {
            guard case .success? = completion({ sdk.tracking.storyView(storyId: story, slideId: slide, code: "b", completion: $0) }) else {
                return XCTFail("\(story)/\(slide): not sent, and no error")
            }
        }
        guard case .invalidArgument? = failure(completion({ sdk.tracking.storyClick(storyId: "12", slideId: "", completion: $0) })) else {
            return XCTFail("an empty slide id")
        }
        guard case .success? = completion({ sdk.tracking.storyClick(storyId: "12", slideId: "007", code: "b", completion: $0) }) else {
            return XCTFail("sent")
        }
        XCTAssertTrue(queueIdle(sdk))
        let sent = requests("/track/stories", shop)
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first?.body["story_id"] as? Int, 12)
        XCTAssertEqual(sent.first?.body["slide_id"] as? String, "007", "digits, as given")
        XCTAssertEqual(sent.first?.body["event"] as? String, "click")
    }

    /// `track/stories` answers `204` without a body, as the live server does: the old completion hears
    /// a success, not `responseError`.
    func test_a_story_event_answered_with_204_and_no_body_is_a_success_on_the_new_core() {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer("/track/stories", StubReply(204, json: ""))
        guard case .success? = completion({ sdk.tracking.storyView(storyId: "40", slideId: "36", code: "b", completion: $0) }) else {
            return XCTFail("the server took it")
        }
        guard case .success? = completion({ sdk.tracking.storyClick(storyId: "40", slideId: "36", code: "b", completion: $0) }) else {
            return XCTFail("the server took it")
        }
        XCTAssertEqual(requests("/track/stories", shop).count, 2)
    }

    func test_a_story_event_answered_with_204_and_no_body_is_a_success_on_the_old_core() {
        let shop = newShop()
        let sdk = makeLegacy(shop)
        answer("/track/stories", StubReply(204, json: ""))
        guard case .success? = completion({ sdk.tracking.storyView(storyId: "40", slideId: "36", code: "b", completion: $0) }) else {
            return XCTFail("the server took it")
        }
        answer("/track/stories", StubReply(json: #"{"status":"error"}"#))
        XCTAssertEqual(failure(completion { sdk.tracking.storyClick(storyId: "40", slideId: "36", code: "b", completion: $0) }), .decoding, "a body that is not success")
    }

    func test_a_slide_without_a_code_and_no_block_loaded_is_refused_and_not_sent_on_both_cores() {
        let shop = newShop()
        let sdk = makeV2(shop)
        guard case .invalidArgument? = failure(completion({ sdk.tracking.storyView(storyId: "12", slideId: "34", completion: $0) })) else {
            return XCTFail("no code and no block: track/stories refuses it with 422")
        }
        guard case .invalidArgument? = failure(completion({ sdk.tracking.storyClick(storyId: "12", slideId: "34", code: " ", completion: $0) })) else {
            return XCTFail("a blank code is none")
        }
        guard case .invalidArgument? = run({ try await sdk.tracking.async.storyClick(storyId: "12", slideId: "34") }) as? Rees46.SdkError else {
            return XCTFail("the async form")
        }
        XCTAssertNil(run { try await sdk.tracking.async.storyView(storyId: "12_1", slideId: "1") } ?? .some(TestError.noOutcome), "a virtual slide is not sent either way")
        XCTAssertTrue(queueIdle(sdk))
        XCTAssertTrue(requests("/track/stories", shop).isEmpty)

        let old = newShop()
        let legacy = makeLegacy(old)
        guard case .invalidArgument? = failure(completion({ legacy.tracking.storyView(storyId: "12", slideId: "34", completion: $0) })) else {
            return XCTFail("the old core refuses it at once instead of the server's 422")
        }
        guard case .success? = completion({ legacy.tracking.storyClick(storyId: "12", slideId: "34", code: "b", completion: $0) }) else {
            return XCTFail("with a code it goes")
        }
        XCTAssertEqual(requests("/track/stories", old).count, 1)
        XCTAssertEqual(requests("/track/stories", old).first?.body["code"] as? String, "b")
    }

    func test_the_old_core_sends_the_slides_as_it_always_has() {
        let shop = newShop()
        let sdk = makeLegacy(shop)
        guard case .success? = completion({ sdk.tracking.storyView(storyId: "12_1", slideId: "+5", code: "b", completion: $0) }) else {
            return XCTFail("sent")
        }
        XCTAssertEqual(requests("/track/stories", shop).first?.body["story_id"] as? String, "12_1")
    }
}

private enum TestError: Error {
    case noOutcome
}

/// A conformer of ``TrackingAPI`` an app writes — a test double —, which the SDK did not make.
private final class AppTracking: TrackingAPI {

    var calls: [String] = []
    var refusal: SdkError?

    private func done(_ call: String, _ completion: (Result<Void, SdkError>) -> Void) {
        calls.append(call)
        completion(refusal.map { .failure($0) } ?? .success(()))
    }

    func productView(itemId: String, source: TrackingSource?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        done("productView \(itemId)", completion)
    }

    func categoryView(categoryId: String, completion: @escaping (Result<Void, SdkError>) -> Void) {
        done("categoryView \(categoryId)", completion)
    }

    func search(query: String, results: [String]?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        done("search", completion)
    }

    func addToCart(item: TrackingItem, source: TrackingSource?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        done("addToCart", completion)
    }

    func syncCart(items: [TrackingItem], completion: @escaping (Result<Void, SdkError>) -> Void) {
        done("syncCart", completion)
    }

    func removeFromCart(itemId: String, completion: @escaping (Result<Void, SdkError>) -> Void) {
        done("removeFromCart", completion)
    }

    func addToFavorites(itemId: String, source: TrackingSource?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        done("addToFavorites", completion)
    }

    func syncFavorites(itemIds: [String], completion: @escaping (Result<Void, SdkError>) -> Void) {
        done("syncFavorites", completion)
    }

    func removeFromFavorites(itemId: String, completion: @escaping (Result<Void, SdkError>) -> Void) {
        done("removeFromFavorites", completion)
    }

    func storyView(storyId: String, slideId: String, code: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        done("storyView", completion)
    }

    func storyClick(storyId: String, slideId: String, code: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        done("storyClick", completion)
    }

    func purchase(_ request: PurchaseTrackingRequest, source: TrackingSource?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        done("purchase", completion)
    }

    func custom(
        event: String, time: Int?, category: String?, label: String?, value: Int?,
        customFields: [String: Any]?, completion: @escaping (Result<Void, SdkError>) -> Void
    ) {
        done("custom", completion)
    }

    func setSource(_ source: TrackingSource) {}
}
