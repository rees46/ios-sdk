import XCTest
@testable import REES46

/// Covers the `tracking` namespace: that every method maps onto the event the API expects, and
/// that the two fields added with the namespace (cart price, search results) reach the wire.
final class TrackingNamespaceTests: XCTestCase {

    // MARK: - Mapping onto events

    func test_productView_mapsToProductViewEvent() {
        let spy = TrackEventServiceSpy()
        let tracking = TrackingAPIImpl(trackService: spy, sourceService: TrackSourceServiceSpy())

        tracking.productView(id: "sku-1")

        guard case let .productView(id) = spy.lastEvent else {
            return XCTFail("Expected .productView, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(id, "sku-1")
        XCTAssertNil(spy.lastRecommendedBy)
    }

    func test_categoryView_mapsToCategoryViewEvent() {
        let spy = TrackEventServiceSpy()
        let tracking = TrackingAPIImpl(trackService: spy, sourceService: TrackSourceServiceSpy())

        tracking.categoryView(id: "women-shoes")

        guard case let .categoryView(id) = spy.lastEvent else {
            return XCTFail("Expected .categoryView, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(id, "women-shoes")
    }

    func test_search_carriesQueryAndResults() {
        let spy = TrackEventServiceSpy()
        let tracking = TrackingAPIImpl(trackService: spy, sourceService: TrackSourceServiceSpy())

        tracking.search(query: "boots", results: ["sku-1", "sku-2"])

        guard case let .search(query, results) = spy.lastEvent else {
            return XCTFail("Expected .search, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(query, "boots")
        XCTAssertEqual(results, ["sku-1", "sku-2"])
    }

    func test_addToCart_carriesQuantityAndPrice() {
        let spy = TrackEventServiceSpy()
        let tracking = TrackingAPIImpl(trackService: spy, sourceService: TrackSourceServiceSpy())

        tracking.addToCart(item: TrackingItem(id: "sku-1", quantity: 3, price: 49.9))

        guard case let .productAddedToCart(id, amount, price) = spy.lastEvent else {
            return XCTFail("Expected .productAddedToCart, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(id, "sku-1")
        XCTAssertEqual(amount, 3)
        XCTAssertEqual(price, 49.9)
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

        tracking.removeFromCart(id: "sku-1")

        guard case let .productRemovedFromCart(id) = spy.lastEvent else {
            return XCTFail("Expected .productRemovedFromCart, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(id, "sku-1")
    }

    func test_favorites_mapToWishEvents() {
        let spy = TrackEventServiceSpy()
        let tracking = TrackingAPIImpl(trackService: spy, sourceService: TrackSourceServiceSpy())

        tracking.addToFavorites(id: "sku-1")
        guard case let .productAddedToFavorites(addedId) = spy.lastEvent else {
            return XCTFail("Expected .productAddedToFavorites, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(addedId, "sku-1")

        tracking.removeFromFavorites(id: "sku-2")
        guard case let .productRemovedFromFavorites(removedId) = spy.lastEvent else {
            return XCTFail("Expected .productRemovedFromFavorites, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(removedId, "sku-2")

        tracking.syncFavorites(ids: ["sku-1", "sku-3"])
        guard case let .synchronizeFavorites(ids) = spy.lastEvent else {
            return XCTFail("Expected .synchronizeFavorites, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(ids, ["sku-1", "sku-3"])
    }

    func test_storyEvents_mapToSlideEvents() {
        let spy = TrackEventServiceSpy()
        let tracking = TrackingAPIImpl(trackService: spy, sourceService: TrackSourceServiceSpy())

        tracking.storyView(storyId: "42", slideId: "3", code: "main_stories")
        guard case let .slideView(viewedStory, viewedSlide, viewedCode) = spy.lastEvent else {
            return XCTFail("Expected .slideView, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(viewedStory, "42")
        XCTAssertEqual(viewedSlide, "3")
        XCTAssertEqual(viewedCode, "main_stories")

        tracking.storyClick(storyId: "42", slideId: "3")
        guard case let .slideClick(clickedStory, clickedSlide, clickedCode) = spy.lastEvent else {
            return XCTFail("Expected .slideClick, got \(String(describing: spy.lastEvent))")
        }
        XCTAssertEqual(clickedStory, "42")
        XCTAssertEqual(clickedSlide, "3")
        XCTAssertNil(clickedCode, "omitted code must fall back to the SDK's loaded block")
    }

    // MARK: - Attribution

    func test_source_isForwardedAsRecommendedBy() {
        let spy = TrackEventServiceSpy()
        let tracking = TrackingAPIImpl(trackService: spy, sourceService: TrackSourceServiceSpy())

        tracking.productView(id: "sku-1", source: TrackingSource(type: .dynamic, code: "popular"))

        XCTAssertEqual(spy.lastRecommendedBy?.type, .dynamic)
        XCTAssertEqual(spy.lastRecommendedBy?.code, "popular")
    }

    func test_setSource_isForwardedToSourceService() {
        let sourceSpy = TrackSourceServiceSpy()
        let tracking = TrackingAPIImpl(trackService: TrackEventServiceSpy(), sourceService: sourceSpy)

        tracking.setSource(TrackingSource(type: .fullSearch, code: "boots"))

        XCTAssertEqual(sourceSpy.lastSource, .fullSearch)
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
        XCTAssertEqual(spy.lastRecommendedBy?.type, .chain)
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
            .productView(id: "sku-1") { _ in
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
    var lastRecommendedBy: RecomendedBy?
    var lastPurchase: PurchaseTrackingRequest?
    var lastCustomEvent: String?
    var lastCustomTime: Int?
    var lastCustomCategory: String?
    var lastCustomLabel: String?
    var lastCustomValue: Int?
    var lastCustomFields: [String: Any]?

    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        lastEvent = event
        lastRecommendedBy = recommendedBy
        completion(.success(()))
    }

    func trackPurchase(_ request: PurchaseTrackingRequest, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        lastPurchase = request
        lastRecommendedBy = recommendedBy
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
    var lastSource: RecommendedByCase?
    var lastCode: String?

    func trackSource(source: RecommendedByCase, code: String) {
        lastSource = source
        lastCode = code
    }
}
