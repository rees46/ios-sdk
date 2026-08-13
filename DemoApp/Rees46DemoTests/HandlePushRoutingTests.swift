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

    func test_delivered_is_tracked_against_the_shop_named_in_the_payload() {
        let a = live("shop-a")
        let b = live("shop-b")

        Rees46.handlePush(payload(shopId: "shop-a", type: "web", code: "d1"), event: .delivered)

        XCTAssertEqual(a.deliveredTracks.map { $0.code }, ["d1"])
        XCTAssertTrue(b.deliveredTracks.isEmpty, "the other shop must not be tracked")
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

    // MARK: - Pending (registered-but-not-initialized) shops

    // A pending shop has no instance, so `handlePush` tracks it standalone (no construction/init). The
    // real tracker POSTs over the network; swap in a recorder so the pending path is asserted offline
    // — this pins parity with Android (materializeForPush) and RN (standalone trackPush): a push for a
    // registered shop is NOT dropped just because the shop is not live yet.
    private struct PendingTrack: Equatable {
        let shopId: String
        let event: String
        let type: String
        let code: String
    }

    private func recordPendingTracks(into sink: @escaping (PendingTrack) -> Void) {
        Rees46.pendingPushTracker = { shopId, _, event, type, code in
            let name: String
            switch event {
            case .delivered: name = "delivered"
            case .received: name = "received"
            case .clicked: name = "clicked"
            }
            sink(PendingTrack(shopId: shopId, event: name, type: type, code: code))
        }
    }

    func test_a_push_for_a_registered_but_pending_shop_is_tracked_without_initializing_it() {
        Rees46.register(shops: [Rees46Config(shopId: "shop-lazy")]) // pending, not initialized
        var tracks: [PendingTrack] = []
        recordPendingTracks { tracks.append($0) }

        Rees46.handlePush(payload(shopId: "shop-lazy", type: "product", code: "p9"), event: .delivered)

        XCTAssertEqual(
            tracks,
            [PendingTrack(shopId: "shop-lazy", event: "delivered", type: "product", code: "p9")]
        )
        XCTAssertNil(registry.byShopId("shop-lazy"), "a push must NOT construct/register the shop")
        XCTAssertTrue(Rees46.pendingShopIds().contains("shop-lazy"), "the shop stays pending after a push")
    }

    func test_a_clicked_push_for_a_pending_shop_is_tracked_standalone() {
        Rees46.register(shops: [Rees46Config(shopId: "shop-lazy")])
        var tracks: [PendingTrack] = []
        recordPendingTracks { tracks.append($0) }

        Rees46.handlePush(payload(shopId: "shop-lazy", type: "web", code: "c3"), event: .clicked)

        XCTAssertEqual(tracks.map { $0.event }, ["clicked"])
        XCTAssertEqual(tracks.first?.code, "c3")
    }

    func test_no_shop_id_with_a_single_pending_shop_falls_back_to_it() {
        Rees46.register(shops: [Rees46Config(shopId: "shop-lazy")])
        var tracks: [PendingTrack] = []
        recordPendingTracks { tracks.append($0) }

        Rees46.handlePush(payload(shopId: nil, code: "solo"), event: .delivered)

        XCTAssertEqual(tracks.map { $0.shopId }, ["shop-lazy"])
    }

    func test_a_pending_shop_push_without_type_or_code_is_ignored() {
        Rees46.register(shops: [Rees46Config(shopId: "shop-lazy")])
        var tracks: [PendingTrack] = []
        recordPendingTracks { tracks.append($0) }

        Rees46.handlePush(["shop_id": "shop-lazy", "title": "Hi"], event: .delivered) // no type/code

        XCTAssertTrue(tracks.isEmpty, "a payload without type/code is not an SDK push")
    }

    func test_no_shop_id_with_one_live_and_one_pending_shop_is_ambiguous_and_dropped() {
        let a = live("shop-a")
        Rees46.register(shops: [Rees46Config(shopId: "shop-lazy")])
        var tracks: [PendingTrack] = []
        recordPendingTracks { tracks.append($0) }

        Rees46.handlePush(payload(shopId: nil), event: .delivered)

        XCTAssertTrue(tracks.isEmpty, "a pending shop counts toward ambiguity — no-shop_id must drop")
        XCTAssertTrue(a.deliveredTracks.isEmpty)
    }
}
