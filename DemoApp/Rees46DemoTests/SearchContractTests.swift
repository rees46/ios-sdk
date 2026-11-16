//
//  SearchContractTests.swift
//  REES46Tests
//
//  The search against the API documentation (rees46.ru/help/integration): the full search
//  (search/full/api) and the instant one (search/instant/api), both `GET /search`. The full search's
//  answer is a recorded one (`Fixtures/api_search_full.json`); the blank search (`GET /search/blank`)
//  has no answer in the documentation, so only the fields its widget reads are pinned.
//

import XCTest
@testable import REES46

final class SearchContractTests: ContractTestCase {

    // MARK: - Full search

    func test_the_full_search_sends_the_documented_parameters() {
        onBothCores { sdk in
            _ = outcome {
                sdk.search(
                    query: "kettle", limit: 10, offset: nil, categoryLimit: nil, brandLimit: 5,
                    categories: [1, 2, 3], extended: "true", sortBy: "price", sortDir: nil,
                    locations: "msk,spb", excludedMerchants: ["m1", "m2"], excludedBrands: ["b1"], brands: "tefal",
                    filters: nil, priceMin: 100, priceMax: 500, colors: ["red", "blue"], fashionSizes: ["42"],
                    exclude: "a1,a2", email: "buyer@example.com", timeOut: nil, disableClarification: true,
                    completion: $0
                )
            }

            let query = StubURLProtocol.requests(to: "/search", shop: sdk.shopId).last { $0.query["search_query"] == "kettle" }?.query ?? [:]
            XCTAssertEqual(query["type"], "full_search")
            XCTAssertEqual(query["shop_id"], sdk.shopId)
            XCTAssertEqual(query["did"], "stub-did")
            XCTAssertEqual(query["sid"], sdk.getSession())
            XCTAssertEqual(query["email"], "buyer@example.com")
            XCTAssertEqual(query["categories"], "1,2,3")
            XCTAssertEqual(query["locations"], "msk,spb")
            XCTAssertEqual(query["brands"], "tefal")
            XCTAssertEqual(query["excluded_brands"], "b1")
            XCTAssertEqual(query["excluded_merchants"], "m1,m2")
            XCTAssertEqual(query["sort_by"], "price")
            XCTAssertEqual(query["price_min"].flatMap { Double($0) }, 100)
            XCTAssertEqual(query["price_max"].flatMap { Double($0) }, 500)
            XCTAssertEqual(query["colors"], "red,blue")
            XCTAssertEqual(query["fashion_sizes"], "42")
            XCTAssertEqual(query["exclude"], "a1,a2")
            XCTAssertEqual(query["extended"], "true")
            XCTAssertEqual(query["brand_limit"], "5")
            XCTAssertEqual(query["limit"], "10")
            XCTAssertTrue(["1", "true"].contains(query["no_clarification"] ?? ""), "no_clarification: \(query["no_clarification"] ?? "nil")")
        }
    }

    func test_a_full_search_with_the_query_alone_sends_no_empty_filters() {
        onBothCores { sdk in
            _ = outcome {
                sdk.search(
                    query: "minimal", limit: nil, offset: nil, categoryLimit: nil, brandLimit: nil, categories: nil,
                    extended: nil, sortBy: nil, sortDir: nil, locations: nil, excludedMerchants: nil, excludedBrands: nil,
                    brands: nil, filters: nil, priceMin: nil, priceMax: nil, colors: nil, fashionSizes: nil, exclude: nil,
                    email: nil, timeOut: nil, disableClarification: nil, completion: $0
                )
            }

            let query = StubURLProtocol.requests(to: "/search", shop: sdk.shopId).last { $0.query["search_query"] == "minimal" }?.query ?? [:]
            XCTAssertEqual(query["type"], "full_search")
            for key in ["categories", "locations", "brands", "excluded_brands", "excluded_merchants", "sort_by", "price_min", "price_max", "exclude", "limit", "no_clarification"] {
                XCTAssertTrue((query[key] ?? "").isEmpty, "\(key) = \(query[key] ?? "")")
            }
        }
    }

