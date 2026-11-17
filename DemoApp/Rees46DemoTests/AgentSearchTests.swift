//
//  AgentSearchTests.swift
//  REES46Tests
//
//  The search agent of `search` end to end over the stub server: `agentDialog` and `agent` go to
//  `Rees46Config.appDomain` with the common fields — `agent` with its own read timeout of 60 seconds —,
//  `agentEnabled` follows `search.blank_mode` of the instance's `/init`, and on the old core the agent
//  is off and its methods are `notInitialized`. The cases of each request and answer are the
//  package's (`CatalogPackageTests`, `search.json`).
//

import XCTest
@_spi(Bridge) @testable import REES46

final class AgentSearchTests: CoreScenarioTestCase {

    private static let path = "/api/v3/storefront/search/agent"

    private let dialog = #"{"sessions": [{"id": 12, "title": "Flash drive"}], "session": {"id": 12, "messages": [{"id": 1, "role": "user", "content": "1 TB"}]}}"#
    private let reply = #"{"session": {"id": 12}, "message": {"id": 2, "role": "assistant", "content": "Here", "products": [{"id": "1", "price": 10, "reason": "fits"}]}}"#

    private func agentDialog(_ sdk: PersonalizationSDK, sessionId: Int? = nil) -> Result<Rees46.AgentDialogResponse, Rees46.SdkError>? {
        let done = expectation(description: "agentDialog")
        let outcome = Locked<Result<Rees46.AgentDialogResponse, Rees46.SdkError>?>(nil)
        sdk.search.agentDialog(sessionId: sessionId) { result in
            XCTAssertTrue(Thread.isMainThread)
            outcome.current = result
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return outcome.current
    }

    private func agent(_ sdk: PersonalizationSDK, _ message: String, sessionId: Int? = nil) -> Result<Rees46.AgentResponse, Rees46.SdkError>? {
        let done = expectation(description: "agent")
        let outcome = Locked<Result<Rees46.AgentResponse, Rees46.SdkError>?>(nil)
        sdk.search.agent(message: message, sessionId: sessionId, locations: ["10"]) { result in
            XCTAssertTrue(Thread.isMainThread)
            outcome.current = result
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return outcome.current
    }

    private func failure<Value>(_ result: Result<Value, Rees46.SdkError>?) -> Rees46.SdkError? {
        if case .failure(let error)? = result { return error }
        return nil
    }

    // MARK: - The host of API v3

    func test_the_dialog_and_a_message_go_to_the_app_domain_with_the_common_fields() throws {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer(Self.path, StubReply(json: dialog))
        let read = try XCTUnwrap(agentDialog(sdk, sessionId: 12)?.get())
        XCTAssertEqual(read.sessions.map(\.id), [12])
        XCTAssertEqual(read.session?.messages.first?.role, .user)
        let get = try XCTUnwrap(requests(Self.path, shop).last)
        XCTAssertEqual(get.method, "GET")
        XCTAssertEqual(get.url?.host, Rees46Config.defaultAppDomain)
        XCTAssertEqual(get.query["session_id"], "12")
        XCTAssertEqual(get.query["shop_id"], shop)
        XCTAssertEqual(get.query["did"], "d")
        XCTAssertEqual(get.query["sid"], sdk.sessionId)
        XCTAssertEqual(get.timeout, NetworkClient.defaultTimeout, "the dialog has the common timeout")

        answer(Self.path, StubReply(json: reply))
        let answered = try XCTUnwrap(agent(sdk, "something cheaper?", sessionId: 12)?.get())
        XCTAssertEqual(answered.session.id, 12)
        XCTAssertEqual(answered.message.products.map(\.reason), ["fits"])
        let post = try XCTUnwrap(requests(Self.path, shop).last)
        XCTAssertEqual(post.method, "POST")
        XCTAssertEqual(post.url?.host, Rees46Config.defaultAppDomain)
        XCTAssertEqual(post.header("Content-Type"), "application/json")
        XCTAssertEqual(post.body["message"] as? String, "something cheaper?")
        XCTAssertEqual(post.body["session_id"] as? Int, 12)
        XCTAssertEqual(post.body["location"] as? String, "10")
        XCTAssertEqual(post.body["shop_id"] as? String, shop)
        XCTAssertEqual(post.body["did"] as? String, "d")
        XCTAssertEqual(post.body["sid"] as? String, sdk.sessionId)
        XCTAssertEqual(post.timeout, 60, "the agent answers in up to 40 seconds and two more tries of its model")
        sdk.release()
    }

    func test_the_agent_goes_to_the_shops_own_app_domain() {
        CoreFlag.reset()
        let shop = newShop()
        let config = Rees46Config(shopId: shop, apiDomain: "stub.test", appDomain: "app.cluster.test", autoSendPushToken: false)
        guard let sdk = Rees46.initializeBridge(config) as? SimplePersonalizationSDK else {
            return XCTFail("no instance")
        }
        answer(Self.path, StubReply(json: reply))
        let done = expectation(description: "agent")
        sdk.search.agent(message: "hi") { _ in done.fulfill() }
        wait(for: [done], timeout: 15)
        XCTAssertEqual(requests(Self.path, shop).last?.url?.host, "app.cluster.test")
        sdk.release()
    }

    func test_the_agents_errors_are_http_with_their_code_and_the_instance_goes_on() {
        let shop = newShop()
        let sdk = makeV2(shop)
        for code in [400, 402, 404, 429, 503] {
            answer(Self.path, StubReply(code, json: #"{"error": "no"}"#))
            XCTAssertEqual(failure(agent(sdk, "hi")), .http(code: code, serverCode: nil), "\(code)")
            XCTAssertEqual(failure(agentDialog(sdk)), .http(code: code, serverCode: nil), "\(code)")
        }
        XCTAssertEqual(sdk.state, .ready)
        sdk.release()
    }

    func test_a_message_the_server_would_refuse_is_refused_before_anything_is_sent() {
        let shop = newShop()
        let sdk = makeV2(shop)
        if case .invalidArgument? = failure(agent(sdk, " ")) {} else { XCTFail("an empty message") }
        if case .invalidArgument? = failure(agent(sdk, String(repeating: "я", count: 501))) {} else { XCTFail("a message of 501 characters") }
        XCTAssertTrue(requests(Self.path, shop).isEmpty)
        XCTAssertTrue(eventually { self.logged(shop, "invalid_argument").contains { $0.context["call"] == "search.agent" } })
        sdk.release()
    }

    func test_the_async_forms() {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer(Self.path, StubReply(json: reply))
        let done = expectation(description: "async")
        let ids = Locked<[Int]>([])
        _Concurrency.Task {
            let dialog = try? await sdk.search.agentDialog()
            let answer = try? await sdk.search.agent(message: "hi")
            ids.current = [dialog?.sessions.count ?? -1, answer?.session.id ?? -1]
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(ids.current, [0, 12], "the reply is no dialog: no sessions")
        sdk.release()
    }

    // MARK: - agentEnabled

    func test_agent_enabled_follows_the_blank_mode_of_the_last_init() {
        let shop = newShop()
        answer("/init", StubReply(json: #"{"did": "d", "seance": "s-1", "search": {"enabled": true, "blank_mode": "agent"}}"#))
        let sdk = makeV2(shop, settled: false)
        XCTAssertTrue(eventually { sdk.search.agentEnabled }, "agent")
        answer("/init", StubReply(json: #"{"did": "d", "seance": "s-2", "search": {"enabled": true, "blank_mode": "history"}}"#))
        sdk.deleteUserCredentials()
        XCTAssertTrue(eventually { !sdk.search.agentEnabled }, "history, after the next /init")
        sdk.release()
    }

    func test_without_an_answer_of_init_the_agent_is_off() {
        let shop = newShop()
        hold("/init")
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        XCTAssertFalse(sdk.search.agentEnabled)
        release("/init")
        sdk.release()
    }

    // MARK: - The old core

    func test_on_the_old_core_the_agent_is_off_and_its_methods_are_not_initialized() {
        let shop = newShop()
        answer("/init", StubReply(json: #"{"did": "d", "seance": "s-1", "search": {"blank_mode": "agent"}}"#))
        let sdk = makeLegacy(shop)
        XCTAssertFalse(sdk.search.agentEnabled)
        XCTAssertEqual(failure(agentDialog(sdk)), .notInitialized)
        XCTAssertEqual(failure(agent(sdk, "hi")), .notInitialized)
        XCTAssertTrue(requests(Self.path, shop).isEmpty)
        XCTAssertTrue(eventually { Set(self.logged(shop, "core_flag_mismatch").compactMap { $0.context["call"] }) == ["search.agentDialog", "search.agent"] })
        sdk.release()
    }
}
