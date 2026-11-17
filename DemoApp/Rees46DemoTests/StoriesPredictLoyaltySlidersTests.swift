//
//  StoriesPredictLoyaltySlidersTests.swift
//  REES46Tests
//
//  `stories`, `predict`, `loyalty`, `sliders` and the banner events of `tracking` end to end over the
//  stub server, by their proposed fixtures: the requests with the common fields, the arguments refused
//  without a request, each answer, the old core's refusal, the `async` forms; the banner events through
//  the new core's queue. What a method makes of an answer field by field is in the package tests.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class StoriesPredictLoyaltySlidersTests: CoreScenarioTestCase {

    private static let fixtures = ["stories", "predict", "loyalty", "sliders"]

    /// The cases of every fixture of these namespaces, with the file's own case for the query's lists.
    private func cases() throws -> [(item: ContractCase, raw: [String: Any])] {
        try Self.fixtures.flatMap { name in
            try ContractFixtures.cases(name, from: .proposed).map { (ContractCase($0), $0) }
        }
    }

    // MARK: - Calls

    /// The method of `call` with its arguments, through `completion`; what it got. The completion comes on
    /// the main thread.
    private func run(_ call: ContractCase.Call, on sdk: PersonalizationSDK, file: StaticString = #filePath, line: UInt = #line) -> Result<Any, Rees46.SdkError>? {
        let done = expectation(description: call.name)
        let outcome = Locked<Result<Any, Rees46.SdkError>?>(nil)
        func finish<T>(_ result: Result<T, Rees46.SdkError>) {
            XCTAssertTrue(Thread.isMainThread, "\(call.name): completion on the main thread", file: file, line: line)
            outcome.current = result.map { $0 as Any }
            done.fulfill()
        }
        let args = call.args
        let text = { (key: String) in args[key] as? String }
        switch call.name {
        case "stories.get":
            sdk.stories.get(code: text("code") ?? "") { finish($0) }
        case "predict.getProbabilityToPurchase":
            sdk.predict.getProbabilityToPurchase { finish($0) }
        case "loyalty.join":
            let gender = text("gender").map { $0 == "male" ? Gender.male : Gender.female }
            sdk.loyalty.join(
                phone: text("phone") ?? "", firstName: text("firstName"), lastName: text("lastName"),
                gender: gender, birthday: text("birthday")
            ) { finish($0) }
        case "loyalty.getStatus":
            sdk.loyalty.getStatus(phone: text("phone") ?? "") { finish($0) }
        case "loyalty.getPromotions":
            sdk.loyalty.getPromotions(
                locationId: text("locationId"), promoCodes: args["promoCodes"] as? [String],
                chargeBonuses: args["chargeBonuses"] as? Bool, currentTime: text("currentTime")
            ) { finish($0) }
        case "sliders.get":
            sdk.sliders.get(code: text("code") ?? "", tags: args["tags"] as? [String], locationId: text("locationId")) { finish($0) }
        case "tracking.bannerView":
            sdk.tracking.bannerView(bannerId: text("bannerId") ?? "", code: text("code") ?? "") { finish($0) }
        case "tracking.bannerClick":
            sdk.tracking.bannerClick(bannerId: text("bannerId") ?? "", code: text("code") ?? "") { finish($0) }
        default:
            XCTFail("\(call.name): a method the test does not know", file: file, line: line)
            return nil
        }
        wait(for: [done], timeout: 5)
        return outcome.current
    }

    private func error(of result: Result<Any, Rees46.SdkError>?) -> Rees46.SdkError? {
        if case .failure(let error)? = result { return error }
        return nil
    }

    /// Every request of these namespaces the stub saw for `shop`.
    private func sent(_ shop: String) -> [StubRequest] {
        StubURLProtocol.requests.filter { request in
            (request.query["shop_id"] ?? request.body["shop_id"] as? String) == shop
                && ["/stories/", "/predict/", "/loyalty/", "/slider", "/track/slider"].contains { request.path.hasPrefix($0) }
        }
    }

    // MARK: - The fixtures

    func test_each_method_sends_the_fixtures_request_with_the_common_fields() throws {
        let shop = newShop()
        let sdk = makeV2(shop)
        // The events of the banners go through the queue: their own test is below.
        let cases = try cases().filter { $0.item.request != nil && $0.item.call?.namespace != "tracking" }
        XCTAssertEqual(cases.count, 9)
        for (item, raw) in cases {
            let call = try XCTUnwrap(item.call, item.name)
            let expected = try XCTUnwrap(item.request)
            let path = "/" + expected.path
            let before = requests(path, shop).count
            _ = run(call, on: sdk)
            XCTAssertEqual(requests(path, shop).count, before + 1, "\(item.name): one request")
            let request = try XCTUnwrap(requests(path, shop).last, item.name)
            XCTAssertEqual(request.method, expected.method, item.name)
            XCTAssertEqual(request.timeout, NetworkClient.defaultTimeout, "\(item.name): the general timeout")
            let rawQuery = (raw["request"] as? [String: Any])?["query"] as? [String: Any] ?? [:]
            let items = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
            for (key, value) in rawQuery {
                if let list = value as? [String] {
                    XCTAssertEqual(items.filter { $0.name == key }.map(\.value), list, "\(item.name): \(key), a list of Rails")
                } else {
                    XCTAssertEqual(request.query[key], "\(value)", "\(item.name): \(key)")
                }
            }
            for (key, value) in expected.body {
                XCTAssertTrue((request.body[key] as AnyObject?)?.isEqual(value) ?? false, "\(item.name): \(key) = \(String(describing: request.body[key]))")
            }
            // What the core adds: in the query of a GET, in the body of a POST.
            let common: [String: String?] = request.method == "GET"
                ? ["shop_id": request.query["shop_id"], "did": request.query["did"], "sid": request.query["sid"],
                   "seance": request.query["seance"], "stream": request.query["stream"], "segment": request.query["segment"]]
                : ["shop_id": request.body["shop_id"] as? String, "did": request.body["did"] as? String,
                   "sid": request.body["sid"] as? String, "seance": request.body["seance"] as? String,
                   "stream": request.body["stream"] as? String, "segment": request.body["segment"] as? String]
            XCTAssertEqual(common["shop_id"], shop, item.name)
            XCTAssertEqual(common["did"], "d", item.name)
            XCTAssertEqual(common["sid"], sdk.sessionId, item.name)
            XCTAssertEqual(common["seance"], sdk.sessionId, "\(item.name): seance, which loyalty's promotions read")
            XCTAssertEqual(common["stream"], "ios", item.name)
            XCTAssertEqual(common["segment"], sdk.segment, item.name)
            // The customer is the device id: no contact, and never the shop's secret. `loyalty.join` sends
            // the phone of the member it makes.
            for field in ["email", "external_id", "loyalty_id", "telegram_id", "shop_secret"] {
                XCTAssertNil(request.query[field], "\(item.name): no \(field)")
                XCTAssertNil(request.body[field], "\(item.name): no \(field)")
            }
            XCTAssertNil(request.query["phone"], "\(item.name): no phone")
        }
        sdk.release()
    }

    func test_an_argument_the_contract_refuses_ends_with_invalid_argument_and_sends_nothing() throws {
        let shop = newShop()
        let sdk = makeV2(shop)
        let cases = try cases().filter { $0.item.expectedError != nil && $0.item.response == nil }
        XCTAssertEqual(cases.count, 12)
        for (item, _) in cases {
            let call = try XCTUnwrap(item.call, item.name)
            let result = run(call, on: sdk)
            guard case .invalidArgument? = error(of: result) else {
                XCTFail("\(item.name): \(String(describing: result))")
                continue
            }
            XCTAssertTrue(waitForLog(shop, "invalid_argument"), item.name)
            XCTAssertTrue(logged(shop, "invalid_argument").contains { $0.context["call"] == call.name }, item.name)
        }
        XCTAssertTrue(sent(shop).isEmpty, "\(sent(shop).map(\.path))")
        XCTAssertTrue(files(sdk.storage).isEmpty, "no event queued")
        sdk.release()
    }

    func test_each_answer_of_the_fixtures_ends_as_they_say_without_a_repeat() throws {
        let shop = newShop()
        let sdk = makeV2(shop)
        let cases = try cases().filter { $0.item.response != nil }
        XCTAssertFalse(cases.isEmpty)
        for (item, _) in cases {
            let call = try XCTUnwrap(item.call, item.name)
            let response = try XCTUnwrap(item.response)
            let path = try XCTUnwrap(Self.path(of: call), item.name)
            answer(path, response.status.map { StubReply($0, json: String(decoding: response.body, as: UTF8.self)) } ?? StubReply.noAnswer)
            let before = requests(path, shop).count
            let result = run(call, on: sdk)
            XCTAssertEqual(requests(path, shop).count, before + 1, "\(item.name): one request, not repeated")
            switch result {
            case .success?:
                XCTAssertNil(item.expectedError, item.name)
            case .failure(let error)?:
                XCTAssertTrue(item.expectedError?.matches(error) == true, "\(item.name): \(error)")
            case nil:
                XCTFail("\(item.name): no outcome")
            }
        }
        XCTAssertEqual(sdk.state, .ready, "an error of one request does not move the state")
        sdk.release()
    }

    /// The stub's path of a call with an answer in the fixtures.
    private static func path(of call: ContractCase.Call) -> String? {
        switch call.name {
        case "stories.get": return "/stories/\(call.args["code"] as? String ?? "")"
        case "predict.getProbabilityToPurchase": return "/predict/probability-to-purchase"
        case "loyalty.join": return "/loyalty/members/join"
        case "loyalty.getStatus": return "/loyalty/members/status"
        case "loyalty.getPromotions": return "/loyalty/promos/for-client"
        case "sliders.get": return "/slider"
        default: return nil
        }
    }

    // MARK: - The new core only

    func test_on_the_old_core_every_method_is_not_initialized_sends_nothing_and_logs_core_flag_mismatch() throws {
        let shop = newShop()
        let sdk = makeLegacy(shop)
        let calls = try cases().compactMap { $0.item.request != nil ? $0.item.call : nil }
        let names = Set(calls.map(\.name))
        XCTAssertEqual(names.count, 8, "\(names)")
        for call in calls {
            XCTAssertEqual(error(of: run(call, on: sdk)), .notInitialized, call.name)
        }
        XCTAssertTrue(sent(shop).isEmpty, "\(sent(shop).map(\.path))")
        XCTAssertTrue(waitForLog(shop, "core_flag_mismatch"))
        let mismatches = logged(shop, "core_flag_mismatch")
        XCTAssertEqual(Set(mismatches.compactMap { $0.context["call"] }), names)
        XCTAssertTrue(mismatches.allSatisfy { $0.level == .warning && $0.message.contains("Rees46.initializeBridge") })
        XCTAssertTrue(heard.filter { $0.shopId == shop }.allSatisfy(LogContract.allows))
        sdk.release()
    }

    func test_another_conformer_of_the_protocol_is_not_initialized() {
        let fake = FakeSDK(shopId: "fake-\(UUID().uuidString)")
        let view = ContractCase.Call(namespace: "tracking", method: "bannerView", args: ["bannerId": "12", "code": "main"])
        XCTAssertEqual(error(of: run(view, on: fake)), .notInitialized)
        let slider = ContractCase.Call(namespace: "sliders", method: "get", args: ["code": "main"])
        XCTAssertEqual(error(of: run(slider, on: fake)), .notInitialized)
        XCTAssertTrue(waitForLog(nil, "not_implemented"))
        XCTAssertTrue(logged(nil, "not_implemented").contains { $0.context["call"] == "tracking.bannerView" })
    }

    // MARK: - The events of the banners

    func test_banner_events_complete_once_queued_and_go_with_the_device_and_the_session() throws {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer("/track/slider", StubReply(204, json: ""))
        let events = try cases().filter { $0.item.call?.namespace == "tracking" && $0.item.request != nil }
        XCTAssertEqual(events.count, 2)
        network.isOnline = false
        for (item, _) in events {
            let result = run(try XCTUnwrap(item.call), on: sdk)
            guard case .success? = result else { return XCTFail("\(item.name): \(String(describing: result))") }
        }
        XCTAssertEqual(files(sdk.storage).count, 2, "accepted: on disk, not sent")
        XCTAssertTrue(requests("/track/slider", shop).isEmpty)

        network.isOnline = true
        XCTAssertTrue(eventually { self.requests("/track/slider", shop).count == 2 })
        let sent = requests("/track/slider", shop)
        for ((item, _), request) in zip(events, sent) {
            XCTAssertEqual(request.method, "POST")
            for (key, value) in item.request?.body ?? [:] {
                XCTAssertTrue((request.body[key] as AnyObject?)?.isEqual(value) ?? false, "\(item.name): \(key) = \(String(describing: request.body[key]))")
            }
            XCTAssertTrue(request.body["banner_id"] is NSNumber, "\(item.name): banner_id is a number")
            XCTAssertNil(request.body["recommended_by"], "\(item.name): the address does not read it")
            XCTAssertNil(request.body["source"], item.name)
            XCTAssertEqual(request.body["did"] as? String, "d")
            XCTAssertEqual(request.body["sid"] as? String, sdk.sessionId)
            XCTAssertEqual(request.body["shop_id"] as? String, shop)
        }
        XCTAssertTrue(queueIdle(sdk))
        XCTAssertTrue(files(sdk.storage).isEmpty, "204: sent")
        sdk.release()
    }

    func test_a_banner_event_of_a_refused_shop_is_shop_blocked_and_after_release_not_initialized() {
        let view = ContractCase.Call(namespace: "tracking", method: "bannerView", args: ["bannerId": "12", "code": "main"])
        let refusedShop = newShop()
        answer("/init", StubReply(402, json: #"{"status":"error","message":"Restricted Mode"}"#))
        let refused = makeV2(refusedShop, settled: false)
        XCTAssertTrue(eventually { refused.state == .refused })
        XCTAssertEqual(error(of: run(view, on: refused)), .shopBlocked)
        refused.release()

        answer("/init")
        let shop = newShop()
        let sdk = makeV2(shop)
        sdk.release()
        XCTAssertEqual(error(of: run(view, on: sdk)), .notInitialized)
        XCTAssertTrue(requests("/track/slider", shop).isEmpty)
        XCTAssertTrue(requests("/track/slider", refusedShop).isEmpty)
    }

    // MARK: - async

    func test_the_async_forms_return_the_value_and_throw_the_error() throws {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer("/stories/abc", StubReply(json: #"{"id":35,"stories":[{"id":39,"slides":[]}]}"#))
        answer("/predict/probability-to-purchase", StubReply(json: #"{"probability":0.42,"client_id":null}"#))
        answer("/loyalty/members/join", StubReply(json: #"{"status":"success","payload":{"identifier":"79991234567"}}"#))
        answer("/loyalty/members/status", StubReply(json: #"{"status":"success","payload":{"member":false,"level":null}}"#))
        answer("/loyalty/promos/for-client", StubReply(json: #"{"status":"success","payload":{"promotions":[{"id":3,"name":"P"}]}}"#))
        answer("/slider", StubReply(404, json: #"{"status":"error","message":"Slider not found"}"#))
        let done = expectation(description: "async")
        let outcome = Locked<[String]>([])
        _Concurrency.Task {
            var seen: [String] = []
            do {
                let block = try await sdk.stories.get(code: "abc")
                seen.append("stories \(block.stories.map(\.id))")
                let probability = try await sdk.predict.getProbabilityToPurchase()
                seen.append("predict \(probability.probability) \(probability.clientId ?? "none")")
                let member = try await sdk.loyalty.join(phone: "+79991234567")
                seen.append("join \(member.identifier)")
                let status = try await sdk.loyalty.getStatus(phone: "+79991234567")
                seen.append("status \(status.isMember)")
                let promotions = try await sdk.loyalty.getPromotions()
                seen.append("promotions \(promotions.map(\.id))")
                try await sdk.tracking.bannerView(bannerId: "12", code: "main")
                try await sdk.tracking.bannerClick(bannerId: "12", code: "main")
                seen.append("banners")
                _ = try await sdk.sliders.get(code: "nope")
            } catch let error as Rees46.SdkError {
                seen.append("\(error)")
            } catch {
                seen.append("not an SdkError: \(error)")
            }
            do {
                try await sdk.tracking.bannerView(bannerId: "", code: "main")
            } catch let error as Rees46.SdkError {
                if case .invalidArgument = error { seen.append("invalidArgument") }
            } catch {
                seen.append("not an SdkError: \(error)")
            }
            outcome.current = seen
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        XCTAssertEqual(outcome.current, [
            "stories [\"39\"]",
            "predict 0.42 none",
            "join 79991234567",
            "status false",
            "promotions [3]",
            "banners",
            "\(Rees46.SdkError.http(code: 404, serverCode: nil))",
            "invalidArgument",
        ])
        sdk.release()
    }
}
