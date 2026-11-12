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
        XCTAssertEqual(StubURLProtocol.requests(to: "/recommend/block-1").first?.timeout, 7)
        XCTAssertEqual(StubURLProtocol.requests(to: "/products/get").first?.timeout, 1)
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
        XCTAssertEqual(StubURLProtocol.requests(to: "/search").first?.timeout, 3)
        XCTAssertEqual(StubURLProtocol.requests(to: "/search/blank").first?.timeout, 1)
        XCTAssertEqual(StubURLProtocol.requests(to: "/profile/set").first?.timeout, 1)
    }

    func test_a_request_without_a_timeout_of_its_own_gets_the_default_one() {
        let sdk = initializedSDK()
        sdk.recommend(blockId: "block-1", timeOut: 7) { _ in }

        let answered = expectation(description: "answered")
        sdk.tracking.custom(event: "event-1") { _ in answered.fulfill() }
        wait(for: [answered], timeout: 5)

        XCTAssertEqual(StubURLProtocol.requests(to: "/push/custom").first?.timeout, 10)
    }
}
