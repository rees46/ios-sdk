//
//  CartPackageTests.swift
//  REES46CoreTests
//
//  `cart.get` without a server: what the request path makes of each answer of the proposed fixture, as
//  the client classifies it, and which bodies are a cart.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class CartPackageTests: XCTestCase {

    /// Every answer of the proposed `cart` fixture, as the client classifies it and the path reads it.
    func test_the_cart_fixture_answers_end_as_the_fixture_says() throws {
        // A case without an answer runs over the stub server (`NamespaceRequestTests`).
        let cases = try ContractFixtures.fixture("cart", from: .proposed).filter { $0.response?.status != nil }
        XCTAssertFalse(cases.isEmpty)
        let logger = SdkLogger(shopId: "package-\(UUID().uuidString)", level: .none)
        for item in cases {
            let response = try XCTUnwrap(item.response, item.name)
            let status = try XCTUnwrap(response.status, item.name)
            let answer = NetworkClient.Response(
                status: status, body: response.body, retryAfter: nil,
                result: NetworkClient.classify(status: status, body: response.body, path: "products/cart")
            )
            let result = NamespaceRequests.value(of: answer, for: CartAPIImpl.cartRequest, call: "cart.get", logger: logger)
            assert(result, as: item)
        }
    }

    /// `result` ends as `item` expects: its error, or its `result` by the contract's field names.
    private func assert(_ result: Result<[CartItem], Rees46.SdkError>, as item: ContractCase, file: StaticString = #filePath, line: UInt = #line) {
        switch result {
        case .success(let items):
            XCTAssertNil(item.expectedError, "\(item.name): \(items)", file: file, line: line)
            let expected = (item.expect["result"] as? [[String: Any]] ?? []).map { "\($0["id"] ?? "")×\($0["quantity"] ?? "")" }
            XCTAssertEqual(items.map { "\($0.id)×\($0.quantity)" }, expected, item.name, file: file, line: line)
        case .failure(let error):
            XCTAssertTrue(item.expectedError?.matches(error) == true, "\(item.name): \(error), expected \(String(describing: item.expectedError))", file: file, line: line)
        }
    }

    func test_the_body_of_a_cart_is_its_value_whatever_else_the_body_holds() {
        let logger = SdkLogger(shopId: "package-\(UUID().uuidString)", level: .none)
        func items(_ json: String) -> [CartItem]? {
            let body = Data(json.utf8)
            let answer = NetworkClient.Response(status: 200, body: body, retryAfter: nil, result: NetworkClient.classify(status: 200, body: body))
            return try? NamespaceRequests.value(of: answer, for: CartAPIImpl.cartRequest, call: "cart.get", logger: logger).get()
        }
        XCTAssertEqual(items("")?.count, 0, "a 2xx without a body is an empty cart")
        XCTAssertNil(items("{}"), "an empty object is not a cart")
        XCTAssertNil(items(#"{"data": {}}"#), "no list of lines: not a cart")
        XCTAssertNil(items(#"{"data": {"items": null}}"#))
        XCTAssertNil(items(#"{"data": {"items": "37"}}"#))
        XCTAssertNil(items(#"[]"#))
        XCTAssertEqual(items(#"{"data": {"items": [{"uniqid": "1"}]}, "payload": {"cart_items": []}}"#)?.map(\.id), ["1"], "today's shape first")
        XCTAssertEqual(items(#"{"data": {"items": "37"}, "payload": {"cart_items": [{"uniqid": "2"}]}}"#)?.map(\.id), ["2"], "else the documented one")
        XCTAssertEqual(items(#"{"data": {"items": [{"uniqid": "  "}, {"uniqid": "3"}]}}"#)?.map(\.id), ["3"], "a blank id is none")
    }

    func test_the_cart_fixture_is_proposed_until_the_contract_has_one() throws {
        let cart = try ContractFixtures.fixture("cart", from: .proposed)
        XCTAssertEqual(try ContractFixtures.load("cart", from: .proposed)["contract"] as? String, ContractFixtures.version)
        XCTAssertEqual(cart.first?.call?.name, "cart.get")
        XCTAssertEqual(cart.first?.request?.path, "products/cart")
        XCTAssertTrue(cart.contains { $0.expectedError?.matches(.http(code: 404, serverCode: nil)) == true })
        XCTAssertFalse(FileManager.default.fileExists(atPath: ContractFixtures.url("cart").path), "the contract has cart.json now: copy it into contract-\(ContractFixtures.version) and remove the proposed one")
    }
}
