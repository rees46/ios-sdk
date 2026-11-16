//
//  CoreDecisionTests.swift
//  REES46Tests
//
//  The decisions taken after the coverage audit of the new core, each pinned by a test that fails
//  without it: what a refused shop's `flush()` and cleared queue tell, the session window that only
//  tracking and a click extend, the token's week a forced re-initialization forgets, a tracking event
//  the disk refused that starts no session from the background, the order in which a refusal frees a
//  push and tells the caller, a full queue that drops nothing for an event the disk refused, every
//  source of a pending shop's did, one waiting token per provider, `release()` and the sessions the app's
//  configurations replaced, tracking that waits for a window with a `sid`, the background task of a
//  pending shop's push, the bridges' fallback errors and a keychain backup that could not be removed.
//

import XCTest
@_spi(Bridge) @testable import REES46

final class CoreDecisionTests: CoreScenarioTestCase {

    // MARK: - flush() and the refused shop's queue

    func test_flush_of_a_refused_shop_completes_without_an_error_and_after_release_is_not_initialized() {
        let shop = newShop()
        answer("/init", StubReply(403))
        let sdk = makeV2(shop)
        XCTAssertEqual(sdk.state, .refused)

        // Nothing to send: it ends, and it is no error (`sdk/core/init.md`).
        XCTAssertEqual(flush(sdk), .some(nil))
        let thrown = Locked<Error?>(nil)
        let async = expectation(description: "flush() async")
        _Concurrency.Task {
            do { try await sdk.flush() } catch { thrown.current = error }
            async.fulfill()
        }
        wait(for: [async], timeout: 5)
        XCTAssertNil(thrown.current)

        sdk.release()
        XCTAssertEqual(flush(sdk), .some(.notInitialized))
        let afterRelease = expectation(description: "flush() async after release")
        _Concurrency.Task {
            do { try await sdk.flush() } catch { thrown.current = error }
            afterRelease.fulfill()
        }
        wait(for: [afterRelease], timeout: 5)
        XCTAssertEqual(thrown.current as? Rees46.SdkError, .notInitialized)
    }

    func test_the_events_of_a_queue_the_shops_refusal_clears_hear_cancelled() {
        let shop = newShop()
        hold("/init")
        let sdk = makeV2(shop, settled: false)
        XCTAssertTrue(eventually { self.inits(shop).count == 1 }, "the launch's /init is on its way")
        network.isOnline = false
        let results = Locked<[Result<Void, Rees46.SdkError>]>([])
        let both = expectation(description: "both")
        both.expectedFulfillmentCount = 2
        for id in ["a", "b"] {
            sdk.tracking.productView(itemId: id, completion: Rees46.BridgeErrors.completion { result in
                results.mutate { $0.append(result) }
                both.fulfill()
            })
        }
        sdk.eventQueue?.settle()
        XCTAssertEqual(sdk.eventQueue?.waiting.count, 2, "on disk, waiting for the network")

        answer("/init", StubReply(403))
        release("/init")
        wait(for: [both], timeout: 5)
        XCTAssertEqual(sdk.state, .refused)
        // Not the shop's refusal: the events were cleared (`sdk/core/queue.md`, «Пределы»).
        XCTAssertEqual(results.current.map { result -> Rees46.SdkError? in
            if case .failure(let error) = result { return error }
            return nil
        }, [.cancelled, .cancelled])
        XCTAssertTrue(waitForLog(shop, "queue_dropped", reason: "refused"))
    }

    // MARK: - The window: tracking and a click extend it, the other events of pushes do not

    func test_push_events_other_than_a_click_do_not_extend_the_session_window() {
        let shop = newShop()
        let identity = knownIdentity()
        let sdk = makeV2(shop, identity: identity)
        let opened = identity.seanceLastActTime
        let launches = inits(shop).count

        // A push delivered in the background 1 h 59 min after the last event.
        clock.advance(by: 2 * 60 * 60 - 60)
        for event in [Rees46.PushEvent.delivered, .opened, .closed] {
            Rees46.handlePush(pushPayload(shop, code: "m-\(event.rawValue)"), event: event)
        }
        XCTAssertEqual(identity.seanceLastActTime, opened, "the window does not move")
        XCTAssertTrue(queueIdle(sdk))

        // Two minutes later the window has ended: the foreground starts a new session.
        clock.advance(by: 120)
        XCTAssertFalse(sdk.sessionWindow?.isAlive ?? true)
        lifecycle.send(.willEnterForeground)
        XCTAssertTrue(eventually { self.inits(shop).count == launches + 1 }, "a new session")
        XCTAssertTrue(eventually { sdk.sessionId != nil && sdk.sessionId != "s-0" })
    }

