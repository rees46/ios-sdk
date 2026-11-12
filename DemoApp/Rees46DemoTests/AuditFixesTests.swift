//
//  AuditFixesTests.swift
//  REES46Tests
//
//  What the public API promised and did not do: the excluded merchants of instant search.
//

import XCTest
@testable import REES46

final class AuditFixesTests: XCTestCase {

    private var shopIds: [String] = []

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
    }

    override func tearDown() {
        StubURLProtocol.uninstall()
        shopIds.forEach { shopId in
            StubSDK.removeSavedInit(shopId: shopId)
            UserIdentityRepositoryImpl(shopId: shopId).clearIdentity()
            UserDefaults.standard.removeObject(forKey: "\(NotificationRegistrar.Constants.mainPushTokenLastUploadDateKey).\(shopId)")
        }
        super.tearDown()
    }

    private func newShopId() -> String {
        let shopId = StubSDK.shopId()
        shopIds.append(shopId)
        return shopId
    }

    private func initializedSDK() -> SimplePersonalizationSDK {
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: newShopId()) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)
        return sdk
    }

    // MARK: - Instant search

    func test_instant_search_sends_excluded_merchants_without_locations() {
        let sdk = initializedSDK()
        let answered = expectation(description: "answered")
        sdk.suggest(query: "shoes", excludedMerchants: ["m1", "m2"]) { _ in answered.fulfill() }
        wait(for: [answered], timeout: 5)

        let query = StubURLProtocol.requests(to: "/search").first?.query ?? [:]
        XCTAssertNotNil(query["excluded_merchants"], "excluded merchants were dropped without locations")
        XCTAssertNil(query["locations"])
    }
}
