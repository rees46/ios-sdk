//
//  PushPayloadParserTests.swift
//  REES46Tests
//
//  Covers the pure push-payload extraction (R4 / iOS-15) shared by `Rees46.handlePush` and the legacy
//  `NotificationService`: the target `shop_id` and the `(type, code)` a track call carries, across the
//  payload shapes the SDK accepts.
//

import XCTest
@testable import REES46

final class PushPayloadParserTests: XCTestCase {

    func test_shopId_is_read_from_the_payload() {
        XCTAssertEqual(PushPayloadParser.shopId(from: ["shop_id": "shop-a"]), "shop-a")
    }

    func test_shopId_is_nil_when_absent() {
        XCTAssertNil(PushPayloadParser.shopId(from: ["type": "web", "id": "c1"]))
    }

    func test_type_and_code_from_top_level_fields() {
        let result = PushPayloadParser.typeAndCode(from: ["type": "product", "id": "p1"])
        XCTAssertEqual(result?.type, "product")
        XCTAssertEqual(result?.code, "p1")
    }

    func test_the_event_type_is_what_the_push_opens_not_the_mailing_type() {
        // FCM data as the server sends it: every value a string, `event` a JSON string.
        let payload: [AnyHashable: Any] = [
            "type": "bulk",
            "id": "c1",
            "event": "{\"type\":\"category\",\"uri\":\"https://x/y\"}"
        ]
        let result = PushPayloadParser.typeAndCode(from: payload)
        XCTAssertEqual(result?.type, "bulk")
        XCTAssertEqual(result?.code, "c1")
        XCTAssertEqual(PushPayloadParser.event(from: payload)?["type"] as? String, "category")
    }

    func test_a_push_without_a_mailing_type_is_not_an_sdk_push() {
        let payload: [AnyHashable: Any] = ["id": "c1", "event": "{\"type\":\"category\"}"]
        XCTAssertNil(PushPayloadParser.typeAndCode(from: payload))
    }

    func test_a_push_sent_through_apns_carries_src_and_event_as_objects() throws {
        // What the server sends to a token with platform=ios (message-service MobilePushToken).
        let json = """
        {"aps":{"alert":{"title":"T","body":"B"},"category":"web","mutable-content":1,"sound":"default"},
         "src":{"type":"chain","id":12345},"event":{"type":"web","uri":"https://example.com"},
         "image_url":"https://example.com/i.png","source":"utm","shop_id":"shop-a"}
        """
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [AnyHashable: Any])

        let result = PushPayloadParser.typeAndCode(from: payload)
        XCTAssertEqual(result?.type, "chain")
        XCTAssertEqual(result?.code, "12345")
        XCTAssertEqual(PushPayloadParser.shopId(from: payload), "shop-a")
        XCTAssertEqual(PushPayloadParser.event(from: payload)?["uri"] as? String, "https://example.com")
    }

    func test_type_and_code_from_nested_src_json() {
        let payload: [AnyHashable: Any] = ["src": "{\"type\":\"transactional\",\"id\":\"s1\"}"]
        let result = PushPayloadParser.typeAndCode(from: payload)
        XCTAssertEqual(result?.type, "transactional")
        XCTAssertEqual(result?.code, "s1")
    }

    func test_type_and_code_is_nil_for_a_non_sdk_push() {
        XCTAssertNil(PushPayloadParser.typeAndCode(from: ["title": "Hi", "body": "there"]))
    }

    func test_type_and_code_is_nil_when_code_is_missing() {
        XCTAssertNil(PushPayloadParser.typeAndCode(from: ["type": "web"]))
    }
}