    func test_a_click_and_tracking_extend_the_session_window() {
        let shop = newShop()
        let identity = knownIdentity()
        let sdk = makeV2(shop, identity: identity)

        clock.advance(by: 2 * 60 * 60 - 60)
        Rees46.handlePush(pushPayload(shop), event: .clicked)
        XCTAssertEqual(identity.seanceLastActTime, clock.now(), "a click extends it, as on the server")

        clock.advance(by: 2 * 60 * 60 - 60)
        sdk.tracking.productView(itemId: "37")
        XCTAssertEqual(identity.seanceLastActTime, clock.now(), "a tracking event extends it")

        clock.advance(by: 120)
        XCTAssertTrue(sdk.sessionWindow?.isAlive ?? false, "extended: the foreground starts no session")
        XCTAssertTrue(SimplePersonalizationSDK.extendsSession("track/clicked"))
        XCTAssertTrue(SimplePersonalizationSDK.extendsSession("push"))
        XCTAssertFalse(SimplePersonalizationSDK.extendsSession("track/delivered"))
        XCTAssertFalse(SimplePersonalizationSDK.extendsSession("track/opened"))
        XCTAssertFalse(SimplePersonalizationSDK.extendsSession("track/closed"))
    }

    // MARK: - needReInitialization forgets the token's week

    func test_a_forced_re_initialization_sends_the_devices_token_with_the_new_did_on_the_new_core() {
        let shop = newShop()
        let store = StubSDK.deviceStore(shopId: shop)
        store.deviceToken = Rees46.PushToken(token: "t", provider: .apns)
        let storage = ShopStorage(shopId: shop, logger: SdkLogger(shopId: shop, level: .none))
        // The token went to the shop this week, for the did the re-initialization drops.
        storage.setPushTokenSent(ShopStorage.PushTokenSent(token: "t", at: clock.now()), platform: "ios")
        let identity = knownIdentity(did: "old-did")

        CoreFlag.reset(to: true)
        let sdk = StubSDK.make(
            shopId: shop, identity: identity, needReInitialization: true, logLevel: .debug, connectivity: network,
            coreV2: true, environment: environment, deviceStore: store
        )
        XCTAssertNil(storage.pushTokenSent(platform: "ios"), "the week was the dropped did's")
        XCTAssertTrue(eventually { !self.requests("/mobile_push_tokens", shop).isEmpty })
        let sent = requests("/mobile_push_tokens", shop).first?.body ?? [:]
        XCTAssertEqual(sent["token"] as? String, "t")
        XCTAssertEqual(sent["did"] as? String, "d-1", "the new did")
        XCTAssertNil(inits(shop).first?.query["did"], "the /init asked for a new one")
        sdk.release()
    }

    // MARK: - A tracking event the disk refused, in the background

