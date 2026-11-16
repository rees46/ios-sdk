//
//  SubscriptionContractTests.swift
//  REES46Tests
//
//  The subscriptions against the API documentation (rees46.ru/help/integration):
//  `POST /subscriptions/manage` (cdp/subscriptions/manage) and the product triggers
//  `subscribe_for_product_price`, `subscribe_for_product_available` and their `unsubscribe_from_*`
//  (cdp/standard-events/subscribe-for-price, subscribe-for-stock). The contact goes as the app gives
//  it — an email, a phone, both, or neither, when the device itself is the subscriber.
//

import XCTest
@testable import REES46

final class SubscriptionContractTests: ContractTestCase {

    private func succeeded(_ result: Result<Void, SdkError>?, file: StaticString = #filePath, line: UInt = #line) {
        if case .failure(let error) = result { XCTFail("failed: \(error)", file: file, line: line) }
    }

    /// The device and its session, which every subscription request carries.
    private func assertDevice(_ body: [String: Any]?, _ sdk: SimplePersonalizationSDK, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(body?["shop_id"] as? String, sdk.shopId, file: file, line: line)
        XCTAssertEqual(body?["did"] as? String, "stub-did", file: file, line: line)
    }

    // MARK: - POST /subscriptions/manage

    func test_managing_subscriptions_posts_the_contacts_as_given() {
        let contacts: [(email: String?, phone: String?)] = [
            ("buyer@example.com", nil), (nil, "+79991234567"), ("buyer@example.com", "+79991234567"), (nil, nil)
        ]
        onBothCores { sdk in
            for contact in contacts {
                StubURLProtocol.handler = StubURLProtocol.defaultHandler
                let before = StubURLProtocol.requests(to: "/subscriptions/manage", shop: sdk.shopId).count

                succeeded(outcome { sdk.manageSubscription(email: contact.email, phone: contact.phone, emailBulk: true, completion: $0) })

                let sent = StubURLProtocol.requests(to: "/subscriptions/manage", shop: sdk.shopId)
                XCTAssertEqual(sent.count, before + 1, "one request for \(contact)")
                let body = sent.last?.body
                XCTAssertEqual(sent.last?.method, "POST")
                assertDevice(body, sdk)
                XCTAssertEqual(body?["email"] as? String, contact.email, "\(contact)")
                XCTAssertEqual(body?["phone"] as? String, contact.phone, "\(contact)")
                XCTAssertEqual(body?["email_bulk"] as? Bool, true)
                XCTAssertNil(body?["shop_secret"], "the SDK never sends the shop's secret")
            }
        }
    }

    func test_the_channel_flags_go_as_booleans_and_flags_left_out_are_not_sent() {
        onBothCores { sdk in
            succeeded(outcome {
                sdk.manageSubscription(
                    email: "buyer@example.com",
                    telegramBulk: true, telegramChain: true, telegramTransactional: false,
                    whatsappBulk: true, whatsappChain: false, whatsappTransactional: true,
                    maxBulk: false, maxChain: true, maxTransactional: true,
                    walletBulk: true,
                    completion: $0
                )
            })

            let body = request(sdk, "/subscriptions/manage")?.body ?? [:]
            let expected: [String: Bool] = [
                "telegram_bulk": true, "telegram_chain": true, "telegram_transactional": false,
                "whatsapp_bulk": true, "whatsapp_chain": false, "whatsapp_transactional": true,
                "max_bulk": false, "max_chain": true, "max_transactional": true,
                "wallet_bulk": true,
            ]
            for (key, value) in expected {
                XCTAssertEqual(body[key] as? Bool, value, key)
            }
            // "If a flag is not given, it does not change": the ones the app left out stay out.
            for key in ["email_bulk", "sms_bulk", "web_push_bulk", "mobile_push_bulk"] {
                XCTAssertNil(body[key], key)
            }
        }
    }

