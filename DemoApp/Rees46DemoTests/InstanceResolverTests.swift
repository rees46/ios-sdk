//
//  InstanceResolverTests.swift
//  REES46Tests
//
//  Covers the resolution rules behind the future `Rees46.instance(for:)` (R3). Pure logic — no SDK
//  construction — so every branch of the single/ambiguous/uninitialized contract is pinned here.
//  Mirror of the Android `InstanceResolverTest`.
//

import XCTest
@testable import REES46

final class InstanceResolverTests: XCTestCase {

    private func resolve(_ requested: String?, live: Set<String>, pending: Set<String>) -> InstanceResolution {
        InstanceResolver.resolve(requestedShopId: requested, liveShopIds: live, pendingShopIds: pending)
    }

    func test_requested_shop_with_a_live_instance_resolves_to_existing() {
        XCTAssertEqual(resolve("shop-a", live: ["shop-a"], pending: []), .existing("shop-a"))
    }

    func test_requested_shop_that_is_only_registered_resolves_to_pending() {
        XCTAssertEqual(resolve("shop-a", live: [], pending: ["shop-a"]), .pending("shop-a"))
    }

    func test_a_live_registration_wins_over_a_stale_pending_one_for_the_same_shop() {
        XCTAssertEqual(resolve("shop-a", live: ["shop-a"], pending: ["shop-a"]), .existing("shop-a"))
    }

    func test_requested_shop_that_is_unknown_resolves_to_notRegistered() {
        XCTAssertEqual(resolve("shop-x", live: ["shop-a"], pending: ["shop-b"]), .notRegistered)
    }

    func test_no_shopId_and_nothing_registered_resolves_to_notRegistered() {
        XCTAssertEqual(resolve(nil, live: [], pending: []), .notRegistered)
    }

    func test_no_shopId_and_exactly_one_live_shop_resolves_to_that_existing() {
        XCTAssertEqual(resolve(nil, live: ["shop-a"], pending: []), .existing("shop-a"))
    }

    func test_no_shopId_and_exactly_one_pending_shop_resolves_to_that_pending() {
        XCTAssertEqual(resolve(nil, live: [], pending: ["shop-a"]), .pending("shop-a"))
    }

    func test_no_shopId_and_more_than_one_shop_resolves_to_ambiguous() {
        XCTAssertEqual(resolve(nil, live: ["shop-a"], pending: ["shop-b"]), .ambiguous)
    }

    func test_no_shopId_and_two_live_shops_resolves_to_ambiguous() {
        XCTAssertEqual(resolve(nil, live: ["shop-a", "shop-b"], pending: []), .ambiguous)
    }
}