    func test_a_tracking_event_the_disk_refuses_starts_no_session_from_the_background() throws {
        let shop = newShop()
        let sdk = makeV2(shop)
        let launches = inits(shop).count
        // A file where the queue's folder should be: the event cannot be written.
        let folder = try XCTUnwrap(sdk.storage.queueDirectory)
        try FileManager.default.createDirectory(at: folder.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not a folder".utf8).write(to: folder)
        defer { try? FileManager.default.removeItem(at: folder) }
        lifecycle.isInForeground = false
        clock.advance(by: 2 * 60 * 60 + 1)

        let done = expectation(description: "not taken")
        let outcome = Locked<Result<Void, Rees46.SdkError>?>(nil)
        sdk.tracking.productView(itemId: "a", completion: Rees46.BridgeErrors.completion { outcome.current = $0; done.fulfill() })
        wait(for: [done], timeout: 5)

        guard case .failure(.cancelled)? = outcome.current else { return XCTFail("\(String(describing: outcome.current))") }
        XCTAssertEqual(inits(shop).count, launches, "no /init from the background")
        XCTAssertTrue(requests("/push", shop).isEmpty)
        XCTAssertTrue(waitForLog(shop, "storage_failed"))
    }

    // MARK: - A refusal frees the push before the caller hears it

    func test_a_refused_push_event_is_free_again_when_its_caller_hears_the_refusal() {
        let shop = newShop()
        let sdk = makeV2(shop)
        sdk.release()
        let done = expectation(description: "refused")
        let takenWhenHeard = Locked<Bool?>(nil)
        sdk.notificationDelivered(type: "bulk", code: "m-1") { _ in
            takenWhenHeard.current = PushCenter.isTaken(.delivered, code: "m-1", shopId: shop)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(takenWhenHeard.current, false, "the same push routed now is not a repeat")
    }

    // MARK: - A full queue and a disk that refuses

    func test_a_full_queue_keeps_its_events_for_one_the_disk_refuses() throws {
        let shop = newShop()
        let sdk = makeV2(shop)
        network.isOnline = false
        for index in 1...EventQueue.capacity {
            sdk.tracking.productView(itemId: "item-\(index)")
        }
        sdk.eventQueue?.settle()
        XCTAssertEqual(sdk.eventQueue?.waiting.count, EventQueue.capacity)
        // The disk takes nothing more.
        let folder = try XCTUnwrap(sdk.storage.queueDirectory)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path) }

        sdk.tracking.productView(itemId: "new")
        sdk.eventQueue?.settle()
        XCTAssertEqual(sdk.eventQueue?.waiting.count, EventQueue.capacity, "no stored event made room for it")
        XCTAssertEqual(files(sdk.storage).count, EventQueue.capacity)
        let first = sdk.eventQueue?.waiting.first?.body["items"] as? [[String: Any]]
        XCTAssertEqual(first?.first?["id"] as? String, "item-1", "the oldest stays")
        XCTAssertTrue(logged(shop, "queue_dropped").isEmpty, "nothing dropped for overflow")
        XCTAssertTrue(waitForLog(shop, "storage_failed"))
    }

    // MARK: - A pending shop's did, from every source

    func test_a_pending_shop_whose_did_is_only_in_the_config_sends_its_push_with_it() {
        let (shop, storage) = registerPending(did: nil, deviceId: "rn-did")
        XCTAssertEqual(Rees46.handlePush(pushPayload(shop), event: .clicked), shop)
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/track/clicked", shop: shop) == 1 })
        XCTAssertEqual(requests("/track/clicked", shop).first?.body["did"] as? String, "rn-did")
        XCTAssertTrue(logged(shop, "push_dropped").isEmpty)
        XCTAssertTrue(inits(shop).isEmpty, "no /init for it")

        // The shop's instance, made later, takes the same did.
        let sdk = try? Rees46.instance(for: shop) as? SimplePersonalizationSDK
        XCTAssertTrue(eventually { !self.inits(shop).isEmpty })
        XCTAssertEqual(inits(shop).first?.query["did"], "rn-did")
        XCTAssertTrue(eventually { self.files(storage).isEmpty })
        sdk?.release()
    }

