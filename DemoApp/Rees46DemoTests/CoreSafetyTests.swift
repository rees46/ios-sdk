//
//  CoreSafetyTests.swift
//  REES46Tests
//
//  App data the SDK cannot write as JSON fails the call instead of crashing the app, and the network
//  monitor never leaves a reader waiting.
//

import XCTest
@testable import REES46

final class CoreSafetyTests: XCTestCase {

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

    func test_safe_json_writes_json_and_refuses_what_is_not() {
        XCTAssertNotNil(SafeJSON.data(["a": 1, "b": ["c": "d"]]))
        XCTAssertNil(SafeJSON.data(["date": Date()]))
        XCTAssertNil(SafeJSON.data(["nan": Double.nan]))
        XCTAssertNil(SafeJSON.data(["object": NSObject()]))
        XCTAssertNil(SafeJSON.data("not a container"))
    }

    func test_a_post_with_parameters_that_are_not_json_fails_and_sends_nothing() {
        let sdk = initializedSDK()
        let done = expectation(description: "done")
        var outcome: Result<[String: Any], SdkError>?
        sdk.postRequest(path: "push/custom", params: ["event": "e", "when": Date()]) { result in
            outcome = result
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        guard case let .failure(.custom(message))? = outcome else {
            return XCTFail("expected a failure, got \(String(describing: outcome))")
        }
        XCTAssertTrue(message.contains("not valid JSON"), message)
        XCTAssertTrue(StubURLProtocol.requests(to: "/push/custom", shop: shopId).isEmpty)
    }

    func test_custom_fields_that_are_not_json_fail_the_event() {
        let sdk = initializedSDK()
        let done = expectation(description: "done")
        var outcome: Result<Void, SdkError>?
        sdk.trackEvent(event: "e", time: nil, category: nil, label: nil, value: nil, customFields: ["when": Date()]) { result in
            outcome = result
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        guard case .failure? = outcome else { return XCTFail("expected a failure") }
        XCTAssertTrue(StubURLProtocol.requests(to: "/push/custom", shop: shopId).isEmpty)
    }

    func test_search_filters_that_are_not_json_are_left_out() {
        let sdk = initializedSDK()
        let done = expectation(description: "done")
        sdk.search(query: "dress", filters: ["when": Date()]) { _ in done.fulfill() }
        wait(for: [done], timeout: 5)

        let query = StubURLProtocol.requests(to: "/search", shop: shopId).first?.query ?? [:]
        XCTAssertEqual(query["search_query"], "dress")
        XCTAssertNil(query["filters"])
    }

    func test_a_cellular_path_without_a_radio_is_still_a_cellular_connection() {
        XCTAssertEqual(NetworkStatus.cellularType(currentRadio: nil), .cellular(radioType: .notdeterminedcellular))
    }

    func test_the_network_monitor_answers_without_blocking() {
        let started = Date()
        _ = NetworkStatus.nManager.connectionStatus
        XCTAssertLessThan(Date().timeIntervalSince(started), 3)
    }
}