    func test_an_error_answer_of_managing_fails_the_call() {
        onBothCores { sdk in
            answer("/subscriptions/manage", status: 400, json: #"{"status": "error", "payload": {"message": "Incorrect params"}}"#)

            let result = outcome { sdk.manageSubscription(email: "buyer@example.com", completion: $0) }

            guard case .failure = result else { return XCTFail("an error answer must fail: \(String(describing: result))") }
        }
    }

    // MARK: - Price drop

    func test_subscribing_for_a_price_drop_posts_the_item_its_price_and_the_contact() {
        let contacts: [(email: String?, phone: String?)] = [
            ("buyer@example.com", nil), (nil, "+79991234567"), ("buyer@example.com", "+79991234567"), (nil, nil)
        ]
        onBothCores { sdk in
            for (index, contact) in contacts.enumerated() {
                let item = "item-\(index)"

                succeeded(outcome { sdk.subscribeForPriceDrop(id: item, currentPrice: 170.0, email: contact.email, phone: contact.phone, completion: $0) })

                let sent = StubURLProtocol.requests(to: "/subscriptions/subscribe_for_product_price", shop: sdk.shopId)
                    .last { $0.body["item_id"] as? String == item }
                XCTAssertEqual(sent?.method, "POST", "\(contact)")
                assertDevice(sent?.body, sdk)
                XCTAssertEqual(sent?.body["email"] as? String, contact.email, "\(contact)")
                XCTAssertEqual(sent?.body["phone"] as? String, contact.phone, "\(contact)")
                XCTAssertEqual((sent?.body["price"] as? NSNumber)?.doubleValue ?? Double(sent?.body["price"] as? String ?? ""), 170.0)
            }
        }
    }

    func test_unsubscribing_from_price_drops_posts_the_items_as_one_string_and_all_as_an_empty_one() {
        onBothCores { sdk in
            succeeded(outcome { sdk.unsubscribeForPriceDrop(itemIds: ["a1", "b2"], currentPrice: 170.0, email: nil, phone: "+79991234567", completion: $0) })
            succeeded(outcome { sdk.unsubscribeForPriceDrop(itemIds: [], currentPrice: 170.0, email: "buyer@example.com", phone: nil, completion: $0) })

            let sent = StubURLProtocol.requests(to: "/subscriptions/unsubscribe_from_product_price", shop: sdk.shopId)
            XCTAssertEqual(sent.count, 2)
            assertDevice(sent.first?.body, sdk)
            XCTAssertEqual(sent.first?.body["item_ids"] as? String, "a1,b2")
            XCTAssertEqual(sent.first?.body["phone"] as? String, "+79991234567")
            XCTAssertEqual(sent.last?.body["item_ids"] as? String, "", "an empty list removes every subscription of the client")
            XCTAssertEqual(sent.last?.body["email"] as? String, "buyer@example.com")
        }
    }

    // MARK: - Back in stock

    func test_subscribing_for_back_in_stock_posts_the_item_and_the_contact() {
        let contacts: [(email: String?, phone: String?)] = [
            ("buyer@example.com", nil), (nil, "+79991234567"), ("buyer@example.com", "+79991234567"), (nil, nil)
        ]
        onBothCores { sdk in
            for (index, contact) in contacts.enumerated() {
                let item = "item-\(index)"

                succeeded(outcome { sdk.subscribeForBackInStock(id: item, email: contact.email, phone: contact.phone, completion: $0) })

                let sent = StubURLProtocol.requests(to: "/subscriptions/subscribe_for_product_available", shop: sdk.shopId)
                    .last { $0.body["item_id"] as? String == item }
                XCTAssertEqual(sent?.method, "POST", "\(contact)")
                assertDevice(sent?.body, sdk)
                XCTAssertEqual(sent?.body["email"] as? String, contact.email, "\(contact)")
                XCTAssertEqual(sent?.body["phone"] as? String, contact.phone, "\(contact)")
            }
        }
    }

    func test_unsubscribing_from_back_in_stock_posts_the_items_as_one_string() {
        onBothCores { sdk in
            succeeded(outcome { sdk.unsubscribeForBackInStock(itemIds: ["a1", "b2"], email: "buyer@example.com", phone: "+79991234567", completion: $0) })

            let sent = request(sdk, "/subscriptions/unsubscribe_from_product_available")
            XCTAssertEqual(sent?.method, "POST")
            assertDevice(sent?.body, sdk)
            XCTAssertEqual(sent?.body["item_ids"] as? String, "a1,b2")
            XCTAssertEqual(sent?.body["email"] as? String, "buyer@example.com")
            XCTAssertEqual(sent?.body["phone"] as? String, "+79991234567")
        }
    }

    func test_an_error_answer_of_a_subscription_fails_the_call() {
        onBothCores { sdk in
            answer("/subscriptions/subscribe_for_product_price", status: 400, json: #"{"status": "error", "payload": {"message": "Email or item id incorrect"}}"#)

            let result = outcome { sdk.subscribeForPriceDrop(id: "a1", currentPrice: 10, email: nil, phone: nil, completion: $0) }

            guard case .failure = result else { return XCTFail("an error answer must fail: \(String(describing: result))") }
        }
    }
}
