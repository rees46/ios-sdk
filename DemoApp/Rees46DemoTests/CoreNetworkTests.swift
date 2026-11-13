//
//  CoreNetworkTests.swift
//  REES46Tests
//
//  The new core's client over the stub server (`sdk/core/network.md`): what an answer means,
//  timeouts, cut bodies, no network, cancellation, the common fields and `Retry-After`; the one
//  mapping to the old errors; the process's core flag; and the SDK's funnel on `CoreV2`.
//

import XCTest
@testable import REES46

final class CoreNetworkTests: XCTestCase {

    private var shopId = ""
    private let fields = CommonFields(shopId: "shop-1", deviceId: "did-1", sessionId: "sid-1", stream: "ios", segment: "A")

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        shopId = StubSDK.shopId()
    }

    override func tearDown() {
        StubURLProtocol.uninstall()
        StubSDK.removeSavedInit(shopId: shopId)
        CoreFlag.reset()
        super.tearDown()
    }

    private func client(online: Bool = true, fields: CommonFields? = nil) -> (NetworkClient, FakeConnectivity) {
        let connectivity = FakeConnectivity(online: online)
        let common = fields ?? self.fields
        let client = NetworkClient(
            baseURL: "https://stub.test/",
            connectivity: connectivity,
            logger: SdkLogger(shopId: "core-network", level: .none)
        ) { common }
        return (client, connectivity)
    }

    private func reply(_ path: String, _ reply: StubReply) {
        StubURLProtocol.handler = { $0.path == path ? reply : StubReply() }
    }

    private func requests(_ path: String) -> [StubRequest] {
        StubURLProtocol.requests(to: path)
    }

    // MARK: - What an answer means

    func test_any_2xx_is_a_success_and_an_empty_body_is_an_empty_success() async {
        let (client, _) = client()
        reply("/ok", StubReply(200, json: #"{"a":1}"#))
        let ok = await client.send(.init(method: .get, path: "ok"))
        XCTAssertEqual((try? ok.result.get()) as? [String: Int], ["a": 1])
        XCTAssertEqual(ok.status, 200)

        reply("/empty", StubReply(204, json: ""))
        let empty = await client.send(.init(method: .post, path: "empty"))
        XCTAssertEqual(((try? empty.result.get()) as? [String: Any])?.count, 0)

        reply("/edge", StubReply(299, json: "[1,2]"))
        let edge = await client.send(.init(method: .get, path: "edge"))
        XCTAssertEqual((try? edge.result.get()) as? [Int], [1, 2], "299 is a 2xx too")
    }

    func test_a_body_that_does_not_parse_is_decoding() async {
        let (client, _) = client()
        reply("/garbage", StubReply(200, json: "<html>not json</html>"))
        let response = await client.send(.init(method: .get, path: "garbage"))
        XCTAssertEqual(response.result.failure, .decoding)
    }

    func test_an_answer_outside_2xx_is_http_with_its_code() async {
        let (client, _) = client()
        for code in [400, 402, 403, 404, 417, 429, 500, 503] {
            reply("/fail", StubReply(code, json: #"{"status":"error","message":"Invalid email buyer@example.com"}"#))
            let response = await client.send(.init(method: .post, path: "fail"))
            XCTAssertEqual(response.result.failure, .http(code: code, serverCode: nil), "\(code)")
            XCTAssertEqual(response.status, code)
        }
    }

    func test_no_answer_within_the_timeout_is_timeout() async {
        let (client, _) = client()
        reply("/slow", StubReply(delay: 2))
        let started = Date()
        let response = await client.send(.init(method: .get, path: "slow", timeout: 0.3))
        XCTAssertEqual(response.result.failure, .timeout)
        XCTAssertNil(response.status)
        XCTAssertLessThan(Date().timeIntervalSince(started), 1.5)
    }

    func test_a_body_cut_midway_is_never_a_success() async {
        let (client, _) = client()
        reply("/dropped", StubReply(200, json: #"{"products":[1,2,3,4,5,6,7,8]}"#, cutAfter: 5))
        let dropped = await client.send(.init(method: .get, path: "dropped"))
        XCTAssertEqual(dropped.result.failure, .network)
        XCTAssertNil(dropped.status)

        reply("/stalled", StubReply(200, json: #"{"products":[1,2,3,4,5,6,7,8]}"#, cutAfter: 5, cutWith: .timedOut))
        let stalled = await client.send(.init(method: .get, path: "stalled"))
        XCTAssertEqual(stalled.result.failure, .timeout)
    }

    func test_without_network_a_request_fails_at_once_and_is_not_sent() async {
        let (client, _) = client(online: false)
        let started = Date()
        let response = await client.send(.init(method: .get, path: "products/get"))
        XCTAssertEqual(response.result.failure, .network)
        XCTAssertLessThan(Date().timeIntervalSince(started), 0.5)
        XCTAssertTrue(requests("/products/get").isEmpty)
    }

    func test_the_errors_of_the_transport_are_classified() {
        XCTAssertEqual(NetworkClient.classify(URLError(.timedOut)), .timeout)
        XCTAssertEqual(NetworkClient.classify(URLError(.cancelled)), .cancelled)
        XCTAssertEqual(NetworkClient.classify(URLError(.notConnectedToInternet)), .network)
        XCTAssertEqual(NetworkClient.classify(URLError(.cannotConnectToHost)), .network)
        XCTAssertEqual(NetworkClient.classify(URLError(.networkConnectionLost)), .network)
        XCTAssertEqual(NetworkClient.classify(NSError(domain: "other", code: 1)), .network)
    }

    // MARK: - Cancellation

    func test_release_cancels_a_request_in_flight_and_the_ones_after_it() async {
        let (client, _) = client()
        reply("/slow", StubReply(delay: 3))
        let inFlight = _Concurrency.Task { await client.send(.init(method: .get, path: "slow")) }
        let sent = await waitUntil { !self.requests("/slow").isEmpty }
        XCTAssertTrue(sent)

        let started = Date()
        await client.release()
        let response = await inFlight.value
        XCTAssertEqual(response.result.failure, .cancelled)
        XCTAssertLessThan(Date().timeIntervalSince(started), 1.5)

        let later = await client.send(.init(method: .get, path: "later"))
        XCTAssertEqual(later.result.failure, .cancelled)
        XCTAssertTrue(requests("/later").isEmpty)
    }

    func test_a_request_that_waits_for_the_network_goes_out_once_it_is_back_or_ends_on_release() async {
        let (client, connectivity) = client(online: false)
        let waiting = _Concurrency.Task { await client.send(.init(method: .get, path: "init", waitsForNetwork: true)) }
        try? await _Concurrency.Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(requests("/init").isEmpty, "nothing goes out without network")

        connectivity.isOnline = true
        let response = await waiting.value
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(requests("/init").count, 1)

        connectivity.isOnline = false
        let released = _Concurrency.Task { await client.send(.init(method: .get, path: "init", waitsForNetwork: true)) }
        try? await _Concurrency.Task.sleep(nanoseconds: 200_000_000)
        await client.release()
        let cancelled = await released.value
        XCTAssertEqual(cancelled.result.failure, .cancelled)
    }

    // MARK: - Common fields, timeouts, Retry-After

    func test_the_common_fields_go_with_every_request_where_the_caller_left_them_out() async {
        let (client, _) = client()
        _ = await client.send(.init(method: .get, path: "products/get", query: ["item_id": "7", "did": ""]))
        _ = await client.send(.init(method: .post, path: "push", body: ["event": "view", "segment": "B"]))

        let query = requests("/products/get").first?.query ?? [:]
        XCTAssertEqual(query["item_id"], "7")
        XCTAssertEqual(query["shop_id"], "shop-1")
        XCTAssertEqual(query["did"], "did-1", "an empty value is filled in")
        XCTAssertEqual(query["sid"], "sid-1")
        XCTAssertEqual(query["seance"], "sid-1")
        XCTAssertEqual(query["stream"], "ios")
        XCTAssertEqual(query["segment"], "A")

        let body = requests("/push").first?.body ?? [:]
        XCTAssertEqual(body["event"] as? String, "view")
        XCTAssertEqual(body["segment"] as? String, "B", "the caller's own value stays")
        XCTAssertEqual(body["did"] as? String, "did-1")
        XCTAssertEqual(body["sid"] as? String, "sid-1")
        XCTAssertEqual(body["seance"] as? String, "sid-1")
        XCTAssertEqual(body["shop_id"] as? String, "shop-1")
        XCTAssertEqual(body["stream"] as? String, "ios")
    }

    func test_init_and_requests_with_the_shop_secret_keep_their_own_identity_and_empty_fields_are_not_sent() async {
        let (client, _) = client(fields: CommonFields(shopId: "shop-1", deviceId: "", sessionId: "sid-1", stream: "ios", segment: "A"))
        _ = await client.send(.init(method: .get, path: "init", query: ["tz": "4"]))
        _ = await client.send(.init(method: .get, path: "orders/by_user", query: ["shop_secret": "secret", "email": "e"]))
        _ = await client.send(.init(method: .get, path: "products/cart"))

        let initQuery = requests("/init").first?.query ?? [:]
        XCTAssertEqual(Set(initQuery.keys), ["tz", "shop_id", "stream"])
        let orders = requests("/orders/by_user").first?.query ?? [:]
        XCTAssertNil(orders["did"])
        XCTAssertNil(orders["sid"])
        XCTAssertNil(orders["segment"])
        XCTAssertEqual(orders["shop_id"], "shop-1")
        let cart = requests("/products/cart").first?.query ?? [:]
        XCTAssertNil(cart["did"], "no device id yet: the field is left out, not sent empty")
        XCTAssertEqual(cart["sid"], "sid-1")
    }

    func test_a_plus_in_the_query_reaches_the_server_as_a_plus() async {
        let (client, _) = client()
        _ = await client.send(.init(method: .get, path: "loyalty/members/status", query: ["identifier": "+79990001122"]))
        let url = requests("/loyalty/members/status").first?.url
        XCTAssertTrue(url?.absoluteString.contains("identifier=%2B79990001122") == true, url?.absoluteString ?? "")
    }

    func test_each_request_has_its_own_timeout() async {
        let (client, _) = client()
        _ = await client.send(.init(method: .get, path: "products/get"))
        _ = await client.send(.init(method: .get, path: "init"))
        _ = await client.send(.init(method: .post, path: "push", timeout: 3))

        XCTAssertEqual(requests("/products/get").first?.timeout, 10)
        XCTAssertEqual(requests("/init").first?.timeout, 5)
        XCTAssertEqual(requests("/push").first?.timeout, 3)
    }

    func test_retry_after_comes_back_as_data_and_the_client_does_not_retry() async {
        let (client, _) = client()
        reply("/init", StubReply(429, headers: ["Retry-After": "7"]))
        let response = await client.send(.init(method: .get, path: "init"))
        XCTAssertEqual(response.result.failure, .http(code: 429, serverCode: nil))
        XCTAssertEqual(response.retryAfter, 7)
        XCTAssertEqual(requests("/init").count, 1)

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        XCTAssertEqual(NetworkClient.retryAfter(formatter.string(from: now.addingTimeInterval(120)), now: now), 120)
        XCTAssertNil(NetworkClient.retryAfter("soon"))
        XCTAssertNil(NetworkClient.retryAfter(nil))
    }

    // MARK: - The old errors

    func test_the_new_errors_map_to_the_old_ones() {
        func kind(_ error: SdkError) -> String { error.logKind + (error.description) }
        XCTAssertEqual(kind(.legacy(.http(code: 404, serverCode: nil))), kind(.invalidResponse))
        XCTAssertEqual(kind(.legacy(.http(code: 400, serverCode: nil), serverMessage: "Bad email")), kind(.custom(error: "Bad email")))
        XCTAssertEqual(kind(.legacy(.network)), kind(.networkOfflineError))
        XCTAssertEqual(kind(.legacy(.timeout)), kind(.invalidResponse))
        XCTAssertEqual(kind(.legacy(.decoding)), kind(.decodeError))
        XCTAssertEqual(kind(.legacy(.shopBlocked)), kind(.custom(error: "shop blocked")))
        XCTAssertEqual(kind(.legacy(.notInitialized)), kind(.initializationFailed))
        XCTAssertEqual(kind(.legacy(.invalidArgument("rate"))), kind(.custom(error: "rate")))
        XCTAssertEqual(kind(.legacy(.cancelled)), kind(.invalidResponse))
        XCTAssertEqual(SdkError.serverMessage(in: Data(#"{"status":"error","message":"Bad email"}"#.utf8)), "Bad email")
        XCTAssertNil(SdkError.serverMessage(in: Data(#"{"status":"success","message":"ok"}"#.utf8)))
    }

    func test_a_new_error_has_a_message_without_data() {
        XCTAssertEqual(Rees46.SdkError.http(code: 404, serverCode: nil).message, "HTTP 404")
        XCTAssertEqual(Rees46.SdkError.network, .network)
        XCTAssertNotEqual(Rees46.SdkError.http(code: 404, serverCode: nil), .http(code: 403, serverCode: nil))
    }

    // MARK: - The flag

    func test_the_first_instance_decides_the_core_of_the_process_and_a_mismatch_is_logged() {
        let lock = NSLock()
        var received: [Rees46.SdkLogMessage] = []
        Rees46.setLogHandler { message in lock.lock(); received.append(message); lock.unlock() }
        defer { Rees46.setLogHandler(nil) }
        CoreFlag.reset()
        let shop = "flag-\(shopId)"

        XCTAssertTrue(CoreFlag.resolve(requested: true, shopId: shop))
        XCTAssertTrue(CoreFlag.resolve(requested: true, shopId: shop))
        XCTAssertTrue(CoreFlag.resolve(requested: false, shopId: shop), "the process keeps its core")

        XCTAssertTrue(eventually {
            lock.lock(); defer { lock.unlock() }
            return received.contains { $0.code == "core_flag_mismatch" && $0.shopId == shop }
        })
        lock.lock()
        let mismatch = received.filter { $0.code == "core_flag_mismatch" && $0.shopId == shop }
        lock.unlock()
        XCTAssertEqual(mismatch.count, 1)
        XCTAssertEqual(mismatch.first?.level, .warning)
        XCTAssertEqual(mismatch.first?.context["active"], "true")
    }

    func test_the_old_core_is_the_default() {
        XCTAssertFalse(Rees46Config(shopId: "a").coreV2)
        XCTAssertTrue(Rees46Config(shopId: "a", coreV2: true).coreV2)
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: shopId) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)
        XCTAssertEqual(sdk.core.kind, .legacy)
    }

    // MARK: - The funnel on CoreV2

    private func coreV2SDK(connectivity: ConnectivityMonitor? = nil) -> SimplePersonalizationSDK {
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: shopId, connectivity: connectivity, coreV2: true) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)
        return sdk
    }

    func test_with_coreV2_the_old_methods_go_through_the_new_client() {
        let sdk = coreV2SDK()
        XCTAssertEqual(sdk.core.kind, .v2)
        XCTAssertEqual(sdk.deviceId, "stub-did")

        let done = expectation(description: "done")
        var outcome: Result<ProductInfo, SdkError>?
        sdk.getProductInfo(id: "item-1") { result in
            outcome = result
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        guard case .success? = outcome else { return XCTFail("expected a success, got \(String(describing: outcome))") }
        let query = StubURLProtocol.requests(to: "/products/get", shop: shopId).first?.query ?? [:]
        XCTAssertEqual(query["item_id"], "item-1")
        XCTAssertEqual(query["did"], "stub-did")
        XCTAssertEqual(query["segment"], sdk.segment, "the client adds what the method left out")
        XCTAssertEqual(query["stream"], "ios")
        XCTAssertEqual(StubURLProtocol.requests(to: "/init", shop: shopId).first?.timeout, 5)
    }

    func test_with_coreV2_the_old_methods_get_the_old_errors() {
        StubURLProtocol.handler = { request in
            switch request.path {
            case "/init": return StubURLProtocol.defaultHandler(request)
            case "/profile/set": return StubReply(400, json: #"{"status":"error","message":"Bad email"}"#)
            case "/products/get": return StubReply(500)
            default: return StubReply(200, json: "not json")
            }
        }
        let connectivity = FakeConnectivity(online: true)
        let sdk = coreV2SDK(connectivity: connectivity)

        func post(_ path: String) -> Result<[String: Any], SdkError>? {
            let done = expectation(description: path)
            var outcome: Result<[String: Any], SdkError>?
            sdk.postRequest(path: path, params: ["email": "e"]) { outcome = $0; done.fulfill() }
            wait(for: [done], timeout: 5)
            return outcome
        }
        func get(_ path: String) -> Result<[String: Any], SdkError>? {
            let done = expectation(description: path)
            var outcome: Result<[String: Any], SdkError>?
            sdk.getRequest(path: path, params: [:], timeout: nil) { outcome = $0; done.fulfill() }
            wait(for: [done], timeout: 5)
            return outcome
        }

        guard case let .failure(.custom(message))? = post("profile/set") else { return XCTFail("a 400 with a message is .custom") }
        XCTAssertEqual(message, "Bad email")
        guard case .failure(.invalidResponse)? = get("products/get") else { return XCTFail("a 500 is .invalidResponse") }
        guard case .failure(.decodeError)? = get("search/blank") else { return XCTFail("a body that does not parse is .decodeError") }
        connectivity.isOnline = false
        guard case .failure(.networkOfflineError)? = get("products/cart") else { return XCTFail("offline is .networkOfflineError") }
        XCTAssertTrue(StubURLProtocol.requests(to: "/products/cart", shop: shopId).isEmpty, "offline, nothing goes out")
    }

    func test_with_coreV2_init_waits_for_the_network_when_there_is_no_saved_answer() {
        let connectivity = FakeConnectivity(online: false)
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: shopId, connectivity: connectivity, coreV2: true) { error in
            XCTAssertNil(error)
            ready.fulfill()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        XCTAssertTrue(StubURLProtocol.requests(to: "/init", shop: shopId).isEmpty)

        connectivity.isOnline = true
        wait(for: [ready], timeout: 5)
        XCTAssertEqual(sdk.deviceId, "stub-did")
    }

    func test_releasing_a_coreV2_instance_cancels_its_requests() {
        let sdk = coreV2SDK()
        StubURLProtocol.handler = { $0.path == "/products/get" ? StubReply(delay: 3) : StubReply() }

        let done = expectation(description: "done")
        var outcome: Result<ProductInfo, SdkError>?
        sdk.getProductInfo(id: "item-1") { result in
            outcome = result
            done.fulfill()
        }
        XCTAssertTrue(eventually { !StubURLProtocol.requests(to: "/products/get", shop: self.shopId).isEmpty })
        let started = Date()
        sdk.release()
        wait(for: [done], timeout: 2)
        XCTAssertLessThan(Date().timeIntervalSince(started), 1.5)
        guard case .failure(.invalidResponse)? = outcome else { return XCTFail("a cancelled request is .invalidResponse for the old methods") }
    }

    // MARK: - Helpers

    private func waitUntil(timeout: TimeInterval = 3, _ condition: @escaping () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await _Concurrency.Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }
}

private extension Result {
    var failure: Failure? {
        if case let .failure(error) = self { return error }
        return nil
    }
}
