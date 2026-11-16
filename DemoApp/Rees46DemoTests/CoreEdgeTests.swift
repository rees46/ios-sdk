//
//  CoreEdgeTests.swift
//  REES46Tests
//
//  The boundaries and rare orderings the coverage audit listed as low gaps, where a test is cheap: the
//  answer table's edges, the pause and its spread, the window's edge, malformed `/init` answers, what a
//  renewal does not repeat, a method's own timeout while it waits, the token's week, a pending shop's
//  push the disk refuses, a token told while a bridge subscribes, the storage that cannot remove the
//  customer's files, the bare conformer's defaults and the core flag under concurrency.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class CoreEdgeTests: CoreScenarioTestCase {

    // MARK: - NET-L1: what an answer means at the edges

    func test_the_edges_of_2xx() {
        XCTAssertEqual(NetworkClient.classify(status: 199, body: Data("{}".utf8)).failureValue, .http(code: 199, serverCode: nil))
        XCTAssertEqual(NetworkClient.classify(status: 300, body: Data("{}".utf8)).failureValue, .http(code: 300, serverCode: nil))
        XCTAssertNil(NetworkClient.classify(status: 201, body: Data("{}".utf8)).failureValue)
        XCTAssertNil(NetworkClient.classify(status: 202, body: Data()).failureValue)
        XCTAssertEqual(NetworkClient.classify(status: 200, body: Data("ok".utf8)).failureValue, .decoding)
        XCTAssertEqual(NetworkClient.classify(status: 200, body: Data(), path: "init").failureValue, .decoding, "an empty /init answer has no did")
    }

    // MARK: - INIT-N11: the pause and its spread

    func test_the_pause_spreads_twenty_percent_and_retry_after_is_held_between_one_second_and_five_minutes() {
        XCTAssertEqual(RetryPolicy.pause(afterFailures: 1, random: 0), 0.8, accuracy: 0.0001)
        XCTAssertEqual(RetryPolicy.pause(afterFailures: 1, random: 0.999), 1.2, accuracy: 0.001)
        XCTAssertEqual(RetryPolicy.pause(afterFailures: 1, random: 0.5), 1)
        XCTAssertEqual(RetryPolicy.pause(afterFailures: 12, random: 0.5), 300)
        XCTAssertEqual(RetryPolicy.pause(retryAfter: 0), 1)
        XCTAssertEqual(RetryPolicy.pause(retryAfter: 300), 300)
        XCTAssertEqual(RetryPolicy.pause(retryAfter: 301), 300)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(NetworkClient.retryAfter("Thu, 01 Jan 1970 00:00:00 GMT", now: now), 0, "a date in the past")
        XCTAssertNil(NetworkClient.retryAfter("7", status: 500, now: now), "only a 429 or a 503 has one")
    }

    // MARK: - Q-L1: 201 and 202 delete the event

    func test_a_201_or_202_to_an_event_is_delivered() {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer("/push", StubReply(201, json: #"{"status":"success"}"#), StubReply(202, json: #"{"status":"success"}"#))
        let done = expectation(description: "both")
        done.expectedFulfillmentCount = 2
        let results = Locked<[Result<Void, SdkError>]>([])
        sdk.tracking.productView(itemId: "a") { result in results.mutate { $0.append(result) }; done.fulfill() }
        sdk.tracking.productView(itemId: "b") { result in results.mutate { $0.append(result) }; done.fulfill() }
        wait(for: [done], timeout: 5)
        XCTAssertTrue(results.current.allSatisfy { if case .success = $0 { return true } else { return false } })
        XCTAssertTrue(queueIdle(sdk))
        XCTAssertTrue(files(sdk.storage).isEmpty)
        XCTAssertEqual(requests("/push", shop).count, 2)
    }

    // MARK: - Q-L3: the event's lifetime at its edge

    func test_an_event_exactly_seven_days_old_goes_and_one_a_second_older_is_dropped() {
        let shop = newShop()
        let sdk = makeV2(shop)
        network.isOnline = false
        sdk.tracking.productView(itemId: "older")
        sdk.eventQueue?.settle()
        clock.advance(by: 1)
        sdk.tracking.productView(itemId: "edge")
        sdk.eventQueue?.settle()
        clock.advance(by: EventQueue.lifetime)
        // A session for the events that are left: the window ended long ago.
        network.isOnline = true
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)) == ["edge"] })
        XCTAssertTrue(waitForLog(shop, "queue_dropped", reason: "expired"))
        XCTAssertEqual(logged(shop, "queue_dropped").count, 1)
    }

    // MARK: - Q-L7: files that do not read as an event

    func test_a_file_of_an_unknown_path_or_without_a_time_is_dropped_unread_and_not_sent() throws {
        let shop = newShop()
        let storage = ShopStorage(shopId: shop, logger: SdkLogger(shopId: shop, level: .none))
        let folder = try XCTUnwrap(storage.makeQueueDirectory())
        let records: [[String: Any]] = [
            ["v": 1, "path": "track/received", "body": ["code": "c"], "created": 1_800_000_000.0],
            ["v": 1, "path": "unknown", "body": [:], "created": 1_800_000_000.0],
            ["v": 1, "path": "push", "body": ["event": "view"]],
            ["v": 1, "path": "push", "body": ["event": "view"], "created": 1e13],
        ]
        for (index, record) in records.enumerated() {
            try JSONSerialization.data(withJSONObject: record).write(to: folder.appendingPathComponent(String(format: "%020d-1-0000000%d.json", index + 1, index)))
        }
        let sdk = makeV2(shop)
        XCTAssertEqual(flush(sdk), .some(nil))
        XCTAssertTrue(eventually { self.logged(shop, "queue_dropped").filter { $0.context["reason"] == "unreadable" }.count == 4 })
        XCTAssertTrue(requests("/push", shop).isEmpty)
        XCTAssertTrue(requests("/track/received", shop).isEmpty)
        XCTAssertTrue(files(storage).isEmpty)
    }

    // MARK: - Q-L15: Retry-After 0 on the queue

    func test_a_retry_after_of_zero_on_the_queue_waits_a_second() {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer("/push", StubReply(503, headers: ["Retry-After": "0"]), StubReply(json: #"{"status":"success"}"#))
        sdk.tracking.productView(itemId: "a")
        XCTAssertTrue(eventually { self.scheduler.pendingDelays == [1] })
        scheduler.advance(by: 1)
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/push", shop: shop) == 2 })
    }

    // MARK: - Q-L16: refused at launch with the files of an earlier one

    func test_a_shop_refused_at_launch_clears_the_files_of_an_earlier_launch_and_sends_none() {
        let shop = newShop()
        let first = makeV2(shop)
        network.isOnline = false
        first.tracking.productView(itemId: "left")
        first.eventQueue?.settle()
        first.release()
        XCTAssertEqual(files(first.storage).count, 1)

        // The shop refused on that launch, after the event was taken.
        first.storage.refused = true

        network.isOnline = true
        answer("/init", StubReply(403))
        let second = makeV2(shop, settled: false)
        XCTAssertEqual(second.state, .refused)
        XCTAssertTrue(eventually { second.settledInitCount >= 1 })
        XCTAssertTrue(eventually { self.files(second.storage).isEmpty })
        XCTAssertTrue(requests("/push", shop).isEmpty)
        // The file the queue had not read yet counts as a dropped event too.
        XCTAssertTrue(waitForLog(shop, "queue_dropped", reason: "refused"))
        XCTAssertEqual(logged(shop, "queue_dropped").first?.context["count"], "1")
    }

    // MARK: - INIT-N10: a success resets the count of failures

    func test_a_successful_init_resets_the_pause_of_the_next_failure() {
        let shop = newShop()
        answer("/init", StubReply(503), StubReply(503), StubReply(json: #"{"did":"d","seance":"s-1"}"#), StubReply(503))
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        XCTAssertTrue(eventually { self.scheduler.pendingDelays == [1] })
        scheduler.advance(by: 1)
        XCTAssertTrue(eventually { self.scheduler.pendingDelays == [2] })
        scheduler.advance(by: 2)
        XCTAssertTrue(eventually { sdk.state == .ready })
        clock.advance(by: 2 * 60 * 60 + 1)
        lifecycle.send(.willEnterForeground)
        XCTAssertTrue(eventually { self.inits(shop).count == 4 && !self.scheduler.pendingDelays.isEmpty })
        XCTAssertEqual(scheduler.pendingDelays.first, 1, "counted from one again")
        sdk.release()
    }

    // MARK: - INIT-N12: the window at its edge

    func test_a_window_exactly_two_hours_old_has_ended() {
        let shop = newShop()
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = "d"
        identity.seance = "S"
        identity.seanceLastActTime = clock.now().addingTimeInterval(-SessionWindow.length)
        let sdk = makeV2(shop, identity: identity)
        XCTAssertNil(inits(shop).first?.query["sid"], "two hours since the last event: no sid")
        clock.advance(by: SessionWindow.length)
        XCTAssertFalse(sdk.sessionWindow?.isAlive ?? true)
        _ = getProduct(sdk)
        XCTAssertEqual(inits(shop).count, 2, "a request renews it first")
        sdk.release()
    }

    // MARK: - INIT-N14: malformed 2xx answers of /init

    func test_a_2xx_init_answer_without_a_usable_did_is_retrying_and_decoding() {
        for body in ["[]", #"{"did":123}"#, #"{"did":""}"#] {
            let shop = newShop()
            answer("/init", StubReply(json: body))
            let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), settled: false)
            XCTAssertTrue(eventually { sdk.state == .retrying }, body)
            XCTAssertTrue(waitForLog(shop, "decoding_failed"), body)
            sdk.release()
        }
        let shop = newShop()
        answer("/init", StubReply(json: #"{"did":"d","seance":123}"#))
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        XCTAssertTrue(eventually { sdk.state == .ready }, "a seance that is no string is none")
        sdk.release()
    }

    // MARK: - INIT-N15: what a renewal does not repeat

    func test_a_renewal_or_a_check_of_the_shop_sends_neither_the_contacts_nor_the_advertising_id_again() {
        let shop = newShop()
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        sdk.userEmail = "a@b.c"
        XCTAssertTrue(eventually { sdk.state == .ready && sdk.settledInitCount >= 1 })
        XCTAssertTrue(eventually { self.requests("/profile/set", shop).count == 1 })
        let settles = sdk.settledInitCount
        clock.advance(by: 2 * 60 * 60 + 1)
        lifecycle.send(.willEnterForeground)
        // The SDK took the renewal's answer, not only the stub gave it: an /init still on its way
        // answers the check itself, and no other goes.
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/init", shop: shop) == 2 && sdk.settledInitCount > settles })
        XCTAssertEqual(sdk.initMachine?.askShop(), .asked)
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/init", shop: shop) == 3 })
        _ = getProduct(sdk)
        XCTAssertEqual(requests("/profile/set", shop).count, 1)
        sdk.release()
    }

    // MARK: - INIT-N17: a method's own timeout bounds its wait

    func test_a_methods_own_timeout_bounds_its_wait_for_the_instance() {
        let shop = newShop()
        hold("/init")
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        let done = expectation(description: "recommend")
        let outcome = Locked<Result<RecommenderResponse, Rees46.SdkError>?>(nil)
        sdk.recommend(blockId: "b", timeOut: 2, completion: Rees46.BridgeErrors.completion { outcome.current = $0; done.fulfill() })
        XCTAssertTrue(eventually { self.scheduler.pendingDelays.contains(2) })
        scheduler.advance(by: 2)
        wait(for: [done], timeout: 5)
        guard case .failure(.timeout)? = outcome.current else { return XCTFail("\(String(describing: outcome.current))") }
        XCTAssertTrue(requests("/recommend/b", shop).isEmpty)
        release("/init")
        sdk.release()
    }

    // MARK: - INIT-N20: /init carries no source

    func test_init_carries_no_source() {
        let shop = newShop()
        let sdk = makeV2(shop)
        sdk.tracking.setSource(TrackingSource(type: .chain, code: "c-1"))
        clock.advance(by: 2 * 60 * 60 + 1)
        lifecycle.send(.willEnterForeground)
        XCTAssertTrue(eventually { self.inits(shop).count == 2 })
        let query = inits(shop).last?.query ?? [:]
        XCTAssertNil(query["from"])
        XCTAssertNil(query["code"])
        XCTAssertNil(query["source"])
        sdk.release()
    }

    // MARK: - INIT-N22: an /init that times out

    func test_an_init_that_times_out_is_retrying_with_the_error_timeout() {
        let shop = newShop()
        answer("/init", StubReply(200, json: #"{"did":"d"}"#, cutAfter: 2, cutWith: .timedOut))
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        XCTAssertTrue(eventually { sdk.state == .retrying })
        XCTAssertTrue(eventually { self.logged(shop, "init_retry").contains { $0.context["error"] == "timeout" } })
        sdk.release()
    }

    // MARK: - PUSH-L1: the week and the mark at their edges

    func test_the_week_and_the_mark_of_a_token_at_their_edges() {
        let shop = newShop()
        let sdk = makeV2(shop)
        sdk.storage.setPushTokenSent(ShopStorage.PushTokenSent(token: "t", at: clock.now()), platform: "ios")
        clock.advance(by: PushTokenWeek.length - 1)
        sdk.submitPushToken(Rees46.PushToken(token: "t", provider: .apns), completion: nil)
        XCTAssertTrue(waitForLog(shop, "push_token_skipped", reason: "sent_recently"), "a second before the week ends")
        XCTAssertTrue(requests("/mobile_push_tokens", shop).isEmpty)

        // A week that starts after now — the clock moved back — holds nothing.
        sdk.storage.setPushTokenSent(ShopStorage.PushTokenSent(token: "t", at: clock.now().addingTimeInterval(3600)), platform: "ios")
        let done = expectation(description: "sent")
        sdk.submitPushToken(Rees46.PushToken(token: "t", provider: .apns)) { _ in done.fulfill() }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(requests("/mobile_push_tokens", shop).count, 1)

        // A mark 4 min 59 s old holds a send back.
        sdk.storage.setPushTokenClaim(ShopStorage.PushTokenClaim(token: "t2", since: clock.now().addingTimeInterval(-(PushTokenWeek.markLifetime - 1))), platform: "ios")
        let skippedBefore = logged(shop, "push_token_skipped").count
        sdk.submitPushToken(Rees46.PushToken(token: "t2", provider: .apns), completion: nil)
        XCTAssertTrue(eventually { self.logged(shop, "push_token_skipped").count > skippedBefore })
        XCTAssertEqual(logged(shop, "push_token_skipped").last?.context["reason"], "sent_recently")
        XCTAssertEqual(requests("/mobile_push_tokens", shop).count, 1)
        sdk.release()
    }

    // MARK: - PUSH-L3: a token for a refused shop

    func test_a_token_for_a_refused_shop_is_shop_blocked_and_claims_nothing() {
        let shop = newShop()
        answer("/init", StubReply(403))
        let sdk = makeV2(shop)
        let done = expectation(description: "refused")
        let outcome = Locked<Result<Void, Rees46.SdkError>?>(nil)
        sdk.setPushTokenNotification(token: "t", completion: Rees46.BridgeErrors.completion { outcome.current = $0; done.fulfill() })
        wait(for: [done], timeout: 5)
        guard case .failure(.shopBlocked)? = outcome.current else { return XCTFail("\(String(describing: outcome.current))") }
        XCTAssertTrue(requests("/mobile_push_tokens", shop).isEmpty)
        XCTAssertNil(sdk.storage.pushTokenClaim(platform: "ios"))
        XCTAssertNil(sdk.storage.pushTokenSent(platform: "ios"))
    }

    // MARK: - PUSH-L4: once per shop, event and message

    func test_the_same_message_counts_once_per_shop_and_per_event() {
        let first = newShop()
        let second = newShop()
        let a = makeV2(first)
        let b = makeV2(second)
        Rees46.handlePush(pushPayload(first), event: .delivered)
        Rees46.handlePush(pushPayload(second), event: .delivered)
        Rees46.handlePush(pushPayload(first), event: .clicked)
        XCTAssertTrue(eventually {
            self.requests("/track/delivered", first).count == 1 && self.requests("/track/delivered", second).count == 1
                && self.requests("/track/clicked", first).count == 1
        })
        XCTAssertTrue(queueIdle(a))
        XCTAssertTrue(queueIdle(b))
    }

    // MARK: - PUSH-L6: a pending shop's push the disk refuses

    func test_a_pending_shops_push_the_disk_refuses_counts_once_it_went_and_not_when_it_failed() throws {
        let (shop, storage) = registerPending(did: "pending-did")
        // A file where the queue's folder should be.
        let folder = try XCTUnwrap(storage.queueDirectory)
        try FileManager.default.createDirectory(at: folder.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not a folder".utf8).write(to: folder)
        defer { try? FileManager.default.removeItem(at: folder) }
        let heard = Locked(0)
        Rees46.setPushCallbacks(Rees46.PushCallbacks(onDelivered: { _ in heard.mutate { $0 += 1 } }))

        // A 5xx: nothing kept, nothing counted, nothing heard.
        answer("/track/delivered", StubReply(503), StubReply(json: #"{"status":"success"}"#))
        Rees46.handlePush(pushPayload(shop), event: .delivered)
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/track/delivered", shop: shop) == 1 })
        XCTAssertTrue(eventually { self.lifecycle.backgroundTasks.ended == self.lifecycle.backgroundTasks.begun })
        XCTAssertTrue(eventually { !PushCenter.isTaken(.delivered, code: "m-1", shopId: shop) })
        drainMainQueue()
        XCTAssertEqual(heard.current, 0)

        // The same push again: it goes, counts and is heard once.
        Rees46.handlePush(pushPayload(shop), event: .delivered)
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/track/delivered", shop: shop) == 2 })
        XCTAssertTrue(eventually { heard.current == 1 })
        XCTAssertTrue(PushCenter.isTaken(.delivered, code: "m-1", shopId: shop))
        XCTAssertTrue(waitForLog(shop, "storage_failed"))
    }

    // MARK: - PUSH-L12: a token told while a bridge subscribes

    func test_a_token_told_while_a_bridge_subscribes_is_heard_once() {
        for round in 0..<50 {
            let token = Rees46.PushToken(token: "race-\(round)-\(UUID().uuidString)", provider: .fcm)
            let heard = Locked(0)
            let subscribed = Locked<Cancellable?>(nil)
            DispatchQueue.concurrentPerform(iterations: 2) { index in
                if index == 0 {
                    PushCenter.notify(token, instance: nil)
                } else {
                    subscribed.current = Rees46.onPushToken { told in
                        if told == token { heard.mutate { $0 += 1 } }
                    }
                }
            }
            drainMainQueue()
            XCTAssertEqual(heard.current, 1, "round \(round)")
            subscribed.current?.cancel()
        }
    }

    // MARK: - S-M4: the customer's files that cannot be removed

    func test_customer_files_that_cannot_be_removed_are_storage_failed_at_error() throws {
        let shop = newShop()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("edge-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = ShopStorage(
            shopId: shop, logger: SdkLogger(shopId: shop, level: .debug), partition: UserDefaults(suiteName: "test-\(shop)"), root: root
        )
        XCTAssertTrue(storage.writeSavedInitAnswer(Data(#"{"did":"d"}"#.utf8)))
        let queue = try XCTUnwrap(storage.makeQueueDirectory())
        try Data("{}".utf8).write(to: queue.appendingPathComponent("e.json"))
        let folder = try XCTUnwrap(storage.directory)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: queue.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: queue.path)
        }
        storage.removeSavedInitAnswer()
        storage.removeQueueDirectory()
        XCTAssertTrue(eventually { self.logged(shop, "storage_failed").count >= 2 })
        let failures = logged(shop, "storage_failed")
        XCTAssertTrue(failures.allSatisfy { $0.level == .error })
        XCTAssertEqual(Set(failures.compactMap { $0.context["op"] }), ["remove_saved_init", "remove_queue_dir"])
    }

    // MARK: - S-L3 / S-L9: what deleteUserCredentials keeps

    func test_delete_user_credentials_keeps_the_devices_tokens_the_flags_and_the_registration() {
        let shop = newShop()
        let store = StubSDK.deviceStore(shopId: shop)
        store.deviceToken = Rees46.PushToken(token: "apns-1", provider: .apns)
        store.deviceToken = Rees46.PushToken(token: "fcm-1", provider: .fcm)
        let sdk = makeV2(shop, deviceStore: store)
        let partition = sdk.storage.partition
        for step in [StorageMigrations.Step.keychainItem, .configuredDeviceId, .storageKeySuite] {
            partition.set(true, forKey: StorageMigrations.flagKey(step))
        }
        sdk.deleteUserCredentials()
        XCTAssertEqual(store.deviceToken(.apns)?.token, "apns-1")
        XCTAssertEqual(store.deviceToken(.fcm)?.token, "fcm-1")
        for step in [StorageMigrations.Step.keychainItem, .configuredDeviceId, .storageKeySuite] {
            XCTAssertTrue(partition.bool(forKey: StorageMigrations.flagKey(step)), step.rawValue)
        }
        XCTAssertTrue(same(try? Rees46.instance(for: shop), sdk), "the instance stays registered")
        sdk.release()
    }

    // MARK: - NET-L10: the core flag under concurrency

    func test_the_core_flag_is_decided_once_under_concurrency() {
        CoreFlag.reset()
        let results = Locked<[Bool]>([])
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            let active = CoreFlag.resolve(requested: index % 2 == 0)
            results.mutate { $0.append(active) }
        }
        XCTAssertEqual(Set(results.current).count, 1)
        XCTAssertEqual(results.current.count, 100)
    }

    // MARK: - NET-M9: the defaults of the new members on a bare conformer

    func test_a_bare_conformer_has_working_defaults_of_the_new_members() {
        let sdk = BareSDK()
        XCTAssertEqual(sdk.state, .ready)
        let states = Locked<[(Rees46.SdkState, Bool)]>([])
        let handle = sdk.onStateChange { state in states.mutate { $0.append((state, Thread.isMainThread)) } }
        drainMainQueue()
        drainMainQueue()
        XCTAssertEqual(states.current.count, 1)
        XCTAssertEqual(states.current.first?.1, true)
        handle.cancel()
        let flushed = Locked<[Bool]>([])
        let done = expectation(description: "flush")
        sdk.flush { error in
            XCTAssertNil(error)
            flushed.mutate { $0.append(Thread.isMainThread) }
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(flushed.current, [true])
        sdk.release()
        let asyncFlush = expectation(description: "flush async")
        _Concurrency.Task {
            try? await sdk.flush()
            asyncFlush.fulfill()
        }
        wait(for: [asyncFlush], timeout: 5)
    }

    // MARK: - Q-M2: a check that passed ten minutes ago is asked again

    func test_a_shop_check_that_passed_ten_minutes_ago_is_asked_again() {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer("/push", StubReply(402), StubReply(json: #"{"status":"success"}"#))
        sdk.tracking.productView(itemId: "a")
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)) == ["a", "a"] }, "checked and sent again")
        let inits = self.inits(shop).count

        // 9 min 59 s later the check still stands: the same refusal drops the event at once.
        clock.advance(by: InitMachine.checkShopInterval - 1)
        answer("/push", StubReply(402))
        sdk.tracking.productView(itemId: "soon")
        XCTAssertTrue(waitForLog(shop, "queue_dropped", reason: "service_refused"))
        XCTAssertEqual(self.inits(shop).count, inits)

        // Ten minutes later it is asked again.
        clock.advance(by: 1)
        answer("/push", StubReply(402), StubReply(json: #"{"status":"success"}"#))
        sdk.tracking.productView(itemId: "late")
        XCTAssertTrue(eventually { self.inits(shop).count == inits + 1 })
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)).filter { $0 == "late" }.count == 2 })
        sdk.release()
    }

    // MARK: - Q-M6: triggers that are not the app's keep an ordinary pause

    func test_the_network_an_init_answer_and_a_new_event_keep_the_queues_pause() {
        let shop = newShop()
        let sdk = makeV2(shop)
        answer("/push", StubReply(503), StubReply(json: #"{"status":"success"}"#))
        sdk.tracking.productView(itemId: "a")
        XCTAssertTrue(eventually { self.scheduler.pendingDelays == [1] })
        network.isOnline = false
        network.isOnline = true
        sdk.eventQueue?.initSucceeded()
        sdk.tracking.productView(itemId: "b")
        sdk.eventQueue?.settle()
        XCTAssertEqual(requests("/push", shop).count, 1, "the pause stands")
        XCTAssertEqual(scheduler.pendingDelays, [1])
        scheduler.advance(by: 1)
        XCTAssertTrue(eventually { self.itemIds(self.requests("/push", shop)) == ["a", "a", "b"] })
        sdk.release()
    }

    // MARK: - INIT-N7 / INIT-N8: what release, delete and askShop do to the pause of /init

    func test_an_init_ended_by_release_is_not_repeated_and_ask_shop_cuts_an_ordinary_pause() {
        let shop = newShop()
        answer("/init", StubReply(503))
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), settled: false)
        XCTAssertTrue(eventually { self.scheduler.pendingDelays == [1] })
        scheduler.advance(by: 1)
        XCTAssertTrue(eventually { self.scheduler.pendingDelays == [2] })
        // A check of the shop does not wait out an ordinary pause.
        let before = inits(shop).count
        XCTAssertEqual(sdk.initMachine?.askShop(), .asked)
        XCTAssertTrue(eventually { self.inits(shop).count == before + 1 })

        sdk.release()
        XCTAssertTrue(eventually { self.scheduler.pending == 0 }, "nothing is repeated after release()")
        scheduler.advance(by: 300)
        XCTAssertEqual(inits(shop).count, before + 1)
    }

    // MARK: - NET-L3 / NET-L6 / NET-L8: the client's edges

    func test_a_configuration_after_release_is_ignored_and_a_session_without_a_delegate_logs_nothing() {
        let shop = newShop()
        let sdk = makeV2(shop)
        sdk.urlSession = URLSession(configuration: .default)
        sdk.release()
        sdk.configureURLSession(configuration: .default)
        guard case .failure(.initializationFailed)? = getProduct(sdk) else { return XCTFail("after release") }
        XCTAssertTrue(logged(shop, "invalid_config").isEmpty)
    }

    func test_an_answer_that_does_not_parse_is_logged_by_its_path_without_its_body() async {
        let shop = "edge-\(UUID().uuidString.prefix(6))"
        let logger = SdkLogger(shopId: shop, level: .debug)
        let client = NetworkClient(baseURL: "https://stub.test/", connectivity: FakeConnectivity(online: true), logger: logger) {
            CommonFields(shopId: shop, deviceId: "d", sessionId: "", stream: "ios", segment: "A")
        }
        StubURLProtocol.handler = { _ in StubReply(200, json: "<html>") }
        let html = await client.send(.init(method: .get, path: "products/get"))
        guard case .failure(.decoding) = html.result else { return XCTFail("\(html.result)") }
        let heardBoth = await MainActor.run { eventually { self.logged(shop, "decoding_failed").count == 1 } }
        XCTAssertTrue(heardBoth)
        let decoding = await MainActor.run { () -> Rees46.SdkLogMessage? in self.logged(shop, "decoding_failed").first }
        XCTAssertEqual(decoding?.context["path"], "products/get")
        XCTAssertFalse(decoding?.message.contains("<html>") ?? true)
        await client.release()
    }

    // MARK: - S-L2 / PUSH-M5: two shops on one app group keep their own weeks and refusals

    func test_two_shops_on_one_app_group_keep_their_own_token_weeks() {
        let group = "group.test.\(UUID().uuidString.prefix(6))"
        defer { UserDefaults.standard.removePersistentDomain(forName: group) }
        let first = newShop()
        let second = newShop()
        let a = ShopStorage(shopId: first, storageKey: group, logger: SdkLogger(shopId: first, level: .none))
        let b = ShopStorage(shopId: second, storageKey: group, logger: SdkLogger(shopId: second, level: .none))
        a.setPushTokenSent(ShopStorage.PushTokenSent(token: "t", at: clock.now()), platform: "ios")
        XCTAssertNil(b.pushTokenSent(platform: "ios"), "a week of its own")
        a.refused = true
        XCTAssertFalse(b.refused)
        XCTAssertEqual(UserDefaults(suiteName: group)?.string(forKey: "personalization_sdk.push_token_sent.ios.\(StoragePartition.sanitize(first))"), "t", "the key carries the shop")
    }
}

private extension Result {
    var failureValue: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
