import XCTest
@_spi(PersonalizationUI) @testable import REES46

/// The search results screen driven by a fake SDK whose `search` answers are scripted:
/// rating visibility on the cards, and the error state with retry for the first and the next page.
final class PersonalizationSearchResultsScreenTests: XCTestCase {

    private var window: UIWindow!
    private var sdk: FakeSDK!
    private var screen: PersonalizationSearchResultsScreen!
    private var errors: [SdkError] = []

    override func setUp() {
        super.setUp()
        // Never shown: the screen lays out the same in a hidden window.
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        sdk = FakeSDK()
        errors = []
        screen = PersonalizationSearchResultsScreen()
        screen.frame = window.bounds
        screen.onError = { [weak self] error in self?.errors.append(error) }
        // An explicit instance, so the screen does not wait for the registry when it joins the window.
        screen.attach(sdk)
        window.addSubview(screen)
    }

    override func tearDown() {
        screen = nil
        sdk = nil
        window = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    private func page(total: Int, ids: Range<Int>) -> Result<SearchResponse, SdkError> {
        let products: [[String: Any]] = ids.map { index in
            ["id": "\(index)", "name": "Product \(index)", "price": 10.0, "price_formatted": "10 ₽"]
        }
        return .success(SearchResponse(json: ["products_total": total, "products": products]))
    }

    /// Sets the query and runs the first request right away instead of on the next main-loop turn.
    private func search(_ query: String) {
        screen.query = query
        screen.reload()
        window.layoutIfNeeded()
    }

    private func views<T: UIView>(_ type: T.Type, in root: UIView) -> [T] {
        root.subviews.flatMap { view -> [T] in
            let own = (view as? T).map { [$0] } ?? []
            return own + views(type, in: view)
        }
    }

    /// How many `search` events the screen tracked.
    private var searchEvents: Int {
        sdk.trackedEvents.filter { if case .search = $0 { return true } else { return false } }.count
    }

    /// Visible buttons titled `text` anywhere on the screen.
    private func buttons(_ text: String) -> [PersonalizationButton] {
        views(PersonalizationButton.self, in: screen).filter { $0.text == text && !$0.isHiddenInHierarchy }
    }

    // MARK: - Rating

    func testCard_hidesRating_whenShowRatingIsOff() {
        let card = PersonalizationProductCard(type: .grid)
        card.setRating(value: "4.5", reviews: 10)
        let rating = views(PersonalizationRating.self, in: card)[0]
        XCTAssertFalse(rating.isHidden)

        card.showRating = false
        XCTAssertTrue(rating.isHidden)

        card.showRating = true
        XCTAssertFalse(rating.isHidden)
        card.setRating(value: nil, reviews: 0)
        XCTAssertTrue(rating.isHidden)
    }

    func testScreen_hidesRatingByDefault() {
        XCTAssertFalse(screen.showRating)
        XCTAssertFalse(screen.catalog.showRating)

        screen.showRating = true
        XCTAssertTrue(screen.catalog.showRating)
    }

    func testCatalog_withRatingOff_drawsNoRatingOnCards() {
        let catalog = screen.catalog
        catalog.products = [PersonalizationProduct(id: "1", name: "Rated", price: "$1", ratingValue: "4.5", reviews: 3)]
        window.layoutIfNeeded()
        let ratings = { self.views(PersonalizationRating.self, in: catalog) }
        XCTAssertFalse(ratings().isEmpty)
        XCTAssertTrue(ratings().allSatisfy(\.isHidden))

        catalog.showRating = true
        window.layoutIfNeeded()
        XCTAssertTrue(ratings().contains { !$0.isHidden })
    }

    // MARK: - Error and retry

    func testFirstPageError_showsErrorWithRetry_andRetryLoadsTheFirstPageAgain() {
        sdk.searchResults = [.failure(.networkOfflineError)]
        search("phone")

        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(screen.catalog.errorText, "Something went wrong. Check your connection and try again.")
        XCTAssertEqual(screen.catalog.retryText, "Retry")
        XCTAssertNil(screen.catalog.emptyText)
        XCTAssertFalse(screen.catalog.isLoading)
        let retry = buttons("Retry")
        XCTAssertEqual(retry.count, 1)

        sdk.searchResults = [page(total: 2, ids: 0..<2)]
        retry.first?.sendActions(for: .touchUpInside)
        window.layoutIfNeeded()

        XCTAssertEqual(sdk.searchOffsets, [0, 0])
        XCTAssertNil(screen.catalog.errorText)
        XCTAssertEqual(screen.products.map(\.id), ["0", "1"])
        XCTAssertTrue(buttons("Retry").isEmpty)
        XCTAssertEqual(errors.count, 1)
    }

    func testFirstPageError_retryFailingAgain_keepsTheErrorAndReportsIt() {
        sdk.searchResults = [.failure(.networkOfflineError), .failure(.responseError)]
        search("phone")

        screen.catalog.onRetry?()

        XCTAssertEqual(sdk.searchOffsets, [0, 0])
        XCTAssertEqual(errors.count, 2)
        XCTAssertNotNil(screen.catalog.errorText)
    }

    func testNextPageError_turnsLoadMoreIntoRetry_thatLoadsThatPageAgain() {
        screen.pageSize = 2
        sdk.searchResults = [page(total: 4, ids: 0..<2), .failure(.networkOfflineError)]
        search("phone")
        XCTAssertEqual(screen.catalog.loadMoreText, "Load more")

        screen.catalog.onLoadMore?()

        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(screen.catalog.loadMoreText, "Retry")
        XCTAssertFalse(screen.catalog.isLoading)
        XCTAssertNil(screen.catalog.errorText)
        XCTAssertEqual(screen.products.count, 2)

        sdk.searchResults = [page(total: 4, ids: 2..<4)]
        screen.catalog.onLoadMore?()

        XCTAssertEqual(sdk.searchOffsets, [0, 2, 2])
        XCTAssertEqual(screen.products.map(\.id), ["0", "1", "2", "3"])
        XCTAssertNil(screen.catalog.loadMoreText)
        XCTAssertEqual(errors.count, 1)
    }

    func testNextPageError_withInfiniteScroll_waitsForTheRetryTap() {
        // Off the window the list never scrolls, so the next page is asked only by the calls below.
        screen.removeFromSuperview()
        screen.pageSize = 2
        screen.infiniteScroll = true
        sdk.searchResults = [page(total: 4, ids: 0..<2), .failure(.networkOfflineError)]
        search("phone")
        XCTAssertNil(screen.catalog.loadMoreText)

        screen.catalog.onNearEnd?()
        XCTAssertEqual(screen.catalog.loadMoreText, "Retry")

        // Scrolling near the end again does not hammer the failed page.
        screen.catalog.onNearEnd?()
        XCTAssertEqual(sdk.searchOffsets, [0, 2])

        sdk.searchResults = [page(total: 4, ids: 2..<4)]
        screen.catalog.onLoadMore?()
        XCTAssertEqual(sdk.searchOffsets, [0, 2, 2])
        XCTAssertNil(screen.catalog.loadMoreText)
    }

    func testErrorTexts_areParameters() {
        screen.errorText = "Не удалось загрузить"
        screen.retryText = "Повторить"
        sdk.searchResults = [.failure(.networkOfflineError)]
        search("phone")

        XCTAssertEqual(screen.catalog.errorText, "Не удалось загрузить")
        XCTAssertEqual(buttons("Повторить").count, 1)
    }

    func testEmptyErrorTexts_fallBackToDefaults_soRetryStaysReachable() {
        screen.errorText = nil
        screen.retryText = ""
        XCTAssertEqual(screen.errorText, "Something went wrong. Check your connection and try again.")
        XCTAssertEqual(screen.retryText, "Retry")

        sdk.searchResults = [.failure(.networkOfflineError)]
        search("phone")
        XCTAssertEqual(buttons("Retry").count, 1)

        screen.retryText = nil
        screen.errorText = ""
        screen.pageSize = 2
        screen.infiniteScroll = true
        screen.removeFromSuperview()
        sdk.searchResults = [page(total: 4, ids: 0..<2), .failure(.networkOfflineError)]
        search("laptop")
        screen.catalog.onNearEnd?()

        XCTAssertEqual(screen.catalog.loadMoreText, "Retry")
        XCTAssertEqual(screen.retryText, "Retry")
    }

    func testRetry_ofTheFirstPage_doesNotTrackTheSearchAgain() {
        sdk.searchResults = [.failure(.networkOfflineError), page(total: 1, ids: 0..<1)]
        search("phone")
        XCTAssertEqual(searchEvents, 1)

        screen.catalog.onRetry?()

        XCTAssertEqual(sdk.searchOffsets, [0, 0])
        XCTAssertEqual(screen.products.count, 1)
        XCTAssertEqual(searchEvents, 1)
    }

    func testRetry_ofTheNextPage_doesNotTrackTheSearchAgain() {
        screen.pageSize = 2
        sdk.searchResults = [page(total: 4, ids: 0..<2), .failure(.networkOfflineError), page(total: 4, ids: 2..<4)]
        search("phone")
        screen.catalog.onLoadMore?()
        XCTAssertEqual(screen.catalog.loadMoreText, "Retry")

        screen.catalog.onLoadMore?()

        XCTAssertEqual(sdk.searchOffsets, [0, 2, 2])
        XCTAssertEqual(screen.products.count, 4)
        XCTAssertEqual(searchEvents, 1)
    }

    func testNewQuery_clearsTheError() {
        sdk.searchResults = [.failure(.networkOfflineError), page(total: 1, ids: 0..<1)]
        search("phone")
        XCTAssertNotNil(screen.catalog.errorText)

        search("laptop")

        XCTAssertNil(screen.catalog.errorText)
        XCTAssertEqual(screen.products.count, 1)
    }
}

private extension UIView {
    /// Hidden itself or under a hidden ancestor. The test window is never shown, so the walk
    /// stops below it.
    var isHiddenInHierarchy: Bool {
        var view: UIView? = self
        while let current = view, !(current is UIWindow) {
            if current.isHidden { return true }
            view = current.superview
        }
        return false
    }
}
