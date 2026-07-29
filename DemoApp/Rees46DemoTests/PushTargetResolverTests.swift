//
//  PushTargetResolverTests.swift
//  REES46Tests
//
//  Covers push routing (R4): which shop a push belongs to. Pure logic — mirror of the routing rules
//  pinned on Android in `PushRoutingTest`.
//

import XCTest
@testable import REES46

final class PushTargetResolverTests: XCTestCase {

    private func resolve(_ payloadShopId: String?, live: Set<String>) -> String? {
        PushTargetResolver.resolve(payloadShopId: payloadShopId, liveShopIds: live)
    }

    func test_payload_shopId_matching_a_live_shop_routes_to_it() {
        XCTAssertEqual(resolve("shop-b", live: ["shop-a", "shop-b"]), "shop-b")
    }

    func test_payload_shopId_that_names_no_live_shop_is_dropped() {
        XCTAssertNil(resolve("shop-x", live: ["shop-a", "shop-b"]))
    }

    func test_no_shopId_with_a_single_live_shop_falls_back_to_it() {
        XCTAssertEqual(resolve(nil, live: ["shop-a"]), "shop-a")
    }

    func test_no_shopId_with_several_live_shops_is_dropped() {
        XCTAssertNil(resolve(nil, live: ["shop-a", "shop-b"]))
    }

    func test_no_shopId_with_no_live_shops_is_dropped() {
        XCTAssertNil(resolve(nil, live: []))
    }

    func test_payload_shopId_matching_the_only_live_shop_routes_to_it() {
        XCTAssertEqual(resolve("shop-a", live: ["shop-a"]), "shop-a")
    }
}
