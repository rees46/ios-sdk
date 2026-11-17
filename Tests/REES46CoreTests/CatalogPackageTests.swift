//
//  CatalogPackageTests.swift
//  REES46CoreTests
//
//  The catalog's namespaces without a server — `products`, `collections`, `recommendations` and the
//  search of `search` —: the request of each call of the proposed fixtures, the calls refused before
//  anything is sent, and what the request path makes of each answer.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class CatalogPackageTests: XCTestCase {

    private typealias Fixtures = NamespaceFixtures

    // MARK: - The fixtures

    func test_products_build_the_fixtures_requests_and_refuse_its_arguments() throws {
        try Fixtures.checkRequests("products", build: Self.products)
    }

    func test_products_end_as_the_fixture_says_for_each_answer() throws {
        try Fixtures.checkAnswers("products", build: Self.products)
    }

    func test_collections_build_the_fixtures_requests_and_refuse_its_arguments() throws {
        try Fixtures.checkRequests("collections", build: Self.collections)
    }

    func test_collections_end_as_the_fixture_says_for_each_answer() throws {
        try Fixtures.checkAnswers("collections", build: Self.collections)
    }

    func test_recommendations_build_the_fixtures_requests_and_refuse_its_arguments() throws {
        try Fixtures.checkRequests("recommendations", build: Self.recommendations)
    }

    func test_recommendations_end_as_the_fixture_says_for_each_answer() throws {
        try Fixtures.checkAnswers("recommendations", build: Self.recommendations)
    }

    func test_search_builds_the_fixtures_requests_and_refuses_its_arguments() throws {
        try Fixtures.checkRequests("search", build: Self.search)
    }

    func test_search_ends_as_the_fixture_says_for_each_answer() throws {
        try Fixtures.checkAnswers("search", build: Self.search)
    }

    func test_the_catalogs_fixtures_are_proposed_until_the_contract_has_them() throws {
        for name in ["products", "collections", "recommendations", "search"] {
            XCTAssertEqual(try ContractFixtures.load(name, from: .proposed)["contract"] as? String, ContractFixtures.version, name)
            let cases = try ContractFixtures.fixture(name, from: .proposed)
            XCTAssertTrue(cases.allSatisfy { $0.call?.namespace == name }, name)
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: ContractFixtures.url(name).path),
                "the contract has \(name).json now: copy it into contract-\(ContractFixtures.version) and remove the proposed one"
            )
        }
    }

    // MARK: - Calls of the fixtures

    private static func products(_ call: ContractCase.Call) throws -> ErasedRequest {
        let args = call.args
        switch call.method {
        case "getInfo":
            return ErasedRequest(try ProductsAPIImpl.infoRequest(itemId: Fixtures.string(args["itemId"]) ?? ""), call: call.name)
        case "getList":
            return ErasedRequest(try ProductsAPIImpl.listRequest(listRequest(args["request"])), call: call.name)
        case "getCounters":
            return ErasedRequest(try ProductsAPIImpl.countersRequest(itemId: Fixtures.string(args["itemId"]) ?? ""), call: call.name)
        case "getCategory":
            let request = categoryRequest(args["request"])
            return ErasedRequest(try ProductsAPIImpl.categoryRequest(categoryId: Fixtures.string(args["categoryId"]) ?? "", request), call: call.name)
        default:
            throw Unknown(call: call.name)
        }
    }

    private static func collections(_ call: ContractCase.Call) throws -> ErasedRequest {
        guard call.method == "get" else { throw Unknown(call: call.name) }
        return ErasedRequest(try CollectionsAPIImpl.collectionRequest(collectionId: Fixtures.string(call.args["collectionId"]) ?? ""), call: call.name)
    }

    private static func recommendations(_ call: ContractCase.Call) throws -> ErasedRequest {
        guard call.method == "get" else { throw Unknown(call: call.name) }
        let json = call.args["request"] as? [String: Any] ?? [:]
        let request = Rees46.RecommendationRequest(
            itemId: Fixtures.string(json["itemId"]),
            categoryId: Fixtures.string(json["categoryId"]),
            searchQuery: Fixtures.string(json["searchQuery"]),
            excludedItemIds: Fixtures.strings(json["excludedItemIds"]),
            brands: Fixtures.strings(json["brands"]),
            locations: Fixtures.strings(json["locations"]),
            limit: Fixtures.int(json["limit"]),
            extended: Fixtures.bool(json["extended"]) ?? true,
            withLocations: Fixtures.bool(json["withLocations"]) ?? false
        )
        return ErasedRequest(try RecommendationsAPIImpl.blockRequest(code: Fixtures.string(call.args["code"]) ?? "", request), call: call.name)
    }

    private static func search(_ call: ContractCase.Call) throws -> ErasedRequest {
        let args = call.args
        switch call.method {
        case "blank":
            return ErasedRequest(SearchAPIImpl.blankRequest, call: call.name)
        case "instant":
            return ErasedRequest(try SearchAPIImpl.instantRequest(
                query: Fixtures.string(args["query"]) ?? "",
                locations: Fixtures.strings(args["locations"]),
                excludedMerchants: Fixtures.strings(args["excludedMerchants"]),
                excludedBrands: Fixtures.strings(args["excludedBrands"])
            ), call: call.name)
        case "full":
            let json = args["request"] as? [String: Any] ?? [:]
            let request = Rees46.SearchFullRequest(
                categoryIds: Fixtures.strings(json["categoryIds"]),
                brands: Fixtures.strings(json["brands"]),
                excludedBrands: Fixtures.strings(json["excludedBrands"]),
                merchants: Fixtures.strings(json["merchants"]),
                excludedMerchants: Fixtures.strings(json["excludedMerchants"]),
                locations: Fixtures.strings(json["locations"]),
                priceMin: Fixtures.double(json["priceMin"]),
                priceMax: Fixtures.double(json["priceMax"]),
                colors: Fixtures.strings(json["colors"]),
                fashionSizes: Fixtures.strings(json["fashionSizes"]),
                excludedItemIds: Fixtures.strings(json["excludedItemIds"]),
                filters: Fixtures.filters(json["filters"]),
                sortBy: Fixtures.sortBy(json["sortBy"]),
                sortDir: Fixtures.sortDir(json["sortDir"]),
                disableClarification: Fixtures.bool(json["disableClarification"]) ?? false,
                categoryLimit: Fixtures.int(json["categoryLimit"]),
                brandLimit: Fixtures.int(json["brandLimit"]),
                limit: Fixtures.int(json["limit"]),
                page: Fixtures.int(json["page"])
            )
            return ErasedRequest(try SearchAPIImpl.fullRequest(query: Fixtures.string(args["query"]) ?? "", request), call: call.name)
        default:
            throw Unknown(call: call.name)
        }
    }

    private static func listRequest(_ value: Any?) -> Rees46.ProductsListRequest {
        let json = value as? [String: Any] ?? [:]
        return Rees46.ProductsListRequest(
            categoryIds: Fixtures.strings(json["categoryIds"]),
            brands: Fixtures.strings(json["brands"]),
            merchants: Fixtures.strings(json["merchants"]),
            locations: Fixtures.strings(json["locations"]),
            priceMin: Fixtures.double(json["priceMin"]),
            priceMax: Fixtures.double(json["priceMax"]),
            filters: Fixtures.filters(json["filters"]),
            sortBy: Fixtures.sortBy(json["sortBy"]),
            sortDir: Fixtures.sortDir(json["sortDir"]),
            limit: Fixtures.int(json["limit"]),
            page: Fixtures.int(json["page"])
        )
    }

    private static func categoryRequest(_ value: Any?) -> Rees46.CategoryRequest {
        let json = value as? [String: Any] ?? [:]
        return Rees46.CategoryRequest(
            brands: Fixtures.strings(json["brands"]),
            locations: Fixtures.strings(json["locations"]),
            filters: Fixtures.filters(json["filters"]),
            priceMin: Fixtures.double(json["priceMin"]),
            priceMax: Fixtures.double(json["priceMax"]),
            sortBy: Fixtures.sortBy(json["sortBy"]),
            sortDir: Fixtures.sortDir(json["sortDir"]),
            limit: Fixtures.int(json["limit"]),
            page: Fixtures.int(json["page"])
        )
    }

    private struct Unknown: Error {
        let call: String
    }

    // MARK: - Beyond the fixtures

    private func value<Value>(_ request: ApiRequest<Value>, _ json: String, status: Int = 200) -> Result<Value, Rees46.SdkError> {
        let body = Data(json.utf8)
        let answer = NetworkClient.Response(status: status, body: body, retryAfter: nil, result: NetworkClient.classify(status: status, body: body))
        return NamespaceRequests.value(of: answer, for: request, call: "test", logger: SdkLogger(shopId: "package-\(UUID().uuidString)", level: .none))
    }

    func test_a_2xx_without_a_body_is_the_empty_value_where_the_method_has_one() throws {
        XCTAssertNil(try value(ProductsAPIImpl.infoRequest(itemId: "37"), "").get(), "no product")
        let counters = try value(ProductsAPIImpl.countersRequest(itemId: "37"), "").get()
        XCTAssertNil(counters.daily)
        XCTAssertNil(counters.triggers)
        let block = try value(RecommendationsAPIImpl.blockRequest(code: "b", Rees46.RecommendationRequest()), "").get()
        XCTAssertEqual(block.products, [])
        XCTAssertEqual(block.itemIds, [])
        XCTAssertEqual(try value(SearchAPIImpl.blankRequest, "").get().products, [])
        XCTAssertEqual(try value(SearchAPIImpl.blankRequest, "[]").get().products, [], "the server's empty object")
        // A listing, a collection and a search have no empty value: a body without products is not one.
        XCTAssertThrowsError(try value(ProductsAPIImpl.listRequest(Rees46.ProductsListRequest()), "").get())
        XCTAssertThrowsError(try value(CollectionsAPIImpl.collectionRequest(collectionId: "1"), "").get())
        XCTAssertThrowsError(try value(SearchAPIImpl.fullRequest(query: "q", Rees46.SearchFullRequest()), "").get())
    }

    func test_counters_the_answer_does_not_have_are_zero_as_the_released_model_reads_them() throws {
        let counters = try value(ProductsAPIImpl.countersRequest(itemId: "37"), #"{"daily": {"view": "4"}, "now": [], "triggers": {}}"#).get()
        XCTAssertEqual(counters.daily?.view, 4)
        XCTAssertEqual(counters.daily?.cart, 0)
        XCTAssertNil(counters.now, "not an object")
        XCTAssertEqual(counters.triggers?.priceDrop, 0)
    }

    func test_an_answer_that_is_not_an_object_is_decoding() throws {
        XCTAssertEqual(value(try ProductsAPIImpl.infoRequest(itemId: "37"), "[]"), .failure(.decoding))
        XCTAssertEqual(value(try RecommendationsAPIImpl.blockRequest(code: "b", Rees46.RecommendationRequest()), #""paused""#), .failure(.decoding))
        XCTAssertEqual(value(SearchAPIImpl.blankRequest, "[1]"), .failure(.decoding))
    }

    func test_a_product_reads_whatever_shape_its_fields_come_in() throws {
        let read = try value(ProductsAPIImpl.infoRequest(itemId: "37"), """
        {"id": 37, "name": 5, "url": "", "price": "12.5", "currency": "", "brand": "",
         "discount": "12", "is_new": "1", "rating": 4.5, "categories": {"id": "1"},
         "params": [{"values": ["x"]}, {"key": "k"}, 7], "image_url_resized": {"120": 120, "x": {"a": 1}},
         "category_ids": ["1", null, "", 2.0, true]}
        """).get()
        let product = try XCTUnwrap(read)
        XCTAssertEqual(product.id, "37", "a number is its digits")
        XCTAssertEqual(product.name, "5")
        XCTAssertEqual(product.url, "", "an empty required text is a value")
        XCTAssertEqual(product.price, 12.5)
        XCTAssertEqual(product.currency, "")
        XCTAssertNil(product.brand, "an empty optional text is none")
        XCTAssertEqual(product.discountPercent, 12, "discount as a number when there is no discount_percent")
        XCTAssertTrue(product.isNew)
        XCTAssertNil(product.rating, "not an integer")
        XCTAssertNil(product.categories, "not a list")
        XCTAssertEqual(product.params, [Rees46.ProductParam(key: "k", values: [])], "a parameter without a key is left out")
        XCTAssertEqual(product.resizedImages, ["120": "120"])
        XCTAssertEqual(product.categoryIds, ["1", "2"])
    }

    func test_a_product_without_a_field_every_product_has_is_left_out() throws {
        let fields = [#""id": "1""#, #""name": "a""#, #""url": "u""#, #""price": 1"#, #""currency": "c""#]
        for (index, name) in ["id", "name", "url", "price", "currency"].enumerated() {
            var rest = fields
            rest.remove(at: index)
            let partial = "{" + rest.joined(separator: ", ") + "}"
            let whole = "{" + fields.joined(separator: ", ") + "}"
            let list = try value(ProductsAPIImpl.listRequest(Rees46.ProductsListRequest()), #"{"products": ["# + whole + ", " + partial + "]}").get()
            XCTAssertEqual(list.products.count, 1, name)
            XCTAssertEqual(value(try ProductsAPIImpl.infoRequest(itemId: "1"), partial).failure, .decoding, "the card without \(name)")
        }
        let priceless = try value(ProductsAPIImpl.listRequest(Rees46.ProductsListRequest()), #"{"products": [{"id": "1", "name": "a", "url": "u", "price": "free", "currency": "c"}]}"#).get()
        XCTAssertEqual(priceless.products, [], "a price that is not a number")
    }

    func test_a_listing_reads_brands_filters_and_prices_leniently() throws {
        let list = try value(ProductsAPIImpl.listRequest(Rees46.ProductsListRequest()), """
        {"products": [], "brands": [{"name": "A", "count": "2"}, {"name": "B"}], "filters": {"a": {"values": {"x": "2", "y": "many"}}, "b": 3},
         "locations": [{"id": "1", "name": "M"}, {"id": "2"}], "price_range": {"min": 1},
         "price_ranges": [{"from": "1", "to": "2", "count": "3"}, {"to": 5}], "price_median": "7.5"}
        """).get()
        XCTAssertEqual(list.brands, [Rees46.Brand(name: "A", count: 2)], "a brand without a count is left out")
        XCTAssertEqual(list.locations?.map(\.id), ["1"], "a location without a name is left out")
        XCTAssertEqual(list.filters?["a"]?.values, ["x": 2])
        XCTAssertNil(list.filters?["b"], "not a facet")
        XCTAssertNil(list.priceRange, "a range without its max is none")
        XCTAssertEqual(list.priceRanges, [Rees46.PriceInterval(from: 1, to: 2, count: 3), Rees46.PriceInterval(from: 0, to: 5, count: nil)])
        XCTAssertEqual(list.priceMedian, 7.5)
        let empty = try value(ProductsAPIImpl.listRequest(Rees46.ProductsListRequest()), #"{"products": [], "filters": [], "brands": {}}"#).get()
        XCTAssertEqual(empty.filters, [:], "an empty list is the server's empty object")
        XCTAssertNil(empty.brands)
    }

    func test_recommendations_by_what_recommends_holds() throws {
        let objects = #"{"recommends": [{"id": "1", "name": "a", "url": "u", "price": 1, "currency": "c"}]}"#
        let ids = #"{"recommends": ["1", 2, ""]}"#
        let request = { try RecommendationsAPIImpl.blockRequest(code: "b", Rees46.RecommendationRequest()) }
        XCTAssertEqual(try value(request(), objects).get().itemIds, ["1"])
        XCTAssertEqual(try value(request(), ids).get().itemIds, ["1", "2"])
        XCTAssertEqual(try value(request(), ids).get().products, [])
        XCTAssertEqual(try value(request(), #"{"state": "paused", "recommends": "x"}"#).get().products, [], "on pause")
        XCTAssertEqual(value(try request(), #"{"recommends": null}"#).failure, .decoding, "neither a list nor on pause")
        XCTAssertEqual(value(try request(), #"{"state": "test"}"#).failure, .decoding)
    }

    func test_numbers_go_without_a_needless_fraction() {
        XCTAssertEqual(CatalogQuery.number(100), "100")
        XCTAssertEqual(CatalogQuery.number(100.0), "100")
        XCTAssertEqual(CatalogQuery.number(999.5), "999.5")
        XCTAssertEqual(CatalogQuery.number(0.1), "0.1")
        XCTAssertEqual(CatalogQuery.number(-0.0), "0")
    }

    func test_a_segment_of_a_path_is_percent_encoded_slashes_and_letters_of_any_script_included() {
        XCTAssertEqual(CatalogQuery.pathSegment("block-1_a.b~c"), "block-1_a.b~c")
        XCTAssertEqual(CatalogQuery.pathSegment("a/b c?d#e"), "a%2Fb%20c%3Fd%23e")
        XCTAssertEqual(CatalogQuery.pathSegment("й"), "%D0%B9")
        XCTAssertEqual(CatalogQuery.pathSegment("a+b"), "a%2Bb")
    }

    func test_prices_must_be_finite() {
        XCTAssertThrowsError(try ProductsAPIImpl.listRequest(Rees46.ProductsListRequest(priceMin: .nan)))
        XCTAssertThrowsError(try ProductsAPIImpl.listRequest(Rees46.ProductsListRequest(priceMax: .infinity)))
        XCTAssertNoThrow(try ProductsAPIImpl.listRequest(Rees46.ProductsListRequest(priceMin: 0, priceMax: 0)))
    }

    func test_filters_go_as_json_with_sorted_keys_and_plain_slashes() throws {
        let request = try ProductsAPIImpl.listRequest(Rees46.ProductsListRequest(filters: ["b": ["1/2"], "a": ["x", "y"]]))
        XCTAssertEqual(request.query["filters"], #"{"a":["x","y"],"b":["1/2"]}"#)
    }

    func test_a_sort_key_the_server_added_goes_as_it_is() throws {
        let request = try ProductsAPIImpl.listRequest(Rees46.ProductsListRequest(sortBy: Rees46.SortBy(rawValue: "popular")))
        XCTAssertEqual(request.query["sort_by"], "popular")
        XCTAssertEqual(try SearchAPIImpl.fullRequest(query: "q", Rees46.SearchFullRequest(sortBy: .relevance)).query["sort_by"], "relevance")
    }
}

private extension Result {

    var failure: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
