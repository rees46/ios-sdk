//
//  CoreGapTests.swift
//  REES46Tests
//
//  The gaps the coverage audit of the new core found, over the stub server with the seams in the test's
//  hands: a pending shop's event on its way while its instance is made, a check of the shop that fails
//  for a moment, enqueues racing deleteUserCredentials, two shops' queues, a 2xx that is not JSON, one
//  message handled at once on many threads, the core flag rolled back, the requests of two shops at once,
//  per-method timeouts, the waits of calls in `initializing` and `refused`, the popup of `/init`, a late
//  answer after release(), the session across a restart, the push lane's answers, the old callbacks'
//  errors, the bridges' API, and what deleteUserCredentials does on a refused shop or twice.
//

import UIKit
import XCTest
@_spi(Bridge) @testable import REES46

final class CoreGapTests: CoreScenarioTestCase {

    // MARK: - Q-H1 / PUSH-H5: a pending shop's event on its way while its instance is made

    func test_a_pending_shops_event_on_its_way_when_its_instance_is_made_goes_once() throws {
        let (shop, storage) = registerPending(did: "pending-did")
        hold("/track/delivered")
        Rees46.handlePush(pushPayload(shop), event: .delivered)
        XCTAssertTrue(eventually { self.requests("/track/delivered", shop).count == 1 })

        let sdk = try XCTUnwrap(try Rees46.instance(for: shop) as? SimplePersonalizationSDK)
        defer { sdk.release() }
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/init", shop: shop) == 1 })
        XCTAssertEqual(flush(sdk), .some(nil))
        XCTAssertEqual(requests("/track/delivered", shop).count, 1, "on its way: the instance's queue waits for its answer")

        release("/track/delivered")
        XCTAssertTrue(eventually { self.files(storage).isEmpty })
        XCTAssertEqual(flush(sdk), .some(nil))
        XCTAssertTrue(queueIdle(sdk))
        XCTAssertEqual(requests("/track/delivered", shop).count, 1, "once")
        XCTAssertTrue(logged(shop, "queue_dropped").isEmpty)
    }

    func test_a_pending_shops_event_its_send_did_not_deliver_goes_once_more_through_its_instance() throws {
        let (shop, storage) = registerPending(did: "pending-did")
        hold("/track/delivered")
        answer("/track/delivered", StubReply(503), StubReply(json: #"{"status":"success"}"#))
        Rees46.handlePush(pushPayload(shop), event: .delivered)
        XCTAssertTrue(eventually { self.requests("/track/delivered", shop).count == 1 })
        let sdk = try XCTUnwrap(try Rees46.instance(for: shop) as? SimplePersonalizationSDK)
        defer { sdk.release() }
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/init", shop: shop) == 1 })

        release("/track/delivered")
        // The 503 leaves it on disk; the instance's queue, woken by the answer, sends it once more.
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/track/delivered", shop: shop) == 2 })
        XCTAssertTrue(eventually { self.files(storage).isEmpty })
        XCTAssertTrue(queueIdle(sdk))
        XCTAssertEqual(requests("/track/delivered", shop).count, 2)
    }

    // MARK: - Q-H4: a check of the shop that fails for a moment

    func test_a_tracking_event_whose_shop_check_fails_for_a_moment_is_neither_lost_nor_dropped() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let launches = inits(shop).count
        answer("/push", StubReply(402), StubReply(json: #"{"status":"success"}"#))
        answer("/init", StubReply(503), StubReply(json: #"{"did":"d","seance":"s-9"}"#))

        sdk.tracking.productView(itemId: "a")
        XCTAssertTrue(eventually { self.inits(shop).count == launches + 1 && self.scheduler.pendingDelays.contains(1) }, "the check failed and waits out a pause")
        sdk.tracking.productView(itemId: "b")
        sdk.eventQueue?.settle()
        XCTAssertEqual(requests("/push", shop).count, 1, "nothing goes while the check is unanswered")
        XCTAssertEqual(sdk.eventQueue?.waiting.count, 2)

        scheduler.advance(by: 1)
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)) == ["a", "a", "b"] })
        XCTAssertTrue(queueIdle(sdk))
        XCTAssertTrue(logged(shop, "queue_dropped").isEmpty)
    }

    // MARK: - Q-H5: enqueues racing deleteUserCredentials

    func test_events_taken_on_many_threads_while_the_customer_is_deleted_are_never_lost_doubled_or_sent_without_a_did() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let succeeded = Locked<[String]>([])
        let finished = Locked(0)
        let total = 8 * 25
        let all = expectation(description: "every completion")
        all.expectedFulfillmentCount = total
        DispatchQueue.concurrentPerform(iterations: 8) { thread in
            for index in 0..<25 {
                let id = "t\(thread)-\(index)"
                sdk.tracking.productView(itemId: id) { result in
                    if case .success = result { succeeded.mutate { $0.append(id) } }
                    finished.mutate { $0 += 1 }
                    all.fulfill()
                }
                if thread == 0, index == 12 {
                    DispatchQueue.main.async { sdk.deleteUserCredentials() }
                }
            }
        }
        // Every event either went or was cleared with the deleted customer.
        XCTAssertTrue(eventually(timeout: 20) {
            _ = self.flush(sdk)
            return finished.current == total
        })
        wait(for: [all], timeout: 10)
        let sent = itemIds(requests("/push", shop))
        XCTAssertTrue(requests("/push", shop).allSatisfy { !(($0.body["did"] as? String) ?? "").isEmpty }, "never without a did")
        for id in succeeded.current {
            XCTAssertEqual(sent.filter { $0 == id }.count, 1, "\(id) once")
        }
        for thread in 0..<8 {
            let mine = sent.filter { $0.hasPrefix("t\(thread)-") }.compactMap { Int($0.split(separator: "-")[1]) }
            XCTAssertEqual(mine, mine.sorted(), "thread \(thread) in its order")
        }
        XCTAssertTrue(queueIdle(sdk))
        XCTAssertTrue(files(sdk.storage).isEmpty)
    }

    // MARK: - Q-H6: two shops' queues

    func test_two_shops_queues_are_independent() {
        let first = newShop()
        let second = newShop()
        let a = makeV2(first, identity: knownIdentity(did: "did-a"))
        let b = makeV2(second, identity: knownIdentity(did: "did-b"))
        StubURLProtocol.handler = { [handler = StubURLProtocol.handler] request in
            if request.path == "/push", request.body["shop_id"] as? String == first {
                return StubReply(503, headers: ["Retry-After": "300"])
            }
            return handler(request)
        }
        a.tracking.productView(itemId: "a-1")
        XCTAssertTrue(eventually { self.scheduler.pendingDelays.contains(300) }, "A waits out the server's pause")
        for id in ["b-1", "b-2", "b-3"] {
            b.tracking.productView(itemId: id)
        }
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", second)) == ["b-1", "b-2", "b-3"] }, "B goes at once, in order")
        XCTAssertTrue(requests("/push", second).allSatisfy { $0.body["did"] as? String == "did-b" })
        XCTAssertNotEqual(a.storage.queueDirectory, b.storage.queueDirectory)

        answer("/init", StubReply(404))
        a.deleteUserCredentials()
        XCTAssertTrue(eventually { a.state == .refused })
        XCTAssertTrue(queueIdle(b))
        XCTAssertEqual(b.state, .ready)
        XCTAssertTrue(logged(second, "queue_dropped").isEmpty)
        b.tracking.productView(itemId: "b-4")
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", second)).last == "b-4" })
    }

    // MARK: - Q-H7: a 2xx that is not JSON

