//
//  SecretMethodsPackageTests.swift
//  REES46CoreTests
//
//  The server methods with the shop's secret — `profile.getOrders`, `cart.clear`,
//  `notifications.getHistory` — without a server: the requests they build, the arguments they refuse,
//  and what they read of the answers the live API gives.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class SecretMethodsPackageTests: XCTestCase {

    private func refuses<Value>(_ make: () throws -> ApiRequest<Value>, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try make(), what, file: file, line: line) { error in
            guard case .invalidArgument? = error as? Rees46.SdkError else {
                return XCTFail("\(what): \(error)", file: file, line: line)
            }
        }
    }

    // MARK: - profile.getOrders

    private func orders(
        _ secret: String = "s", did: String? = nil, email: String? = nil, phone: String? = nil,
        loyaltyId: String? = nil, externalId: String? = nil, dateFrom: String? = nil
    ) throws -> ApiRequest<[Order]> {
        try ProfileAPIImpl.ordersRequest(
            shopSecret: secret, did: did, email: email, phone: phone, loyaltyId: loyaltyId, externalId: externalId, dateFrom: dateFrom
        )
    }

    func test_getOrders_asks_orders_by_user_with_the_secret_and_the_ids_given() throws {
        let request = try orders(did: "d-1", loyaltyId: "l-1", dateFrom: "2026-11-01")
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.path, "orders/by_user")
        XCTAssertEqual(request.query, ["shop_secret": "s", "did": "d-1", "loyalty_id": "l-1", "date_from": "2026-11-01"])
        XCTAssertTrue(request.secret)
        XCTAssertTrue(request.coreRequest.secret, "it goes with shop_id alone")
        XCTAssertEqual(try orders(email: "e", phone: "+7", externalId: "x").query, ["shop_secret": "s", "email": "e", "phone": "+7", "external_id": "x"])
    }

    func test_getOrders_refuses_an_empty_secret_or_id_no_id_and_a_date_that_is_not_one() {
        refuses({ try orders(" ", did: "d") }, "an empty secret")
        refuses({ try orders() }, "no id")
        refuses({ try orders(did: "") }, "an empty did")
        refuses({ try orders(email: " ") }, "an empty email")
        for date in ["2026-13-01", "01.11.2026", "2026-02-30", ""] {
            refuses({ try orders(did: "d", dateFrom: date) }, date)
        }
    }

    func test_getOrders_reads_the_orders_of_the_answer_with_their_sums_as_strings() throws {
        let request = try orders(did: "d")
        let answer = #"""
        {"status": "success", "data": {"orders": [{
          "_id": 9007199254740993, "id": "sdk-test-ios-1", "date": "2026-11-18T11:57:52.000Z", "value": "85980.0",
          "cash_value": null, "bonuses_value": null, "delivery_value": null, "location_id": null, "promocode": null,
          "offline": null, "marketplace": null, "delivery_date": null, "internal_status": "new", "stream": "ios",
          "channel": null, "tax_free": false, "delivery_type": "pickup", "delivery_address": null, "order_status": null,
          "payment_type": "card", "bank_issuer": null, "bank_pos_processor": null, "bank_loyalty_program": null,
          "bank_total_installment": null, "payment_card_provider": null, "gift_package": null, "payment_structure": null,
          "value_raw": null, "custom_properties": {},
          "items": [{"amount": 1, "price": "69990.0", "status": "created", "original_price": null, "discount_product": null,
                     "discount_coupon": null, "discount_bonuses": null, "delivery_company": null, "barcode": "284730",
                     "line_id": null, "cancel_reason": null, "item": {"id": "284730", "name": "Phone", "price": 69990}}],
          "history": []
        }]}}
        """#
        let read = try request.decode(Data(answer.utf8))
        XCTAssertEqual(read.count, 1)
        XCTAssertEqual(read.first?.id, "sdk-test-ios-1")
        XCTAssertEqual(read.first?.internalId, 9_007_199_254_740_993, "64-bit")
        XCTAssertEqual(read.first?.value, "85980.0")
        XCTAssertEqual(read.first?.deliveryType, "pickup")
        XCTAssertEqual(read.first?.items.first?.price, "69990.0")
        XCTAssertEqual(read.first?.items.first?.item?.id, "284730")
        XCTAssertEqual(try request.decode(Data(#"{"status": "success", "data": {"orders": []}}"#.utf8)).count, 0)
        for body in [#"{"status": "success"}"#, #"{"data": {}}"#, "[]", ""] {
            XCTAssertThrowsError(try request.decode(Data(body.utf8)), body)
        }
    }

    // MARK: - cart.clear

    private func clear(
        _ secret: String = "s", email: String? = nil, phone: String? = nil, loyaltyId: String? = nil,
        externalId: String? = nil, telegramId: String? = nil
    ) throws -> ApiRequest<Void> {
        try CartAPIImpl.clearRequest(shopSecret: secret, email: email, phone: phone, loyaltyId: loyaltyId, externalId: externalId, telegramId: telegramId)
    }

    func test_cart_clear_asks_products_cart_clear_with_get_and_the_ids_the_server_reads() throws {
        let request = try clear(externalId: "x-1", telegramId: "t-1")
        XCTAssertEqual(request.method, .get, "the API routes only GET there")
        XCTAssertEqual(request.path, "products/cart/clear")
        XCTAssertEqual(request.query, ["shop_secret": "s", "external_id": "x-1", "telegram_id": "t-1"])
        XCTAssertTrue(request.coreRequest.secret)
        XCTAssertEqual(try clear(email: "e", phone: "p", loyaltyId: "l").query, ["shop_secret": "s", "email": "e", "phone": "p", "loyalty_id": "l"])
    }

    func test_cart_clear_refuses_an_empty_secret_or_id_and_no_id() {
        refuses({ try clear("", externalId: "x") }, "an empty secret")
        refuses({ try clear() }, "no id: the server finds the customer by none of the device's")
        refuses({ try clear(telegramId: " ") }, "an empty telegram id")
    }

    func test_cart_clear_is_a_success_only_for_status_success() throws {
        let request = try clear(externalId: "x")
        XCTAssertNoThrow(try request.decode(Data(#"{"status": "success"}"#.utf8)))
        for body in [#"{"status": "ok"}"#, "{}", "", "[]"] {
            XCTAssertThrowsError(try request.decode(Data(body.utf8)), body)
        }
    }

    // MARK: - notifications.getHistory

    private func history(
        _ secret: String = "s", type: String = "bulk", phone: String? = nil, email: String? = nil, externalId: String? = nil,
        loyaltyId: String? = nil, channel: String? = nil, limit: Int? = nil, page: Int? = nil, dateFrom: String? = "2026-10-01",
        did: String? = "d"
    ) throws -> ApiRequest<UserPayloadResponse> {
        try NotificationsAPIImpl.historyRequest(
            shopSecret: secret, type: type, phone: phone, email: email, externalId: externalId, loyaltyId: loyaltyId,
            channel: channel, limit: limit, page: page, dateFrom: dateFrom, did: did
        )
    }

    func test_getHistory_asks_notifications_under_the_names_of_the_root_method() throws {
        let request = try history(phone: "p", email: "e", externalId: "x", loyaltyId: "l", channel: "mobile_push", limit: 5, page: 2)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.path, "notifications")
        XCTAssertEqual(request.query, [
            "shop_secret": "s", "type": "bulk", "phone": "p", "email": "e", "external_id": "x", "loyalty_id": "l",
            "did": "d", "channel": "mobile_push", "limit": "5", "page": "2", "date_from": "2026-10-01",
        ])
        XCTAssertTrue(request.coreRequest.secret)
        XCTAssertEqual(try history().query, ["shop_secret": "s", "type": "bulk", "did": "d", "date_from": "2026-10-01"])
    }

    func test_getHistory_refuses_what_the_server_would() {
        refuses({ try history(" ") }, "an empty secret")
        refuses({ try history(type: "") }, "an empty type")
        refuses({ try history(did: nil) }, "no id")
        refuses({ try history(did: "") }, "an empty did")
        refuses({ try history(channel: " ") }, "an empty channel")
        refuses({ try history(limit: 0) }, "limit below 1")
        refuses({ try history(page: 0) }, "page below 1")
        refuses({ try history(dateFrom: nil) }, "no dateFrom: the server answers 400 without it")
        refuses({ try history(dateFrom: "2026-10") }, "not a day")
    }

    func test_getHistory_reads_the_messages_under_payload() throws {
        let request = try history()
        let empty = try request.decode(Data(#"{"status": "success", "payload": {"messages": []}}"#.utf8))
        XCTAssertEqual(empty.notifications.count, 0)
        let one = try request.decode(Data(#"{"status": "success", "payload": {"messages": [{"type": "bulk", "code": "c-1", "subject": "Sale", "body": "Today", "date": "2026-11-01"}]}}"#.utf8))
        XCTAssertEqual(one.notifications.first?.codeId, "c-1")
        XCTAssertEqual(one.notifications.first?.subject, "Sale")
        for body in [#"{"status": "success", "messages": []}"#, #"{"payload": {}}"#, "", "[]"] {
            XCTAssertThrowsError(try request.decode(Data(body.utf8)), body)
        }
    }

    /// The answer of `GET notifications` as the API documents it: `campaign_id` a number, `channel`,
    /// `statistics` one object with the keys in snake case.
    private static let historyAnswer = #"""
    {"status": "success", "payload": {"messages": [
      {"type": "bulk", "campaign_id": 4511, "channel": "email", "code": "c-1", "date": "2026-11-01",
       "sent_at": "2026-11-01T14:25:21.000Z", "subject": "Sale", "body": "Today", "url": "https://shop.example/sale",
       "icon": "https://shop.example/icon.png", "picture": "https://shop.example/picture.png",
       "statistics": {"opened": true, "clicked": true, "hard_bounced": false, "soft_bounced": true,
                      "complained": false, "unsubscribed": false, "purchased": true}},
      {"type": "trigger", "campaign_id": 12, "channel": "mobile_push", "code": "c-2", "date": "2026-11-02",
       "sent_at": "2026-11-02T08:00:00.000Z", "subject": null, "body": "Back in stock", "url": null, "icon": null,
       "picture": null,
       "statistics": {"opened": false, "clicked": false, "hard_bounced": true, "soft_bounced": false,
                      "complained": true, "unsubscribed": true, "purchased": false}}
    ]}}
    """#

    /// Every field of `historyAnswer`, as the model reads it.
    private func assertReadsTheHistoryAnswer(_ history: UserPayloadResponse, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(history.status, "success", file: file, line: line)
        XCTAssertEqual(history.notifications.count, 2, file: file, line: line)
        guard history.notifications.count == 2 else { return }
        let sale = history.notifications[0]
        XCTAssertEqual(sale.type, "bulk", file: file, line: line)
        XCTAssertEqual(sale.campaignId, 4511, file: file, line: line)
        XCTAssertNil(sale.campaignsIds, "the old list of names, which the server does not send", file: file, line: line)
        XCTAssertEqual(sale.channel, "email", file: file, line: line)
        XCTAssertEqual(sale.codeId, "c-1", file: file, line: line)
        XCTAssertEqual(sale.dateString, "2026-11-01", file: file, line: line)
        XCTAssertEqual(sale.dateSentAt, "2026-11-01T14:25:21.000Z", file: file, line: line)
        XCTAssertEqual(sale.subject, "Sale", file: file, line: line)
        XCTAssertEqual(sale.bodyData, "Today", file: file, line: line)
        XCTAssertEqual(sale.url, "https://shop.example/sale", file: file, line: line)
        XCTAssertEqual(sale.icon, "https://shop.example/icon.png", file: file, line: line)
        XCTAssertEqual(sale.picture, "https://shop.example/picture.png", file: file, line: line)
        XCTAssertEqual(sale.statistics.count, 1, "the one object of the answer", file: file, line: line)
        let read = sale.statistics.first
        XCTAssertEqual(read?.opened, true, file: file, line: line)
        XCTAssertEqual(read?.clicked, true, file: file, line: line)
        XCTAssertEqual(read?.hardBounced, false, file: file, line: line)
        XCTAssertEqual(read?.softBounced, true, file: file, line: line)
        XCTAssertEqual(read?.complained, false, file: file, line: line)
        XCTAssertEqual(read?.unsubscribed, false, file: file, line: line)
        XCTAssertEqual(read?.purchased, true, file: file, line: line)

        let push = history.notifications[1]
        XCTAssertEqual(push.campaignId, 12, file: file, line: line)
        XCTAssertEqual(push.channel, "mobile_push", file: file, line: line)
        XCTAssertEqual(push.subject, "", "a null string reads as before", file: file, line: line)
        let pushRead = push.statistics.first
        XCTAssertEqual(pushRead?.hardBounced, true, file: file, line: line)
        XCTAssertEqual(pushRead?.softBounced, false, file: file, line: line)
        XCTAssertEqual(pushRead?.complained, true, file: file, line: line)
        XCTAssertEqual(pushRead?.unsubscribed, true, file: file, line: line)
    }

    func test_getHistory_reads_the_status_and_every_field_of_a_message_the_server_sends() throws {
        let request = try history()
        let body = Data(Self.historyAnswer.utf8)
        let answer = NetworkClient.Response(
            status: 200, body: body, retryAfter: nil, result: NetworkClient.classify(status: 200, body: body, path: request.path)
        )
        let logger = SdkLogger(shopId: "package-\(UUID().uuidString)", level: .none)
        let read = NamespaceRequests.value(of: answer, for: request, call: NotificationsAPIImpl.getHistoryCall, logger: logger)
        assertReadsTheHistoryAnswer(try read.get())
    }

    /// The root `getAllNotifications(shopSecret:…)` hands the model the whole answer, as
    /// `NotificationHandlerServiceImpl` gets it.
    func test_the_root_getAllNotifications_reads_the_same_answer_whole() throws {
        let answer = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(Self.historyAnswer.utf8)) as? [String: Any])
        assertReadsTheHistoryAnswer(UserPayloadResponse(json: answer))
    }

    func test_the_history_model_still_reads_the_shapes_it_read_before() {
        let old = UserPayloadResponse(json: [
            "messages": [[
                "type": "bulk",
                "campaign_id": [["name": "Sale"], ["name": "Autumn"], ["id": 1]],
                "statistics": [
                    ["opened": true, "hardBounced": true, "softBounced": false],
                    ["clicked": true],
                ],
            ]],
        ])
        XCTAssertNil(old.status)
        let message = old.notifications.first
        XCTAssertEqual(message?.campaignsIds, ["Sale", "Autumn"])
        XCTAssertNil(message?.campaignId)
        XCTAssertNil(message?.channel)
        XCTAssertEqual(message?.statistics.count, 2)
        XCTAssertEqual(message?.statistics.first?.opened, true)
        XCTAssertEqual(message?.statistics.first?.hardBounced, true)
        XCTAssertEqual(message?.statistics.first?.softBounced, false)
        XCTAssertNil(message?.statistics.first?.clicked)
        XCTAssertEqual(message?.statistics.last?.clicked, true)
    }

    func test_the_history_model_leaves_out_what_is_missing_or_not_a_whole_number() throws {
        let answer = #"""
        {"status": "success", "payload": {"messages": [
          {"code": "none"},
          {"code": "boolean", "campaign_id": true, "statistics": "opened"},
          {"code": "fraction", "campaign_id": 1.5},
          {"code": "text", "campaign_id": "77"}
        ]}}
        """#
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(answer.utf8)) as? [String: Any])
        let read = UserPayloadResponse(json: json)
        XCTAssertEqual(read.notifications.map(\.codeId), ["none", "boolean", "fraction", "text"])
        XCTAssertEqual(read.notifications.map(\.campaignId), [nil, nil, nil, 77])
        XCTAssertEqual(read.notifications.map(\.statistics.count), [0, 0, 0, 0])
        XCTAssertEqual(read.notifications.map(\.channel), [nil, nil, nil, nil])
        XCTAssertEqual(UserPayloadResponse(json: [:]).notifications.count, 0)
    }

    // MARK: - The common fields

    func test_a_server_methods_request_gets_shop_id_alone() {
        let fields = CommonFields(shopId: "shop", deviceId: "d", sessionId: "s", stream: "ios", segment: "A")
        let query = fields.apply(to: ["shop_secret": "secret", "did": "given"], path: "orders/by_user", onlyShop: true)
        XCTAssertEqual(query, ["shop_id": "shop", "shop_secret": "secret", "did": "given"], "no stream, sid, seance, segment; did only the caller's")
        XCTAssertEqual(fields.apply(to: ["shop_secret": "secret"], path: "orders/by_user")["stream"], "ios", "the root methods keep their fields")
    }
}
