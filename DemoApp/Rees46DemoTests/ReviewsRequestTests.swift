//
//  ReviewsRequestTests.swift
//  REES46Tests
//
//  `reviews` end to end over the stub server: each call of the proposed fixture sends its request to its
//  host — the polls to `appDomain`, the reviews of products to the API — with the common fields, or
//  refuses its argument and sends nothing; each answer ends as the fixture says, its `completion` on the
//  main thread; the `async` forms; the old core's refusal of every method.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class ReviewsRequestTests: CoreScenarioTestCase {

    /// The fields the core adds to every request but `/init`.
    private static let commonFields: Set<String> = ["shop_id", "did", "sid", "seance", "stream", "segment"]

    /// The paths of the namespace on the stub server.
    private static let paths = [
        "/api/v3/polls/nps/reviews", "/api/v3/polls/csat/reviews", "/api/v3/polls/ces/reviews",
        "/api/v3/polls/nps/categories", "/api/v3/polls/nps/channels", "/api/v3/polls/csat/campaigns",
        "/api/v3/polls/ces/campaigns", "/reviews/product", "/reviews/client",
    ]

    private func fixture() throws -> [ContractCase] {
        try ContractFixtures.fixture("reviews", from: .proposed)
    }

    /// The call of `item` through `sdk.reviews`: what its `completion` got, on the main thread.
    private func run(_ item: ContractCase, on sdk: PersonalizationSDK, file: StaticString = #filePath, line: UInt = #line) -> Result<Any, Rees46.SdkError>? {
        guard let call = item.call else { return nil }
        let done = expectation(description: item.name)
        let outcome = Locked<Result<Any, Rees46.SdkError>?>(nil)
        ReviewsFixtureCalls.run(call, on: sdk.reviews) { result in
            XCTAssertTrue(Thread.isMainThread, "\(item.name): completion on the main thread", file: file, line: line)
            outcome.current = result
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return outcome.current
    }

    private func sentToTheNamespace(_ shop: String) -> Int {
        Self.paths.reduce(0) { $0 + requests($1, shop).count }
    }

    // MARK: - Requests

    func test_each_call_of_the_fixture_sends_its_request_to_its_host_with_the_common_fields() throws {
        let shop = newShop()
        let sdk = makeV2(shop)
        let cases = try fixture().filter { $0.request != nil }
        XCTAssertGreaterThanOrEqual(cases.count, 12)
        for item in cases {
            let expected = try XCTUnwrap(item.request)
            _ = run(item, on: sdk)
            let sent = try XCTUnwrap(requests("/" + expected.path, shop).last, item.name)
            XCTAssertEqual(sent.method, expected.method, item.name)
            // The polls on the host of API v3 — `app.rees46.ru` unless the config names another —, the
            // reviews of products on the API's.
            let host = ReviewsFixtureCalls.host(of: expected.path) == .app ? Rees46Config(shopId: shop).appDomain : "stub.test"
            XCTAssertEqual(sent.url?.host, host, item.name)
            XCTAssertEqual(sent.url?.scheme, "https", item.name)
            let isGet = expected.method == "GET"
            let fields: [String: Any] = isGet ? sent.query as [String: Any] : sent.body
            let listed = isGet ? Array(expected.query.keys) : Array(expected.body.keys)
            XCTAssertEqual(Set(fields.keys).subtracting(Self.commonFields), Set(listed), "\(item.name): only the fields the case lists")
            if isGet {
                for (key, value) in expected.query {
                    XCTAssertEqual(sent.query[key], value, "\(item.name): \(key)")
                }
            } else {
                for (key, value) in expected.body {
                    XCTAssertEqual(ReviewsFixtureCalls.canonical(sent.body[key] ?? NSNull()), ReviewsFixtureCalls.canonical(value), "\(item.name): \(key)")
                }
            }
            // What the core adds, on either host: the API v3 finds the customer by the device id too.
            XCTAssertEqual(fields["shop_id"] as? String, shop, item.name)
            XCTAssertEqual(fields["did"] as? String, "d", item.name)
            XCTAssertEqual(fields["sid"] as? String, sdk.sessionId, item.name)
            XCTAssertEqual(fields["seance"] as? String, sdk.sessionId, item.name)
            XCTAssertEqual(fields["stream"] as? String, "ios", item.name)
            XCTAssertEqual(fields["segment"] as? String, sdk.segment, item.name)
            XCTAssertEqual(sent.timeout, NetworkClient.defaultTimeout, item.name)
        }
        sdk.release()
    }

    func test_a_call_the_fixture_refuses_is_invalid_argument_and_sends_nothing() throws {
        let shop = newShop()
        let sdk = makeV2(shop)
        let cases = try fixture().filter { $0.call != nil && $0.request == nil && $0.response == nil }
        XCTAssertGreaterThanOrEqual(cases.count, 15)
        for item in cases {
            let result = run(item, on: sdk)
            guard case .failure(let error)? = result else {
                XCTFail("\(item.name): \(String(describing: result))")
                continue
            }
            XCTAssertTrue(item.expectedError?.matches(error) == true, "\(item.name): \(error)")
        }
        XCTAssertEqual(sentToTheNamespace(shop), 0, "nothing was sent")
        XCTAssertTrue(waitForLog(shop, "invalid_argument"))
        XCTAssertTrue(logged(shop, "invalid_argument").allSatisfy { $0.context["call"]?.hasPrefix("reviews.") == true })
        sdk.release()
    }

    // MARK: - Answers

    func test_each_answer_of_the_fixture_ends_as_the_fixture_says_without_a_repeat() throws {
        let shop = newShop()
        let sdk = makeV2(shop)
        let cases = try fixture().filter { $0.response != nil }
        XCTAssertGreaterThanOrEqual(cases.count, 20)
        for item in cases {
            let call = try XCTUnwrap(item.call, item.name)
            let response = try XCTUnwrap(item.response)
            let path = "/" + (try ReviewsFixtureCalls.request(for: call).path)
            // No status: no answer — a connection never made.
            answer(path, response.status.map { StubReply($0, json: String(decoding: response.body, as: UTF8.self)) } ?? StubReply.noAnswer)
            let before = requests(path, shop).count
            let result = run(item, on: sdk)
            XCTAssertEqual(requests(path, shop).count, before + 1, "\(item.name): one request, not repeated")
            switch result {
            case .success(let value)?:
                XCTAssertNil(item.expectedError, "\(item.name): \(value)")
                XCTAssertTrue(
                    ReviewsFixtureCalls.matches(value, item.expect["result"]),
                    "\(item.name): \(ReviewsFixtureCalls.canonical(ReviewsFixtureCalls.json(value)))"
                )
            case .failure(let error)?:
                XCTAssertTrue(item.expectedError?.matches(error) == true, "\(item.name): \(error)")
            case nil:
                XCTFail("\(item.name): no outcome")
            }
        }
        // A 402, 403 or 404 of one service does not move the state of the instance.
        XCTAssertEqual(sdk.state, .ready)
        sdk.release()
    }

    // MARK: - The host of API v3

    func test_the_polls_go_to_the_app_domain_of_the_config_and_the_reviews_of_products_to_the_api() {
        CoreFlag.reset()
        let shop = newShop()
        let config = Rees46Config(shopId: shop, apiDomain: "stub.test", appDomain: "app.cluster.test", autoSendPushToken: false)
        guard let sdk = Rees46.initializeBridge(config) as? SimplePersonalizationSDK else {
            return XCTFail("no instance")
        }
        answer("/api/v3/polls/nps/channels", StubReply(json: #"{"status":"success","payload":{"channels":[{"code":"ios_app","name":"App"}]}}"#))
        let channels = expectation(description: "getNpsChannels")
        let read = Locked<[PollChannel]>([])
        sdk.reviews.getNpsChannels { result in
            read.current = (try? result.get()) ?? []
            channels.fulfill()
        }
        wait(for: [channels], timeout: 15)
        XCTAssertEqual(read.current, [PollChannel(code: "ios_app", name: "App")])
        XCTAssertEqual(requests("/api/v3/polls/nps/channels", shop).last?.url?.host, "app.cluster.test")

        let reviews = expectation(description: "getProductReviews")
        sdk.reviews.getProductReviews(itemId: "37") { _ in reviews.fulfill() }
        wait(for: [reviews], timeout: 15)
        XCTAssertEqual(requests("/reviews/product", shop).last?.url?.host, "stub.test")
        XCTAssertEqual(requests("/reviews/product", shop).last?.query["product"], "37")
        sdk.release()
    }

    // MARK: - async

    func test_the_async_forms_return_the_value_and_throw_the_error() {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer("/api/v3/polls/nps/reviews", StubReply(json: #"{"status":"success","payload":{"review":{"id":512}}}"#))
        answer("/api/v3/polls/ces/reviews", StubReply(404, json: #"{"status":"fail","message":"Campaign not found"}"#))
        answer("/reviews/client", StubReply(json: #"{"status":"success","payload":{"reviews":[{"id":1,"product":"37","order":"A-1","rating":5,"state":"published","created_at":"2026-11-10T12:00:00+03:00"}]}}"#))
        let reviews: ReviewsAPI = sdk.reviews
        let done = expectation(description: "async")
        let outcome = Locked<(PollReview?, Rees46.SdkError?, [ClientReview], Rees46.SdkError?)>((nil, nil, [], nil))
        _Concurrency.Task {
            let score = try? await reviews.createNps(rate: 10, channel: "ios_app", category: "delivery")
            var failed: Rees46.SdkError?
            do {
                _ = try await reviews.createCes(rate: 7, channel: "ios_app", campaign: "checkout", orderId: "A-1", comment: nil, label: nil)
            } catch {
                failed = error as? Rees46.SdkError
            }
            let mine = (try? await reviews.getClientReviews(orderId: "A-1")) ?? []
            var refused: Rees46.SdkError?
            do {
                _ = try await reviews.getProductReviews(itemId: "37", limit: 0, offset: nil)
            } catch {
                refused = error as? Rees46.SdkError
            }
            outcome.current = (score, failed, mine, refused)
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        XCTAssertEqual(outcome.current.0, PollReview(id: 512))
        XCTAssertEqual(outcome.current.1, .http(code: 404, serverCode: nil))
        XCTAssertEqual(outcome.current.2, [ClientReview(id: 1, itemId: "37", orderId: "A-1", rating: 5, state: .published, createdAt: "2026-11-10T12:00:00+03:00")])
        XCTAssertEqual(outcome.current.3, .invalidArgument("limit must be from 1 to 100"))
        // The call without the optional arguments sends none of them.
        let score = requests("/api/v3/polls/nps/reviews", shop).last?.body ?? [:]
        XCTAssertEqual(Set(score.keys).subtracting(Self.commonFields), ["rate", "channel", "category"])
        XCTAssertEqual(requests("/api/v3/polls/ces/reviews", shop).last?.body["order_id"] as? String, "A-1")
        XCTAssertTrue(requests("/reviews/product", shop).isEmpty)
        sdk.release()
    }

    // MARK: - The new core only

    func test_on_the_old_core_every_method_is_not_initialized_sends_nothing_and_says_why() throws {
        let shop = newShop()
        let sdk = makeLegacy(shop)
        // One call of each method, with arguments it would take.
        var calls: [String: ContractCase] = [:]
        for item in try fixture() where item.request != nil {
            if let method = item.call?.method, calls[method] == nil {
                calls[method] = item
            }
        }
        XCTAssertEqual(calls.count, 9)
        for item in calls.values {
            guard case .failure(let error)? = run(item, on: sdk) else {
                XCTFail("\(item.name): not refused")
                continue
            }
            XCTAssertEqual(error, .notInitialized, item.name)
        }
        XCTAssertEqual(sentToTheNamespace(shop), 0)
        XCTAssertTrue(eventually { Set(self.logged(shop, "core_flag_mismatch").compactMap { $0.context["call"] }).count == 9 })
        let said = Set(logged(shop, "core_flag_mismatch").compactMap { $0.context["call"] })
        XCTAssertEqual(said, Set(calls.keys.map { "reviews.\($0)" }))
        XCTAssertTrue(logged(shop, "core_flag_mismatch").allSatisfy { $0.level == .warning })
        XCTAssertTrue(heard.filter { $0.shopId == shop }.allSatisfy(LogContract.allows))
        sdk.release()
    }
}