    func test_a_pending_shop_whose_did_is_only_in_the_saved_init_answer_sends_its_push_with_it() {
        let (shop, storage) = registerPending(did: nil)
        storage.writeSavedInitAnswer(Data(#"{"did":"saved-did","seance":"s"}"#.utf8))
        XCTAssertEqual(Rees46.handlePush(pushPayload(shop), event: .delivered), shop)
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/track/delivered", shop: shop) == 1 })
        XCTAssertEqual(requests("/track/delivered", shop).first?.body["did"] as? String, "saved-did")
        XCTAssertTrue(logged(shop, "push_dropped").isEmpty)
    }

    func test_a_pending_shop_whose_did_is_only_in_the_keychain_sends_its_push_with_it() throws {
        let (shop, _) = registerPending(did: nil)
        let account = KeychainPartition.account(shopId: shop, service: KeychainPartition.service)
        try InitService.upsertKeychainDidToken(Data(#"{"did":"keychain-did"}"#.utf8), identifier: account, instanceKeychainService: KeychainPartition.service)
        defer { try? InitService.deleteKeychainDidToken(identifier: account, instanceKeychainService: KeychainPartition.service) }
        XCTAssertEqual(Rees46.handlePush(pushPayload(shop), event: .delivered), shop)
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/track/delivered", shop: shop) == 1 })
        XCTAssertEqual(requests("/track/delivered", shop).first?.body["did"] as? String, "keychain-did")
    }

    func test_a_pending_shop_takes_the_pre_partition_did_while_no_shop_took_it() {
        let shop = newShop()
        let legacy = UserDefaults(suiteName: "test-standard-\(shop)")!
        defer { UserDefaults.standard.removePersistentDomain(forName: "test-standard-\(shop)") }
        legacy.set("standard-did", forKey: StoragePartition.deviceIdKey)
        let config = Rees46Config(shopId: shop, apiDomain: "stub.test")
        let storage = ShopStorage(shopId: shop, logger: SdkLogger(shopId: shop, level: .none))
        let push = PendingPush(shopId: shop, config: config, route: .event(.delivered), type: "bulk", code: "m", deviceId: "")
        XCTAssertEqual(PendingPushEvents.deviceId(for: push, storage: storage, legacy: legacy), "standard-did")

        // Another shop took it: it is not this one's.
        legacy.set(true, forKey: StoragePartition.legacyConsumedFlag)
        XCTAssertEqual(PendingPushEvents.deviceId(for: push, storage: storage, legacy: legacy), "")

        // The config's did once the shop took it no more; a forced re-initialization takes none.
        let configured = PendingPush(
            shopId: shop, config: Rees46Config(shopId: shop, apiDomain: "stub.test", deviceId: "cfg"),
            route: .event(.delivered), type: "bulk", code: "m", deviceId: ""
        )
        XCTAssertEqual(PendingPushEvents.deviceId(for: configured, storage: storage, legacy: legacy), "cfg")
        storage.partition.set(true, forKey: StorageMigrations.flagKey(.configuredDeviceId))
        XCTAssertEqual(PendingPushEvents.deviceId(for: configured, storage: storage, legacy: legacy), "")
        let forced = PendingPush(
            shopId: shop, config: Rees46Config(shopId: shop, apiDomain: "stub.test", deviceId: "cfg2", needReInitialization: true),
            route: .event(.delivered), type: "bulk", code: "m", deviceId: ""
        )
        storage.writeSavedInitAnswer(Data(#"{"did":"saved"}"#.utf8))
        XCTAssertEqual(PendingPushEvents.deviceId(for: forced, storage: storage, legacy: legacy), "")
        StoragePartition.store(for: shop).set("stored", forKey: StoragePartition.deviceIdKey)
        XCTAssertEqual(PendingPushEvents.deviceId(for: forced, storage: storage, legacy: legacy), "stored", "the stored did always counts")
    }

    // MARK: - The background task of a pending shop's push

    func test_the_background_task_of_a_pending_shops_push_begins_before_handle_push_returns() {
        let (shop, _) = registerPending(did: "pending-did")
        hold("/track/delivered")
        XCTAssertEqual(Rees46.handlePush(pushPayload(shop), event: .delivered), shop)
        XCTAssertEqual(lifecycle.backgroundTasks.begun, 1, "begun on the caller's thread")
        release("/track/delivered")
        XCTAssertTrue(eventually { self.lifecycle.backgroundTasks == (1, 1) }, "ended once it went")

        // A shop without a did: the task it began ends too.
        let (empty, _) = registerPending(did: nil)
        Rees46.handlePush(pushPayload(empty), event: .delivered)
        XCTAssertTrue(waitForLog(empty, "push_dropped", reason: "no_did"))
        XCTAssertTrue(eventually { self.lifecycle.backgroundTasks == (2, 2) })
    }

    // MARK: - One waiting token per provider

    func test_the_apns_and_fcm_tokens_given_before_the_first_did_both_go_once_init_answers() {
        let shop = newShop()
        hold("/init")
        let store = StubSDK.deviceStore(shopId: shop)
        let sdk = makeV2(shop, identity: InMemoryUserIdentityRepository(), deviceStore: store, settled: false)
        let service = NotificationService(sdk: sdk, notificationLogger: NotificationLogger())
        service.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: Data([0xAA]))
        service.didReceiveRegistrationFCMToken(fcmToken: "fcm-1")
        XCTAssertTrue(eventually { sdk.pendingPushTokens.count == 2 }, "each waits in its own slot")
        XCTAssertTrue(requests("/mobile_push_tokens", shop).isEmpty)

        release("/init")
        XCTAssertTrue(eventually { self.requests("/mobile_push_tokens", shop).count == 2 })
        let sent = requests("/mobile_push_tokens", shop).map { "\($0.body["platform"] as? String ?? ""):\($0.body["token"] as? String ?? "")" }
        XCTAssertEqual(Set(sent), ["ios:aa", "ios_firebase:fcm-1"])
        XCTAssertTrue(requests("/mobile_push_tokens", shop).allSatisfy { $0.body["did"] as? String == "d-1" })
        sdk.release()
    }

    // MARK: - The tracking waits for a window with a sid

    func test_tracking_waits_for_a_session_with_a_sid_instead_of_going_without_one() {
        let shop = newShop()
        // The renewal's answer brings no seance: the window opens without a sid.
        answer("/init", StubReply(json: #"{"did":"d","seance":"s-1"}"#), StubReply(json: #"{"did":"d"}"#), StubReply(json: #"{"did":"d","seance":"s-3"}"#))
        let sdk = makeV2(shop)
        XCTAssertEqual(sdk.sessionId, "s-1")
        clock.advance(by: 2 * 60 * 60 + 1)
        lifecycle.send(.willEnterForeground)
        XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/init", shop: shop) == 2 })
        XCTAssertTrue(eventually { sdk.sessionWindow?.isAlive == true && sdk.sessionWindow?.sid == "" })

        sdk.tracking.productView(itemId: "a")
        // The API refuses an event with a did and no sid: it waits for an /init that brings one.
        XCTAssertTrue(eventually { self.requests("/push", shop).count == 1 })
        XCTAssertEqual(inits(shop).count, 3, "a sid was asked for first")
        XCTAssertEqual(requests("/push", shop).first?.body["sid"] as? String, "s-3")
        XCTAssertTrue(queueIdle(sdk))
    }

    // MARK: - release() and the sessions the app's configurations replaced

    func test_release_cancels_a_request_on_a_session_the_apps_configuration_replaced_twice() async {
        let shop = newShop()
        let gate = DispatchSemaphore(value: 0)
        defer { for _ in 0..<4 { gate.signal() } }
        StubURLProtocol.handler = { request in
            if request.path == "/slow" { _ = gate.wait(timeout: .now() + 20) }
            return StubReply(json: "{}")
        }
        let client = NetworkClient(
            baseURL: "https://stub.test/", connectivity: FakeConnectivity(online: true), logger: SdkLogger(shopId: shop, level: .none)
        ) { CommonFields(shopId: shop, deviceId: "d", sessionId: "", stream: "ios", segment: "A") }
        let request = NetworkClient.Request(method: .get, path: "slow", timeout: 30)
        let pending = _Concurrency.Task { await client.send(request) }
        while StubURLProtocol.requests(to: "/slow").isEmpty {
            try? await _Concurrency.Task.sleep(nanoseconds: 10_000_000)
        }
        await client.use(URLSessionConfiguration.default)
        await client.use(URLSessionConfiguration.default)
        let retired = await client.retiredSessions
        XCTAssertGreaterThanOrEqual(retired, 1, "the session carrying the request is kept until it finished")
        await client.release()
        // Ends, though the server never answers: its session was cancelled too.
        let ended = expectation(description: "ended")
        let result = Locked<NetworkClient.Response?>(nil)
        _Concurrency.Task {
            result.current = await pending.value
            ended.fulfill()
        }
        await fulfillment(of: [ended], timeout: 5)
        guard case .failure(.cancelled)? = result.current?.result else { return XCTFail("\(String(describing: result.current?.result))") }
    }

    // MARK: - The bridges' fallback

    func test_an_old_error_outside_a_completion_maps_to_the_closest_new_one() {
        XCTAssertEqual(Rees46.BridgeErrors.error(of: .invalidResponse), .decoding, "an answer the SDK could not take")
        XCTAssertEqual(Rees46.BridgeErrors.error(of: .responseError), .decoding)
        XCTAssertEqual(Rees46.BridgeErrors.error(of: .decodeError), .decoding)
        XCTAssertEqual(Rees46.BridgeErrors.error(of: .networkOfflineError), .network)
        XCTAssertEqual(Rees46.BridgeErrors.error(of: .airplaneModeError), .network)
        XCTAssertEqual(Rees46.BridgeErrors.error(of: .initializationFailed), .notInitialized)
    }

    // MARK: - A keychain that does not remove the backup

    func test_a_keychain_backup_that_cannot_be_removed_is_storage_failed_at_error() {
        let shop = newShop()
        SdkLogger.register(SdkLogger(shopId: shop, level: .debug), owner: self)
        defer { SdkLogger.unregister(owner: self) }
        let original = InitService.deleteItem
        InitService.deleteItem = { _ in errSecInteractionNotAllowed }
        defer { InitService.deleteItem = original }

        KeychainInitStoreImpl(shopId: shop, service: "test.\(shop)").clear()

        XCTAssertTrue(waitForLog(shop, "storage_failed"))
        let failed = logged(shop, "storage_failed").first
        XCTAssertEqual(failed?.level, .error, "the customer's data was not removed")
        XCTAssertEqual(failed?.context["op"], "remove_keychain_backup")
    }
}
