//
//  ClientNamespaceTests.swift
//  REES46Tests
//
//  The client's namespaces end to end over the stub server — `profile`, `subscriptions`, `segments` —:
//  each method sends its request with the common fields and reads the answer, in `completion` and in
//  `async` code; on the old core each one is `notInitialized`, sends nothing and logs its name; the A/B
//  group is the device's on either core. The cases of each request and answer are the package's
//  (`ClientPackageTests`).
//

import XCTest
@_spi(Bridge) @testable import REES46

final class ClientNamespaceTests: CoreScenarioTestCase {

    /// One method of the client, called with arguments it sends.
    private struct Method {
        /// What the log calls it.
        let name: String
        let httpMethod: String
        /// The stub's path of its request.
        let path: String
        /// The fields of the query or the body it sends for these arguments, as text.
        let sends: [String: String]
        /// An answer it reads.
        let answer: String
        let call: (PersonalizationSDK, @escaping (Rees46.SdkError?) -> Void) -> Void
        let callAsync: (PersonalizationSDK) async throws -> Void
    }

    private let methods: [Method] = [
        Method(
            name: "profile.get", httpMethod: "GET", path: "/profile", sends: [:],
            answer: #"{"id": "1", "gender": "f"}"#,
            call: { sdk, done in sdk.profile.get { done($0.failure) } },
            callAsync: { sdk in _ = try await sdk.profile.get() }
        ),
        Method(
            name: "profile.set", httpMethod: "POST", path: "/profile/set",
            sends: ["external_id": "ext-1", "id": "ext-1", "birthday": "1990-05-17", "vip": "1"],
            answer: #"{"status": "success"}"#,
            call: { sdk, done in
                sdk.profile.set(Rees46.ProfileUpdateRequest(externalId: "ext-1", birthday: "1990-05-17", customProperties: ["vip": true])) { done($0.failure) }
            },
            callAsync: { sdk in try await sdk.profile.set(Rees46.ProfileUpdateRequest(externalId: "ext-1", birthday: "1990-05-17", customProperties: ["vip": true])) }
        ),
        Method(
            name: "profile.getLastOrder", httpMethod: "GET", path: "/orders/last_for_user", sends: [:],
            answer: #"[{"id": "1", "name": "Phone", "url": "u", "price": 1, "currency": "$"}]"#,
            call: { sdk, done in sdk.profile.getLastOrder { done($0.failure) } },
            callAsync: { sdk in _ = try await sdk.profile.getLastOrder() }
        ),
        Method(
            name: "subscriptions.manage", httpMethod: "POST", path: "/subscriptions/manage", sends: ["email_bulk": "1", "sms_chain": "0"],
            answer: "{}",
            call: { sdk, done in sdk.subscriptions.manage(Rees46.SubscriptionsUpdateRequest(emailBulk: true, smsChain: false)) { done($0.failure) } },
            callAsync: { sdk in try await sdk.subscriptions.manage(Rees46.SubscriptionsUpdateRequest(emailBulk: true, smsChain: false)) }
        ),
        Method(
            name: "subscriptions.check", httpMethod: "GET", path: "/subscriptions/check", sends: [:],
            answer: #"{"exists": true, "email_bulk": true}"#,
            call: { sdk, done in sdk.subscriptions.check { done($0.failure) } },
            callAsync: { sdk in _ = try await sdk.subscriptions.check() }
        ),
        Method(
            name: "subscriptions.subscribeForPriceDrop", httpMethod: "POST", path: "/subscriptions/subscribe_for_product_price",
            sends: ["item_id": "37", "price": "99.5"], answer: "{}",
            call: { sdk, done in sdk.subscriptions.subscribeForPriceDrop(itemId: "37", currentPrice: 99.5) { done($0.failure) } },
            callAsync: { sdk in try await sdk.subscriptions.subscribeForPriceDrop(itemId: "37", currentPrice: 99.5) }
        ),
        Method(
            name: "subscriptions.unsubscribeFromPriceDrop", httpMethod: "POST", path: "/subscriptions/unsubscribe_from_product_price",
            sends: ["item_ids": "37,38"], answer: "{}",
            call: { sdk, done in sdk.subscriptions.unsubscribeFromPriceDrop(itemIds: ["37", "38"]) { done($0.failure) } },
            callAsync: { sdk in try await sdk.subscriptions.unsubscribeFromPriceDrop(itemIds: ["37", "38"]) }
        ),
        Method(
            name: "subscriptions.subscribeForBackInStock", httpMethod: "POST", path: "/subscriptions/subscribe_for_product_available",
            sends: ["item_id": "37"], answer: "{}",
            call: { sdk, done in
                sdk.subscriptions.subscribeForBackInStock(itemId: "37", properties: Rees46.BackInStockProperties(fashionSize: "M")) { done($0.failure) }
            },
            callAsync: { sdk in try await sdk.subscriptions.subscribeForBackInStock(itemId: "37", properties: Rees46.BackInStockProperties(fashionSize: "M")) }
        ),
        Method(
            name: "subscriptions.unsubscribeFromBackInStock", httpMethod: "POST", path: "/subscriptions/unsubscribe_from_product_available",
            sends: ["item_ids": ""], answer: "{}",
            call: { sdk, done in sdk.subscriptions.unsubscribeFromBackInStock(itemIds: []) { done($0.failure) } },
            callAsync: { sdk in try await sdk.subscriptions.unsubscribeFromBackInStock(itemIds: []) }
        ),
        Method(
            name: "segments.add", httpMethod: "POST", path: "/segments/add", sends: ["segment_id": "313"],
            answer: #"{"status": "success"}"#,
            call: { sdk, done in sdk.segments.add(segmentId: 313) { done($0.failure) } },
            callAsync: { sdk in try await sdk.segments.add(segmentId: 313) }
        ),
        Method(
            name: "segments.remove", httpMethod: "POST", path: "/segments/remove", sends: ["segment_id": "313", "email": "jane@example.com"],
            answer: #"{"status": "success"}"#,
            call: { sdk, done in sdk.segments.remove(segmentId: 313, email: "jane@example.com") { done($0.failure) } },
            callAsync: { sdk in try await sdk.segments.remove(segmentId: 313, email: "jane@example.com") }
        ),
        Method(
            name: "segments.get", httpMethod: "GET", path: "/segments/get", sends: [:],
            answer: #"[{"id": 313, "type": "static"}]"#,
            call: { sdk, done in sdk.segments.get { done($0.failure) } },
            callAsync: { sdk in _ = try await sdk.segments.get() }
        ),
    ]

