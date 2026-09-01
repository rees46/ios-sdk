import XCTest
@testable import REES46

/// Guards the upgrade path: everything the `tracking` namespace touched has to keep working for
/// code written against the previous release — conformers of `PersonalizationSDK`, the old
/// arities of `Event` and `CartItem`, and the deprecated root-level methods.
final class TrackingBackCompatTests: XCTestCase {

    private var savedSourceCode: Any?
    private var savedSourceType: Any?
    private var savedSourceTime: Any?

    override func setUp() {
        super.setUp()
        // The tracked source lives in shared UserDefaults and leaks between tests — park it.
        savedSourceCode = UserDefaults.standard.object(forKey: "recomendedCode")
        savedSourceType = UserDefaults.standard.object(forKey: "recomendedType")
        savedSourceTime = UserDefaults.standard.object(forKey: "timeStartSave")
        UserDefaults.standard.removeObject(forKey: "recomendedCode")
        UserDefaults.standard.removeObject(forKey: "recomendedType")
        UserDefaults.standard.removeObject(forKey: "timeStartSave")
    }

    override func tearDown() {
        UserDefaults.standard.set(savedSourceCode, forKey: "recomendedCode")
        UserDefaults.standard.set(savedSourceType, forKey: "recomendedType")
        UserDefaults.standard.set(savedSourceTime, forKey: "timeStartSave")
        super.tearDown()
    }

    // MARK: - Conformers keep compiling

    /// `MockPersonalizationSDK` conforms to `PersonalizationSDK` and does *not* implement
    /// `tracking`. That it compiles at all is the compile-time half of the guarantee; this
    /// asserts the runtime half — the default implementation is wired to the same instance.
    func test_conformerWithoutTrackingMember_getsAWorkingDefault() {
        let sdk = MockPersonalizationSDK()
        let expectation = expectation(description: "tracked through the default implementation")

        sdk.tracking.productView(itemId: "sku-1") { _ in expectation.fulfill() }

        waitForExpectations(timeout: 2.0)
        XCTAssertEqual(sdk.postCallCount, 1)
        XCTAssertEqual(sdk.lastPostPath, "push")
        XCTAssertEqual(sdk.lastPostParams?["shop_id"] as? String, sdk.shopId)
    }

    // MARK: - Old call shapes still compile

    /// `Event` is public, so a host may both build cases *and* pattern-match them. Adding an
    /// associated value would keep construction compiling while silently breaking every `case let`
    /// with the old number of bindings — so the namespace's extra payload lives in the internal
    /// `TrackEventDetails` instead, and the cases stay exactly as they shipped.
    ///
    /// This test is written the way a host on the previous release writes them: if an arity ever
    /// changes again, this file stops compiling.
    func test_eventCases_keepTheirPreviousArities() {
        let cartWithDefaultAmount: Event = .productAddedToCart(id: "sku-1")
        let cartWithAmount: Event = .productAddedToCart(id: "sku-1", amount: 3)
        let search: Event = .search(query: "boots")
        let slideView: Event = .slideView(storyId: "42", slideId: "3")
        let slideClick: Event = .slideClick(storyId: "42", slideId: "3")

        guard case let .slideView(viewStoryId, viewSlideId) = slideView else {
            return XCTFail("Expected .slideView")
        }
        XCTAssertEqual(viewStoryId, "42")
        XCTAssertEqual(viewSlideId, "3")

        guard case let .slideClick(clickStoryId, clickSlideId) = slideClick else {
            return XCTFail("Expected .slideClick")
        }
        XCTAssertEqual(clickStoryId, "42")
        XCTAssertEqual(clickSlideId, "3")

        guard case let .productAddedToCart(defaultId, defaultAmount) = cartWithDefaultAmount else {
            return XCTFail("Expected .productAddedToCart")
        }
        XCTAssertEqual(defaultId, "sku-1")
        XCTAssertEqual(defaultAmount, 1)

        guard case let .productAddedToCart(_, amount) = cartWithAmount else {
            return XCTFail("Expected .productAddedToCart")
        }
        XCTAssertEqual(amount, 3)

        guard case let .search(query) = search else {
            return XCTFail("Expected .search")
        }
        XCTAssertEqual(query, "boots")
    }

