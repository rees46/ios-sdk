//
//  RequestTimeoutTests.swift
//  REES46Tests
//
//  Calls run side by side on the session queue: each keeps its own timeout, and none swaps the
//  session the others are sending through.
//

import XCTest
@testable import REES46

final class RequestTimeoutTests: XCTestCase {

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

    func test_a_call_keeps_its_own_timeout_and_leaves_the_shared_session_alone() {
        let sdk = initializedSDK()
        let session = sdk.urlSession

        let answered = expectation(description: "answered")
        answered.expectedFulfillmentCount = 2
        sdk.recommend(blockId: "block-1", timeOut: 7) { _ in answered.fulfill() }
        sdk.getProductInfo(id: "item-1") { _ in answered.fulfill() }
        wait(for: [answered], timeout: 5)

        XCTAssertTrue(sdk.urlSession === session, "a call swapped the session every request goes through")
        XCTAssertEqual(StubURLProtocol.requests(to: "/recommend/block-1", shop: sdk.shopId).first?.timeout, 7)
        XCTAssertEqual(StubURLProtocol.requests(to: "/products/get", shop: sdk.shopId).first?.timeout, 10)
    }

    func test_the_services_give_their_timeouts_to_their_requests_and_leave_the_session_alone() {
        let sdk = initializedSDK()
        let session = sdk.urlSession

        let answered = expectation(description: "answered")
        answered.expectedFulfillmentCount = 3
        sdk.search(query: "shoes", timeOut: 3) { _ in answered.fulfill() }
        sdk.searchBlank { _ in answered.fulfill() }
        sdk.setProfileData(userEmail: "buyer@example.com") { _ in answered.fulfill() }
        wait(for: [answered], timeout: 5)

        XCTAssertTrue(sdk.urlSession === session, "a service swapped the session every request goes through")
        XCTAssertEqual(StubURLProtocol.requests(to: "/search", shop: sdk.shopId).first?.timeout, 3)
        XCTAssertEqual(StubURLProtocol.requests(to: "/search/blank", shop: sdk.shopId).first?.timeout, 10)
        XCTAssertEqual(StubURLProtocol.requests(to: "/profile/set", shop: sdk.shopId).first?.timeout, 10)
    }

    func test_a_request_without_a_timeout_of_its_own_gets_the_default_one() {
        let sdk = initializedSDK()
        sdk.recommend(blockId: "block-1", timeOut: 7) { _ in }

        let answered = expectation(description: "answered")
        sdk.tracking.custom(event: "event-1") { _ in answered.fulfill() }
        wait(for: [answered], timeout: 5)

        XCTAssertEqual(StubURLProtocol.requests(to: "/push/custom", shop: sdk.shopId).first?.timeout, 10)
    }

    func test_init_waits_five_seconds_as_the_server_does() {
        let sdk = initializedSDK()
        XCTAssertEqual(StubURLProtocol.requests(to: "/init", shop: sdk.shopId).first?.timeout, 5)
    }

    func test_no_call_gives_up_after_one_second() {
        let sdk = initializedSDK()
        let answered = expectation(description: "answered")
        answered.expectedFulfillmentCount = 9
        sdk.getProductsList(brands: nil, merchants: nil, categories: nil, locations: nil, limit: nil, page: nil, filters: nil) { _ in answered.fulfill() }
        sdk.getProductsFromCart { _ in answered.fulfill() }
        sdk.getProfile { _ in answered.fulfill() }
        sdk.getProductCounters(item: "item-1") { _ in answered.fulfill() }
        sdk.suggest(query: "shoes") { _ in answered.fulfill() }
        sdk.search(query: "shoes") { _ in answered.fulfill() }
        sdk.recommend(blockId: "block-1") { _ in answered.fulfill() }
        sdk.joinLoyalty(phone: "+79990001122", email: nil, firstName: nil, lastName: nil) { _ in answered.fulfill() }
        sdk.setPushTokenNotification(token: "token-1") { _ in answered.fulfill() }
        wait(for: [answered], timeout: 5)

        let shop = StubURLProtocol.requests.filter { ($0.query["shop_id"] ?? $0.body["shop_id"] as? String) == sdk.shopId }
        let short = shop.filter { $0.path != "/init" && $0.timeout < SimplePersonalizationSDK.defaultRequestTimeout }
        XCTAssertTrue(short.isEmpty, "requests with a short timeout: \(short.map { "\($0.path) \($0.timeout)" })")
        XCTAssertGreaterThanOrEqual(shop.count, 10)
    }
}
