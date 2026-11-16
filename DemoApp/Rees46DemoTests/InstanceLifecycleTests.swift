//
//  InstanceLifecycleTests.swift
//  REES46Tests
//
//  The instance on both cores (`sdk/contract/root.md`, `sdk/core/README.md`, "Экземпляр"): a repeated
//  `initialize` returns the shop's instance, also from many threads at once; the registry holds it;
//  `release()` stops it and lets a new one be made; `state` and its listeners, on the main thread and
//  once per change; the old core's states.
//

import UIKit
import XCTest
@testable import REES46

final class InstanceLifecycleTests: XCTestCase {

    private var shops: [String] = []
    private let logLock = NSLock()
    private var logs: [Rees46.SdkLogMessage] = []

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        Rees46.reset()
        SdkRegistry.shared.reset()
        CoreFlag.reset()
        logs = []
        Rees46.setLogHandler { [weak self] message in
            guard let self = self else { return }
            self.logLock.lock(); self.logs.append(message); self.logLock.unlock()
        }
    }

    override func tearDown() {
        Rees46.setLogHandler(nil)
        SdkRegistry.shared.all().forEach { $0.release() }
        Rees46.reset()
        SdkRegistry.shared.reset()
        StubURLProtocol.uninstall()
        CoreFlag.reset()
        shops.forEach { StubSDK.removeSavedInit(shopId: $0) }
        shops.removeAll()
        super.tearDown()
    }

    private func newShop() -> String {
        let shop = StubSDK.shopId()
        shops.append(shop)
        return shop
    }

    private func config(_ shop: String, logLevel: Rees46.LogLevel = .warning, coreV2: Bool = false) -> Rees46Config {
        Rees46Config(shopId: shop, apiDomain: "stub.test", logLevel: logLevel, autoSendPushToken: false, enableAutoPopupPresentation: false, coreV2: coreV2)
    }

    private func same(_ lhs: PersonalizationSDK?, _ rhs: PersonalizationSDK?) -> Bool {
        (lhs as AnyObject?) === (rhs as AnyObject?)
    }

    private func messages(_ shop: String, _ code: String) -> [Rees46.SdkLogMessage] {
        logLock.lock(); defer { logLock.unlock() }
        return logs.filter { $0.shopId == shop && $0.code == code }
    }

    /// The init answer: `/init` waits for `gate` when there is one.
    private func holdInit(until gate: DispatchSemaphore? = nil, reply: StubReply = StubReply(json: #"{"did":"stub-did"}"#)) {
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            if let gate = gate { _ = gate.wait(timeout: .now() + 10) }
            return reply
        }
    }

    // MARK: - initialize

    func test_a_repeated_initialize_returns_the_shops_instance_and_each_completion_is_called_once() {
        for coreV2 in [false, true] {
            CoreFlag.reset()
            let shop = newShop()
            let gate = DispatchSemaphore(value: 0)
            holdInit(until: gate)
            let lock = NSLock()
            var counts: [String: Int] = [:]
            func count(_ key: String) { lock.lock(); counts[key, default: 0] += 1; lock.unlock() }
            func calls(_ key: String) -> Int? { lock.lock(); defer { lock.unlock() }; return counts[key] }

            let opened = Locked(false)
            let early = expectation(description: "a completion before init settled")
            early.isInverted = true
            let first = Rees46.initialize(config(shop, coreV2: coreV2)) { _ in count("first") }
            let second = Rees46.initialize(config(shop, coreV2: coreV2)) { _ in
                count("second")
                if !opened.current { early.fulfill() }
            }

            XCTAssertTrue(same(first, second), "coreV2 = \(coreV2)")
            XCTAssertEqual(SdkRegistry.shared.count(), 1)
            wait(for: [early], timeout: 0.3)
            XCTAssertNil(calls("second"), "the second completion waits for init to settle")

            opened.current = true
            gate.signal()
            XCTAssertTrue(eventually { calls("first") == 1 && calls("second") == 1 })

            // After init settled, a third call hears the outcome at once.
            let third = expectation(description: "third")
            var outcome: SdkError?? = .none
            _ = Rees46.initialize(config(shop, coreV2: coreV2)) { outcome = .some($0); third.fulfill() }
            wait(for: [third], timeout: 2)
            XCTAssertEqual(outcome.map { $0 == nil }, true, "the instance initialized")
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            XCTAssertEqual(calls("first"), 1)
            XCTAssertEqual(calls("second"), 1)
            first.release()
        }
    }

    func test_a_repeated_initialize_with_another_config_keeps_the_instance_and_says_so() {
        let shop = newShop()
        holdInit()
        let first = Rees46.initialize(config(shop))
        let again = Rees46.initialize(config(shop))
        let other = Rees46.initialize(Rees46Config(shopId: shop, apiDomain: "other.test", autoSendPushToken: false, enableAutoPopupPresentation: false))

        XCTAssertTrue(same(first, again))
        XCTAssertTrue(same(first, other))
        XCTAssertEqual((other as? SimplePersonalizationSDK)?.baseURL, "https://stub.test/", "the instance keeps its configuration")
        XCTAssertTrue(eventually { self.messages(shop, "invalid_config").count == 1 }, "only the different config is reported")
        XCTAssertEqual(messages(shop, "invalid_config").first?.level, .warning)
        XCTAssertEqual(messages(shop, "invalid_config").first?.context["reason"], "already_initialized")
    }

    func test_initialize_from_many_threads_at_once_makes_one_instance() {
        let shop = newShop()
        holdInit()
        let lock = NSLock()
        var made: [AnyObject] = []
        DispatchQueue.concurrentPerform(iterations: 16) { _ in
            let sdk = Rees46.initialize(config(shop)) as AnyObject
            lock.lock(); made.append(sdk); lock.unlock()
        }

        XCTAssertEqual(made.count, 16)
        XCTAssertTrue(made.allSatisfy { $0 === made[0] })
        XCTAssertEqual(SdkRegistry.shared.count(), 1)
        XCTAssertTrue(eventually { StubURLProtocol.requests(to: "/init", shop: shop).count == 1 }, "one instance, one /init")
        expectNoRequest(to: "/init", shop: shop, within: 0.3)
        XCTAssertEqual(StubURLProtocol.requests(to: "/init", shop: shop).count, 1)
    }

    func test_release_takes_the_creation_lock_so_initialize_never_hands_out_a_released_instance() {
        let shop = newShop()
        holdInit()
        guard let sdk = Rees46.initialize(config(shop)) as? SimplePersonalizationSDK else { return XCTFail("no instance") }
        let holding = DispatchSemaphore(value: 0)
        let letGo = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            Rees46.withCreationLock { () -> ((), () -> Void) in
                holding.signal()
                _ = letGo.wait(timeout: .now() + 10)
                return ((), {})
            }
        }
        holding.wait()
        let done = Locked(false)
        let released = expectation(description: "released")
        DispatchQueue.global().async {
            sdk.release()
            done.current = true
            released.fulfill()
        }
        // An initialize that holds the lock now sees the instance registered and not released.
        let quiet = expectation(description: "release waits")
        quiet.isInverted = true
        wait(for: [quiet], timeout: 0.3)
        XCTAssertFalse(done.current, "release waited for the creation lock")
        XCTAssertFalse(sdk.isReleased)
        XCTAssertTrue(same(SdkRegistry.shared.byShopId(shop), sdk))

        letGo.signal()
        wait(for: [released], timeout: 5)
        XCTAssertTrue(sdk.isReleased)
        XCTAssertNil(SdkRegistry.shared.byShopId(shop), "out of the registry once released")
        let next = Rees46.initialize(config(shop)) as? SimplePersonalizationSDK
        XCTAssertFalse(same(next, sdk))
        XCTAssertEqual(next?.isReleased, false)

        // Many times at once: whatever initialize returns while it is not released is registered.
        for _ in 0..<20 {
            guard let current = Rees46.initialize(config(shop)) as? SimplePersonalizationSDK else { return XCTFail("no instance") }
            let got = Locked<SimplePersonalizationSDK?>(nil)
            DispatchQueue.concurrentPerform(iterations: 2) { index in
                if index == 0 {
                    current.release()
                } else {
                    got.current = Rees46.initialize(self.config(shop)) as? SimplePersonalizationSDK
                }
            }
            if let got = got.current, !got.isReleased {
                XCTAssertTrue(same(SdkRegistry.shared.byShopId(shop), got))
            }
            XCTAssertFalse((SdkRegistry.shared.byShopId(shop) as? SimplePersonalizationSDK)?.isReleased ?? false,
                           "the registry never holds a released instance")
        }
    }

    func test_the_old_core_released_while_init_is_on_its_way_ends_not_initialized_and_shows_no_popup() {
        final class Delegate: PopupPresentationDelegate {
            let asked = Locked<[Bool]>([])
            var onAsk: (() -> Void)?
            func sdk(_ sdk: PersonalizationSDK, shouldPresentPopup popup: Popup) -> UIViewController? {
                asked.mutate { $0.append(Thread.isMainThread) }
                onAsk?()
                return nil
            }
        }
        let withPopup = StubReply(json: #"{"did":"stub-did","popup":{"id":7,"html":"<p>x</p>"}}"#)
        // The test host's own SDK may hold the modal slot with a popup of popups v3 from its live shop:
        // a legacy popup would wait for it to close, offered or not.
        PopupV3Slots.shared.reset()
        let shop = newShop()
        let gate = DispatchSemaphore(value: 0)
        holdInit(until: gate, reply: withPopup)
        let delegate = Delegate()
        let sdk = StubSDK.make(shopId: shop, logLevel: .debug)
        sdk.popupPresentationDelegate = delegate
        XCTAssertTrue(eventually { StubURLProtocol.requests(to: "/init", shop: shop).count == 1 })

        let shown = expectation(description: "a popup offered")
        shown.isInverted = true
        delegate.onAsk = { shown.fulfill() }
        sdk.release()
        gate.signal()
        XCTAssertTrue(eventually { self.messages(shop, "request").contains { $0.context["path"] == "init" } }, "/init answered")
        wait(for: [shown], timeout: 0.5)
        XCTAssertEqual(sdk.state, .notInitialized, "release is not undone by the answer")

        // Not released, the popup of the answer is offered — on the main thread.
        let live = newShop()
        let liveGate = DispatchSemaphore(value: 0)
        holdInit(until: liveGate, reply: withPopup)
        let liveDelegate = Delegate()
        let asked = expectation(description: "asked")
        liveDelegate.onAsk = { asked.fulfill() }
        let other = StubSDK.make(shopId: live)
        other.popupPresentationDelegate = liveDelegate
        PopupV3Slots.shared.reset()
        liveGate.signal()
        wait(for: [asked], timeout: 5)
        XCTAssertEqual(liveDelegate.asked.current, [true])
        XCTAssertEqual(other.state, .ready)
    }

    func test_a_lazily_registered_shop_and_initialize_meet_on_one_instance() {
        let shop = newShop()
        holdInit()
        Rees46.register(shops: [config(shop)])
        let lock = NSLock()
        var made: [AnyObject] = []
        DispatchQueue.concurrentPerform(iterations: 8) { index in
            let sdk: AnyObject? = index % 2 == 0
                ? (try? Rees46.instance(for: shop)) as AnyObject?
                : Rees46.initialize(config(shop)) as AnyObject
            lock.lock(); if let sdk = sdk { made.append(sdk) }; lock.unlock()
        }

        XCTAssertEqual(made.count, 8, "no lookup found the shop between its registration and its instance")
        XCTAssertTrue(made.allSatisfy { $0 === made[0] })
        XCTAssertTrue(Rees46.pendingShopIds().isEmpty)
    }

    func test_the_registry_keeps_the_instance_the_app_did_not_hold() throws {
        let shop = newShop()
        holdInit()
        weak var made: AnyObject?
        do {
            made = Rees46.initialize(config(shop)) as AnyObject
        }

        XCTAssertNotNil(made)
        XCTAssertTrue(made === (try Rees46.instance(for: shop) as AnyObject))
    }

    // MARK: - release()

    func test_release_stops_the_instance_and_the_next_initialize_makes_a_new_one() throws {
        for coreV2 in [false, true] {
            CoreFlag.reset()
            let shop = newShop()
            holdInit()
            let ready = expectation(description: "init")
            let sdk = Rees46.initialize(config(shop, coreV2: coreV2)) { _ in ready.fulfill() }
            wait(for: [ready], timeout: 5)
            XCTAssertEqual(sdk.state, .ready)

            sdk.release()

            XCTAssertEqual(sdk.state, .notInitialized)
            XCTAssertFalse(Rees46.isInitialized(shopId: shop))
            XCTAssertThrowsError(try Rees46.instance(for: shop)) { error in
                guard case Rees46Error.unknownShopId = error else { return XCTFail("expected unknownShopId, got \(error)") }
            }
            let call = expectation(description: "call")
            var outcome: Result<RecommenderResponse, SdkError>?
            sdk.recommend(blockId: "after-release") { outcome = $0; call.fulfill() }
            wait(for: [call], timeout: 5)
            guard case .failure(.initializationFailed)? = outcome else { return XCTFail("coreV2 = \(coreV2): expected notInitialized") }

            let fresh = Rees46.initialize(config(shop, coreV2: coreV2))
            XCTAssertFalse(same(fresh, sdk), "a new instance after release")
            XCTAssertTrue(same(try Rees46.instance(for: shop), fresh))
            fresh.release()
        }
    }

    func test_release_before_init_settles_calls_the_completion_once() {
        for coreV2 in [false, true] {
            CoreFlag.reset()
            let shop = newShop()
            let gate = DispatchSemaphore(value: 0)
            holdInit(until: gate)
            let lock = NSLock()
            var outcomes: [SdkError?] = []
            let sdk = Rees46.initialize(config(shop, coreV2: coreV2)) { error in
                lock.lock(); outcomes.append(error); lock.unlock()
            }
            XCTAssertTrue(eventually { !StubURLProtocol.requests(to: "/init", shop: shop).isEmpty })

            sdk.release()
            gate.signal()

            XCTAssertTrue(eventually { outcomes.count == 1 })
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            XCTAssertEqual(outcomes.count, 1, "coreV2 = \(coreV2)")
            guard case .initializationFailed?? = outcomes.first else { return XCTFail("coreV2 = \(coreV2): \(outcomes)") }
        }
    }

    // MARK: - State and its listeners

    func test_listeners_hear_the_current_state_then_each_change_once_on_the_main_thread_until_cancelled() {
        CoreFlag.reset(to: true)
        let shop = newShop()
        let lock = NSLock()
        let gate = DispatchSemaphore(value: 0)
        var replies = [StubReply(503), StubReply(json: #"{"did":"d"}"#)]
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            _ = gate.wait(timeout: .now() + 10)
            lock.lock(); defer { lock.unlock() }
            return replies.count > 1 ? replies.removeFirst() : replies[0]
        }
        let clock = FakeClock()
        let scheduler = ManualScheduler(clock: clock)
        let sdk = StubSDK.make(
            shopId: shop, coreV2: true,
            environment: CoreEnvironment(clock: clock, scheduler: scheduler, lifecycle: ManualAppLifecycle(), random: { 0.5 })
        )
        var heard: [(Rees46.SdkState, Bool)] = []
        let first = sdk.onStateChange { heard.append(($0, Thread.isMainThread)) }
        var second: [Rees46.SdkState] = []
        let cancelled = sdk.onStateChange { second.append($0) }
        cancelled.cancel()
        // The change that comes right after subscribing is not lost, and comes after the current state.
        gate.signal()

        XCTAssertTrue(eventually { sdk.state == .retrying && scheduler.pending == 1 })
        gate.signal()
        scheduler.advance(by: 1)
        XCTAssertTrue(eventually { heard.count == 3 })
        sdk.release()
        XCTAssertTrue(eventually { heard.count == 4 })
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))

        XCTAssertEqual(heard.map(\.0), [.initializing, .retrying, .ready, .notInitialized])
        XCTAssertTrue(heard.allSatisfy(\.1), "on the main thread")
        XCTAssertTrue(second.isEmpty, "a listener cancelled at once hears nothing")
        first.cancel()
    }

    func test_the_old_core_is_initializing_until_init_brings_a_did_and_then_ready() {
        let shop = newShop()
        let gate = DispatchSemaphore(value: 0)
        holdInit(until: gate)
        let identity = InMemoryUserIdentityRepository()
        let sdk = StubSDK.make(shopId: shop, identity: identity)
        var heard: [Rees46.SdkState] = []
        sdk.onStateChange { heard.append($0) }
        XCTAssertEqual(sdk.state, .initializing)

        gate.signal()
        XCTAssertTrue(eventually { sdk.state == .ready })
        XCTAssertTrue(eventually { heard == [.initializing, .ready] })

        // deleteUserCredentials: no did until the new /init answers.
        holdInit(reply: StubReply(json: #"{"did":"next-did"}"#, delay: 0.5))
        sdk.deleteUserCredentials()
        XCTAssertEqual(sdk.state, .initializing)
        XCTAssertTrue(eventually { sdk.state == .ready })
        XCTAssertTrue(eventually { heard == [.initializing, .ready, .initializing, .ready] })
        XCTAssertEqual(sdk.sessionId, sdk.userSeance)
    }

    func test_the_old_core_with_a_stored_did_is_ready_at_once_and_never_retrying_or_refused() {
        let replies: [(String, StubReply?)] = [("402", StubReply(402)), ("503", StubReply(503)), ("no answer", StubReply.noAnswer)]
        for (name, reply) in replies {
            StubURLProtocol.handler = { $0.path == "/init" ? reply : StubReply() }
            let shop = newShop()
            let identity = InMemoryUserIdentityRepository()
            identity.deviceId = "kept-did"
            let ready = expectation(description: "init")
            let kept = StubSDK.make(shopId: shop, identity: identity) { _ in ready.fulfill() }
            XCTAssertEqual(kept.state, .ready, name)
            wait(for: [ready], timeout: 5)
            XCTAssertEqual(kept.state, .ready, name)

            let fresh = newShop()
            let failed = expectation(description: "fresh init")
            let newDevice = StubSDK.make(shopId: fresh) { _ in failed.fulfill() }
            wait(for: [failed], timeout: 5)
            XCTAssertEqual(newDevice.state, .initializing, "\(name): a failed /init leaves the old core initializing")
            XCTAssertFalse(newDevice.storage.refused, "\(name): the old core keeps no refusal")
        }
    }

    func test_session_id_is_the_session_of_the_instance() {
        let sdk = StubSDK.make(shopId: newShop())
        XCTAssertFalse(sdk.userSeance.isEmpty)
        XCTAssertEqual(sdk.sessionId, sdk.userSeance)
        let fake = FakeSDK(shopId: "fake")
        XCTAssertEqual(fake.sessionId, "fake-seance")
        XCTAssertEqual(fake.state, .ready, "a conformer with a device id is ready by default")
        var told: [Rees46.SdkState] = []
        fake.onStateChange { told.append($0) }
        XCTAssertTrue(eventually { told == [.ready] }, "a conformer tells its state once")
    }
}