    func test_the_full_search_takes_a_recorded_answer_whole() throws {
        let recorded = ApiFixtures.json("search_full")
        let data = try JSONSerialization.data(withJSONObject: recorded)
        let recordedProducts = recorded["products"] as? [[String: Any]] ?? []

        onBothCores { sdk in
            answer("/search", json: String(decoding: data, as: UTF8.self))

            let response = success(outcome {
                sdk.search(
                    query: "kettle", limit: nil, offset: nil, categoryLimit: nil, brandLimit: nil, categories: nil,
                    extended: "true", sortBy: nil, sortDir: nil, locations: nil, excludedMerchants: nil, excludedBrands: nil,
                    brands: nil, filters: nil, priceMin: nil, priceMax: nil, colors: nil, fashionSizes: nil, exclude: nil,
                    email: nil, timeOut: nil, disableClarification: nil, completion: $0
                )
            })

            XCTAssertEqual(response?.productsTotal, recorded["products_total"] as? Int)
            XCTAssertEqual(response?.products.map(\.id), recordedProducts.compactMap { $0["id"] as? String })
            XCTAssertEqual(response?.products.first?.name, recordedProducts.first?["name"] as? String)
        }
    }

    // MARK: - Instant search

    /// The instant search's answer as the documentation shows it, cut to one product.
    private let instantAnswer = """
    {"search_query": "iphon", "search_query_original": "iphon", "collections": [], "products_total": 348,
     "clarification": true, "requests_count": 1,
     "products": [{"name": "Чайник Tefal Thermo Protect KO-140AE0", "url": "https://demo.r46.dev/product/286429",
       "brand": "Tefal", "picture": "https://pictures.rees46.ru/resize-images/180/16041.jpg",
       "price_formatted": "19 990 ₽", "price": 19990, "price_full": 19990, "oldprice": 29990,
       "currency": "₽", "_id": "16041", "id": "286429"}]}
    """

    func test_the_instant_search_sends_the_documented_parameters_and_reads_the_documented_answer() {
        onBothCores { sdk in
            answer("/search", json: instantAnswer)

            let response = success(outcome {
                sdk.suggest(query: "iphon", locations: "msk", excludedMerchants: ["m1", "m2"], excludedBrands: ["dior", "estee lauder"], timeOut: nil, extended: nil, completion: $0)
            })

            let query = StubURLProtocol.requests(to: "/search", shop: sdk.shopId).last { $0.query["search_query"] == "iphon" }?.query ?? [:]
            XCTAssertEqual(query["type"], "instant_search")
            XCTAssertEqual(query["shop_id"], sdk.shopId)
            XCTAssertEqual(query["did"], "stub-did")
            XCTAssertEqual(query["sid"], sdk.getSession())
            XCTAssertEqual(query["locations"], "msk")
            XCTAssertEqual(query["excluded_merchants"], "m1,m2")
            XCTAssertEqual(query["excluded_brands"], "dior,estee lauder")
            XCTAssertEqual(response?.productsTotal, 348)
            XCTAssertEqual(response?.products.first?.id, "286429")
            XCTAssertEqual(response?.products.first?.name, "Чайник Tefal Thermo Protect KO-140AE0")
            XCTAssertEqual(response?.products.first?.brand, "Tefal")
            XCTAssertEqual(response?.products.first?.price, 19990)
            XCTAssertEqual(response?.products.first?.currency, "₽")
        }
    }

    // MARK: - Blank search

    func test_the_blank_search_is_read_for_the_device_with_its_popular_items() {
        onBothCores { sdk in
            answer("/search/blank", json: """
            {"last_queries": [], "suggests": [], "last_products": false, "products": [],
             "popular_links": [{"name": "Sale", "url": "https://shop.test/sale"}],
             "popular_categories": [{"name": "Kettles", "url": "https://shop.test/c/kettles"}],
             "popular_brands": [{"name": "Tefal", "url": "https://shop.test/b/tefal"}]}
            """)

            let blank = success(outcome { sdk.searchBlank(completion: $0) })

            let sent = request(sdk, "/search/blank")
            XCTAssertEqual(sent?.method, "GET")
            XCTAssertEqual(sent?.query["shop_id"], sdk.shopId)
            XCTAssertEqual(sent?.query["did"], "stub-did")
            XCTAssertEqual(blank?.popularLinks.map(\.name), ["Sale"])
            XCTAssertEqual(blank?.popularLinks.map(\.url), ["https://shop.test/sale"])
            XCTAssertEqual(blank?.popularCategories.map(\.name), ["Kettles"])
            XCTAssertEqual(blank?.popularBrands.map(\.url), ["https://shop.test/b/tefal"])
        }
    }
}