    /// How `method` ended with `completion`, which comes on the main thread.
    private func outcome(_ method: Method, _ sdk: PersonalizationSDK, file: StaticString = #filePath, line: UInt = #line) -> Rees46.SdkError? {
        let done = expectation(description: method.name)
        let error = Locked<Rees46.SdkError?>(nil)
        method.call(sdk) { failure in
            XCTAssertTrue(Thread.isMainThread, "\(method.name): completion on the main thread", file: file, line: line)
            error.current = failure
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return error.current
    }

    /// How `method` ended in `async` code.
    private func asyncOutcome(_ method: Method, _ sdk: PersonalizationSDK) -> Rees46.SdkError? {
        let done = expectation(description: "async \(method.name)")
        let error = Locked<Rees46.SdkError?>(nil)
        _Concurrency.Task {
            do {
                try await method.callAsync(sdk)
            } catch let failure as Rees46.SdkError {
                error.current = failure
            } catch {
                XCTFail("\(method.name): not an SdkError: \(error)")
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return error.current
    }

    // MARK: - The new core

    func test_each_method_sends_its_request_with_the_common_fields_and_reads_the_answer() throws {
        let shop = newShop()
        let sdk = makeV2(shop)
        for method in methods {
            answer(method.path, StubReply(json: method.answer))
            let before = requests(method.path, shop).count
            XCTAssertNil(outcome(method, sdk), method.name)
            let sent = requests(method.path, shop)
            XCTAssertEqual(sent.count, before + 1, "\(method.name): one request")
            let request = try XCTUnwrap(sent.last, method.name)
            XCTAssertEqual(request.method, method.httpMethod, method.name)
            let fields: [String: String] = method.httpMethod == "GET" ? request.query : request.body.mapValues { "\($0)" }
            for (key, value) in method.sends {
                XCTAssertEqual(fields[key], value, "\(method.name): \(key)")
            }
            XCTAssertEqual(fields["shop_id"], shop, method.name)
            XCTAssertEqual(fields["did"], "d", method.name)
            XCTAssertEqual(fields["sid"], sdk.sessionId, method.name)
            XCTAssertEqual(fields["seance"], sdk.sessionId, method.name)
            XCTAssertEqual(fields["stream"], "ios", method.name)
            XCTAssertEqual(fields["segment"], sdk.segment, method.name)
            XCTAssertNil(fields["shop_secret"], method.name)
        }
        sdk.release()
    }

    func test_each_method_returns_its_value_in_async_code() {
        let shop = newShop()
        let sdk = makeV2(shop)
        for method in methods {
            answer(method.path, StubReply(json: method.answer))
            XCTAssertNil(asyncOutcome(method, sdk), method.name)
        }
        answer("/subscriptions/check", StubReply(400, json: #"{"status": "error", "message": "Client not found"}"#))
        XCTAssertEqual(asyncOutcome(methods[4], sdk), .http(code: 400, serverCode: nil))
        sdk.release()
    }

    func test_the_values_come_whole_through_the_core() {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer("/profile", StubReply(json: #"{"id": 7, "gender": "m", "custom_properties": {"vip": true, "tags": ["a"]}}"#))
        answer("/segments/get", StubReply(json: #"[{"id": "313", "type": "static"}, {"type": "dynamic"}]"#))
        let done = expectation(description: "values")
        done.expectedFulfillmentCount = 2
        let profile = Locked<Rees46.Profile?>(nil)
        let segments = Locked<[Rees46.Segment]>([])
        sdk.profile.get { result in
            profile.current = try? result.get()
            done.fulfill()
        }
        sdk.segments.get { result in
            segments.current = (try? result.get()) ?? []
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(profile.current?.id, "7")
        XCTAssertEqual(profile.current?.gender, .male)
        XCTAssertEqual(profile.current?.customProperties?["vip"] as? Bool, true)
        XCTAssertEqual(segments.current, [Rees46.Segment(id: 313, type: "static")])
        sdk.release()
    }

    func test_a_refused_argument_sends_nothing_and_is_logged_with_the_call() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let done = expectation(description: "refused")
        done.expectedFulfillmentCount = 3
        let errors = Locked<[Rees46.SdkError]>([])
        let record: (Result<Void, Rees46.SdkError>) -> Void = { result in
            if case .failure(let error) = result { errors.mutate { $0.append(error) } }
            done.fulfill()
        }
        sdk.profile.set(Rees46.ProfileUpdateRequest(customProperties: ["when": Date()]), completion: record)
        sdk.subscriptions.manage(Rees46.SubscriptionsUpdateRequest(email: "jane@example.com"), completion: record)
        sdk.segments.add(segmentId: 0, completion: record)
        wait(for: [done], timeout: 5)
        XCTAssertEqual(errors.current.count, 3)
        XCTAssertTrue(errors.current.allSatisfy { if case .invalidArgument = $0 { return true } else { return false } }, "\(errors.current)")
        XCTAssertTrue(requests("/profile/set", shop).isEmpty)
        XCTAssertTrue(requests("/subscriptions/manage", shop).isEmpty)
        XCTAssertTrue(requests("/segments/add", shop).isEmpty)
        XCTAssertTrue(eventually { Set(self.logged(shop, "invalid_argument").compactMap { $0.context["call"] }).isSuperset(of: ["profile.set", "subscriptions.manage", "segments.add"]) })
        sdk.release()
    }

    func test_the_ab_group_is_the_devices_on_either_core() {
        let v2 = makeV2(newShop())
        XCTAssertEqual(v2.segments.getAbGroup(), v2.segment)
        XCTAssertTrue(["A", "B"].contains(v2.segments.getAbGroup()))
        v2.release()
        XCTAssertEqual(v2.segments.getAbGroup(), v2.segment, "the device's, after release() too")
        CoreFlag.reset()
        let legacy = makeLegacy(newShop())
        XCTAssertEqual(legacy.segments.getAbGroup(), legacy.segment)
        legacy.release()
    }

    // MARK: - The old core

    func test_on_the_old_core_each_method_is_not_initialized_sends_nothing_and_logs_its_name() {
        let shop = newShop()
        let sdk = makeLegacy(shop)
        for method in methods {
            XCTAssertEqual(outcome(method, sdk), .notInitialized, method.name)
            XCTAssertEqual(asyncOutcome(method, sdk), .notInitialized, method.name)
            XCTAssertTrue(requests(method.path, shop).isEmpty, method.name)
        }
        XCTAssertTrue(waitForLog(shop, "core_flag_mismatch"))
        let names = Set(methods.map(\.name))
        XCTAssertTrue(eventually { Set(self.logged(shop, "core_flag_mismatch").compactMap { $0.context["call"] }) == names })
        XCTAssertTrue(logged(shop, "core_flag_mismatch").allSatisfy { $0.level == .warning })
        sdk.release()
    }

    func test_another_conformer_of_the_protocol_is_not_initialized() {
        let fake = FakeSDK(shopId: "fake-\(UUID().uuidString)")
        for method in methods {
            XCTAssertEqual(outcome(method, fake), .notInitialized, method.name)
        }
    }
}

private extension Result {

    var failure: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

/// The server methods with the shop's secret — `profile.getOrders`, `cart.clear`,
/// `notifications.getHistory` — end to end over the stub server: the verb, the path and the query —
/// `shop_id` and the method's own fields, none of the device's —, the answers the live API gives and
/// its errors, the old core, and a secret that never reaches the log. The cases of each request and
/// answer are the package's (`SecretMethodsPackageTests`).
final class SecretMethodsNamespaceTests: CoreScenarioTestCase {

    private let secret = "the-shop-secret-7f3c"

    private struct Method {
        let name: String
        let path: String
        /// The query it sends for its arguments, beside `shop_id`.
        let sends: [String: String]
        let answer: String
        let call: (PersonalizationSDK, String, @escaping (Rees46.SdkError?) -> Void) -> Void
        let callAsync: (PersonalizationSDK, String) async throws -> Void
    }

    private lazy var methods: [Method] = [
        Method(
            name: "profile.getOrders", path: "/orders/by_user",
            sends: ["shop_secret": secret, "did": "given-did", "date_from": "2026-11-01"],
            answer: #"{"status": "success", "data": {"orders": [{"_id": 1, "id": "o-1", "value": "69990.0", "items": [], "history": []}]}}"#,
            call: { sdk, secret, done in sdk.profile.getOrders(shopSecret: secret, did: "given-did", dateFrom: "2026-11-01") { done($0.failure) } },
            callAsync: { sdk, secret in _ = try await sdk.profile.getOrders(shopSecret: secret, did: "given-did", dateFrom: "2026-11-01") }
        ),
        Method(
            name: "cart.clear", path: "/products/cart/clear",
            sends: ["shop_secret": secret, "external_id": "x-1"],
            answer: #"{"status": "success"}"#,
            call: { sdk, secret, done in sdk.cart.clear(shopSecret: secret, externalId: "x-1") { done($0.failure) } },
            callAsync: { sdk, secret in try await sdk.cart.clear(shopSecret: secret, externalId: "x-1") }
        ),
        Method(
            name: "notifications.getHistory", path: "/notifications",
            sends: ["shop_secret": secret, "type": "bulk", "channel": "mobile_push", "date_from": "2026-10-01", "email": "e@example.com"],
            answer: #"{"status": "success", "payload": {"messages": []}}"#,
            call: { sdk, secret, done in
                sdk.notifications.getHistory(shopSecret: secret, type: "bulk", email: "e@example.com", channel: "mobile_push", dateFrom: "2026-10-01") { done($0.failure) }
            },
            callAsync: { sdk, secret in
                _ = try await sdk.notifications.getHistory(shopSecret: secret, type: "bulk", email: "e@example.com", channel: "mobile_push", dateFrom: "2026-10-01")
            }
        ),
    ]

    private func outcome(_ method: Method, _ sdk: PersonalizationSDK, secret: String? = nil) -> Rees46.SdkError? {
        let done = expectation(description: method.name)
        let error = Locked<Rees46.SdkError?>(nil)
        method.call(sdk, secret ?? self.secret) { failure in
            XCTAssertTrue(Thread.isMainThread, method.name)
            error.current = failure
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return error.current
    }

    private func asyncOutcome(_ method: Method, _ sdk: PersonalizationSDK) -> Rees46.SdkError? {
        let done = expectation(description: "async \(method.name)")
        let error = Locked<Rees46.SdkError?>(nil)
        let secret = self.secret
        _Concurrency.Task {
            do {
                try await method.callAsync(sdk, secret)
            } catch let failure as Rees46.SdkError {
                error.current = failure
            } catch {
                XCTFail("\(method.name): \(error)")
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return error.current
    }

    func test_each_method_sends_get_with_shop_id_and_its_own_fields_alone() throws {
        let shop = newShop()
        let sdk = makeV2(shop)
        for method in methods {
            answer(method.path, StubReply(json: method.answer))
            XCTAssertNil(outcome(method, sdk), method.name)
            XCTAssertNil(asyncOutcome(method, sdk), method.name)
            let sent = requests(method.path, shop)
            XCTAssertEqual(sent.count, 2, method.name)
            let request = try XCTUnwrap(sent.last)
            XCTAssertEqual(request.method, "GET", method.name)
            var expected = method.sends
            expected["shop_id"] = shop
            XCTAssertEqual(request.query, expected, "\(method.name): no did, sid, seance, segment or stream of the device")
            XCTAssertTrue(request.body.isEmpty, method.name)
        }
        sdk.release()
    }

    func test_the_answers_are_read_into_the_released_models() {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer("/orders/by_user", StubReply(json: #"""
        {"status": "success", "data": {"orders": [{"_id": 61, "id": "sdk-test-ios-1", "date": "2026-11-18", "value": "85980.0",
         "cash_value": "0.0", "tax_free": false, "delivery_type": "pickup", "payment_type": "card", "gift_package": false,
         "custom_properties": {}, "history": [], "items": [{"amount": 1, "price": "69990.0", "item": {"id": "284730"}}]}]}}
        """#))
        answer("/notifications", StubReply(json: #"{"status": "success", "payload": {"messages": [{"type": "bulk", "code": "c-1", "subject": "Sale"}]}}"#))
        let done = expectation(description: "answers")
        done.expectedFulfillmentCount = 2
        let orders = Locked<[Order]>([])
        let history = Locked<UserPayloadResponse?>(nil)
        sdk.profile.getOrders(shopSecret: secret, externalId: "x") { orders.current = (try? $0.get()) ?? []; done.fulfill() }
        sdk.notifications.getHistory(shopSecret: secret, type: "bulk", channel: "mobile_push", dateFrom: "2026-10-01", did: "d") {
            history.current = try? $0.get()
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(orders.current.map(\.id), ["sdk-test-ios-1"])
        XCTAssertEqual(orders.current.first?.value, "85980.0")
        XCTAssertEqual(orders.current.first?.items.first?.item?.id, "284730")
        XCTAssertEqual(history.current?.notifications.map(\.codeId), ["c-1"])
        sdk.release()
    }

    func test_the_errors_of_the_server_are_its_http_codes_and_other_answers_decoding() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let errors: [(String, StubReply, Rees46.SdkError)] = [
            ("/orders/by_user", StubReply(403, json: #"{"status": "error", "message": "Shop secret is missing"}"#), .http(code: 403, serverCode: nil)),
            ("/products/cart/clear", StubReply(400, json: #"{"status": "error", "message": "Client not found"}"#), .http(code: 400, serverCode: nil)),
            ("/notifications", StubReply(404, json: #"{"status": "error", "message": "User is not found"}"#), .http(code: 404, serverCode: nil)),
        ]
        for (index, (path, reply, error)) in errors.enumerated() {
            answer(path, reply)
            XCTAssertEqual(outcome(methods[index], sdk), error, path)
        }
        answer("/orders/by_user", StubReply(json: #"{"status": "success"}"#))
        answer("/products/cart/clear", StubReply(json: #"{"cleared": true}"#))
        answer("/notifications", StubReply(json: #"{"status": "success", "messages": []}"#))
        for method in methods {
            XCTAssertEqual(outcome(method, sdk), .decoding, method.name)
        }
        sdk.release()
    }

    func test_a_refused_argument_sends_nothing() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let done = expectation(description: "refused")
        done.expectedFulfillmentCount = 4
        let errors = Locked<[Rees46.SdkError]>([])
        let orders: (Result<[Order], Rees46.SdkError>) -> Void = { if case .failure(let error) = $0 { errors.mutate { $0.append(error) } }; done.fulfill() }
        let cleared: (Result<Void, Rees46.SdkError>) -> Void = { if case .failure(let error) = $0 { errors.mutate { $0.append(error) } }; done.fulfill() }
        let history: (Result<UserPayloadResponse, Rees46.SdkError>) -> Void = { if case .failure(let error) = $0 { errors.mutate { $0.append(error) } }; done.fulfill() }
        sdk.profile.getOrders(shopSecret: secret, completion: orders)
        sdk.profile.getOrders(shopSecret: "", did: "d", completion: orders)
        sdk.cart.clear(shopSecret: secret, completion: cleared)
        sdk.notifications.getHistory(shopSecret: secret, type: "bulk", did: "d", completion: history)
        wait(for: [done], timeout: 5)
        XCTAssertEqual(errors.current.count, 4)
        XCTAssertTrue(errors.current.allSatisfy { if case .invalidArgument = $0 { return true } else { return false } }, "\(errors.current)")
        for method in methods {
            XCTAssertTrue(requests(method.path, shop).isEmpty, method.name)
        }
        sdk.release()
    }

    func test_the_secret_never_reaches_the_log() {
        let shop = newShop()
        let sdk = makeV2(shop)
        for method in methods {
            answer(method.path, StubReply(403, json: #"{"status": "error", "message": "Shop secret is missing"}"#))
            _ = outcome(method, sdk)
            answer(method.path, StubReply(json: "not json"))
            _ = outcome(method, sdk)
        }
        sdk.profile.getOrders(shopSecret: secret, did: " ") { _ in }
        XCTAssertTrue(eventually { self.logged(shop, "request").count + self.logged(shop, "request_failed").count >= 3 })
        drainMainQueue()
        let lines = heard.flatMap { [$0.message] + $0.context.values }
        XCTAssertFalse(lines.isEmpty)
        XCTAssertFalse(lines.contains { $0.contains(secret) }, "the secret is not in the log")
        sdk.release()
    }

    func test_on_the_old_core_each_method_is_not_initialized_sends_nothing_and_logs_its_name() {
        let shop = newShop()
        let sdk = makeLegacy(shop)
        for method in methods {
            XCTAssertEqual(outcome(method, sdk), .notInitialized, method.name)
            XCTAssertEqual(asyncOutcome(method, sdk), .notInitialized, method.name)
            XCTAssertTrue(requests(method.path, shop).isEmpty, method.name)
        }
        let names = Set(methods.map(\.name))
        XCTAssertTrue(eventually { Set(self.logged(shop, "core_flag_mismatch").compactMap { $0.context["call"] }) == names })
        sdk.release()
    }

    func test_another_conformer_of_the_protocol_is_not_initialized() {
        let fake = FakeSDK(shopId: "fake-\(UUID().uuidString)")
        for method in methods {
            XCTAssertEqual(outcome(method, fake), .notInitialized, method.name)
        }
    }
}