    func test_cartItem_keepsItsPreviousInitializers() {
        let onlyId = CartItem(productId: "sku-1")
        XCTAssertEqual(onlyId.quantity, 1)
        XCTAssertNil(onlyId.price)

        let withQuantity = CartItem(productId: "sku-1", quantity: 4)
        XCTAssertEqual(withQuantity.quantity, 4)
        XCTAssertNil(withQuantity.price)

        let fromJson = CartItem(json: ["uniqid": "sku-1", "quantity": 2])
        XCTAssertEqual(fromJson.productId, "sku-1")
        XCTAssertEqual(fromJson.quantity, 2)
        XCTAssertNil(fromJson.price)
    }

    // MARK: - Deprecated methods still work

    @available(*, deprecated)
    func test_deprecatedTrackEvent_stillReachesTheWire() {
        let sdk = MockPersonalizationSDK()
        let expectation = expectation(description: "custom event tracked")

        sdk.trackEvent(
            event: "legacy_event",
            time: 111,
            category: "cat",
            label: "lbl",
            value: 7,
            customFields: ["foo": "bar"]
        ) { _ in expectation.fulfill() }

        waitForExpectations(timeout: 2.0)
        XCTAssertEqual(sdk.lastPostPath, "push/custom")
        XCTAssertEqual(sdk.lastPostParams?["event"] as? String, "legacy_event")
        XCTAssertEqual(sdk.lastPostParams?["time"] as? Int, 111)
        XCTAssertEqual(sdk.lastPostParams?["foo"] as? String, "bar")
    }

    @available(*, deprecated)
    func test_deprecatedTrackPurchase_stillReachesTheWire() {
        let sdk = MockPersonalizationSDK()
        let expectation = expectation(description: "purchase tracked")
        let request = PurchaseTrackingRequest(
            orderId: "order-1",
            orderPrice: 100,
            items: [PurchaseItemRequest(id: "sku-1", amount: 1, price: 100)]
        )

        sdk.trackPurchase(request) { _ in expectation.fulfill() }

        waitForExpectations(timeout: 2.0)
        XCTAssertEqual(sdk.lastPostPath, "push")
        XCTAssertEqual(sdk.lastPostParams?["event"] as? String, "purchase")
        XCTAssertEqual(sdk.lastPostParams?["order_id"] as? String, "order-1")
    }

