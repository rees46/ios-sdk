//
//  NamespaceRequestTests.swift
//  REES46Tests
//
//  The base of the namespaces end to end, through `cart.get` over the stub server: the request the
//  fixture names with the common fields, every answer of the fixture, no network, a timeout, a shop that
//  refused, the old core's refusal, `completion` once on the main thread, the `async` form and its
//  cancellation, `release()`.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class NamespaceRequestTests: CoreScenarioTestCase {

    // MARK: - Calls

    /// `cart.get` with `completion`: what it got, called on the main thread.
    private func get(_ sdk: PersonalizationSDK, file: StaticString = #filePath, line: UInt = #line) -> Result<[CartItem], Rees46.SdkError>? {
        let done = expectation(description: "cart.get")
        let outcome = Locked<Result<[CartItem], Rees46.SdkError>?>(nil)
        sdk.cart.get { result in
            XCTAssertTrue(Thread.isMainThread, "completion on the main thread", file: file, line: line)
            outcome.current = result
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return outcome.current
    }

    /// `cart.get` in `async` code, cancelled by `cancel` when it is given.
    private func getAsync(
        _ sdk: PersonalizationSDK,
        cancel: ((_Concurrency.Task<[CartItem], Error>) -> Void)? = nil
    ) -> Result<[CartItem], Rees46.SdkError>? {
        let done = expectation(description: "async cart.get")
        let outcome = Locked<Result<[CartItem], Rees46.SdkError>?>(nil)
        let task = _Concurrency.Task { try await sdk.cart.get() }
        _Concurrency.Task {
            do {
                outcome.current = .success(try await task.value)
            } catch let error as Rees46.SdkError {
                outcome.current = .failure(error)
            } catch {
                XCTFail("not an SdkError: \(error)")
            }
            done.fulfill()
        }
        cancel?(task)
        wait(for: [done], timeout: 5)
        return outcome.current
    }

    private func error(of result: Result<[CartItem], Rees46.SdkError>?) -> Rees46.SdkError? {
        if case .failure(let error)? = result { return error }
        return nil
    }

    /// Waits until a call waits for the instance: the timeout of its wait is on the test's scheduler.
    private func awaitWaitingCall(_ before: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(eventually { self.waitsOfACall > before }, "the call waits for the instance", file: file, line: line)
    }

    /// The waits of a request's timeout on the scheduler.
    private var waitsOfACall: Int {
        scheduler.pendingDelays.filter { abs($0 - NetworkClient.defaultTimeout) < 0.001 }.count
    }

    // MARK: - The fixture

    func test_cart_get_sends_the_fixtures_request_with_the_common_fields() throws {
        let shop = newShop()
        let sdk = makeV2(shop)
        let cases = try ContractFixtures.fixture("cart", from: .proposed).filter { $0.request != nil }
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            let expected = try XCTUnwrap(item.request)
            _ = get(sdk)
            let sent = try XCTUnwrap(requests("/" + expected.path, shop).last, item.name)
            XCTAssertEqual(sent.method, expected.method, item.name)
            for (key, value) in expected.query {
                XCTAssertEqual(sent.query[key], value, "\(item.name): \(key)")
            }
            // What the core adds: the API finds the cart by the device id.
            XCTAssertEqual(sent.query["shop_id"], shop)
            XCTAssertEqual(sent.query["did"], "d")
            XCTAssertEqual(sent.query["sid"], sdk.sessionId)
            XCTAssertEqual(sent.query["seance"], sdk.sessionId)
            XCTAssertEqual(sent.query["stream"], "ios")
            XCTAssertEqual(sent.query["segment"], sdk.segment)
            XCTAssertEqual(sent.timeout, NetworkClient.defaultTimeout)
        }
        sdk.release()
    }

    func test_cart_get_ends_as_the_fixture_says_for_each_answer_without_a_repeat() throws {
        let shop = newShop()
        let sdk = makeV2(shop)
        let cases = try ContractFixtures.fixture("cart", from: .proposed).filter { $0.response != nil }
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            let response = try XCTUnwrap(item.response)
            // No status: no answer — a connection never made.
            answer("/products/cart", response.status.map { StubReply($0, json: String(decoding: response.body, as: UTF8.self)) } ?? StubReply.noAnswer)
            let before = requests("/products/cart", shop).count
            let result = get(sdk)
            XCTAssertEqual(requests("/products/cart", shop).count, before + 1, "\(item.name): one request, not repeated")
            switch result {
            case .success(let items)?:
                XCTAssertNil(item.expectedError, "\(item.name): \(items)")
                let expected = (item.expect["result"] as? [[String: Any]] ?? []).map { "\($0["id"] ?? "")×\($0["quantity"] ?? "")" }
                XCTAssertEqual(items.map { "\($0.id)×\($0.quantity)" }, expected, item.name)
            case .failure(let error)?:
                XCTAssertTrue(item.expectedError?.matches(error) == true, "\(item.name): \(error)")
            case nil:
                XCTFail("\(item.name): no outcome")
            }
        }
        // The state of the instance does not move on an error of one request.
        XCTAssertEqual(sdk.state, .ready)
        sdk.release()
    }

    // MARK: - Errors without an answer

    func test_without_network_the_call_fails_at_once_with_network_and_sends_nothing() {
        let shop = newShop()
        let sdk = makeV2(shop)
        network.isOnline = false
        XCTAssertEqual(error(of: get(sdk)), .network)
        XCTAssertTrue(requests("/products/cart", shop).isEmpty)

        // Online, but the connection is never made.
        network.isOnline = true
        answer("/products/cart", StubReply.noAnswer)
        XCTAssertEqual(error(of: get(sdk)), .network)
        sdk.release()
    }

    func test_an_answer_the_read_timeout_cut_is_timeout() {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer("/products/cart", StubReply(200, json: #"{"status":"success","data":{"items":[]}}"#, cutAfter: 8, cutWith: .timedOut))
        XCTAssertEqual(error(of: get(sdk)), .timeout)
        sdk.release()
    }

    func test_a_shop_that_is_not_usable_within_the_calls_timeout_ends_it_with_timeout() {
        let shop = newShop()
        hold("/init")
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        let before = waitsOfACall
        let done = expectation(description: "cart.get")
        let outcome = Locked<Result<[CartItem], Rees46.SdkError>?>(nil)
        sdk.cart.get { outcome.current = $0; done.fulfill() }
        awaitWaitingCall(before)
        scheduler.advance(by: NetworkClient.defaultTimeout)
        wait(for: [done], timeout: 5)
        XCTAssertEqual(error(of: outcome.current), .timeout)
        XCTAssertTrue(requests("/products/cart", shop).isEmpty)
        release("/init")
        sdk.release()
    }

    func test_a_refused_shop_is_shop_blocked_and_sends_nothing() {
        let shop = newShop()
        answer("/init", StubReply(402, json: #"{"status":"error","message":"Restricted Mode"}"#))
        let sdk = makeV2(shop, settled: false)
        XCTAssertTrue(eventually { sdk.state == .refused })
        XCTAssertEqual(error(of: get(sdk)), .shopBlocked)
        XCTAssertEqual(error(of: getAsync(sdk)), .shopBlocked)
        XCTAssertTrue(requests("/products/cart", shop).isEmpty)
        sdk.release()
    }

    // MARK: - The new core only

    func test_on_the_old_core_every_call_is_not_initialized_and_sends_nothing() {
        let shop = newShop()
        let sdk = makeLegacy(shop)
        XCTAssertEqual(error(of: get(sdk)), .notInitialized)
        XCTAssertEqual(error(of: getAsync(sdk)), .notInitialized)
        XCTAssertTrue(requests("/products/cart", shop).isEmpty)
        // The code Android logs for it too.
        XCTAssertTrue(waitForLog(shop, "core_flag_mismatch"))
        let message = logged(shop, "core_flag_mismatch").first
        XCTAssertEqual(message?.context["call"], "cart.get")
        XCTAssertEqual(message?.level, .warning)
        XCTAssertTrue(message?.message.contains("Rees46.initializeBridge") == true, message?.message ?? "")
        XCTAssertTrue(heard.filter { $0.shopId == shop }.allSatisfy(LogContract.allows))
        sdk.release()
    }

    func test_another_conformer_of_the_protocol_is_not_initialized() {
        let fake = FakeSDK(shopId: "fake-\(UUID().uuidString)")
        XCTAssertEqual(error(of: get(fake)), .notInitialized)
        XCTAssertTrue(waitForLog(nil, "not_implemented"))
    }

    // MARK: - completion

    func test_completion_comes_once_on_the_main_thread_whatever_thread_calls() {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer("/products/cart", StubReply(json: #"{"status":"success","data":{"items":[{"uniqid":"37","quantity":2}]}}"#))
        let once = expectation(description: "completion")
        let again = expectation(description: "a second completion")
        again.isInverted = true
        let calls = Locked(0)
        let items = Locked<[CartItem]>([])
        DispatchQueue.global().async {
            sdk.cart.get { result in
                XCTAssertTrue(Thread.isMainThread)
                calls.mutate { $0 += 1 }
                items.current = (try? result.get()) ?? []
                if calls.current == 1 { once.fulfill() } else { again.fulfill() }
            }
        }
        wait(for: [once], timeout: 5)
        wait(for: [again], timeout: 0.5)
        XCTAssertEqual(items.current.map(\.id), ["37"])
        XCTAssertEqual(items.current.map(\.quantity), [2])
        sdk.release()
    }

    // MARK: - release()

    func test_release_cancels_the_call_in_flight_and_later_calls_are_not_initialized() {
        let shop = newShop()
        let sdk = makeV2(shop)
        hold("/products/cart")
        let done = expectation(description: "cart.get")
        let outcome = Locked<Result<[CartItem], Rees46.SdkError>?>(nil)
        sdk.cart.get { outcome.current = $0; done.fulfill() }
        XCTAssertTrue(eventually { self.requests("/products/cart", shop).count == 1 }, "the request is on its way")
        sdk.release()
        wait(for: [done], timeout: 5)
        XCTAssertEqual(error(of: outcome.current), .cancelled)
        release("/products/cart")
        XCTAssertEqual(error(of: get(sdk)), .notInitialized)
        XCTAssertEqual(error(of: getAsync(sdk)), .notInitialized)
    }

    func test_release_cancels_a_call_that_waits_for_the_instance() {
        let shop = newShop()
        hold("/init")
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        let before = waitsOfACall
        let done = expectation(description: "cart.get")
        let outcome = Locked<Result<[CartItem], Rees46.SdkError>?>(nil)
        sdk.cart.get { outcome.current = $0; done.fulfill() }
        awaitWaitingCall(before)
        sdk.release()
        wait(for: [done], timeout: 5)
        XCTAssertEqual(error(of: outcome.current), .cancelled)
        XCTAssertTrue(requests("/products/cart", shop).isEmpty)
        release("/init")
    }

    // MARK: - async

    func test_the_async_form_returns_the_value_and_throws_the_error() {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer("/products/cart", StubReply(json: #"{"status":"success","payload":{"cart_items":[{"uniqid":"7","quantity":"3"}]}}"#))
        let items = try? getAsync(sdk)?.get()
        XCTAssertEqual(items?.map(\.id), ["7"])
        XCTAssertEqual(items?.map(\.quantity), [3])
        answer("/products/cart", StubReply(404, json: #"{"status":"error","message":"Client not found"}"#))
        XCTAssertEqual(error(of: getAsync(sdk)), .http(code: 404, serverCode: nil))
        sdk.release()
    }

    func test_cancelling_the_task_ends_a_call_that_waits_for_the_instance_at_once() {
        let shop = newShop()
        hold("/init")
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        let before = waitsOfACall
        let result = getAsync(sdk) { task in
            self.awaitWaitingCall(before)
            task.cancel()
        }
        XCTAssertEqual(error(of: result), .cancelled)
        XCTAssertEqual(waitsOfACall, before, "its wait is over")
        XCTAssertTrue(requests("/products/cart", shop).isEmpty)
        release("/init")
        sdk.release()
    }

    func test_cancelling_the_task_cancels_the_request_in_flight() {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer("/products/cart", StubReply(json: #"{"status":"success","data":{"items":[]}}"#))
        hold("/products/cart")
        let result = getAsync(sdk) { task in
            XCTAssertTrue(self.eventually { self.requests("/products/cart", shop).count == 1 })
            task.cancel()
        }
        XCTAssertEqual(error(of: result), .cancelled)
        release("/products/cart")
        // The instance goes on.
        XCTAssertEqual(try? get(sdk)?.get().count, 0)
        sdk.release()
    }
}
