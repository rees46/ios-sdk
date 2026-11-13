//
//  SearchRequestTests.swift
//  REES46Tests
//
//  The search filters as the server reads them: lists split on "," without trimming, merchants
//  filtered inside the given locations, brands excluded under `excluded_brands`.
//

import XCTest
@testable import REES46

final class SearchRequestTests: XCTestCase {

    private var shopId = ""

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        shopId = StubSDK.shopId()
    }

    override func tearDown() {
        StubURLProtocol.uninstall()
        StubSDK.removeSavedInit(shopId: shopId)
        super.tearDown()
    }

    private func initializedSDK() -> SimplePersonalizationSDK {
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: shopId) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)
        return sdk
    }

    private func searchQuery(_ sdk: SimplePersonalizationSDK, _ text: String) -> [String: String] {
        StubURLProtocol.requests(to: "/search", shop: sdk.shopId).first { $0.query["search_query"] == text }?.query ?? [:]
    }

    func test_full_search_excludes_brands_under_the_name_the_server_reads() {
        let sdk = initializedSDK()
        let answered = expectation(description: "answered")
        sdk.search(query: "dress", excludedBrands: ["dior", "estee lauder"]) { _ in answered.fulfill() }
        wait(for: [answered], timeout: 5)

        let query = searchQuery(sdk, "dress")
        XCTAssertEqual(query["excluded_brands"], "dior,estee lauder")
        XCTAssertNil(query["exclude_brands"])
    }

    func test_full_search_sends_excluded_merchants_with_locations_joined_without_spaces() {
        let sdk = initializedSDK()
        let answered = expectation(description: "answered")
        answered.expectedFulfillmentCount = 2
        sdk.search(query: "with", locations: "10", excludedMerchants: ["m1", "m2"]) { _ in answered.fulfill() }
        sdk.search(query: "without", excludedMerchants: ["m1", "m2"]) { _ in answered.fulfill() }
        wait(for: [answered], timeout: 5)

        XCTAssertEqual(searchQuery(sdk, "with")["excluded_merchants"], "m1,m2")
        XCTAssertNil(searchQuery(sdk, "without")["excluded_merchants"])
    }

    func test_excluded_merchants_do_not_go_with_blank_locations() {
        XCTAssertNil(SearchFilterParams.excludedMerchants(["m1"], locations: " "))
        XCTAssertNil(SearchFilterParams.excludedMerchants(["m1"], locations: nil))
        XCTAssertEqual(SearchFilterParams.excludedMerchants(["m1", "m2"], locations: "10"), "m1,m2")
    }

    func test_instant_search_joins_excluded_brands_and_merchants_without_spaces() {
        let sdk = initializedSDK()
        let answered = expectation(description: "answered")
        sdk.suggest(query: "bag", locations: "10", excludedMerchants: ["m1", "m2"], excludedBrands: ["b1", "b2"]) { _ in
            answered.fulfill()
        }
        wait(for: [answered], timeout: 5)

        let query = searchQuery(sdk, "bag")
        XCTAssertEqual(query["excluded_merchants"], "m1,m2")
        XCTAssertEqual(query["excluded_brands"], "b1,b2")
    }

    func test_a_blank_search_without_last_products_has_none() {
        // The server sends `last_products` only when it is true.
        XCTAssertFalse(SearchBlankResponse(json: ["suggests": []]).lastProducts)
        XCTAssertTrue(SearchBlankResponse(json: ["last_products": true]).lastProducts)
    }
}
