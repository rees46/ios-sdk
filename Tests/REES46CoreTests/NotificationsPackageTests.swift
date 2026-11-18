//
//  NotificationsPackageTests.swift
//  REES46CoreTests
//
//  `notifications` without a server: which calls of the proposed fixture are refused before anything
//  goes and where the others go, the request `getHistory` builds — the shop's secret, `shop_id` alone of
//  the common fields — and what it makes of each answer, and the `async` form of a method with
//  `completion`.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class NotificationsPackageTests: XCTestCase {

    /// The cases of the proposed `notifications` fixture for iOS: those of no platform and of iOS.
    static func iosCases() throws -> [ContractCase] {
        try ContractFixtures.cases("notifications", from: .proposed)
            .filter { ($0["platform"] as? String ?? "ios") == "ios" }
            .map(ContractCase.init)
    }

    static func event(of method: String) -> Rees46.PushEvent? {
        guard method.hasPrefix("track") else { return nil }
        return Rees46.PushEvent(rawValue: method.dropFirst("track".count).lowercased())
    }

    func test_the_fixture_is_proposed_until_the_contract_has_one() throws {
        XCTAssertEqual(try ContractFixtures.load("notifications", from: .proposed)["contract"] as? String, ContractFixtures.version)
        let cases = try Self.iosCases()
        XCTAssertEqual(Set(cases.compactMap { $0.call?.name }), [
            "notifications.trackDelivered", "notifications.trackOpened", "notifications.trackClicked",
            "notifications.trackClosed", "notifications.setPushToken", "notifications.getHistory",
        ])
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: ContractFixtures.url("notifications").path),
            "the contract has notifications.json now: copy it into contract-\(ContractFixtures.version) and remove the proposed one"
        )
    }

    func test_every_event_of_the_fixture_goes_to_its_path_or_is_refused_before_anything_goes() throws {
        let cases = try Self.iosCases().filter { $0.call?.method.hasPrefix("track") == true && $0.response == nil }
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            let call = try XCTUnwrap(item.call, item.name)
            let event = try XCTUnwrap(Self.event(of: call.method), item.name)
            XCTAssertEqual(NotificationsAPIImpl.callName(of: event), call.name, item.name)
            let refusal = NotificationsAPIImpl.refusal(code: call.args["code"] as? String ?? "", type: call.args["type"] as? String ?? "")
            if let expected = item.expectedError {
                XCTAssertTrue(refusal.map(expected.matches) == true, "\(item.name): \(String(describing: refusal))")
                continue
            }
            XCTAssertNil(refusal, item.name)
            let request = try XCTUnwrap(item.request, item.name)
            XCTAssertEqual(request.method, "POST", item.name)
            XCTAssertEqual(request.path, event.path, item.name)
            XCTAssertEqual(request.body["code"] as? String, call.args["code"] as? String, item.name)
            XCTAssertEqual(request.body["type"] as? String, call.args["type"] as? String, item.name)
            XCTAssertTrue(EventQueue.sessionlessPaths.contains(request.path), "\(item.name): an event of a push, without a session")
        }
    }

    func test_every_token_of_the_fixture_goes_with_its_ios_platform_or_is_refused_before_anything_goes() throws {
        let cases = try Self.iosCases().filter { $0.call?.method == "setPushToken" && $0.response == nil }
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            let call = try XCTUnwrap(item.call, item.name)
            let provider = try XCTUnwrap(Rees46.PushProvider(rawValue: call.args["provider"] as? String ?? ""), item.name)
            let token = call.args["token"] as? String ?? ""
            let refusal = NotificationsAPIImpl.refusal(token: token, provider: provider)
            if let expected = item.expectedError {
                XCTAssertTrue(refusal.map(expected.matches) == true, "\(item.name): \(String(describing: refusal))")
                continue
            }
            XCTAssertNil(refusal, item.name)
            let request = try XCTUnwrap(item.request, item.name)
            XCTAssertEqual(request.path, "mobile_push_tokens", item.name)
            XCTAssertEqual(request.body["token"] as? String, token, item.name)
            XCTAssertEqual(request.body["platform"] as? String, provider.iosPlatform, item.name)
            XCTAssertNil(request.body["push_provider"], "\(item.name): iOS sends none")
        }
    }

    func test_get_history_builds_the_fixtures_requests_and_refuses_its_arguments() throws {
        try NamespaceFixtures.checkRequests("notifications", methods: ["getHistory"], build: Self.history)
    }

    /// The answer's model is the released `UserPayloadResponse`: the case of Android names its own.
    func test_get_history_ends_as_the_fixture_says_for_each_answer() throws {
        try NamespaceFixtures.checkAnswers("notifications", methods: ["getHistory"], listed: ["getHistory"], build: Self.history)
    }

    /// The request of a fixture's `notifications.getHistory`.
    private static func history(_ call: ContractCase.Call) throws -> ErasedRequest {
        let args = call.args
        return ErasedRequest(
            try NotificationsAPIImpl.historyRequest(
                shopSecret: NamespaceFixtures.string(args["shopSecret"]) ?? "",
                type: NamespaceFixtures.string(args["type"]) ?? "",
                phone: NamespaceFixtures.string(args["phone"]),
                email: NamespaceFixtures.string(args["email"]),
                externalId: NamespaceFixtures.string(args["externalId"]),
                loyaltyId: NamespaceFixtures.string(args["loyaltyId"]),
                channel: NamespaceFixtures.string(args["channel"]),
                limit: NamespaceFixtures.int(args["limit"]),
                page: NamespaceFixtures.int(args["page"]),
                dateFrom: NamespaceFixtures.string(args["dateFrom"]),
                did: NamespaceFixtures.string(args["did"])
            ),
            call: call.name
        )
    }

    // MARK: - completion and async

    func test_the_async_form_returns_or_throws_the_result_of_the_completion() async {
        do {
            try await NotificationsAPIImpl.awaiting { done in DispatchQueue.global().async { done(.success(())) } }
        } catch {
            XCTFail("\(error)")
        }
        do {
            try await NotificationsAPIImpl.awaiting { $0(.failure(.shopBlocked)) }
            XCTFail("it throws")
        } catch {
            XCTAssertEqual(error as? Rees46.SdkError, .shopBlocked)
        }
    }

    func test_a_cancelled_task_throws_cancelled_and_starts_nothing() async {
        let started = Guarded(false)
        let task = _Concurrency.Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await NotificationsAPIImpl.awaiting { done in
                started.current = true
                done(.success(()))
            }
        }
        do {
            try await task.value
            XCTFail("it throws")
        } catch {
            XCTAssertEqual(error as? Rees46.SdkError, .cancelled)
        }
        XCTAssertFalse(started.current)
    }

    func test_cancelling_a_long_wait_ends_it_as_cancelled_only_where_it_says_so() async throws {
        let pending = Guarded<((Result<Void, Rees46.SdkError>) -> Void)?>(nil)
        let task = _Concurrency.Task {
            try await NotificationsAPIImpl.awaiting(endsOnCancel: true) { pending.current = $0 }
        }
        while pending.current == nil {
            await _Concurrency.Task.yield()
        }
        task.cancel()
        do {
            try await task.value
            XCTFail("it throws")
        } catch {
            XCTAssertEqual(error as? Rees46.SdkError, .cancelled)
        }
        // The call's own result later changes nothing.
        pending.current?(.success(()))

        // Without `endsOnCancel` the wait is for the call's result.
        let call = Guarded<((Result<Void, Rees46.SdkError>) -> Void)?>(nil)
        let event = _Concurrency.Task {
            try await NotificationsAPIImpl.awaiting { call.current = $0 }
        }
        while call.current == nil {
            await _Concurrency.Task.yield()
        }
        event.cancel()
        call.current?(.success(()))
        try await event.value
    }

    func test_a_completion_is_called_once_on_the_main_thread() {
        let done = expectation(description: "completion")
        let again = expectation(description: "a second completion")
        again.isInverted = true
        let calls = Guarded(0)
        let finish = NotificationsAPIImpl.onMain { _ in
            XCTAssertTrue(Thread.isMainThread)
            calls.mutate { $0 += 1 }
            if calls.current == 1 { done.fulfill() } else { again.fulfill() }
        }
        DispatchQueue.global().async {
            finish(.success(()))
            finish(.failure(.network))
        }
        wait(for: [done], timeout: 5)
        wait(for: [again], timeout: 0.3)
    }
}

/// A value under a lock, for the closures of these tests.
private final class Guarded<Value> {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    var current: Value {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }

    func mutate(_ change: (inout Value) -> Void) {
        lock.lock(); defer { lock.unlock() }
        change(&value)
    }
}
