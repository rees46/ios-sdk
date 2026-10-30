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

    // MARK: - Found count

    /// Whether "Found N products" is on screen; the filter and sort buttons next to it stay either way.
    private func foundShown() -> Bool {
        let prefix = views(UILabel.self, in: screen).first { $0.attributedText?.string == "Found" }
        return prefix.map { !($0.superview?.isHidden ?? true) } ?? false
    }

    func testFoundCount_staysHiddenUntilTheFirstPageOfEachRequestAnswers() {
        search("phone")  // nothing scripted: the request stays pending
        XCTAssertFalse(foundShown())

        sdk.searchResults = [page(total: 2, ids: 0..<2)]
        search("phone")
        XCTAssertTrue(foundShown())

        sdk.searchResults = [.failure(.networkOfflineError)]
        search("tv")
        XCTAssertFalse(foundShown())
    }

    // MARK: - Facets

    /// `f01`…`f12` with two values each — the earlier, the more products have it — and a
    /// single-valued facet that every product has.
    private func pageWithFacets() -> Result<SearchResponse, SdkError> {
        var filters: [String: Any] = ["single": ["count": 5000, "values": ["only": 5000]]]
        for index in 1...12 {
            filters[String(format: "f%02d", index)] = ["count": 1000 - index, "values": ["a": 1, "b": 2]]
        }
        let product: [String: Any] = ["id": "1", "name": "Product", "price": 10.0]
        return .success(SearchResponse(json: ["products_total": 1, "products": [product], "filters": filters]))
    }

    private var facetSections: [String] {
        screen.openFilters()
        return screen.filters.sections.map(\.id).filter { $0.hasPrefix("facet:") }.map { String($0.dropFirst(6)) }
    }

    func testFacets_mostCommonFirst_atMostMaxFacets() {
        sdk.searchResults = [pageWithFacets()]
        search("samsung")

        XCTAssertEqual(facetSections, (1...10).map { String(format: "f%02d", $0) })
        screen.maxFacets = nil
        XCTAssertEqual(facetSections.count, 12)
    }

    func testFilters_keepTheTitleAndButtonsOnScreen_whileSectionsScroll() {
        sdk.searchResults = [pageWithFacets()]
        search("samsung")
        screen.maxFacets = nil
        screen.openFilters()
        window.layoutIfNeeded()

        let apply = buttons("Apply")
        XCTAssertEqual(apply.count, 1)
        let frame = apply[0].convert(apply[0].bounds, to: screen)
        XCTAssertLessThanOrEqual(frame.maxY, screen.bounds.maxY)
        XCTAssertGreaterThan(frame.minY, screen.bounds.midY)
    }

    func testFacets_explicitList_winsInTheHostsOrder() {
        sdk.searchResults = [pageWithFacets()]
        search("samsung")

        screen.facets = ["f12", "single", "f01"]

        XCTAssertEqual(facetSections, ["f12", "single", "f01"])
    }

    // MARK: - Value counts

    /// Labels of the options in the section `id`.
    private func optionLabels(_ id: String) -> [String] {
        screen.openFilters()
        for case let .options(sectionId, _, options, _, _, _) in screen.filters.sections where sectionId == id {
            return options.map(\.label)
        }
        return []
    }

    func testValueCounts_ofBrandsColorsAndSizes_whenTheResponseHasThem() {
        let product: [String: Any] = ["id": "1", "name": "Product", "price": 10.0]
        sdk.searchResults = [.success(SearchResponse(json: [
            "products_total": 1,
            "products": [product],
            "brands": [["name": "Samsung", "count": 801], ["name": "NoCount"]],
            "industrial_filters": [
                "colors": [["color": "red", "count": 3]],
                "fashion_sizes": [["size": "M", "count": 2], ["size": "L"]]
            ]
        ]))]
        search("samsung")

        XCTAssertEqual(optionLabels("brands"), ["Samsung (801)", "NoCount"])
        XCTAssertEqual(optionLabels("colors"), ["red (3)"])
        XCTAssertEqual(optionLabels("sizes"), ["M (2)", "L"])

        // The tag of an applied value carries no count.
        screen.applied.brands = ["Samsung"]
        screen.reload()
        XCTAssertEqual(views(PersonalizationTag.self, in: screen.title).compactMap(\.text), ["Samsung"])

        screen.showValueCounts = false
        XCTAssertEqual(optionLabels("brands"), ["Samsung", "NoCount"])
        XCTAssertEqual(optionLabels("sizes"), ["M", "L"])
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
