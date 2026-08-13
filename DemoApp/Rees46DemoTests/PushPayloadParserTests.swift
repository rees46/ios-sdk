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

    func test_type_from_event_json_with_top_level_id() {
        let payload: [AnyHashable: Any] = [
            "event": "{\"type\":\"category\",\"uri\":\"https://x/y\"}",
            "id": "c1"
        ]
        let result = PushPayloadParser.typeAndCode(from: payload)
        XCTAssertEqual(result?.type, "category")
        XCTAssertEqual(result?.code, "c1")
    }

    func test_type_and_code_from_nested_src_json() {
        let payload: [AnyHashable: Any] = ["src": "{\"type\":\"web\",\"id\":\"s1\"}"]
        let result = PushPayloadParser.typeAndCode(from: payload)
        XCTAssertEqual(result?.type, "web")
        XCTAssertEqual(result?.code, "s1")
    }

    func test_type_and_code_is_nil_for_a_non_sdk_push() {
        XCTAssertNil(PushPayloadParser.typeAndCode(from: ["title": "Hi", "body": "there"]))
    }

    func test_type_and_code_is_nil_when_code_is_missing() {
        XCTAssertNil(PushPayloadParser.typeAndCode(from: ["type": "web"]))
    }
}