    @available(*, deprecated)
    func test_deprecatedTrackSource_andNamespaceSetSource_storeTheSameThing() {
        let sdk = MockPersonalizationSDK()

        sdk.trackSource(source: .dynamic, code: "legacy-code")
        let legacyCode = UserDefaults.standard.string(forKey: "recomendedCode")
        let legacyType = UserDefaults.standard.string(forKey: "recomendedType")

        sdk.tracking.setSource(TrackingSource(type: .dynamic, code: "legacy-code"))

        XCTAssertEqual(legacyCode, "legacy-code")
        XCTAssertEqual(legacyType, RecommendedByCase.dynamic.rawValue)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "recomendedCode"), legacyCode)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "recomendedType"), legacyType)
    }

    // MARK: - Same request on both paths

    /// The namespace must not change a single byte of what the old call produced. Each case
    /// tracks the same thing twice — through the previous API and through the namespace — and
    /// compares the two request bodies.
    @available(*, deprecated)
    func test_wireIsIdenticalBetweenLegacyCallAndNamespace() {
        assertSameWire(
            legacy: { $0.track(event: .productView(id: "sku-1"), recommendedBy: nil, completion: $1) },
            namespace: { $0.tracking.productView(itemId: "sku-1", completion: $1) }
        )
        assertSameWire(
            legacy: { $0.track(event: .categoryView(id: "cat-1"), recommendedBy: nil, completion: $1) },
            namespace: { $0.tracking.categoryView(categoryId: "cat-1", completion: $1) }
        )
        assertSameWire(
            legacy: { $0.track(event: .search(query: "boots"), recommendedBy: nil, completion: $1) },
            namespace: { $0.tracking.search(query: "boots", completion: $1) }
        )
        assertSameWire(
            legacy: { $0.track(event: .productAddedToCart(id: "sku-1", amount: 2), recommendedBy: nil, completion: $1) },
            namespace: { $0.tracking.addToCart(item: TrackingItem(id: "sku-1", quantity: 2), completion: $1) }
        )
        assertSameWire(
            legacy: { $0.track(event: .productRemovedFromCart(id: "sku-1"), recommendedBy: nil, completion: $1) },
            namespace: { $0.tracking.removeFromCart(itemId: "sku-1", completion: $1) }
        )
        assertSameWire(
            legacy: { $0.track(event: .productAddedToFavorites(id: "sku-1"), recommendedBy: nil, completion: $1) },
            namespace: { $0.tracking.addToFavorites(itemId: "sku-1", completion: $1) }
        )
        assertSameWire(
            legacy: { $0.track(event: .productRemovedFromFavorites(id: "sku-1"), recommendedBy: nil, completion: $1) },
            namespace: { $0.tracking.removeFromFavorites(itemId: "sku-1", completion: $1) }
        )
        assertSameWire(
            legacy: { $0.track(event: .synchronizeCart(items: [CartItem(productId: "sku-1", quantity: 2)]), recommendedBy: nil, completion: $1) },
            namespace: { $0.tracking.syncCart(items: [TrackingItem(id: "sku-1", quantity: 2)], completion: $1) }
        )
        assertSameWire(
            legacy: { $0.track(event: .synchronizeFavorites(ids: ["sku-1", "sku-2"]), recommendedBy: nil, completion: $1) },
            namespace: { $0.tracking.syncFavorites(itemIds: ["sku-1", "sku-2"], completion: $1) }
        )
        assertSameWire(
            legacy: { $0.track(event: .slideView(storyId: "42", slideId: "3"), recommendedBy: nil, completion: $1) },
            namespace: { $0.tracking.storyView(storyId: "42", slideId: "3", completion: $1) }
        )
        assertSameWire(
            legacy: { $0.track(event: .slideClick(storyId: "42", slideId: "3"), recommendedBy: nil, completion: $1) },
            namespace: { $0.tracking.storyClick(storyId: "42", slideId: "3", completion: $1) }
        )
        assertSameWire(
            legacy: { sdk, done in
                let request = PurchaseTrackingRequest(
                    orderId: "order-1",
                    orderPrice: 100,
                    items: [PurchaseItemRequest(id: "sku-1", amount: 1, price: 100)]
                )
                sdk.trackPurchase(request, recommendedBy: nil, completion: done)
            },
            namespace: { sdk, done in
                let request = PurchaseTrackingRequest(
                    orderId: "order-1",
                    orderPrice: 100,
                    items: [PurchaseItemRequest(id: "sku-1", amount: 1, price: 100)]
                )
                sdk.tracking.purchase(request, completion: done)
            }
        )
        assertSameWire(
            legacy: { $0.trackEvent(event: "e", time: 1, category: "c", label: "l", value: 2, customFields: ["k": "v"], completion: $1) },
            namespace: { $0.tracking.custom(event: "e", time: 1, category: "c", label: "l", value: 2, customFields: ["k": "v"], completion: $1) }
        )
    }

    private typealias Call = (PersonalizationSDK, @escaping (Result<Void, SdkError>) -> Void) -> Void

    private func assertSameWire(
        legacy: Call,
        namespace: Call,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let legacySdk = MockPersonalizationSDK()
        let namespaceSdk = MockPersonalizationSDK()

        let legacyDone = expectation(description: "legacy")
        legacy(legacySdk) { _ in legacyDone.fulfill() }
        let namespaceDone = expectation(description: "namespace")
        namespace(namespaceSdk) { _ in namespaceDone.fulfill() }

        wait(for: [legacyDone, namespaceDone], timeout: 2.0)

        XCTAssertEqual(legacySdk.lastPostPath, namespaceSdk.lastPostPath, "path differs", file: file, line: line)
        guard
            let legacyParams = legacySdk.lastPostParams,
            let namespaceParams = namespaceSdk.lastPostParams
        else {
            return XCTFail("both calls must reach the wire", file: file, line: line)
        }
        XCTAssertTrue(
            NSDictionary(dictionary: legacyParams).isEqual(to: namespaceParams),
            "request body differs\nlegacy:    \(legacyParams)\nnamespace: \(namespaceParams)",
            file: file,
            line: line
        )
    }
}