    func test_a_2xx_that_is_not_json_counts_as_delivered_and_is_never_sent_again() {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer("/push", StubReply(200, json: "OK"))
        let done = expectation(description: "sent")
        let outcome = Locked<Result<Void, SdkError>?>(nil)
        sdk.tracking.productView(itemId: "a") { outcome.current = $0; done.fulfill() }
        wait(for: [done], timeout: 5)
        guard case .failure(.decodeError)? = outcome.current else { return XCTFail("\(String(describing: outcome.current))") }
        XCTAssertEqual(flush(sdk), .some(nil))
        XCTAssertTrue(queueIdle(sdk))
        XCTAssertEqual(requests("/push", shop).count, 1)
        XCTAssertTrue(files(sdk.storage).isEmpty)
        XCTAssertEqual(scheduler.pending, 0, "not repeated")
        XCTAssertTrue(logged(shop, "queue_dropped").isEmpty)

        answer("/track/delivered", StubReply(200, json: "OK"))
        Rees46.handlePush(pushPayload(shop), event: .delivered)
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/track/delivered", shop: shop) == 1 })
        XCTAssertTrue(queueIdle(sdk))
        XCTAssertEqual(requests("/track/delivered", shop).count, 1)
    }

    // MARK: - PUSH-H6: one message handled on many threads at once

