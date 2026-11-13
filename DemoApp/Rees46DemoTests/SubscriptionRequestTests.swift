//
//  SubscriptionRequestTests.swift
//  REES46Tests
//
//  The product subscriptions as the server reads them: item ids as one comma-separated string,
//  the product properties as an object, and phone numbers as people write them in any country.
//

import XCTest
@testable import REES46

final class SubscriptionRequestTests: XCTestCase {

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

    private func body(_ sdk: SimplePersonalizationSDK, _ path: String) -> [String: Any] {
        StubURLProtocol.requests(to: path, shop: sdk.shopId).first?.body ?? [:]
    }

    func test_unsubscribing_sends_the_item_ids_as_one_comma_separated_string() {
        let sdk = initializedSDK()
        let answered = expectation(description: "answered")
        answered.expectedFulfillmentCount = 2
        sdk.unsubscribeForPriceDrop(itemIds: ["a1", "b2"], currentPrice: 99.5, email: "buyer@example.com") { _ in answered.fulfill() }
        sdk.unsubscribeForBackInStock(itemIds: ["a1", "b2"], email: "buyer@example.com") { _ in answered.fulfill() }
        wait(for: [answered], timeout: 5)

        let price = body(sdk, "/subscriptions/unsubscribe_from_product_price")
        XCTAssertEqual(price["item_ids"] as? String, "a1,b2")
        XCTAssertNil(price["price"], "the server reads no price when unsubscribing")
        XCTAssertEqual(body(sdk, "/subscriptions/unsubscribe_from_product_available")["item_ids"] as? String, "a1,b2")
    }

    func test_back_in_stock_sends_the_product_properties() {
        let sdk = initializedSDK()
        let answered = expectation(description: "answered")
        answered.expectedFulfillmentCount = 2
        sdk.subscribeForBackInStock(id: "a1", email: "buyer@example.com", fashionSize: "42", fashionColor: "red", barcode: "460") { _ in
            answered.fulfill()
        }
        sdk.subscribeForBackInStock(id: "b2", email: "buyer@example.com") { _ in answered.fulfill() }
        wait(for: [answered], timeout: 5)

        let requests = StubURLProtocol.requests(to: "/subscriptions/subscribe_for_product_available", shop: sdk.shopId)
        let withProperties = requests.first { $0.body["item_id"] as? String == "a1" }?.body ?? [:]
        let without = requests.first { $0.body["item_id"] as? String == "b2" }?.body ?? [:]
        let properties = withProperties["properties"] as? [String: String]
        XCTAssertEqual(properties, ["fashion_size": "42", "fashion_color": "red", "barcode": "460"])
        XCTAssertNil(without["properties"])
    }

    func test_phone_numbers_are_accepted_as_written_in_any_country() {
        for phone in [
            "+7 999 123-45-67", "+7(999)123-45-67", "89991234567", "+375 29 123-45-67", "+998 90 123 45 67",
            "+380 44 123 4567", "+49 30 1234567", "+44 20 7946 0958", "+1 (415) 555-2671", "+79990001122",
            "+683 4002"  // Niue: 7 digits with the country code, the fewest the server takes
        ] {
            XCTAssertTrue(isValid(phone: phone), phone)
        }
    }

    func test_what_is_not_a_phone_number_is_rejected() {
        for phone in ["", "+", "12345", "123456", "+7 999 abc 45 67", "phone", "+1234567890123456", "7+9991234567"] {
            XCTAssertFalse(isValid(phone: phone), phone)
        }
    }

    func test_an_invalid_phone_sends_nothing() {
        let sdk = initializedSDK()
        let answered = expectation(description: "answered")
        var outcome: Result<Void, SdkError>?
        sdk.subscribeForPriceDrop(id: "a1", currentPrice: 10, phone: "12345") { result in
            outcome = result
            answered.fulfill()
        }
        wait(for: [answered], timeout: 5)

        if case .success = outcome { XCTFail("an invalid phone must fail") }
        XCTAssertTrue(StubURLProtocol.requests(to: "/subscriptions/subscribe_for_product_price", shop: sdk.shopId).isEmpty)
    }
}
