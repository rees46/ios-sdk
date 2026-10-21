import XCTest
@_spi(PersonalizationUI) @testable import REES46

/// The data-bound recommender block over a fake SDK whose `recommend` / `getCollection` answers are
/// scripted: title, hidden states and callbacks, the shared cache and `reload()`, the client-side
/// limit, the `dynamic` source on taps, and the cards built from a live recommendations sample.
final class PersonalizationRecommenderBlockTests: XCTestCase {

    private var window: UIWindow!
    private var sdk: FakeSDK!
    /// Every block of a test shares this cache, as blocks of one app share `ResponseCache.shared`.
    private var cache: ResponseCache!
    private var loaded: [Int] = []
    private var errors: [SdkError] = []

    override func setUp() {
        super.setUp()
        // Never shown: the block lays out the same in a hidden window.
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        sdk = FakeSDK()
        cache = ResponseCache()
        loaded = []
        errors = []
    }

    override func tearDown() {
        window = nil
        sdk = nil
        cache = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// A block in the window on the test's cache, loaded from the fake. The shop is one nobody
    /// registers, so joining the window waits for it instead of picking another test's instance;
    /// `attach` then hands the fake over.
    @discardableResult
    private func makeBlock(
        _ source: PersonalizationRecommenderBlock.Source = .recommendations(code: "block-1"),
        configure: (PersonalizationRecommenderBlock) -> Void = { _ in }
    ) -> PersonalizationRecommenderBlock {
        let block = PersonalizationRecommenderBlock(source: source, shopId: "recommender-tests-shop")
        block.cache = cache
        block.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        block.onLoaded = { [weak self] in self?.loaded.append($0) }
        block.onError = { [weak self] in self?.errors.append($0) }
        configure(block)
        window.addSubview(block)
        block.attach(sdk)
        return block
    }

    private func items(_ count: Int) -> [[String: Any]] {
        (0..<count).map { index in
            ["id": "\(index)", "name": "Product \(index)", "price": 10.0, "price_formatted": "10 ₽",
             "url": "https://shop.example/p/\(index)", "deeplink_ios": "shop://p/\(index)"]
        }
    }

    private func recommendations(_ count: Int, title: String = "Popular") -> Result<RecommenderResponse, SdkError> {
        .success(RecommenderResponse(json: ["title": title, "recommends": items(count)]))
    }

    private func collection(_ count: Int) -> Result<CollectionResponse, SdkError> {
        .success(CollectionResponse(json: ["products": items(count)]))
    }

    /// Lets the main queue run once: the block reports `onLoaded` / `onError` on its next turn.
    private func drain() {
        let turn = expectation(description: "main queue turn")
        DispatchQueue.main.async { turn.fulfill() }
        wait(for: [turn], timeout: 2)
    }

    private func titleRow(of block: PersonalizationRecommenderBlock) -> PersonalizationTitle? {
        views(PersonalizationTitle.self, in: block).first
    }

    private func views<T: UIView>(_ type: T.Type, in root: UIView) -> [T] {
        root.subviews.flatMap { view -> [T] in
            let own = (view as? T).map { [$0] } ?? []
            return own + views(type, in: view)
        }
    }

    // MARK: - Title

    func testTitle_comesFromTheResponse() {
        sdk.recommendResults = [recommendations(3, title: "Popular")]
        let block = makeBlock()

        XCTAssertEqual(block.block.text, "Popular")
        XCTAssertEqual(titleRow(of: block)?.isHidden, false)
    }

    func testOwnTitle_replacesTheResponseTitle() {
        sdk.recommendResults = [recommendations(3, title: "Popular")]
        let block = makeBlock { $0.title = "You may also like" }

        XCTAssertEqual(block.block.text, "You may also like")
    }

    func testEmptyTitle_dropsTheTitleRow() {
        sdk.recommendResults = [recommendations(3, title: "Popular")]
        let block = makeBlock { $0.title = "" }

        XCTAssertFalse(block.isHidden)
        XCTAssertEqual(titleRow(of: block)?.isHidden, true)
    }

    func testCollection_hasNoTitle_andAsksForTheCollection() {
        sdk.collectionResults = [collection(2)]
        let block = makeBlock(.collection(id: "42"))

        XCTAssertEqual(sdk.collectionCalls, ["42"])
        XCTAssertTrue(sdk.recommendCalls.isEmpty)
        XCTAssertEqual(block.products.map(\.id), ["0", "1"])
        XCTAssertEqual(titleRow(of: block)?.isHidden, true)
    }

    // MARK: - Request, states, callbacks

    func testRequest_carriesTheBlockParameters_extended() {
        sdk.recommendResults = [recommendations(1)]
        makeBlock(.recommendations(code: "similar", itemId: "item-7", categoryId: "cat-3", locations: "msk,spb"))

        XCTAssertEqual(sdk.recommendCalls.count, 1)
        let call = sdk.recommendCalls[0]
        XCTAssertEqual(call.blockId, "similar")
        XCTAssertEqual(call.itemId, "item-7")
        XCTAssertEqual(call.categoryId, "cat-3")
        XCTAssertEqual(call.locations, "msk,spb")
        XCTAssertTrue(call.extended)
    }

    func testAnswer_showsTheBlock_andReportsTheCount_onTheNextTurn() {
        sdk.recommendResults = [recommendations(3)]
        let block = makeBlock()

        XCTAssertFalse(block.isHidden)
        XCTAssertEqual(block.products.count, 3)
        XCTAssertEqual(loaded, [], "callbacks wait for the next main queue turn")
        drain()
        XCTAssertEqual(loaded, [3])
        XCTAssertTrue(errors.isEmpty)
    }

    func testFewerThanMinProducts_hidesTheBlock_andReportsZero() {
        sdk.recommendResults = [recommendations(2)]
        let block = makeBlock { $0.minProducts = 3 }
        drain()

        XCTAssertTrue(block.isHidden)
        XCTAssertTrue(block.products.isEmpty)
        XCTAssertEqual(block.fittingHeight(forWidth: 390), 0)
        XCTAssertEqual(loaded, [0])
    }

    func testEmptyAnswer_hidesTheBlock_andReportsZero() {
        sdk.recommendResults = [recommendations(0)]
        let block = makeBlock()
        drain()

        XCTAssertTrue(block.isHidden)
        XCTAssertEqual(block.intrinsicContentSize.height, 0)
        XCTAssertEqual(loaded, [0])
    }

    func testError_hidesTheBlock_andReportsIt() {
        sdk.recommendResults = [.failure(.networkOfflineError)]
        let block = makeBlock()
        drain()

        XCTAssertTrue(block.isHidden)
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(loaded, [])
    }

    func testEmptyCode_isAnError_withoutARequest() {
        let block = makeBlock(.recommendations(code: ""))
        drain()

        XCTAssertTrue(block.isHidden)
        XCTAssertTrue(sdk.recommendCalls.isEmpty)
        XCTAssertEqual(errors.count, 1)
    }

    func testWhileLoading_theBlockTakesNoSpace() {
        sdk.holdsRecommend = true
        let block = makeBlock()

        XCTAssertTrue(block.isHidden)
        XCTAssertEqual(block.fittingHeight(forWidth: 390), 0)

        sdk.heldRecommend[0](recommendations(2))
        XCTAssertFalse(block.isHidden)
        XCTAssertGreaterThan(block.fittingHeight(forWidth: 390), 0)
    }

    func testLimit_cutsTheProducts_andMinProductsCountsWhatIsShown() {
        sdk.recommendResults = [recommendations(6)]
        let block = makeBlock { $0.limit = 4 }
        drain()

        XCTAssertEqual(block.products.map(\.id), ["0", "1", "2", "3"])
        XCTAssertEqual(loaded, [4])

        block.minProducts = 5
        XCTAssertTrue(block.isHidden, "4 shown is fewer than 5")
        block.limit = nil
        XCTAssertFalse(block.isHidden)
        XCTAssertEqual(block.products.count, 6)
        XCTAssertEqual(sdk.recommendCalls.count, 1, "the limit is cut on the client")
    }

    func testActionText_isTheButtonOfEveryCard() {
        sdk.recommendResults = [recommendations(2)]
        let block = makeBlock()
        XCTAssertEqual(block.products.map(\.actionText), [nil, nil])

        block.actionText = "Add to cart"
        XCTAssertEqual(block.products.map(\.actionText), ["Add to cart", "Add to cart"])
    }

    // MARK: - Cache and reload

    func testSecondInstance_withTheSameParameters_showsTheCachedAnswerAtOnce_withoutARequestOrFade() {
        sdk.recommendResults = [recommendations(3)]
        makeBlock(.recommendations(code: "block-1", itemId: "item-1"))

        let second = makeBlock(.recommendations(code: "block-1", itemId: "item-1"))

        XCTAssertEqual(sdk.recommendCalls.count, 1, "the second block asked nobody")
        XCTAssertFalse(second.isHidden, "shown right away, not after a hidden turn")
        XCTAssertEqual(second.products.count, 3)
        XCTAssertEqual(second.alpha, 1)
        XCTAssertNil(second.layer.animationKeys(), "a cached answer appears without the fade")
        drain()
        XCTAssertEqual(loaded, [3, 3])
    }

    func testOtherParameters_loadAgain() {
        sdk.recommendResults = [recommendations(3), recommendations(2), recommendations(1)]
        makeBlock(.recommendations(code: "block-1", itemId: "item-1"))
        makeBlock(.recommendations(code: "block-1", itemId: "item-2"))
        makeBlock(.collection(id: "block-1"))

        XCTAssertEqual(sdk.recommendCalls.map { $0.itemId }, ["item-1", "item-2"])
        XCTAssertEqual(sdk.collectionCalls, ["block-1"])
    }

    func testReload_goesPastTheCache() {
        sdk.recommendResults = [recommendations(3), recommendations(5)]
        let block = makeBlock()

        block.reload()

        XCTAssertEqual(sdk.recommendCalls.count, 2)
        XCTAssertEqual(block.products.count, 5)
        drain()
        XCTAssertEqual(loaded, [5], "only the answer of the reload is reported")
    }

    func testReload_keepsTheShownBlock_untilTheNewAnswer() {
        sdk.recommendResults = [recommendations(3)]
        let block = makeBlock()
        sdk.holdsRecommend = true

        block.reload()
        XCTAssertFalse(block.isHidden, "no collapse while reloading")
        XCTAssertEqual(block.products.count, 3)

        sdk.heldRecommend[0](recommendations(4))
        XCTAssertFalse(block.isHidden)
        XCTAssertEqual(block.products.count, 4)
    }

    func testReload_thatFails_hidesTheBlock_andReportsTheError() {
        sdk.recommendResults = [recommendations(3)]
        let block = makeBlock()
        sdk.holdsRecommend = true

        block.reload()
        sdk.heldRecommend[0](.failure(.networkOfflineError))
        drain()

        XCTAssertTrue(block.isHidden)
        XCTAssertEqual(errors.count, 1)
    }

    func testSourceChange_hidesTheBlock_untilTheNewAnswer() {
        sdk.recommendResults = [recommendations(3)]
        let block = makeBlock(.recommendations(code: "block-1", itemId: "item-1"))
        sdk.holdsRecommend = true

        block.source = .recommendations(code: "block-1", itemId: "item-2")
        XCTAssertTrue(block.isHidden, "the products of another item are not shown meanwhile")
        XCTAssertEqual(sdk.recommendCalls.count, 2)

        sdk.heldRecommend[0](recommendations(2))
        XCTAssertFalse(block.isHidden)
        XCTAssertEqual(block.products.count, 2)
    }

    func testController_reloadsTheBlockItIsBoundTo() {
        sdk.recommendResults = [recommendations(3), recommendations(1)]
        let block = makeBlock()
        let controller = PersonalizationRecommenderBlockController()
        controller.block = block

        controller.reload()

        XCTAssertEqual(sdk.recommendCalls.count, 2)
        XCTAssertEqual(block.products.count, 1)
    }

    // MARK: - Tracking

    func testProductTap_setsTheDynamicSourceWithTheCode_beforeTheHostCallback() {
        sdk.recommendResults = [recommendations(2)]
        var sourcesAtCallback: Int?
        var tapped: PersonalizationProduct?
        let block = makeBlock(.recommendations(code: "block-1")) { block in
            block.onProductTap = { [unowned self] product in
                sourcesAtCallback = self.sdk.storedSources.count
                tapped = product
            }
        }

        block.block.onProductTap?(block.products[1])

        XCTAssertEqual(sdk.storedSources.map { $0.type }, ["dynamic"])
        XCTAssertEqual(sdk.storedSources.map { $0.code }, ["block-1"])
        XCTAssertEqual(sourcesAtCallback, 1, "the source is stored before the host hears of the tap")
        XCTAssertEqual(tapped?.id, "1")
    }

    func testCardButton_setsTheDynamicSourceToo_beforeTheHostCallback() {
        sdk.recommendResults = [recommendations(2)]
        var sourcesAtCallback: Int?
        let block = makeBlock(.recommendations(code: "block-1")) { block in
            block.actionText = "Add to cart"
            block.onProductAction = { [unowned self] _ in sourcesAtCallback = self.sdk.storedSources.count }
        }

        block.block.onProductAction?(block.products[0])

        XCTAssertEqual(sdk.storedSources.map { $0.type }, ["dynamic"])
        XCTAssertEqual(sdk.storedSources.map { $0.code }, ["block-1"])
        XCTAssertEqual(sourcesAtCallback, 1)
    }

    func testCollection_tapAndCardButton_setNoSource() {
        sdk.collectionResults = [collection(2)]
        var taps = 0
        let block = makeBlock(.collection(id: "42")) { block in
            block.onProductTap = { _ in taps += 1 }
            block.onProductAction = { _ in taps += 1 }
        }

        block.block.onProductTap?(block.products[0])
        block.block.onProductAction?(block.products[0])

        XCTAssertEqual(taps, 2)
        XCTAssertTrue(sdk.storedSources.isEmpty)
    }

    // MARK: - Live sample

    func testCards_ofTheLiveRecommendations_carryDiscountAndDeeplink() {
        sdk.recommendResults = [.success(RecommenderResponse(json: ApiFixtures.json("recommend_extended")))]
        var tapped: PersonalizationProduct?
        let block = makeBlock { $0.onProductTap = { tapped = $0 } }

        XCTAssertEqual(block.block.text, "Популярные")
        XCTAssertEqual(block.products.map(\.id), [ApiFixtures.discountedId, ApiFixtures.fullPriceId])
        let discounted = block.products[0]
        XCTAssertEqual(discounted.price, "164 990 ₽")
        XCTAssertEqual(discounted.oldPrice, "174 990 ₽")
        XCTAssertEqual(discounted.discount, "-6%")
        XCTAssertNil(block.products[1].discount)

        block.block.onProductTap?(discounted)
        XCTAssertEqual(tapped?.deeplink, "https://www.technodom.kz/p/holodilnik-beko-rdsk-mw-52173")
        XCTAssertTrue(tapped?.url?.hasPrefix("https://www.technodom.kz/p/holodilnik-beko-rdsk-mw-52173") == true)
    }

    func testRating_isOffByDefault() {
        XCTAssertFalse(PersonalizationRecommenderBlock(code: "block-1").showRating)
    }

    // MARK: - Products block (presentational)

    func testProductsBlock_dropsTheTitleRow_onlyWithoutTextAndShowAll() {
        let block = PersonalizationProductsBlock(layout: .carousel)
        let row = { self.views(PersonalizationTitle.self, in: block)[0] }
        XCTAssertTrue(row().isHidden)

        block.text = "Similar"
        XCTAssertFalse(row().isHidden)
        block.text = ""
        XCTAssertTrue(row().isHidden)
        block.showAllText = "Show all"
        XCTAssertFalse(row().isHidden, "the row still holds the show-all button")
    }

    func testProductsBlock_passesTheRatingFlagToItsCards() {
        // The carousel knows its card width before layout, so one pass lays the cells out.
        let block = PersonalizationProductsBlock(layout: .carousel)
        block.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        window.addSubview(block)
        block.products = [PersonalizationProduct(id: "1", name: "Rated", price: "$1", ratingValue: "4.5", reviews: 3)]
        let ratings = { self.views(PersonalizationRating.self, in: block) }

        block.showRating = false
        window.layoutIfNeeded()
        window.layoutIfNeeded()
        XCTAssertFalse(ratings().isEmpty)
        XCTAssertTrue(ratings().allSatisfy(\.isHidden))

        block.showRating = true
        window.layoutIfNeeded()
        XCTAssertTrue(ratings().contains { !$0.isHidden })
    }
}