    func test_one_message_handled_on_many_threads_at_once_is_one_event() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let callbacks = Locked(0)
        let listened = Locked(0)
        Rees46.setPushCallbacks(Rees46.PushCallbacks(onDelivered: { _ in callbacks.mutate { $0 += 1 } }))
        let listener = Rees46.onPushEvent { _, _ in listened.mutate { $0 += 1 } }
        defer { listener.cancel() }
        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            Rees46.handlePush(self.pushPayload(shop), event: .delivered)
        }
        XCTAssertTrue(eventually { self.requests("/track/delivered", shop).count == 1 })
        XCTAssertTrue(queueIdle(sdk))
        drainMainQueue()
        XCTAssertEqual(requests("/track/delivered", shop).count, 1)
        XCTAssertEqual(callbacks.current, 1)
        XCTAssertEqual(listened.current, 1)
        XCTAssertTrue(PushCenter.isTaken(.delivered, code: "m-1", shopId: shop))

        let (pending, storage) = registerPending(did: "pending-did")
        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            Rees46.handlePush(self.pushPayload(pending), event: .delivered)
        }
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/track/delivered", shop: pending) == 1 })
        XCTAssertTrue(eventually { self.files(storage).isEmpty })
        XCTAssertTrue(eventually { self.lifecycle.backgroundTasks.begun == self.lifecycle.backgroundTasks.ended })
        XCTAssertEqual(requests("/track/delivered", pending).count, 1)
    }

    // MARK: - S-H1: the core flag rolled back

    func test_rolling_the_core_flag_back_keeps_the_customer_and_the_session() {
        let shop = newShop()
        let partition = StoragePartition.store(for: shop)
        let device = UserDefaults(suiteName: "test-device-\(shop)")!
        let standardLike = UserDefaults(suiteName: "test-standard-\(shop)")!
        defer {
            UserDefaults.standard.removePersistentDomain(forName: "test-device-\(shop)")
            UserDefaults.standard.removePersistentDomain(forName: "test-standard-\(shop)")
        }
        let store = DeviceStore(defaults: device, pushTokenDefaults: standardLike)
        CoreFlag.reset(to: true)
        let v2 = StubSDK.make(
            shopId: shop, identity: UserIdentityRepositoryImpl(store: partition, device: store), logLevel: .debug,
            connectivity: network, coreV2: true, environment: environment, deviceStore: store
        )
        XCTAssertTrue(eventually { v2.state == .ready && v2.sessionId == "s-1" })
        NotificationRegistrar(sdk: v2).registerWithDeviceToken(deviceToken: Data([0x0A, 0x0B]))
        XCTAssertTrue(eventually { !self.requests("/mobile_push_tokens", shop).isEmpty })
        v2.release()

        // What 3.37.3 reads.
        XCTAssertEqual(partition.string(forKey: StoragePartition.deviceIdKey), "d-1")
        XCTAssertEqual(partition.string(forKey: StoragePartition.seanceKey), "s-1")
        XCTAssertNotNil(partition.object(forKey: StoragePartition.seanceLastActKey) as? Double)
        XCTAssertTrue(["A", "B"].contains(partition.string(forKey: StoragePartition.abSegmentKey) ?? ""))
        XCTAssertEqual(standardLike.data(forKey: SdkConstants.deviceToken), Data([0x0A, 0x0B]), "where the old core reads the token")

        // The old core on the same shop: the same customer, the same session.
        CoreFlag.reset(to: false)
        let legacy = makeLegacy(shop, identity: UserIdentityRepositoryImpl(store: partition, device: store))
        XCTAssertEqual(inits(shop).last?.query["did"], "d-1")
        XCTAssertEqual(inits(shop).last?.query["sid"], "s-1", "inside its window")
        legacy.release()

        // And back: the did stays, ready at once.
        CoreFlag.reset(to: true)
        let again = StubSDK.make(
            shopId: shop, identity: UserIdentityRepositoryImpl(store: partition, device: store), logLevel: .debug,
            connectivity: network, coreV2: true, environment: environment, deviceStore: store
        )
        XCTAssertEqual(again.state, .ready)
        XCTAssertEqual(again.deviceId, "d-1")
        again.release()
    }

    // MARK: - NET-M1: per-method timeouts on the new core

    func test_each_method_keeps_its_own_timeout_on_the_new_core() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let done = expectation(description: "all")
        done.expectedFulfillmentCount = 4
        sdk.recommend(blockId: "b", timeOut: 7) { _ in done.fulfill() }
        sdk.search(query: "q", timeOut: 3) { _ in done.fulfill() }
        sdk.getProductInfo(id: "1") { _ in done.fulfill() }
        sdk.sendIDFARequest(idfa: UUID()) { _ in done.fulfill() }
        wait(for: [done], timeout: 10)
        XCTAssertEqual(requests("/recommend/b", shop).first?.timeout, 7)
        XCTAssertEqual(requests("/search", shop).first?.timeout, 3)
        XCTAssertEqual(requests("/products/get", shop).first?.timeout, 10)
        XCTAssertEqual(inits(shop).last?.timeout, 5)
        _ = getProduct(sdk)
        XCTAssertEqual(requests("/products/get", shop).last?.timeout, 10, "a call after another keeps its own")
    }

    // MARK: - NET-M2: two shops' requests at once

    func test_requests_of_two_shops_at_once_never_mix() {
        let first = newShop()
        let second = newShop()
        let a = makeV2(first, identity: knownIdentity(did: "did-a"))
        let b = makeV2(second, identity: knownIdentity(did: "did-b"))
        StubURLProtocol.handler = { request in
            guard request.path == "/products/get" else { return StubReply() }
            Thread.sleep(forTimeInterval: Double.random(in: 0...0.02))
            return StubReply(json: #"{"name":"\#(request.query["shop_id"] ?? ""):\#(request.query["did"] ?? "")"}"#)
        }
        let names = Locked<[Int: String]>([:])
        let done = expectation(description: "all")
        done.expectedFulfillmentCount = 60
        DispatchQueue.concurrentPerform(iterations: 60) { index in
            let sdk = index % 2 == 0 ? a : b
            sdk.getProductInfo(id: "\(index)") { result in
                if case .success(let info) = result { names.mutate { $0[index] = info.name } }
                done.fulfill()
            }
        }
        wait(for: [done], timeout: 20)
        XCTAssertEqual(names.current.count, 60)
        for (index, name) in names.current {
            XCTAssertEqual(name, index % 2 == 0 ? "\(first):did-a" : "\(second):did-b")
        }
    }

    // MARK: - NET-M3: a call offline before the instance is ready

    func test_a_call_offline_before_ready_waits_for_the_instance_its_timeout_then_fails_as_timeout() {
        let shop = newShop()
        network.isOnline = false
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        XCTAssertEqual(sdk.state, .initializing)
        let done = expectation(description: "products/get")
        let outcome = Locked<Result<ProductInfo, Rees46.SdkError>?>(nil)
        sdk.getProductInfo(id: "1", completion: Rees46.BridgeErrors.completion { outcome.current = $0; done.fulfill() })
        XCTAssertTrue(eventually { self.scheduler.pendingDelays.contains(10) }, "it waits for the instance, at most its own timeout")
        XCTAssertNil(outcome.current)
        scheduler.advance(by: 10)
        wait(for: [done], timeout: 5)
        // As on Android: the wait for the instance is not cut by the network.
        guard case .failure(.timeout)? = outcome.current else { return XCTFail("\(String(describing: outcome.current))") }
        XCTAssertTrue(requests("/products/get", shop).isEmpty)
        sdk.release()
    }

    // MARK: - INIT-N1 / INIT-L3: the popup of /init and the saved answer

    func test_the_popup_of_an_init_answer_shows_on_main_and_not_after_release_nor_from_a_saved_answer() {
        final class Delegate: PopupPresentationDelegate {
            let asked = Locked<[(Int, Bool)]>([])
            func sdk(_ sdk: PersonalizationSDK, shouldPresentPopup popup: Popup) -> UIViewController? {
                asked.mutate { $0.append((popup.id, Thread.isMainThread)) }
                return nil
            }
        }
        PopupV3Slots.shared.reset()
        let popup = #""popup":{"id":7,"html":"<p>x</p>"}"#
        let shop = newShop()
        hold("/init")
        answer("/init", StubReply(json: #"{"did":"d","seance":"s-1",\#(popup)}"#))
        let delegate = Delegate()
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        sdk.popupPresentationDelegate = delegate
        release("/init")
        XCTAssertTrue(eventually { delegate.asked.current.count == 1 })
        XCTAssertEqual(delegate.asked.current.first?.0, 7)
        XCTAssertEqual(delegate.asked.current.first?.1, true, "on the main thread")
        sdk.release()

        // Released while its /init is on its way: nothing of the answer is taken.
        let late = newShop()
        hold("/init")
        let identity = InMemoryUserIdentityRepository()
        let lateDelegate = Delegate()
        let released = makeV2(late, identity: identity, settled: false)
        released.popupPresentationDelegate = lateDelegate
        XCTAssertTrue(eventually { self.inits(late).count == 1 })
        released.release()
        release("/init")
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/init", shop: late) == 1 })
        drainMainQueue()
        XCTAssertTrue(lateDelegate.asked.current.isEmpty)
        XCTAssertNil(identity.deviceId, "a late answer writes nothing")
        XCTAssertNil(released.storage.readSavedInitAnswer())
        XCTAssertEqual(released.state, .notInitialized)

        // A saved answer stands in: its popup was shown when it came, and its did is not the shop's.
        let saved = newShop()
        let storage = ShopStorage(shopId: saved, logger: SdkLogger(shopId: saved, level: .none))
        storage.writeSavedInitAnswer(Data(#"{"did":"saved-did",\#(popup)}"#.utf8))
        answer("/init", StubReply.noAnswer)
        let savedDelegate = Delegate()
        let standIn = makeV2(saved, identity: knownIdentity(did: "stored-did"), settled: false)
        standIn.popupPresentationDelegate = savedDelegate
        XCTAssertTrue(eventually { standIn.state == .retrying })
        _ = getProduct(standIn)
        XCTAssertEqual(requests("/products/get", saved).first?.query["did"], "stored-did")
        XCTAssertEqual(standIn.deviceId, "stored-did")
        drainMainQueue()
        XCTAssertTrue(savedDelegate.asked.current.isEmpty)
        standIn.release()
    }

    // MARK: - INIT-N2: a call waiting in initializing when the shop refuses

    func test_a_call_waiting_for_the_first_init_fails_shop_blocked_when_the_shop_refuses() {
        let shop = newShop()
        hold("/init")
        answer("/init", StubReply(403))
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        let done = expectation(description: "products/get")
        let outcome = Locked<Result<ProductInfo, Rees46.SdkError>?>(nil)
        sdk.getProductInfo(id: "1", completion: Rees46.BridgeErrors.completion { outcome.current = $0; done.fulfill() })
        XCTAssertTrue(eventually { self.scheduler.pendingDelays.contains(10) })
        release("/init")
        wait(for: [done], timeout: 5)
        guard case .failure(.shopBlocked)? = outcome.current else { return XCTFail("\(String(describing: outcome.current))") }
        XCTAssertFalse(scheduler.pendingDelays.contains(10), "its wait ended with the answer")
        XCTAssertTrue(requests("/products/get", shop).isEmpty)
        sdk.release()
    }

    // MARK: - INIT-N3: refused on an earlier launch, and the launch's /init fails

    func test_a_shop_refused_on_an_earlier_launch_stays_refused_while_its_init_fails() {
        let shop = newShop()
        let storage = ShopStorage(shopId: shop, logger: SdkLogger(shopId: shop, level: .none))
        storage.refused = true
        storage.writeSavedInitAnswer(Data(#"{"did":"x"}"#.utf8))
        answer("/init", StubReply(503), StubReply(json: #"{"did":"x","seance":"s-1"}"#))
        let sdk = makeV2(shop, identity: knownIdentity(did: "x"), settled: false)
        XCTAssertTrue(eventually { self.scheduler.pendingDelays.contains(1) })
        XCTAssertEqual(sdk.state, .refused, "not retrying: the first answer of this launch has not come")
        guard case .failure(.custom("shop blocked"))? = getProduct(sdk) else { return XCTFail("refused") }
        XCTAssertTrue(waitForLog(shop, "init_retry"))
        XCTAssertTrue(logged(shop, "init_saved_answer").isEmpty)
        scheduler.advance(by: 1)
        XCTAssertTrue(eventually { sdk.state == .ready })
        XCTAssertFalse(storage.refused)
        sdk.release()
    }

    // MARK: - INIT-N4: deleteUserCredentials while /init waits out a pause

    func test_delete_user_credentials_while_init_waits_out_a_pause_asks_for_a_new_did_at_once() {
        let shop = newShop()
        answer("/init", StubReply(json: #"{"did":"old","seance":"s-1"}"#), StubReply(503, headers: ["Retry-After": "120"]), StubReply(json: #"{"did":"new","seance":"s-2"}"#))
        let sdk = makeV2(shop, identity: knownIdentity(did: "old"))
        clock.advance(by: 2 * 60 * 60 + 1)
        lifecycle.send(.willEnterForeground)
        XCTAssertTrue(eventually { self.scheduler.pendingDelays.contains(120) }, "the renewal waits out the server's pause")
        let before = inits(shop).count

        sdk.deleteUserCredentials()
        XCTAssertTrue(eventually { sdk.state == .ready && sdk.deviceId == "new" })
        XCTAssertEqual(inits(shop).count, before + 1)
        XCTAssertNil(inits(shop).last?.query["did"])
        XCTAssertFalse(scheduler.pendingDelays.contains(120), "the deleted customer's pause is gone")
        sdk.release()
    }

    // MARK: - INIT-N16: the network back after a first launch that failed with a saved answer

    func test_the_network_back_after_a_failed_launch_with_a_saved_answer_sends_init_at_once() {
        let shop = newShop()
        let storage = ShopStorage(shopId: shop, logger: SdkLogger(shopId: shop, level: .none))
        storage.writeSavedInitAnswer(Data(#"{"did":"s"}"#.utf8))
        network.isOnline = false
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        XCTAssertTrue(eventually { sdk.state == .retrying && self.scheduler.pending >= 1 })
        XCTAssertTrue(inits(shop).isEmpty)
        network.isOnline = true
        XCTAssertTrue(eventually { self.inits(shop).count == 1 }, "at once, not after the pause")
        XCTAssertTrue(eventually { sdk.state == .ready })
        sdk.release()
    }

    // MARK: - INIT-N21: the thread of the new core's initialize completion

    func test_the_new_cores_init_completion_is_called_on_the_main_thread() {
        let shop = newShop()
        let onMain = Locked<[Bool]>([])
        let done = expectation(description: "init")
        CoreFlag.reset(to: true)
        let sdk = StubSDK.make(shopId: shop, connectivity: network, coreV2: true, environment: environment) { _ in
            onMain.mutate { $0.append(Thread.isMainThread) }
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        let late = expectation(description: "late")
        sdk.whenInitialized { _ in onMain.mutate { $0.append(Thread.isMainThread) }; late.fulfill() }
        wait(for: [late], timeout: 5)
        XCTAssertEqual(onMain.current, [true, true])
        sdk.release()
    }

    // MARK: - INIT-S2: the session across a restart, with the real identity store

    func test_the_session_goes_on_across_a_restart_inside_its_window_and_not_after_it() {
        let shop = newShop()
        let partition = StoragePartition.store(for: shop)
        let first = makeV2(shop, identity: UserIdentityRepositoryImpl(store: partition))
        XCTAssertEqual(first.sessionId, "s-1")
        first.release()

        clock.advance(by: 30 * 60)
        hold("/init")
        let second = makeV2(shop, identity: UserIdentityRepositoryImpl(store: partition), settled: false)
        XCTAssertEqual(second.sessionId, "s-1", "before the answer")
        XCTAssertTrue(eventually { self.inits(shop).count == 2 })
        XCTAssertEqual(inits(shop).last?.query["sid"], "s-1")
        release("/init")
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/init", shop: shop) == 2 })
        second.release()

        clock.advance(by: 2 * 60 * 60 + 1)
        hold("/init")
        let third = makeV2(shop, identity: UserIdentityRepositoryImpl(store: partition), settled: false)
        XCTAssertNil(third.sessionId, "the window ended")
        XCTAssertTrue(eventually { self.inits(shop).count == 3 })
        XCTAssertNil(inits(shop).last?.query["sid"])
        release("/init")
        XCTAssertTrue(eventually { third.sessionId != nil })
        third.release()
    }

    // MARK: - Q-M1 / Q-M10 / PUSH-L16: the push lane's answers

    func test_the_push_lane_drops_an_event_after_ten_server_errors_and_goes_on_without_init() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let launches = inits(shop).count
        answer("/track/clicked", StubReply(500))
        Rees46.handlePush(pushPayload(shop), event: .clicked)
        for attempt in 1...10 {
            XCTAssertTrue(eventually { self.requests("/track/clicked", shop).count == attempt }, "attempt \(attempt)")
            if attempt < 10 {
                XCTAssertTrue(eventually { !self.scheduler.pendingDelays.isEmpty })
                scheduler.advance(by: scheduler.pendingDelays.first ?? 1)
            }
        }
        XCTAssertTrue(waitForLog(shop, "queue_dropped", reason: "attempts"))
        XCTAssertEqual(logged(shop, "queue_dropped").first?.context["status"], "500")
        answer("/track/clicked")
        Rees46.handlePush(pushPayload(shop, code: "m-2"), event: .clicked)
        // The lane waits out the pause the tenth failure began, then goes on.
        if let pause = scheduler.pendingDelays.first { scheduler.advance(by: pause) }
        XCTAssertTrue(eventually { self.requests("/track/clicked", shop).last?.body["code"] as? String == "m-2" })
        XCTAssertEqual(inits(shop).count, launches, "no /init")
    }

    func test_the_push_lane_repeats_a_timeout_without_counting_it() {
        let shop = newShop()
        let sdk = makeV2(shop)
        var list = Array(repeating: StubReply(200, json: #"{"status":"success"}"#, cutAfter: 3, cutWith: .timedOut) as StubReply?, count: 11)
        list.append(StubReply(json: #"{"status":"success"}"#))
        replies.mutate { $0["/track/clicked"] = list }
        Rees46.handlePush(pushPayload(shop), event: .clicked)
        var pauses: [TimeInterval] = []
        for attempt in 1...11 {
            XCTAssertTrue(eventually { self.requests("/track/clicked", shop).count == attempt && !self.scheduler.pendingDelays.isEmpty }, "attempt \(attempt)")
            let pause = scheduler.pendingDelays.first ?? 1
            pauses.append(pause)
            scheduler.advance(by: pause)
        }
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/track/clicked", shop: shop) == 1 })
        XCTAssertTrue(queueIdle(sdk))
        XCTAssertEqual(requests("/track/clicked", shop).count, 12)
        XCTAssertEqual(Array(pauses.prefix(4)), [1, 2, 4, 8])
        XCTAssertEqual(pauses.last, 300)
        XCTAssertTrue(logged(shop, "queue_dropped").isEmpty, "a timeout is never counted")
    }

    func test_the_push_lane_drops_a_400_401_422_as_rejected_and_goes_on() {
        let shop = newShop()
        let sdk = makeV2(shop)
        for (index, code) in [400, 401, 422].enumerated() {
            answer("/track/clicked", StubReply(code))
            Rees46.handlePush(pushPayload(shop, code: "m-\(code)"), event: .clicked)
            XCTAssertTrue(eventually { self.logged(shop, "queue_dropped").count == index + 1 }, "\(code)")
            XCTAssertEqual(logged(shop, "queue_dropped").last?.context["reason"], "rejected")
            XCTAssertEqual(logged(shop, "queue_dropped").last?.context["status"], String(code))
            XCTAssertTrue(queueIdle(sdk))
        }
        XCTAssertEqual(scheduler.pending, 0, "none repeated")
    }

    // MARK: - Q-M5: JSON types survive the disk

    func test_the_json_types_of_an_event_survive_the_disk_and_a_restart() throws {
        let shop = newShop()
        let first = makeV2(shop)
        network.isOnline = false
        first.tracking.syncCart(items: [TrackingItem(id: "1", quantity: 2, price: 999.5)])
        first.tracking.syncFavorites(itemIds: ["1"])
        first.tracking.storyView(storyId: "12", slideId: "34", code: "main")
        first.trackPopupShown(popupId: 7) { _ in }
        first.tracking.custom(event: "e", time: 1_700_000_000)
        first.eventQueue?.settle()
        first.release()
        network.isOnline = true

        let second = makeV2(shop)
        XCTAssertEqual(flush(second), .some(nil))
        XCTAssertTrue(eventually { self.requests("/push/custom", shop).count == 1 })
        let pushes = requests("/push", shop).map(\.body)
        let cart = try XCTUnwrap(pushes.first { $0["full_cart"] != nil })
        let item = try XCTUnwrap((cart["items"] as? [[String: Any]])?.first)
        XCTAssertTrue(isInt(item["amount"]), "amount is a number")
        XCTAssertEqual(item["amount"] as? Int, 2)
        XCTAssertEqual(item["price"] as? Double, 999.5)
        XCTAssertTrue(isBool(cart["full_cart"]))
        XCTAssertTrue(isBool(pushes.first { $0["full_wish"] != nil }?["full_wish"]))
        XCTAssertTrue(isInt(requests("/track/stories", shop).first?.body["story_id"]))
        XCTAssertEqual(requests("/track/stories", shop).first?.body["story_id"] as? Int, 12)
        XCTAssertTrue(isInt(requests("/popup/showed", shop).first?.body["popup"]))
        XCTAssertEqual(requests("/push/custom", shop).first?.body["time"] as? Int, 1_700_000_000)
        second.release()
    }

    private func isBool(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private func isInt(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return false }
        return !CFNumberIsFloatType(number)
    }

    // MARK: - Q-M9: a tracking lane paused for a check holds no push

    func test_a_tracking_lane_paused_for_a_shop_check_holds_no_push_event() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let launches = inits(shop).count
        answer("/push", StubReply(402))
        hold("/init")
        sdk.tracking.productView(itemId: "a")
        XCTAssertTrue(eventually { self.inits(shop).count == launches + 1 }, "the check is on its way")
        Rees46.handlePush(pushPayload(shop), event: .clicked)
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/track/clicked", shop: shop) == 1 }, "the push went beside the paused lane")
        XCTAssertEqual(requests("/push", shop).count, 1)
        release("/init")
    }

    // MARK: - Q-M11: the old callback's error per drop

    func test_the_old_callback_hears_the_error_of_each_drop() {
        let shop = newShop()
        let sdk = makeV2(shop)
        // The server refuses a service of a shop that passed its check: its message reaches the callback.
        answer("/push", StubReply(402, json: #"{"status":"error","message":"crm off"}"#))
        let first = expectation(description: "service refused")
        let refused = Locked<Result<Void, SdkError>?>(nil)
        sdk.tracking.productView(itemId: "a") { refused.current = $0; first.fulfill() }
        // 402, the check passes, 402 again: the refusal of a service.
        wait(for: [first], timeout: 10)
        guard case .failure(.custom("crm off"))? = refused.current else { return XCTFail("\(String(describing: refused.current))") }

        // Expired: the callback hears a timeout.
        answer("/push")
        network.isOnline = false
        let second = expectation(description: "expired")
        let expired = Locked<Result<Void, Rees46.SdkError>?>(nil)
        sdk.tracking.productView(itemId: "old", completion: Rees46.BridgeErrors.completion { expired.current = $0; second.fulfill() })
        sdk.eventQueue?.settle()
        clock.advance(by: 7 * 24 * 60 * 60 + 1)
        network.isOnline = true
        wait(for: [second], timeout: 10)
        guard case .failure(.timeout)? = expired.current else { return XCTFail("\(String(describing: expired.current))") }

        // Cleared with the deleted customer: cancelled.
        network.isOnline = false
        let third = expectation(description: "cleared")
        let cleared = Locked<Result<Void, Rees46.SdkError>?>(nil)
        sdk.tracking.productView(itemId: "gone", completion: Rees46.BridgeErrors.completion { cleared.current = $0; third.fulfill() })
        sdk.eventQueue?.settle()
        sdk.deleteUserCredentials()
        wait(for: [third], timeout: 10)
        guard case .failure(.cancelled)? = cleared.current else { return XCTFail("\(String(describing: cleared.current))") }
        network.isOnline = true
    }

    // MARK: - Q-M13: a flush during a check of the shop

    func test_a_flush_during_a_check_of_the_shop_waits_for_its_init_at_most_a_read_timeout() {
        let shop = newShop()
        let sdk = makeV2(shop)
        let launches = inits(shop).count
        answer("/push", StubReply(402), StubReply(json: #"{"status":"success"}"#))
        // The check's /init gets no answer for a while: the server asks for five minutes.
        answer("/init", StubReply(503, headers: ["Retry-After": "300"]), StubReply(json: #"{"did":"d","seance":"s-9"}"#))
        sdk.tracking.productView(itemId: "a")
        XCTAssertTrue(eventually { self.inits(shop).count == launches + 1 && self.scheduler.pendingDelays.contains(300) })
        let flushed = Locked(false)
        sdk.flush { _ in flushed.current = true }
        XCTAssertTrue(eventually { self.scheduler.pendingDelays.contains(10) }, "it waits for the check's /init")
        drainMainQueue()
        XCTAssertFalse(flushed.current)
        scheduler.advance(by: 10)
        XCTAssertTrue(eventually { flushed.current }, "a read timeout at most")
        XCTAssertEqual(requests("/push", shop).count, 1, "the check is not answered yet")
    }

    // MARK: - PUSH-M1: a refused instance's push

    func test_a_refused_instance_takes_no_push_and_tells_nothing() {
        let shop = newShop()
        answer("/init", StubReply(403))
        let sdk = makeV2(shop)
        StoragePartition.store(for: shop).set("stored", forKey: StoragePartition.deviceIdKey)
        let heard = Locked(0)
        Rees46.setPushCallbacks(Rees46.PushCallbacks(onDelivered: { _ in heard.mutate { $0 += 1 } }))
        XCTAssertEqual(Rees46.handlePush(pushPayload(shop), event: .delivered), shop)
        XCTAssertTrue(eventually { !PushCenter.isTaken(.delivered, code: "m-1", shopId: shop) })
        sdk.eventQueue?.settle()
        drainMainQueue()
        XCTAssertEqual(heard.current, 0)
        XCTAssertTrue(files(sdk.storage).isEmpty)
        XCTAssertTrue(requests("/track/delivered", shop).isEmpty, "not rerouted to the pending path either")
    }

    // MARK: - PUSH-M2: two sends of a token at once, the first fails

    func test_two_sends_of_a_token_at_once_hear_the_one_failure_and_count_no_week() {
        let shop = newShop()
        let sdk = makeV2(shop)
        hold("/mobile_push_tokens")
        answer("/mobile_push_tokens", StubReply(500))
        let results = Locked<[Result<Void, SdkError>]>([])
        let both = expectation(description: "both")
        both.expectedFulfillmentCount = 2
        sdk.setPushTokenNotification(token: "t") { result in results.mutate { $0.append(result) }; both.fulfill() }
        XCTAssertTrue(eventually { self.requests("/mobile_push_tokens", shop).count == 1 })
        sdk.setPushTokenNotification(token: "t") { result in results.mutate { $0.append(result) }; both.fulfill() }
        drainMainQueue()
        XCTAssertTrue(results.current.isEmpty, "the second waits for the first's answer")
        release("/mobile_push_tokens")
        wait(for: [both], timeout: 5)
        XCTAssertTrue(results.current.allSatisfy { if case .failure = $0 { return true } else { return false } })
        XCTAssertEqual(requests("/mobile_push_tokens", shop).count, 1)
        XCTAssertNil(sdk.storage.pushTokenSent(platform: "ios"))
        XCTAssertNil(sdk.storage.pushTokenClaim(platform: "ios"))
    }

    // MARK: - PUSH-M4: an upgrade with only the old APNs token

    func test_an_upgrade_with_only_the_old_apns_token_sends_it_on_the_new_core() {
        let shop = newShop()
        let device = UserDefaults(suiteName: "test-device-\(shop)")!
        let standardLike = UserDefaults(suiteName: "test-standard-\(shop)")!
        defer {
            UserDefaults.standard.removePersistentDomain(forName: "test-device-\(shop)")
            UserDefaults.standard.removePersistentDomain(forName: "test-standard-\(shop)")
        }
        standardLike.set(Data([0x0A, 0x0B]), forKey: SdkConstants.deviceToken)
        UserDefaults.standard.set(Date(), forKey: NotificationRegistrar.lastUploadDateKey(shopId: shop))
        let sdk = makeV2(shop, deviceStore: DeviceStore(defaults: device, pushTokenDefaults: standardLike))
        XCTAssertTrue(eventually { self.requests("/mobile_push_tokens", shop).count == 1 })
        let body = requests("/mobile_push_tokens", shop).first?.body ?? [:]
        XCTAssertEqual(body["token"] as? String, "0a0b")
        XCTAssertEqual(body["platform"] as? String, "ios")
        XCTAssertTrue(eventually { sdk.storage.pushTokenSent(platform: "ios") != nil })
        XCTAssertNotNil(UserDefaults.standard.object(forKey: NotificationRegistrar.lastUploadDateKey(shopId: shop)), "the old week is the old core's")
    }

    // MARK: - PUSH-M8 / PUSH-M9: the bridges' initialize and queueEvent

    func test_the_bridges_hear_the_errors_of_initialize_on_each_core() {
        for (coreV2, reply, expected) in [
            (true, StubReply(404) as StubReply?, Rees46.SdkError.shopBlocked),
            (false, StubReply(404), .http(code: 404, serverCode: nil)),
            (false, StubReply(500), .http(code: 500, serverCode: nil)),
        ] {
            CoreFlag.reset(to: coreV2)
            let shop = newShop()
            answer("/init", reply)
            let heard = Locked<[Rees46.SdkError?]>([])
            let done = expectation(description: "init")
            done.expectedFulfillmentCount = 2
            let config = Rees46Config(shopId: shop, apiDomain: "stub.test", autoSendPushToken: false)
            let start: (@escaping (LegacySdkError?) -> Void) -> PersonalizationSDK = { completion in
                coreV2 ? Rees46.initializeBridge(config, completion: completion) : Rees46.initialize(config, completion: completion)
            }
            let sdk = start(Rees46.BridgeErrors.completion { error in heard.mutate { $0.append(error) }; done.fulfill() })
            if coreV2 {
                // The same shop again: its outcome, once more.
                _ = start(Rees46.BridgeErrors.completion { error in heard.mutate { $0.append(error) }; done.fulfill() })
            } else {
                (sdk as? SimplePersonalizationSDK)?.whenInitializedForTests { error in heard.mutate { $0.append(error) }; done.fulfill() }
            }
            wait(for: [done], timeout: 10)
            XCTAssertEqual(heard.current, [expected, expected], "coreV2 = \(coreV2), \(String(describing: reply?.status))")
            sdk.release()
        }
    }

    // MARK: - The bridges' way in: the new core and the A/B group they kept

    private func bridgeConfig(_ shop: String) -> Rees46Config {
        Rees46Config(shopId: shop, apiDomain: "stub.test", autoSendPushToken: false)
    }

    func test_initialize_bridge_runs_the_new_core_and_an_apps_initialize_the_old_one() {
        CoreFlag.reset()
        let bridged = newShop()
        let sdk = Rees46.initializeBridge(bridgeConfig(bridged)) as? SimplePersonalizationSDK
        XCTAssertEqual(sdk?.usesCoreV2, true)
        XCTAssertEqual(sdk?.core.kind, .v2)
        XCTAssertEqual(CoreFlag.current, true, "the bridge decided the process's core")
        sdk?.release()

        CoreFlag.reset()
        let app = newShop()
        let legacy = Rees46.initialize(bridgeConfig(app)) as? SimplePersonalizationSDK
        XCTAssertEqual(legacy?.usesCoreV2, false, "an app's configuration runs the old core")
        XCTAssertEqual(legacy?.core.kind, .legacy)
        XCTAssertEqual(legacy?.config.coreV2, false)

        // A bridge after the app: the process keeps the core the app decided, and says so.
        let late = newShop()
        let after = Rees46.initializeBridge(bridgeConfig(late)) as? SimplePersonalizationSDK
        XCTAssertEqual(after?.usesCoreV2, false)
        XCTAssertTrue(waitForLog(late, "core_flag_mismatch"))
        XCTAssertEqual(CoreFlag.current, false)
        legacy?.release()
        after?.release()
    }

    func test_the_shops_instance_keeps_the_app_domain_of_its_config() {
        CoreFlag.reset()
        let shop = newShop()
        let config = Rees46Config(shopId: shop, apiDomain: "stub.test", appDomain: "app.cluster.test", autoSendPushToken: false)
        let sdk = Rees46.initializeBridge(config) as? SimplePersonalizationSDK
        XCTAssertEqual(sdk?.config.appDomain, "app.cluster.test")
        XCTAssertEqual(sdk?.usesCoreV2, true)

        // The same shop with another host keeps the one it was made with, and says so.
        _ = Rees46.initializeBridge(Rees46Config(shopId: shop, apiDomain: "stub.test", appDomain: "app.other.test", autoSendPushToken: false))
        XCTAssertTrue(waitForLog(shop, "invalid_config", reason: "already_initialized"))
        XCTAssertEqual(sdk?.config.appDomain, "app.cluster.test")
        sdk?.release()
    }

    func test_initialize_bridge_brings_its_ab_group_only_to_a_device_that_has_none() {
        let deviceSuite = UserDefaults(suiteName: DeviceStore.suiteName) ?? .standard
        let before = deviceSuite.string(forKey: DeviceStore.abGroupKey)
        defer { deviceSuite.set(before, forKey: DeviceStore.abGroupKey) }
        deviceSuite.removeObject(forKey: DeviceStore.abGroupKey)
        CoreFlag.reset()

        let first = newShop()
        let a = Rees46.initializeBridge(bridgeConfig(first), segment: "B")
        XCTAssertEqual(a.segment, "B", "the device had no group: it takes the bridge's")
        XCTAssertEqual(DeviceStore.shared.abGroup, "B")
        XCTAssertEqual(StoragePartition.store(for: first).string(forKey: StoragePartition.abSegmentKey), "B", "and the shop, for the old core")
        XCTAssertTrue(logged(first, "invalid_config").isEmpty)

        let second = newShop()
        let b = Rees46.initializeBridge(bridgeConfig(second), segment: "A")
        XCTAssertEqual(b.segment, "B", "the device keeps its own")
        XCTAssertTrue(waitForLog(second, "invalid_config", reason: "segment_kept"))

        let third = newShop()
        let c = Rees46.initializeBridge(bridgeConfig(third), segment: "a")
        XCTAssertEqual(c.segment, "B", "only a group the SDK makes is taken")
        XCTAssertTrue(waitForLog(third, "invalid_config", reason: "segment_invalid"))

        // The shop's instance is there: its group stays, whatever the bridge brings.
        XCTAssertTrue((Rees46.initializeBridge(bridgeConfig(first), segment: "A") as AnyObject) === (a as AnyObject))
        XCTAssertTrue(waitForLog(first, "invalid_config", reason: "segment_kept"))
        XCTAssertEqual(DeviceStore.shared.abGroup, "B")
        [a, b, c].forEach { $0.release() }
    }

    func test_queue_event_of_a_refused_or_released_instance_fails_on_main_and_queues_nothing() {
        let shop = newShop()
        answer("/init", StubReply(403))
        let refused = makeV2(shop)
        let first = expectation(description: "refused")
        let onMain = Locked<[Bool]>([])
        refused.queueEvent(path: "push", body: ["event": "view"]) { result in
            onMain.mutate { $0.append(Thread.isMainThread) }
            if case .failure(.shopBlocked) = result { first.fulfill() }
        }
        wait(for: [first], timeout: 5)
        XCTAssertTrue(files(refused.storage).isEmpty)

        CoreFlag.reset(to: false)
        answer("/init")
        let legacyShop = newShop()
        let legacy = makeLegacy(legacyShop)
        legacy.release()
        let second = expectation(description: "released")
        legacy.queueEvent(path: "push", body: ["event": "view"]) { result in
            onMain.mutate { $0.append(Thread.isMainThread) }
            if case .failure(.notInitialized) = result { second.fulfill() }
        }
        wait(for: [second], timeout: 5)
        XCTAssertEqual(onMain.current, [true, true])
        XCTAssertTrue(requests("/push", legacyShop).isEmpty)
    }

    // MARK: - S-M2 / S-M3: deleteUserCredentials on a refused shop, and twice

    func test_delete_user_credentials_on_a_refused_shop_asks_init_again_without_a_did() {
        let shop = newShop()
        answer("/init", StubReply(403))
        let sdk = makeV2(shop)
        XCTAssertEqual(sdk.state, .refused)
        XCTAssertTrue(sdk.storage.refused)
        hold("/init")
        answer("/init", StubReply(json: #"{"did":"fresh","seance":"s-1"}"#))
        sdk.deleteUserCredentials()
        XCTAssertFalse(sdk.storage.refused, "forgotten with the customer")
        XCTAssertEqual(sdk.state, .initializing)
        release("/init")
        XCTAssertTrue(eventually { sdk.state == .ready && sdk.deviceId == "fresh" })
        XCTAssertNil(inits(shop).last?.query["did"])
    }

    func test_delete_user_credentials_twice_at_once_never_sends_a_deleted_did() {
        let shop = newShop()
        let sdk = makeV2(shop)
        DispatchQueue.concurrentPerform(iterations: 2) { _ in sdk.deleteUserCredentials() }
        XCTAssertTrue(eventually { sdk.state == .ready && !sdk.deviceId.isEmpty })
        XCTAssertTrue(inits(shop).dropFirst(1).allSatisfy { $0.query["did"] == nil }, "no /init carries a did after the delete")
        XCTAssertEqual(sdk.userIdentity.deviceId, sdk.deviceId)
        XCTAssertTrue(eventually { self.logged(shop, "device_id_reset").count == 2 })
    }

    // MARK: - S-M6: the source an older SDK kept in .standard

    func test_delete_user_credentials_forgets_the_source_an_older_sdk_kept_in_standard() {
        let shop = newShop()
        let keys = [TrackingSourceStoreImpl.Keys.type, TrackingSourceStoreImpl.Keys.code, TrackingSourceStoreImpl.Keys.savedAt]
        let previous = keys.map { UserDefaults.standard.object(forKey: $0) }
        defer { zip(keys, previous).forEach { UserDefaults.standard.set($1, forKey: $0) } }
        UserDefaults.standard.set("chain", forKey: TrackingSourceStoreImpl.Keys.type)
        UserDefaults.standard.set("c", forKey: TrackingSourceStoreImpl.Keys.code)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: TrackingSourceStoreImpl.Keys.savedAt)
        let sdk = makeV2(shop)
        XCTAssertEqual(sdk.sourceStore.currentSource()?.code, "c", "the fallback of an install mid-window")
        sdk.deleteUserCredentials()
        XCTAssertNil(sdk.sourceStore.currentSource())
        XCTAssertTrue(eventually { sdk.state == .ready })
        sdk.tracking.productView(itemId: "1")
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 })
        XCTAssertNil(requests("/push", shop).first?.body["source"])
    }

    // MARK: - LOG-M1: nothing personal reaches the log on the new core

    func test_nothing_personal_reaches_the_log_on_the_new_core() {
        let shop = newShop()
        let popup = #""popup":{"id":7,"html":"<p>secret html</p>"}"#
        answer("/init", StubReply(json: #"{"did":"secret-did-123","seance":"s",\#(popup)}"#))
        answer("/push", StubReply(422, json: #"{"status":"error","message":"Invalid email buyer@example.com"}"#))
        answer("/search", StubReply(500, json: #"{"message":"typed text"}"#))
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository())
        sdk.userEmail = "buyer@example.com"
        let done = expectation(description: "all")
        done.expectedFulfillmentCount = 3
        sdk.tracking.productView(itemId: "1") { _ in done.fulfill() }
        sdk.search(query: "typed text") { _ in done.fulfill() }
        sdk.setPushTokenNotification(token: "abcdef") { _ in done.fulfill() }
        Rees46.handlePush(pushPayload(shop).merging(["body": "secret body"]) { $1 }, event: .delivered)
        wait(for: [done], timeout: 10)
        XCTAssertTrue(waitForLog(shop, "queue_dropped", reason: "rejected"))
        let secrets = ["secret html", "secret-did-123", "buyer@example.com", "Invalid email", "abcdef", "secret body", "typed text"]
        for message in heard where message.shopId == shop || message.shopId == nil {
            let text = ([message.message] + message.context.map { "\($0.key)=\($0.value)" }).joined(separator: " ")
            for secret in secrets {
                XCTAssertFalse(text.contains(secret), "\(message.code): \(secret)")
            }
        }
        let dropped = logged(shop, "queue_dropped").first
        XCTAssertEqual(Set(dropped?.context.keys.map { $0 } ?? []), ["reason", "path", "status"])
    }

    // MARK: - PUSH-M6: the shop changes between the resolution and the lookup

    func test_a_push_whose_shop_is_released_right_after_its_resolution_goes_on_the_stored_did() {
        let shop = newShop()
        let sdk = makeV2(shop)
        StoragePartition.store(for: shop).set("stored", forKey: StoragePartition.deviceIdKey)
        let once = Locked(true)
        Rees46.resolutionObserver = { _ in
            var first = false
            once.mutate { first = $0; $0 = false }
            if first { sdk.release() }
        }
        XCTAssertEqual(Rees46.handlePush(pushPayload(shop), event: .delivered), shop)
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/track/delivered", shop: shop) == 1 }, "not dropped")
        XCTAssertEqual(requests("/track/delivered", shop).first?.body["did"] as? String, "stored")
        XCTAssertFalse(logged(nil, "push_dropped").contains { $0.context["reason"] == "unknown_shop" })
    }

    func test_a_push_whose_pending_shop_is_made_right_after_its_resolution_goes_through_the_new_instance() throws {
        let (shop, _) = registerPending(did: "pending-did")
        let made = Locked<PersonalizationSDK?>(nil)
        let once = Locked(true)
        Rees46.resolutionObserver = { resolution in
            var first = false
            once.mutate { first = $0; $0 = false }
            if first, case .pending = resolution { made.current = try? Rees46.instance(for: shop) }
        }
        XCTAssertEqual(Rees46.handlePush(pushPayload(shop), event: .delivered), shop)
        let sdk = try XCTUnwrap(made.current as? SimplePersonalizationSDK)
        defer { sdk.release() }
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/track/delivered", shop: shop) == 1 }, "not dropped")
        XCTAssertTrue(queueIdle(sdk))
        XCTAssertEqual(requests("/track/delivered", shop).count, 1)
        XCTAssertFalse(logged(nil, "push_dropped").contains { $0.context["reason"] == "unknown_shop" })
    }

    // MARK: - NET-L9 / 0f5d269: every media session of the SDK without cookies

    func test_every_media_and_image_session_of_the_sdk_neither_sends_nor_keeps_cookies() {
        func assertNoCookies(_ configuration: URLSessionConfiguration, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertFalse(configuration.httpShouldSetCookies, name, file: file, line: line)
            XCTAssertEqual(configuration.httpCookieAcceptPolicy, .never, name, file: file, line: line)
            XCTAssertNil(configuration.httpCookieStorage, name, file: file, line: line)
        }
        assertNoCookies(SdkURLSession.shared.configuration, "SdkURLSession")
        assertNoCookies(VideoDownloadManager.shared.session.configuration, "VideoDownloadManager.session")
        assertNoCookies(VideoDownloadManager.shared.backgroundSession.configuration, "VideoDownloadManager.backgroundSession")
        assertNoCookies(StoryBlockImageCache.urlSession.configuration, "StoryBlockImageCache")
        assertNoCookies(StoriesCollectionCellLoader.LoaderManager().session.configuration, "StoriesImageLoader")
        assertNoCookies(RWebViewManager().urlSession.configuration, "RWebViewManager")
        assertNoCookies(PersonalizationStoryVideos.shared.session.configuration, "PersonalizationStoryVideos")
        assertNoCookies(URLSessionQueue().session.configuration, "URLSessionQueue")
        // The loaders that used URLSession.shared go through the SDK's session.
        XCTAssertTrue(PersonalizationStoryImages().session === SdkURLSession.shared, "PersonalizationStoryMedia's default session")
    }

    // MARK: - S-M5: where the did comes from, both cores

    func test_the_configured_did_wins_over_the_keychains_on_both_cores() {
        for coreV2 in [false, true] {
            let shop = newShop()
            let keychain = InMemoryKeychainInitStore(Data(#"{"did":"K"}"#.utf8))
            let identity = InMemoryUserIdentityRepository()
            CoreFlag.reset(to: coreV2)
            let done = expectation(description: "init")
            let sdk = StubSDK.make(shopId: shop, identity: identity, keychain: keychain, connectivity: network, coreV2: coreV2, deviceId: "C", environment: environment) { _ in done.fulfill() }
            wait(for: [done], timeout: 10)
            XCTAssertTrue(eventually { !self.inits(shop).isEmpty })
            XCTAssertEqual(inits(shop).first?.query["did"], "C", "coreV2 = \(coreV2)")
            XCTAssertEqual(identity.deviceId, "C")
            XCTAssertTrue(StorageMigrations.isDone(.configuredDeviceId, in: sdk.storage.partition))
            sdk.release()
        }
    }

    // MARK: - S-M7: a storageKey set on an install that had none

    func test_a_storage_key_set_later_starts_a_partition_of_its_own_and_leaves_the_unprefixed_one() {
        let shop = newShop()
        let key = "later-\(UUID().uuidString.prefix(6))"
        let unprefixed = StoragePartition.store(for: shop)
        unprefixed.set("X", forKey: StoragePartition.deviceIdKey)
        let prefixedName = StoragePartition.suiteName(for: shop, storageKey: key)
        defer {
            UserDefaults.standard.removePersistentDomain(forName: prefixedName)
            ShopStorage(shopId: shop, storageKey: key, logger: SdkLogger(shopId: shop, level: .none)).directory.map { try? FileManager.default.removeItem(at: $0) }
        }
        CoreFlag.reset(to: false)
        let ready = expectation(description: "init")
        let sdk = SimplePersonalizationSDK(
            shopId: shop, apiDomain: "stub.test", autoSendPushToken: false, enableAutoPopupPresentation: false,
            storageKey: key, keychainStore: InMemoryKeychainInitStore(), connectivity: network
        ) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 10)
        XCTAssertNil(inits(shop).first?.query["did"], "separate keys stay separate")
        XCTAssertEqual(unprefixed.string(forKey: StoragePartition.deviceIdKey), "X", "left as it was")
        XCTAssertEqual(sdk.deviceId, "d-1")
        sdk.release()
    }

    // MARK: - Q-M4: a flush on the way to the background ends its task

    func test_the_way_to_the_background_flushes_under_a_task_it_ends_also_when_the_tracking_is_held() {
        let shop = newShop()
        let sdk = makeV2(shop)
        network.isOnline = false
        sdk.tracking.productView(itemId: "a")
        sdk.tracking.productView(itemId: "b")
        sdk.eventQueue?.settle()
        lifecycle.send(.didEnterBackground)
        clock.advance(by: 2 * 60 * 60 + 1)
        network.isOnline = true
        let launches = inits(shop).count
        lifecycle.send(.didEnterBackground)
        XCTAssertTrue(eventually { self.lifecycle.backgroundTasks.begun >= 2 && self.lifecycle.backgroundTasks.begun == self.lifecycle.backgroundTasks.ended })
        sdk.eventQueue?.settle()
        XCTAssertEqual(inits(shop).count, launches, "no session starts from the background")
        XCTAssertEqual(sdk.eventQueue?.waiting.count, 2)
        sdk.release()
    }

    // MARK: - NET-M4: the process's core after a release, and a pending shop of the other core

    func test_the_process_keeps_its_core_after_a_release_and_a_pending_shop_of_the_other_core_takes_the_process_one() {
        CoreFlag.reset()
        let first = newShop()
        let a = Rees46.initializeBridge(Rees46Config(shopId: first, apiDomain: "stub.test", autoSendPushToken: false))
        a.release()
        let second = newShop()
        let b = Rees46.initialize(Rees46Config(shopId: second, apiDomain: "stub.test", autoSendPushToken: false))
        XCTAssertEqual((b as? SimplePersonalizationSDK)?.usesCoreV2, true, "decided by the first, until the process ends")
        XCTAssertTrue(waitForLog(second, "core_flag_mismatch"))
        b.release()

        CoreFlag.reset()
        let legacy = newShop()
        let pending = newShop()
        let tracked = Locked<[PendingPush]>([])
        Rees46.pendingPushTracker = { push in tracked.mutate { $0.append(push) } }
        Rees46.register(shops: [
            Rees46Config(shopId: legacy, apiDomain: "stub.test"),
            Rees46Config(shopId: pending, apiDomain: "stub.test", coreV2: true),
        ])
        StoragePartition.store(for: pending).set("d", forKey: StoragePartition.deviceIdKey)
        Rees46.handlePush(pushPayload(pending), event: .clicked)
        XCTAssertEqual(tracked.current.count, 1, "the old core's path: the process runs the old core")
        XCTAssertEqual(tracked.current.first?.shopId, pending)
        XCTAssertTrue(files(ShopStorage(shopId: pending, logger: SdkLogger(shopId: pending, level: .none))).isEmpty)
        XCTAssertTrue(inits(pending).isEmpty)
    }

    // MARK: - PUSH-L14: an instance offline hears the event once it is on disk

    func test_an_instance_offline_tells_the_push_once_it_is_on_disk() {
        let shop = newShop()
        let sdk = makeV2(shop)
        network.isOnline = false
        let heard = Locked(0)
        Rees46.setPushCallbacks(Rees46.PushCallbacks(onDelivered: { _ in heard.mutate { $0 += 1 } }))
        Rees46.handlePush(pushPayload(shop), event: .delivered)
        XCTAssertTrue(eventually { heard.current == 1 }, "accepted on disk")
        XCTAssertEqual(files(sdk.storage).count, 1)
        XCTAssertTrue(requests("/track/delivered", shop).isEmpty)
        network.isOnline = true
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/track/delivered", shop: shop) == 1 })
        drainMainQueue()
        XCTAssertEqual(heard.current, 1, "once")
    }
}

private extension SimplePersonalizationSDK {
    /// The outcome of the instance's first initialization, for the bridges' view.
    func whenInitializedForTests(_ heard: @escaping (Rees46.SdkError?) -> Void) {
        whenInitialized(Rees46.BridgeErrors.completion(heard))
    }
}
