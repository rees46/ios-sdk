//
//  HandlePushRoutingTests.swift
//  REES46Tests
//
//  Covers `Rees46.handlePush` (R4 / iOS-15): a push is tracked against the instance its `shop_id`
//  names, and is dropped rather than mis-tracked when the shop is unknown or the target is ambiguous.
//  Mirror of the Android push-routing tests. Uses `FakeSDK`, which records its notification-track
//  calls, so routing is asserted without any network. The registry holds instances weakly, so each
//  fake is bound to a retained local.
//

import XCTest
@testable import REES46

final class HandlePushRoutingTests: XCTestCase {

    private var registry: SdkRegistry { SdkRegistry.shared }
    private var retained: [FakeSDK] = []

    override func setUp() {
        super.setUp()
        Rees46.reset()
        registry.reset()
    }

    override func tearDown() {
        Rees46.reset()
        registry.reset()
        retained.removeAll()
        super.tearDown()
    }

    @discardableResult
    private func live(_ shopId: String) -> FakeSDK {
        let sdk = FakeSDK(shopId: shopId)
        retained.append(sdk)
        registry.register(shopId: shopId, sdk: sdk)
        return sdk
    }

    private func payload(shopId: String?, type: String = "web", code: String = "c1") -> [AnyHashable: Any] {
        var p: [AnyHashable: Any] = ["type": type, "id": code]
        if let shopId = shopId { p["shop_id"] = shopId }
        return p
    }

    func test_clicked_is_tracked_against_the_shop_named_in_the_payload() {
        let a = live("shop-a")
        let b = live("shop-b")

        Rees46.handlePush(payload(shopId: "shop-a", type: "product", code: "p1"), event: .clicked)

        XCTAssertEqual(a.clickedTracks.count, 1)
        XCTAssertEqual(a.clickedTracks.first?.type, "product")
        XCTAssertEqual(a.clickedTracks.first?.code, "p1")
        XCTAssertTrue(b.clickedTracks.isEmpty, "the other shop must not be tracked")
    }

    func test_received_is_tracked_against_the_shop_named_in_the_payload() {
        let a = live("shop-a")
        let b = live("shop-b")

        Rees46.handlePush(payload(shopId: "shop-b", type: "category", code: "c9"), event: .received)

        XCTAssertEqual(b.receivedTracks.map { $0.code }, ["c9"])
        XCTAssertTrue(a.receivedTracks.isEmpty)
    }

    func test_an_unknown_shop_id_drops_the_push() {
        let a = live("shop-a")

        Rees46.handlePush(payload(shopId: "shop-x"), event: .clicked)

        XCTAssertTrue(a.clickedTracks.isEmpty, "a push for an unknown shop must not fall through to a live one")
    }

    func test_no_shop_id_with_a_single_instance_still_delivers() {
        let a = live("shop-a")

        Rees46.handlePush(payload(shopId: nil, code: "solo"), event: .clicked)

        XCTAssertEqual(a.clickedTracks.map { $0.code }, ["solo"])
    }

    func test_no_shop_id_with_several_instances_drops_the_push() {
        let a = live("shop-a")
        let b = live("shop-b")

        Rees46.handlePush(payload(shopId: nil), event: .clicked)

        XCTAssertTrue(a.clickedTracks.isEmpty)
        XCTAssertTrue(b.clickedTracks.isEmpty)
    }

    func test_a_non_sdk_push_is_ignored_even_for_a_valid_shop() {
        let a = live("shop-a")

        Rees46.handlePush(["shop_id": "shop-a", "title": "Hi"], event: .received)

        XCTAssertTrue(a.receivedTracks.isEmpty, "a payload without type/code is not an SDK push")
    }
}
