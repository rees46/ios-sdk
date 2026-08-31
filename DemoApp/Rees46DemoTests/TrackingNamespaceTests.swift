import XCTest
@testable import REES46

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

    /// A host passing its own `storageKey` opts out of per-shop partitioning. Pinned so the opt-out
    /// stays visible — two shops on one key deliberately share a store.
    func test_aHostSuppliedStorageKey_isUsedVerbatim() {
        let hostKey = "host_own_key_\(UUID().uuidString)"
        suiteNames.append(hostKey)
        let shop = uniqueShop("shop-a")

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
