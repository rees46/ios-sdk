//
//  PushArrivalTests.swift
//  REES46Tests
//
//  What `NotificationService` tracks when a push arrives, by app state: a push that comes while the
//  app is open is delivered, not clicked; the tap that brings the app back is the click.
//

import XCTest
import UIKit
@testable import REES46

final class PushArrivalTests: XCTestCase {

    private var retained: [FakeSDK] = []

    override func setUp() {
        super.setUp()
        Rees46.reset()
        SdkRegistry.shared.reset()
    }

    override func tearDown() {
        Rees46.reset()
        SdkRegistry.shared.reset()
        retained.removeAll()
        super.tearDown()
    }

    private func live(_ shopId: String) -> FakeSDK {
        let sdk = FakeSDK(shopId: shopId)
        retained.append(sdk)
        SdkRegistry.shared.register(shopId: shopId, sdk: sdk)
        return sdk
    }

    private let push: [AnyHashable: Any] = [
        "shop_id": "shop-a", "type": "bulk", "id": "m1",
        "event": "{\"type\":\"custom\",\"uri\":\"app://nowhere\"}"
    ]

    func test_a_push_that_arrives_while_the_app_is_open_is_not_a_click() {
        let sdk = live("shop-a")
        let service = NotificationService(sdk: sdk, notificationLogger: NotificationLogger())

        service.handleArrival(push, state: .active)

        XCTAssertTrue(sdk.clickedTracks.isEmpty, "nobody tapped the push")
    }

    func test_the_tap_that_brings_the_app_back_is_a_click_with_the_mailing_type() {
        let sdk = live("shop-a")
        let service = NotificationService(sdk: sdk, notificationLogger: NotificationLogger())

        service.handleArrival(push, state: .inactive)

        XCTAssertEqual(sdk.clickedTracks.map { $0.type }, ["bulk"])
        XCTAssertEqual(sdk.clickedTracks.map { $0.code }, ["m1"])
    }

    func test_the_tap_opens_what_the_event_names_and_the_link_carries_the_mailing_type() throws {
        let sdk = live("shop-a")
        let service = NotificationService(sdk: sdk, notificationLogger: NotificationLogger())
        let actions = RecordingActions()
        service.pushActionDelegate = actions
        // APNs shape: src and event are objects.
        let json = """
        {"shop_id":"shop-a","src":{"type":"chain","id":"m2"},"event":{"type":"web","uri":"https://example.com/sale"}}
        """
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [AnyHashable: Any])

        service.handleArrival(payload, state: .inactive)

        XCTAssertEqual(sdk.clickedTracks.map { $0.type }, ["chain"])
        XCTAssertEqual(actions.web, ["https://example.com/sale?recommended_by=chain&mail_code=m2"])
    }
}

private final class RecordingActions: NotificationActionsProtocol {
    var web: [String] = []
    func openCategory(categoryId: String) {}
    func openProduct(productId: String) {}
    func openWeb(url: String) { web.append(url) }
    func openCustom(url: String) {}
}
