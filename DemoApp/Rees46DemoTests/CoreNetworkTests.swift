//
//  CoreNetworkTests.swift
//  REES46Tests
//
//  The new core's client over the stub server (`sdk/core/network.md`): what an answer means,
//  timeouts, cut bodies, no network, cancellation, the common fields and `Retry-After`; the one
//  mapping to the old errors; the process's core flag; and the SDK's funnel on `CoreV2`.
//

import XCTest
@_spi(Bridge) @testable import REES46

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

    /// The requests of this test's client: `shop-1`, or none. An SDK an earlier test left may still send
    /// to the stub server, with a shop of its own.
    private func requests(_ path: String) -> [StubRequest] {
        StubURLProtocol.requests(to: path).filter {
            let shop = $0.query["shop_id"] ?? $0.body["shop_id"] as? String
            return shop == nil || shop == fields.shopId
        }
    }

    /// Holds every request to `path` until the test ends: what ends it is the client, never an answer.
    private func holdForever(_ path: String) -> DispatchSemaphore {
        let gate = DispatchSemaphore(value: 0)
        StubURLProtocol.handler = { request in
            if request.path == path { _ = gate.wait(timeout: .now() + 30) }
            return StubReply()
        }
        addTeardownBlock { for _ in 0..<8 { gate.signal() } }
        return gate
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
        // The answer would come after the request's own timeout: the request times out first.
        reply("/slow", StubReply(delay: 2))
        let response = await client.send(.init(method: .get, path: "slow", timeout: 0.3))
        XCTAssertEqual(response.result.failure, .timeout)
        XCTAssertNil(response.status)
        XCTAssertEqual(requests("/slow").first?.timeout, 0.3, "the request carried its own timeout")
    }

    func test_a_body_cut_midway_is_never_a_success() async {
        let (client, _) = client()
        reply("/dropped", StubReply(200, json: #"{"products":[1,2,3,4,5,6,7,8]}"#, cutAfter: 5))
        let dropped = await client.send(.init(method: .get, path: "dropped"))
        XCTAssertEqual(dropped.result.failure, .timeout, "the request reached the server: a dropped answer is timeout")
        XCTAssertNil(dropped.status)

        reply("/stalled", StubReply(200, json: #"{"products":[1,2,3,4,5,6,7,8]}"#, cutAfter: 5, cutWith: .timedOut))
        let stalled = await client.send(.init(method: .get, path: "stalled"))
        XCTAssertEqual(stalled.result.failure, .timeout)
    }

    func test_without_network_a_request_fails_at_once_and_is_not_sent() async {
        // Offline for good: a request that waited for the network would never end.
        let (client, _) = client(online: false)
        let response = await client.send(.init(method: .get, path: "products/get"))
        XCTAssertEqual(response.result.failure, .network)
        XCTAssertTrue(requests("/products/get").isEmpty)
    }

    func test_the_errors_of_the_transport_are_classified_by_whether_the_request_reached_the_server() {
        // Before the request reached the server: no network, DNS, a refused or timed-out connect.
        for code: URLError.Code in [.notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .timedOut, .networkConnectionLost] {
            XCTAssertEqual(NetworkClient.classify(URLError(code), reachedServer: false), .network, "\(code)")
        }
        // After: the answer did not come in time or broke off midway.
        for code: URLError.Code in [.timedOut, .networkConnectionLost, .badServerResponse] {
            XCTAssertEqual(NetworkClient.classify(URLError(code), reachedServer: true), .timeout, "\(code)")
        }
        XCTAssertEqual(NetworkClient.classify(URLError(.cancelled), reachedServer: true), .cancelled)
        XCTAssertEqual(NetworkClient.classify(URLError(.cancelled), reachedServer: false), .cancelled)
        XCTAssertEqual(NetworkClient.classify(NSError(domain: "other", code: 1), reachedServer: false), .network)
    }

    func test_a_connect_that_never_happened_is_network_and_a_held_answer_is_timeout() async {
        let (client, _) = client()
        StubURLProtocol.handler = { $0.path == "/unreachable" ? StubReply.noAnswer : StubReply(delay: 2) }
        let unreachable = await client.send(.init(method: .get, path: "unreachable"))
        XCTAssertEqual(unreachable.result.failure, .network)

        let held = await client.send(.init(method: .get, path: "held", timeout: 0.3))
        XCTAssertEqual(held.result.failure, .timeout)
    }

    func test_the_real_session_tells_a_refused_connect_from_a_silent_server() async throws {
        // Real sockets, no stub: the phase comes from the session's own metrics.
        StubURLProtocol.uninstall()
        defer { StubURLProtocol.install() }
        let silent = try SilentServer()
        defer { silent.close() }
        let connectivity = FakeConnectivity(online: true)
        let logger = SdkLogger(shopId: "core-network", level: .none)

        // A port that had a listener a moment ago and has none now: a connection to it is refused.
        let gone = try SilentServer()
        let closedPort = gone.port
        gone.close()
        let refused = NetworkClient(baseURL: "http://127.0.0.1:\(closedPort)/", connectivity: connectivity, logger: logger) { self.fields }
        let refusedResponse = await refused.send(.init(method: .get, path: "x", timeout: 2))
        XCTAssertEqual(refusedResponse.result.failure, .network, "a refused connection never reached the server")

        let accepting = NetworkClient(baseURL: "http://127.0.0.1:\(silent.port)/", connectivity: connectivity, logger: logger) { self.fields }
        let silentResponse = await accepting.send(.init(method: .get, path: "x", timeout: 0.5))
        XCTAssertEqual(silentResponse.result.failure, .timeout, "the server took the request and did not answer")
        await refused.release()
        await accepting.release()
    }

    // MARK: - Cancellation

    func test_release_cancels_a_request_in_flight_and_the_ones_after_it() async {
        let (client, _) = client()
        // The server never answers: only release() can end the request.
        _ = holdForever("/slow")
        let inFlight = _Concurrency.Task { await client.send(.init(method: .get, path: "slow")) }
        let sent = await waitUntil { !self.requests("/slow").isEmpty }
        XCTAssertTrue(sent)

        await client.release()
        let response = await inFlight.value
        XCTAssertEqual(response.result.failure, .cancelled)

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

    func test_release_while_a_waiting_request_wakes_up_never_sends_on_the_released_session() async {
        // The wake-up and release() race for the actor: whichever wins, nothing is sent on the
        // invalidated session, which would raise an exception.
        for _ in 0..<100 {
            let (client, connectivity) = client(online: false)
            let waiting = _Concurrency.Task { await client.send(.init(method: .get, path: "init", waitsForNetwork: true)) }
            try? await _Concurrency.Task.sleep(nanoseconds: 1_000_000)
            connectivity.isOnline = true
            await client.release()
            let response = await waiting.value
            if case .failure(let error) = response.result {
                XCTAssertEqual(error, .cancelled)
            }
        }
    }

    func test_cancelling_the_callers_task_cancels_the_request_in_flight_and_the_waiting_one() async {
        let (client, connectivity) = client()
        // The server never answers: only the cancellation can end the request.
        _ = holdForever("/slow")
        let inFlight = _Concurrency.Task { await client.send(.init(method: .get, path: "slow")) }
        let sent = await waitUntil { !self.requests("/slow").isEmpty }
        XCTAssertTrue(sent)
        inFlight.cancel()
        let response = await inFlight.value
        XCTAssertEqual(response.result.failure, .cancelled)

        connectivity.isOnline = false
        let waiting = _Concurrency.Task { await client.send(.init(method: .get, path: "init", waitsForNetwork: true)) }
        try? await _Concurrency.Task.sleep(nanoseconds: 200_000_000)
        waiting.cancel()
        let cancelled = await waiting.value
        XCTAssertEqual(cancelled.result.failure, .cancelled)
        XCTAssertTrue(requests("/init").isEmpty)

        // The client itself goes on.
        connectivity.isOnline = true
        let next = await client.send(.init(method: .get, path: "next"))
        XCTAssertEqual(next.status, 200)
    }

    func test_at_cold_start_a_waiting_init_that_finds_no_network_waits_for_the_first_path() async {
        // The monitor has no path yet and counts that as online; the first try finds no network.
        let connectivity = FakeConnectivity(online: true, hasPath: false)
        // The first path comes when the test says so, not within a time of the runner's.
        let firstPathWait = NetworkClient.firstPathWait
        NetworkClient.firstPathWait = 60
        defer { NetworkClient.firstPathWait = firstPathWait }
        // A shop of its own: an SDK an earlier test left may still send /init to the stub server.
        let shop = "cold-\(UUID().uuidString.prefix(8))"
        let fields = CommonFields(shopId: shop, deviceId: "did-1", sessionId: "sid-1", stream: "ios", segment: "A")
        func inits() -> [StubRequest] { StubURLProtocol.requests(to: "/init", shop: shop) }
        let client = NetworkClient(
            baseURL: "https://stub.test/",
            connectivity: connectivity,
            logger: SdkLogger(shopId: "core-network", level: .none)
        ) { fields }
        StubURLProtocol.handler = { _ in
            connectivity.hasPath ? StubReply(json: #"{"did":"d"}"#) : StubReply.noAnswer
        }
        let waiting = _Concurrency.Task { await client.send(.init(method: .get, path: "init", waitsForNetwork: true)) }
        let first = await waitUntil { inits().count == 1 }
        XCTAssertTrue(first)
        try? await _Concurrency.Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(inits().count, 1, "it waits for the path, it does not retry in a loop")

        connectivity.hasPath = true
        let response = await waiting.value
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(inits().count, 2)

        // Once the monitor knows the path, a request lost for want of a network is its failure.
        StubURLProtocol.handler = { _ in StubReply.noAnswer }
        let lost = await client.send(.init(method: .get, path: "init", waitsForNetwork: true))
        XCTAssertEqual(lost.result.failure, .network)
        XCTAssertEqual(inits().count, 3)
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

    func test_the_first_instance_decides_the_core_of_the_process_and_a_mismatch_is_logged_once_at_the_instances_level() throws {
        let lock = NSLock()
        var received: [Rees46.SdkLogMessage] = []
        Rees46.setLogHandler { message in lock.lock(); received.append(message); lock.unlock() }
        Rees46.reset()
        SdkRegistry.shared.reset()
        defer {
            Rees46.setLogHandler(nil)
            Rees46.reset()
            SdkRegistry.shared.reset()
        }
        func mismatches(_ shop: String) -> [Rees46.SdkLogMessage] {
            // Every message logged before the call is with the handler.
            SdkLogger.awaitDelivery()
            lock.lock(); defer { lock.unlock() }
            return received.filter { $0.code == "core_flag_mismatch" && $0.shopId == shop }
        }
        CoreFlag.reset()
        XCTAssertTrue(CoreFlag.resolve(requested: true))
        XCTAssertTrue(CoreFlag.resolve(requested: false), "the process keeps its core")

        // Registered, then made: the shop's instance says it once, at its own level.
        let shop = "flag-\(shopId)"
        Rees46.register(shops: [Rees46Config(shopId: shop, apiDomain: "stub.test", autoSendPushToken: false)])
        let sdk = try XCTUnwrap(try Rees46.instance(for: shop) as? SimplePersonalizationSDK)
        XCTAssertTrue(sdk.usesCoreV2)
        let again = Rees46.initialize(Rees46Config(shopId: shop, apiDomain: "stub.test", autoSendPushToken: false))
        XCTAssertTrue(eventually { !mismatches(shop).isEmpty })
        XCTAssertEqual(mismatches(shop).count, 1)
        XCTAssertEqual(mismatches(shop).first?.level, .warning)
        XCTAssertEqual(mismatches(shop).first?.context["active"], "true")

        // An instance that logs errors only does not get the warning.
        let quiet = "flag-quiet-\(shopId)"
        let quietSDK = Rees46.initialize(Rees46Config(shopId: quiet, apiDomain: "stub.test", logLevel: .error, autoSendPushToken: false))
        // The mismatch is logged in the instance's init, before it returns.
        XCTAssertTrue(mismatches(quiet).isEmpty)
        withExtendedLifetime([sdk, again, quietSDK] as [AnyObject]) {}
        StubSDK.removeSavedInit(shopId: shop)
        StubSDK.removeSavedInit(shopId: quiet)
    }

    func test_the_old_createPersonalizationSDK_decides_the_core_of_the_process_too() {
        Rees46.reset()
        SdkRegistry.shared.reset()
        defer {
            Rees46.reset()
            SdkRegistry.shared.reset()
        }
        CoreFlag.reset()
        let shop = "legacy-flag-\(shopId)"
        let legacy = createPersonalizationSDK(shopId: shop, apiDomain: "stub.test", autoSendPushToken: false)
        XCTAssertEqual(CoreFlag.current, false)

        let later = Rees46.initializeBridge(Rees46Config(shopId: "\(shop)-2", apiDomain: "stub.test", autoSendPushToken: false))
        XCTAssertEqual((later as? SimplePersonalizationSDK)?.usesCoreV2, false, "the process keeps the old core")
        withExtendedLifetime([legacy, later] as [AnyObject]) {}
        StubSDK.removeSavedInit(shopId: shop)
        StubSDK.removeSavedInit(shopId: "\(shop)-2")
    }

    func test_the_old_core_is_the_default() {
        XCTAssertFalse(Rees46Config(shopId: "a").coreV2)
        XCTAssertTrue(Rees46Config(shopId: "a").onNewCore().coreV2, "the bridges' configuration")
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

    func test_with_coreV2_an_empty_init_answer_is_retried_on_the_saved_answer_and_keeps_the_device_id_and_the_backup() {
        StubURLProtocol.handler = { request in
            request.path == "/init" ? StubReply(200, json: "") : StubReply()
        }
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = "kept-did"
        let saved = Data(#"{"did":"kept-did","seance":"s"}"#.utf8)
        let keychain = InMemoryKeychainInitStore(saved)
        let ready = expectation(description: "init")
        var initError: SdkError?
        let sdk = StubSDK.make(shopId: shopId, identity: identity, keychain: keychain, coreV2: true) { error in
            initError = error
            ready.fulfill()
        }
        wait(for: [ready], timeout: 5)

        // A stored did is ready at once; an empty /init is decoding: retried, and meanwhile the saved
        // answer lets calls through.
        XCTAssertNil(initError, "the saved answer stands in")
        XCTAssertTrue(eventually { sdk.state == .retrying })
        XCTAssertEqual(sdk.deviceId, "kept-did")
        XCTAssertEqual(identity.deviceId, "kept-did")
        XCTAssertEqual(keychain.data, saved)

        // The init that saves its answer (sendIDFARequest) does not save an empty one either.
        let idfa = expectation(description: "idfa")
        sdk.sendIDFARequest(idfa: UUID()) { _ in idfa.fulfill() }
        wait(for: [idfa], timeout: 5)
        XCTAssertEqual(keychain.data, saved, "an empty answer never replaces the keychain backup")
    }

    func test_an_init_answer_without_a_device_id_keeps_the_stored_one_on_both_cores() {
        for coreV2 in [false, true] {
            StubURLProtocol.handler = { request in
                request.path == "/init" ? StubReply(json: #"{"seance":"s"}"#) : StubReply()
            }
            let identity = InMemoryUserIdentityRepository()
            identity.deviceId = "kept-did"
            let saved = Data(#"{"did":"kept-did"}"#.utf8)
            let keychain = InMemoryKeychainInitStore(saved)
            let ready = expectation(description: "init")
            let sdk = StubSDK.make(shopId: shopId, identity: identity, keychain: keychain, coreV2: coreV2) { _ in ready.fulfill() }
            wait(for: [ready], timeout: 5)
            XCTAssertEqual(sdk.deviceId, "kept-did", "coreV2 = \(coreV2)")

            let idfa = expectation(description: "idfa")
            sdk.sendIDFARequest(idfa: UUID()) { _ in idfa.fulfill() }
            wait(for: [idfa], timeout: 5)
            XCTAssertEqual(keychain.data, saved, "an answer without a device id is not saved, coreV2 = \(coreV2)")
            XCTAssertEqual(sdk.deviceId, "kept-did")
        }
    }

    func test_releasing_a_coreV2_instance_cancels_its_requests() {
        let sdk = coreV2SDK()
        // The server never answers: only release() can end the request.
        _ = holdForever("/products/get")

        let done = expectation(description: "done")
        var outcome: Result<ProductInfo, SdkError>?
        sdk.getProductInfo(id: "item-1") { result in
            outcome = result
            done.fulfill()
        }
        XCTAssertTrue(eventually { !StubURLProtocol.requests(to: "/products/get", shop: self.shopId).isEmpty })
        sdk.release()
        wait(for: [done], timeout: 10)
        guard case .failure(.invalidResponse)? = outcome else { return XCTFail("a cancelled request is .invalidResponse for the old methods") }
    }

    // MARK: - The app's session on CoreV2

    func test_with_coreV2_the_apps_session_configuration_is_used_and_a_delegate_is_reported() {
        let lock = NSLock()
        var received: [Rees46.SdkLogMessage] = []
        Rees46.setLogHandler { message in lock.lock(); received.append(message); lock.unlock() }
        defer { Rees46.setLogHandler(nil) }
        RecordingProtocol.clear()
        let sdk = coreV2SDK()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WaitingSession.self]
        sdk.configureURLSession(configuration: configuration)
        XCTAssertTrue(getProducts(sdk, untilSeenBy: "waiting"), "the next requests go through the app's configuration")

        let delegated = URLSessionConfiguration.ephemeral
        delegated.protocolClasses = [ImmediateSession.self]
        sdk.urlSession = URLSession(configuration: delegated, delegate: PinningDelegate(), delegateQueue: nil)
        XCTAssertTrue(getProducts(sdk, untilSeenBy: "immediate"), "a session the app sets gives its configuration")
        XCTAssertTrue(eventually {
            lock.lock(); defer { lock.unlock() }
            return received.contains { $0.code == "invalid_config" && $0.context["reason"] == "url_session_delegate" && $0.shopId == self.shopId }
        }, "its delegate does not apply, and the log says so")
    }

    /// Sends `products/get` until the session of `name` serves it: the configuration reaches the
    /// client's actor a moment after the call.
    private func getProducts(_ sdk: SimplePersonalizationSDK, untilSeenBy name: String) -> Bool {
        for _ in 0..<20 {
            let done = expectation(description: "get")
            sdk.getProductInfo(id: "item-1") { _ in done.fulfill() }
            wait(for: [done], timeout: 5)
            if RecordingProtocol.seen.contains("\(name) /products/get") { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return false
    }

    // MARK: - The old core, pinned

    private func legacyCore(waiting: URLSession? = nil, immediate: URLSession? = nil, connectivity: ConnectivityMonitor = FakeConnectivity(online: true), logger: SdkLogger? = nil) -> LegacyCore {
        LegacyCore(
            baseURL: "https://stub.test/",
            stream: "ios",
            logger: logger ?? SdkLogger(shopId: "legacy-core", level: .none),
            connectivity: connectivity,
            session: { waiting ?? URLSession(configuration: .default) },
            sessionWithoutWaiting: immediate ?? URLSession(configuration: .default)
        )
    }

    private func send(_ core: Core, _ request: CoreRequest) -> CoreResponse? {
        let done = expectation(description: request.path)
        var response: CoreResponse?
        core.send(request) { response = $0; done.fulfill() }
        wait(for: [done], timeout: 5)
        return response
    }

    func test_the_old_core_takes_299_as_a_success_as_any_2xx() {
        reply("/edge", StubReply(299, json: "[1,2]"))
        let response = send(legacyCore(), CoreRequest(method: .get, path: "edge"))
        XCTAssertEqual(response?.status, 299)
        guard case .success? = response?.result else { return XCTFail("299 is a 2xx: a success on the old core too") }
        reply("/edge", StubReply(300, json: "[1,2]"))
        guard case .failure(.invalidResponse)? = send(legacyCore(), CoreRequest(method: .get, path: "edge"))?.result else {
            return XCTFail("300 is not a success")
        }
    }

    func test_the_old_core_gives_the_error_body_message_of_a_post_as_custom() {
        reply("/profile/set", StubReply(400, json: #"{"status":"error","message":"Bad email"}"#))
        let post = send(legacyCore(), CoreRequest(method: .post, path: "profile/set", body: ["email": "e"]))
        guard case let .failure(.custom(message))? = post?.result else { return XCTFail("a POST error body is .custom") }
        XCTAssertEqual(message, "Bad email")

        reply("/products/get", StubReply(400, json: #"{"status":"error","message":"Bad item"}"#))
        let get = send(legacyCore(), CoreRequest(method: .get, path: "products/get"))
        guard case .failure(.invalidResponse)? = get?.result else { return XCTFail("a GET error is .invalidResponse") }
    }

    func test_the_old_core_picks_the_session_by_whether_the_request_waits_for_the_network() {
        RecordingProtocol.clear()
        let waitingConfiguration = URLSessionConfiguration.ephemeral
        waitingConfiguration.protocolClasses = [WaitingSession.self]
        let immediateConfiguration = URLSessionConfiguration.ephemeral
        immediateConfiguration.protocolClasses = [ImmediateSession.self]
        let core = legacyCore(
            waiting: URLSession(configuration: waitingConfiguration),
            immediate: URLSession(configuration: immediateConfiguration)
        )

        _ = send(core, CoreRequest(method: .get, path: "stories/a"))
        _ = send(core, CoreRequest(method: .get, path: "stories/b", waitsForNetwork: false))
        _ = send(core, CoreRequest(method: .post, path: "push", body: ["event": "view"], waitsForNetwork: false))

        XCTAssertEqual(RecordingProtocol.seen, ["waiting /stories/a", "immediate /stories/b", "waiting /push"],
                       "a GET that does not wait goes through the session without waiting; a POST always waits")
    }

    func test_the_old_core_logs_request_failed_when_a_get_gets_no_answer() {
        let lock = NSLock()
        var received: [Rees46.SdkLogMessage] = []
        Rees46.setLogHandler { message in lock.lock(); received.append(message); lock.unlock() }
        defer { Rees46.setLogHandler(nil) }
        let shop = "legacy-get-\(shopId)"
        StubURLProtocol.handler = { _ in StubReply.noAnswer }

        let response = send(legacyCore(logger: SdkLogger(shopId: shop, level: .warning)), CoreRequest(method: .get, path: "products/get"))

        XCTAssertNil(response?.status)
        guard case .failure(.invalidResponse)? = response?.result else { return XCTFail("online, no answer is .invalidResponse") }
        XCTAssertTrue(eventually {
            lock.lock(); defer { lock.unlock() }
            return received.contains { $0.code == "request_failed" && $0.shopId == shop && $0.context["path"] == "products/get" && $0.context["status"] == nil }
        })
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

/// A server that takes connections and never answers.
private final class SilentServer {
    let port: UInt16
    private let socketDescriptor: Int32

    init() throws {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        socketDescriptor = descriptor
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0, listen(descriptor, 8) == 0 else { throw URLError(.cannotConnectToHost) }
        var assigned = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &assigned) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &length) }
        }
        port = UInt16(bigEndian: assigned.sin_port)
    }

    func close() {
        Darwin.close(socketDescriptor)
    }
}

/// Answers every request with `{}` and records which session's protocol saw it.
private class RecordingProtocol: URLProtocol {
    class var name: String { "" }
    private static let lock = NSLock()
    private static var log: [String] = []

    static var seen: [String] {
        lock.lock(); defer { lock.unlock() }
        return log
    }

    static func clear() {
        lock.lock(); log.removeAll(); lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil) else { return }
        RecordingProtocol.lock.lock()
        RecordingProtocol.log.append("\(type(of: self).name) \(url.path)")
        RecordingProtocol.lock.unlock()
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class WaitingSession: RecordingProtocol {
    override class var name: String { "waiting" }
}

private final class ImmediateSession: RecordingProtocol {
    override class var name: String { "immediate" }
}

/// A session delegate as an app that pins certificates has one.
private final class PinningDelegate: NSObject, URLSessionDelegate {}
