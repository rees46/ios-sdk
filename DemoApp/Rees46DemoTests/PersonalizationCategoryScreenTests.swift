import XCTest
@_spi(PersonalizationUI) @testable import REES46

/// The category screen driven by a fake SDK whose `getCategory` answers are scripted: what goes into
/// the request, `categoryView` once per category, the filter sections from the category response,
/// errors with retry, the empty category; the facet rule and the value labels shared with the search
/// screen; and where the protocol's default `getCategory` sends a call for conformers that predate it.
final class PersonalizationCategoryScreenTests: XCTestCase {

    private var window: UIWindow!
    private var sdk: FakeSDK!
    private var screen: PersonalizationCategoryScreen!
    private var errors: [SdkError] = []

    override func setUp() {
        super.setUp()
        // Never shown: the screen lays out the same in a hidden window.
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        sdk = FakeSDK()
        errors = []
        screen = PersonalizationCategoryScreen(categoryId: "kitchen")
        screen.frame = window.bounds
        screen.onError = { [weak self] error in self?.errors.append(error) }
    }

    override func tearDown() {
        screen = nil
        sdk = nil
        window = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    private func page(total: Int, ids: Range<Int>, extra: [String: Any] = [:]) -> Result<CategoryResponse, SdkError> {
        let products: [[String: Any]] = ids.map { index in
            ["id": "\(index)", "name": "Product \(index)", "price": 10.0, "price_formatted": "10 ₽"]
        }
        var json: [String: Any] = ["products_total": total, "products": products]
        json.merge(extra) { _, new in new }
        return .success(CategoryResponse(json: json))
    }

    /// `count` facets named `f01`…, two values each; the earlier, the more products have it.
    private func facets(_ count: Int) -> [String: Any] {
        var filters: [String: Any] = [:]
        for index in 1...count {
            filters[String(format: "f%02d", index)] = ["count": 1000 - index, "values": ["a": 1, "b": 2]]
        }
        return filters
    }

    /// An explicit instance — the first page goes out right away — and the answers it gets.
    private func open(_ results: [Result<CategoryResponse, SdkError>]) {
        sdk.categoryResults = results
        screen.attach(sdk)
        window.addSubview(screen)
        window.layoutIfNeeded()
    }

    private var categoryEvents: [String] {
        sdk.trackedEvents.compactMap { event -> String? in
            if case let .categoryView(id) = event { return id } else { return nil }
        }
    }

    private var facetSections: [String] {
        screen.openFilters()
        return screen.filters.sections.map(\.id).filter { $0.hasPrefix("facet:") }.map { String($0.dropFirst(6)) }
    }

    // MARK: - Request

    func testRequest_carriesTheCategoryAndThePage() {
        screen.pageSize = 2
        open([page(total: 4, ids: 0..<2), page(total: 4, ids: 2..<4)])

        screen.loadMore()

        XCTAssertEqual(sdk.categoryCalls.map(\.category), ["kitchen", "kitchen"])
        XCTAssertEqual(sdk.categoryCalls.map(\.page), [1, 2])
        XCTAssertEqual(sdk.categoryCalls.map(\.limit), [2, 2])
        XCTAssertEqual(screen.products.compactMap(\.id), ["0", "1", "2", "3"])
        XCTAssertNil(screen.catalog.loadMoreText)
    }

    func testRequest_carriesBrandsFacetsPriceSortingAndLocations() {
        open([page(total: 1, ids: 0..<1)])
        var applied = PersonalizationAppliedFilters()
        applied.brands = ["Tefal", "Bosch"]
        applied.priceMin = "100"
        applied.priceMax = " 500 "
        applied.facets = ["color": ["red", "blue"], "empty": []]
        screen.applied = applied
        screen.sortBy = "price"
        screen.sortDir = "asc"
        screen.locations = "1,2"
        screen.reload()

        let call = sdk.categoryCalls.last
        XCTAssertEqual(call?.page, 1)
        XCTAssertEqual(call?.brands, "Bosch,Tefal")
        XCTAssertEqual(call?.filters, ["color": ["blue", "red"]])
        XCTAssertEqual(call?.priceMin, 100)
        XCTAssertEqual(call?.priceMax, 500)
        XCTAssertEqual(call?.sortBy, "price")
        XCTAssertEqual(call?.sortDir, "asc")
        XCTAssertEqual(call?.locations, "1,2")
    }

    func testFirstRequest_hasNoFiltersOrSorting() {
        open([page(total: 1, ids: 0..<1)])

        let call = sdk.categoryCalls.first
        XCTAssertNil(call?.brands)
        XCTAssertNil(call?.filters)
        XCTAssertNil(call?.priceMin)
        XCTAssertNil(call?.priceMax)
        XCTAssertNil(call?.sortBy)
        XCTAssertNil(call?.sortDir)
    }

    // MARK: - Tracking

    func testCategoryView_goesOncePerCategory() {
        screen.pageSize = 2
        open([page(total: 4, ids: 0..<2), page(total: 4, ids: 2..<4)])
        screen.loadMore()
        screen.sortBy = "price"
        screen.reload()
        sdk.categoryResults = [.failure(.networkOfflineError), page(total: 1, ids: 0..<1)]
        screen.applied.brands = ["Bosch"]
        screen.reload()
        screen.catalog.onRetry?()

        XCTAssertEqual(screen.products.count, 1)
        XCTAssertEqual(categoryEvents, ["kitchen"])

        screen.categoryId = "laundry"
        screen.reload()
        XCTAssertEqual(categoryEvents, ["kitchen", "laundry"])
    }

    func testProductTap_handsTheProductOver_withoutATrackingSource() {
        var tapped: [String] = []
        screen.onProductTap = { tapped.append($0.id ?? "") }
        open([page(total: 2, ids: 0..<2)])

        screen.catalog.onProductTap?(screen.catalog.products[1])

        XCTAssertEqual(tapped, ["1"])
        XCTAssertTrue(sdk.storedSources.isEmpty)
    }

    // MARK: - Filters

    func testFilterSections_comeFromTheCategoryResponse_withoutColorsAndSizes() {
        open([page(total: 2, ids: 0..<2, extra: [
            "price_range": ["min": 200.0, "max": 1089990.0],
            "brands": [["name": "Bosch", "count": 3], ["name": "Tefal", "count": 2]],
            "filters": ["power": ["count": 5, "values": ["1000": 2, "2000": 3]], "single": ["count": 9, "values": ["x": 9]]]
        ])])

        screen.openFilters()

        XCTAssertTrue(screen.isFiltersOpen)
        XCTAssertEqual(screen.filters.sections.map(\.id), ["price", "brands", "facet:power"])
        guard case let .range(_, _, _, _, _, _, _, fromPlaceholder, toPlaceholder) = screen.filters.sections[0] else {
            return XCTFail("price is a range")
        }
        XCTAssertEqual(fromPlaceholder, "200")
        XCTAssertEqual(toPlaceholder, "1089990")
        guard case let .options(_, _, brands, _, _, _) = screen.filters.sections[1] else {
            return XCTFail("brands are options")
        }
        XCTAssertEqual(brands.map(\.label), ["Bosch (3)", "Tefal (2)"])
        XCTAssertEqual(brands.map(\.id), ["Bosch", "Tefal"])
    }

    func testAppliedFilters_fromTheFiltersScreen_goToTheNextRequest() {
        open([page(total: 2, ids: 0..<2, extra: [
            "brands": [["name": "Bosch", "count": 3]],
            "filters": ["power": ["count": 5, "values": ["1000": 2, "2000": 3]]]
        ])])
        screen.openFilters()
        let checked = screen.filters.sections.map { section -> PersonalizationFilters.Section in
            guard case let .options(id, title, options, collapsed, more, less) = section else { return section }
            return .options(id: id, title: title, options: options.map { option in
                var next = option
                next.checked = option.id == "Bosch" || option.id == "2000"
                return next
            }, collapsedCount: collapsed, showMoreText: more, showLessText: less)
        }
        screen.filters.setSections(checked)

        screen.filters.onApply?()
        screen.reload()

        XCTAssertFalse(screen.isFiltersOpen)
        XCTAssertEqual(sdk.categoryCalls.last?.brands, "Bosch")
        XCTAssertEqual(sdk.categoryCalls.last?.filters, ["power": ["2000"]])
    }

    // MARK: - Errors and the empty category

    func testFirstPageError_showsErrorWithRetry_thatLoadsTheFirstPageAgain() {
        open([.failure(.networkOfflineError)])

        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(screen.catalog.errorText, "Something went wrong. Check your connection and try again.")
        XCTAssertEqual(screen.catalog.retryText, "Retry")
        XCTAssertNil(screen.catalog.emptyText)

        sdk.categoryResults = [page(total: 2, ids: 0..<2)]
        screen.catalog.onRetry?()

        XCTAssertEqual(sdk.categoryCalls.map(\.page), [1, 1])
        XCTAssertNil(screen.catalog.errorText)
        XCTAssertEqual(screen.products.count, 2)
        XCTAssertEqual(categoryEvents, ["kitchen"])
    }

    func testNextPageError_turnsLoadMoreIntoRetry_thatLoadsThatPageAgain() {
        screen.pageSize = 2
        open([page(total: 4, ids: 0..<2), .failure(.networkOfflineError)])
        XCTAssertEqual(screen.catalog.loadMoreText, "Load more")

        screen.catalog.onLoadMore?()

        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(screen.catalog.loadMoreText, "Retry")
        XCTAssertNil(screen.catalog.errorText)

        sdk.categoryResults = [page(total: 4, ids: 2..<4)]
        screen.catalog.onLoadMore?()

        XCTAssertEqual(sdk.categoryCalls.map(\.page), [1, 2, 2])
        XCTAssertEqual(screen.products.count, 4)
        XCTAssertNil(screen.catalog.loadMoreText)
    }

    func testEmptyCategory_showsTheEmptyState() {
        open([page(total: 0, ids: 0..<0)])

        XCTAssertEqual(screen.catalog.emptyText, "No products in this category yet.")
        XCTAssertNil(screen.catalog.errorText)
        XCTAssertNil(screen.catalog.loadMoreText)
    }

    func testEmptyNextPage_endsTheList() {
        screen.pageSize = 2
        open([page(total: 10, ids: 0..<2), page(total: 10, ids: 0..<0)])

        screen.loadMore()

        XCTAssertNil(screen.catalog.loadMoreText)
        screen.loadMore()
        XCTAssertEqual(sdk.categoryCalls.count, 2)
    }

    func testCounter_readsNProducts_andTheTitleIsTheHosts() {
        screen.titleText = "Kitchen"
        open([page(total: 3, ids: 0..<3)])

        XCTAssertEqual(screen.title.text, "Kitchen")
        XCTAssertNil(screen.foundPrefix)
        let labels = views(UILabel.self, in: screen.title).filter { !$0.isHidden }.compactMap(\.text)
        XCTAssertTrue(labels.contains("3"))
        XCTAssertTrue(labels.contains("products"))
        XCTAssertFalse(labels.contains("Found"))
    }

    private func views<T: UIView>(_ type: T.Type, in root: UIView) -> [T] {
        root.subviews.flatMap { view -> [T] in
            let own = (view as? T).map { [$0] } ?? []
            return own + views(type, in: view)
        }
    }

    // MARK: - Facets: the most common first, at most `maxFacets`

    func testFacets_mostCommonFirst_atMostTen_singleValuedLeftOut() {
        var filters = facets(12)
        filters["single"] = ["count": 5000, "values": ["only": 5000]]
        open([page(total: 1, ids: 0..<1, extra: ["filters": filters])])

        XCTAssertEqual(screen.maxFacets, 10)
        XCTAssertEqual(facetSections, (1...10).map { String(format: "f%02d", $0) })
    }

    func testFacets_withoutALimit_showsAllMultiValued() {
        open([page(total: 1, ids: 0..<1, extra: ["filters": facets(12)])])

        screen.maxFacets = nil
        XCTAssertEqual(facetSections.count, 12)
        screen.maxFacets = 0
        XCTAssertEqual(facetSections.count, 12)
        screen.maxFacets = 3
        XCTAssertEqual(facetSections, ["f01", "f02", "f03"])
    }

    func testFacets_explicitList_winsInTheHostsOrder() {
        open([page(total: 1, ids: 0..<1, extra: ["filters": facets(12)])])

        screen.facets = ["f12", "missing", "f03"]

        XCTAssertEqual(facetSections, ["f12", "f03"])
    }

    func testFacets_appliedOutsideTheList_staysReachable() {
        open([page(total: 1, ids: 0..<1, extra: ["filters": facets(12)])])
        screen.maxFacets = 2
        screen.applied.facets = ["f11": ["a"]]

        XCTAssertEqual(facetSections, ["f01", "f02", "f11"])
    }

    // MARK: - Value labels

    /// A sticker value of the demo shop's feed: a JSON object with a `title`.
    private let sticker = ##"{"slug": "super_price", "title": "Суперцена", "text_color": "#ffffff", "background_color": "#f48012", "priority": 1}"##

    /// Options of the facet section `name`.
    private func facetOptions(_ name: String) -> [PersonalizationFilters.Option] {
        screen.openFilters()
        for case let .options(id, _, options, _, _, _) in screen.filters.sections where id == "facet:" + name {
            return options
        }
        return []
    }

    private var brandOptions: [PersonalizationFilters.Option] {
        screen.openFilters()
        for case let .options(id, _, options, _, _, _) in screen.filters.sections where id == "brands" {
            return options
        }
        return []
    }

    private var tagLabels: [String] {
        views(PersonalizationTag.self, in: screen.title).compactMap(\.text)
    }

    private func openWithStickers(_ values: [String: Int]) {
        open([page(total: 1, ids: 0..<1, extra: [
            "brands": [["name": "Bosch", "count": 3]],
            "filters": ["stickers": ["count": 9, "values": values], "power": ["count": 5, "values": ["1000": 2, "2000": 3]]]
        ])])
    }

    func testJsonValue_isShownByItsTitle_andGoesToTheRequestAsIs() {
        openWithStickers([sticker: 7, "plain": 2])

        let options = facetOptions("stickers")
        XCTAssertEqual(options.map(\.label), ["plain (2)", "Суперцена (7)"])
        XCTAssertEqual(options.map(\.id), ["plain", sticker])

        screen.applied.facets = ["stickers": [sticker]]
        screen.reload()

        XCTAssertEqual(sdk.categoryCalls.last?.filters, ["stickers": [sticker]])
        XCTAssertEqual(tagLabels, ["Суперцена"])
    }

    func testValuesThatAreNotJsonObjectsWithATitle_areShownAsIs() {
        let values = [
            #"{"slug": "broken""#,
            #"{"slug": "no_title"}"#,
            #"{"title": 5}"#,
            #"{"title": "  "}"#,
            #"["title"]"#,
            #"  {"title": "Trimmed"}"#
        ]
        openWithStickers(Dictionary(uniqueKeysWithValues: values.map { ($0, 1) }))
        screen.showValueCounts = false

        let labels = Dictionary(uniqueKeysWithValues: facetOptions("stickers").map { ($0.id, $0.label) })
        for value in values.dropLast() {
            XCTAssertEqual(labels[value], value)
        }
        XCTAssertEqual(labels[values[5]], "Trimmed")
    }

    func testHostValueTitle_winsOverTheJsonTitle_onlyForFacets() {
        openWithStickers([sticker: 7, "plain": 2])
        screen.facetValueTitle = { facet, value in
            switch (facet, value) {
            case ("stickers", "plain"): return "Обычный"
            case ("stickers", _): return ""
            default: return "Host"
            }
        }

        XCTAssertEqual(facetOptions("stickers").map(\.label), ["Обычный (2)", "Суперцена (7)"])
        XCTAssertEqual(facetOptions("power").map(\.label), ["Host (2)", "Host (3)"])
        XCTAssertEqual(brandOptions.map(\.label), ["Bosch (3)"])

        screen.applied.facets = ["stickers": ["plain"]]
        screen.reload()
        XCTAssertEqual(tagLabels, ["Обычный"])
    }

    func testValueCounts_canBeTurnedOff() {
        openWithStickers([sticker: 7, "plain": 2])
        XCTAssertTrue(screen.showValueCounts)

        screen.showValueCounts = false

        XCTAssertEqual(facetOptions("stickers").map(\.label), ["plain", "Суперцена"])
        XCTAssertEqual(brandOptions.map(\.label), ["Bosch"])
    }

    func testAppliedValueMissingFromTheResponse_hasNoCount() {
        openWithStickers(["plain": 2])
        screen.applied.facets = ["stickers": [sticker]]

        XCTAssertEqual(facetOptions("stickers").map(\.label), ["plain (2)", "Суперцена"])
    }

    // MARK: - SDK: the protocol's default `getCategory` with price and sorting

    func testDefaultGetCategory_withoutPriceOrSorting_goesToTheConformersOwnCategory() {
        let mock = NotificationsMockSDK()

        mock.getCategory(category: "kitchen", limit: 20, page: 2, brands: "Bosch", locations: nil, filters: nil, priceMin: nil, priceMax: nil, sortBy: nil, sortDir: nil) { _ in }

        XCTAssertEqual(mock.categoryCalls.map(\.category), ["kitchen"])
        XCTAssertEqual(mock.categoryCalls.map(\.page), [2])
        XCTAssertTrue(mock.getRequests.isEmpty)
    }

    func testDefaultGetCategory_withPriceAndSorting_sendsTheCategoryRequest() {
        let mock = NotificationsMockSDK()

        mock.getCategory(category: "kitchen", limit: 20, page: 1, brands: "Bosch", locations: nil, filters: ["power": ["2000"]], priceMin: 100, priceMax: 500.5, sortBy: "discount", sortDir: "desc") { _ in }

        XCTAssertTrue(mock.categoryCalls.isEmpty)
        XCTAssertEqual(mock.getRequests.map(\.path), ["category/kitchen"])
        let params = mock.getRequests.first?.params ?? [:]
        XCTAssertEqual(params["shop_id"], "mock-shop")
        XCTAssertEqual(params["did"], "mock-device-id")
        XCTAssertEqual(params["limit"], "20")
        XCTAssertEqual(params["page"], "1")
        XCTAssertEqual(params["brands"], "Bosch")
        XCTAssertEqual(params["filters"], #"{"power":["2000"]}"#)
        XCTAssertEqual(params["price_min"], "100.0")
        XCTAssertEqual(params["price_max"], "500.5")
        XCTAssertEqual(params["sort_by"], "discount")
        XCTAssertEqual(params["sort_dir"], "desc")
    }

    func testOldGetCategory_stillReachesTheConformer() {
        let mock = NotificationsMockSDK()

        mock.getCategory(category: "kitchen", limit: 5) { _ in }

        XCTAssertEqual(mock.categoryCalls.map(\.category), ["kitchen"])
        XCTAssertTrue(mock.getRequests.isEmpty)
    }
}
