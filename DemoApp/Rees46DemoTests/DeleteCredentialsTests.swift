//
//  DeleteCredentialsTests.swift
//  REES46Tests
//
//  `deleteUserCredentials()` and `release()` after the review of stage 2: an `/init` answer that
//  comes during the wipe, work queued behind the earlier `/init`, the push token that never goes out
//  without a did, the customer outside the partition, a released instance, a late `sendIDFARequest`.
//

import XCTest
@testable import REES46

/// An identity whose first wipe stops halfway until the test lets it go on, and that remembers every
/// device id written after it.
final class PausingIdentity: UserIdentityRepository {
    private let lock = NSLock()
    private var storedDeviceId: String?
    private var wiped = false
    private var pauses = true
    private(set) var writtenAfterWipe: [String?] = []
    var seance: String?
    var seanceLastActTime: Date?
    var advertisingId: String?
    var abSegment: String?
    /// Signalled when the wipe has started.
    let wiping = DispatchSemaphore(value: 0)
    /// Lets the wipe finish.
    let resume = DispatchSemaphore(value: 0)

    var deviceId: String? {
        get { lock.lock(); defer { lock.unlock() }; return storedDeviceId }
        set {
            lock.lock()
            storedDeviceId = newValue
            if wiped { writtenAfterWipe.append(newValue) }
            lock.unlock()
        }
    }

    func removeDeviceId() { deviceId = nil }

    func clearIdentity() {
        lock.lock()
        storedDeviceId = nil
        wiped = true
        let pause = pauses
        pauses = false
        lock.unlock()
        seance = nil
        seanceLastActTime = nil
        guard pause else { return }
        wiping.signal()
        resume.wait()
    }
}

final class DeleteCredentialsTests: XCTestCase {

    private var shops: [String] = []
    private var suites: [String] = []
    private let standardKeys = StorageMigrations.customerKeys
    private var standardSnapshot: [String: Any] = [:]
    private var tokenSnapshot: Data?

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        standardSnapshot = [:]
        for key in standardKeys {
            if let value = UserDefaults.standard.object(forKey: key) { standardSnapshot[key] = value }
        }
        tokenSnapshot = DeviceStore.shared.pushToken
    }

    override func tearDown() {
        StubURLProtocol.uninstall()
        CoreFlag.reset()
        for shop in shops {
            StubSDK.removeSavedInit(shopId: shop)
            UserDefaults.standard.removeObject(forKey: NotificationRegistrar.lastUploadDateKey(shopId: shop))
            UserDefaults.standard.removeObject(forKey: RecentSearches.key(shopKey: shop))
        }
        shops.removeAll()
        suites.forEach { UserDefaults.standard.removePersistentDomain(forName: $0) }
        suites.removeAll()
        for key in standardKeys {
            UserDefaults.standard.removeObject(forKey: key)
            if let value = standardSnapshot[key] { UserDefaults.standard.set(value, forKey: key) }
        }
        DeviceStore.shared.pushToken = tokenSnapshot
        super.tearDown()
    }

    private func newShop() -> String {
        let shop = StubSDK.shopId()
        shops.append(shop)
        return shop
    }

    /// `/init` answers in turn: the n-th one waits for `gates[n]` when there is one, and brings `dids[n]`.
    private func initAnswers(dids: [String], gates: [Int: DispatchSemaphore] = [:]) -> () -> Int {
        let lock = NSLock()
        var calls = 0
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            lock.lock(); let call = calls; calls += 1; lock.unlock()
            if let gate = gates[call] {
                _ = gate.wait(timeout: .now() + 10)
            }
            let did = call < dids.count ? dids[call] : (dids.last ?? "")
            return StubReply(json: did.isEmpty ? "{}" : #"{"did":"\#(did)"}"#)
        }
        return { lock.lock(); defer { lock.unlock() }; return calls }
    }

    private func tokens(_ shop: String) -> [StubRequest] {
        StubURLProtocol.requests(to: "/mobile_push_tokens", shop: shop)
    }

    // MARK: - After the review of stage 3

    func test_the_configured_did_is_taken_once_does_not_come_back_after_delete_and_is_reported_once() {
        for coreV2 in [false, true] {
            let shop = newShop()
            _ = initAnswers(dids: ["server-did"])
            let identity = InMemoryUserIdentityRepository()
            let sdk = StubSDK.make(shopId: shop, identity: identity, coreV2: coreV2, deviceId: "app-did")
            XCTAssertEqual(identity.deviceId, "app-did", "coreV2 = \(coreV2)")
            XCTAssertTrue(eventually { StubURLProtocol.requests(to: "/init", shop: shop).count == 1 })
            sdk.deleteUserCredentials()
            XCTAssertTrue(eventually { identity.deviceId == "server-did" })
            sdk.release()

            // The next launch, with no did stored yet: the app's did is not taken again.
            let later = InMemoryUserIdentityRepository()
            let gate = DispatchSemaphore(value: 0)
            _ = initAnswers(dids: ["fresh-did"], gates: [0: gate])
            let next = StubSDK.make(shopId: shop, identity: later, coreV2: coreV2, deviceId: "app-did")
            XCTAssertNil(later.deviceId, "coreV2 = \(coreV2): the configured did does not come back")
            gate.signal()
            next.release()
        }

        // A shop that keeps its own did says so once, not on every launch.
        let own = newShop()
        let logs = Locked<[Rees46.SdkLogMessage]>([])
        Rees46.setLogHandler { message in
            if message.shopId == own { logs.mutate { $0.append(message) } }
        }
        defer { Rees46.setLogHandler(nil) }
        _ = initAnswers(dids: ["own-did"])
        for _ in 0..<2 {
            let identity = InMemoryUserIdentityRepository()
            identity.deviceId = "own-did"
            let sdk = StubSDK.make(shopId: own, identity: identity, deviceId: "app-did")
            XCTAssertEqual(identity.deviceId, "own-did")
            sdk.release()
        }
        XCTAssertTrue(eventually { logs.current.contains { $0.context["reason"] == "device_id_kept" } })
        // Both instances were made and released: everything they logged is with the handler now.
        SdkLogger.awaitDelivery()
        XCTAssertEqual(logs.current.filter { $0.context["reason"] == "device_id_kept" }.count, 1)
    }

    func test_the_stored_did_wins_over_the_did_a_caller_passed_on_both_cores() {
        for coreV2 in [false, true] {
            let shop = newShop()
            _ = initAnswers(dids: ["stored-did"])
            let identity = InMemoryUserIdentityRepository()
            let ready = expectation(description: "init")
            let sdk = StubSDK.make(shopId: shop, identity: identity, coreV2: coreV2) { _ in ready.fulfill() }
            wait(for: [ready], timeout: 5)
            XCTAssertTrue(eventually { identity.deviceId == "stored-did" })
            // The old core: a request whose instance lost its did in memory takes the stored one.
            sdk.deviceId = ""
            let posted = expectation(description: "post")
            sdk.postRequest(path: "push", params: ["shop_id": shop, "event": "view", "did": "caller-did"]) { _ in posted.fulfill() }
            wait(for: [posted], timeout: 5)
            XCTAssertEqual(StubURLProtocol.requests(to: "/push", shop: shop).last?.body["did"] as? String, "stored-did", "coreV2 = \(coreV2)")
            sdk.release()
        }
    }

    func test_a_push_token_deferred_just_as_the_did_came_is_sent_at_once() {
        let shop = newShop()
        _ = initAnswers(dids: ["the-did"])
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: shop) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)
        XCTAssertEqual(sdk.deviceId, "the-did")

        // The service saw no did, /init stored one and drained the deferred token, then the token was deferred.
        sdk.deferPushToken(.direct(token: "late-token", isFirebase: false))

        XCTAssertNil(sdk.pendingPushToken, "not left until the next /init")
        XCTAssertTrue(eventually { self.tokens(shop).contains { $0.body["token"] as? String == "late-token" } })
    }

    // MARK: - The wipe and a late /init

    func test_an_init_answer_that_comes_during_the_wipe_does_not_bring_the_deleted_did_back() {
        for coreV2 in [false, true] {
            let shop = newShop()
            let firstAnswer = DispatchSemaphore(value: 0)
            _ = initAnswers(dids: ["deleted-did", "next-did"], gates: [0: firstAnswer])
            let identity = PausingIdentity()
            let sdk = StubSDK.make(shopId: shop, identity: identity, coreV2: coreV2)
            XCTAssertTrue(eventually { StubURLProtocol.requests(to: "/init", shop: shop).count == 1 })

            DispatchQueue.global().async { sdk.deleteUserCredentials() }
            XCTAssertEqual(identity.wiping.wait(timeout: .now() + 5), .success)
            // The earlier /init answers while the wipe is halfway through: the stub has handed it to the
            // client before the wipe goes on.
            firstAnswer.signal()
            XCTAssertTrue(eventually { StubURLProtocol.answered(to: "/init", shop: shop) >= 1 }, "coreV2 = \(coreV2)")
            identity.resume.signal()

            XCTAssertTrue(eventually { identity.deviceId == "next-did" && sdk.deviceId == "next-did" }, "coreV2 = \(coreV2)")
            XCTAssertFalse(identity.writtenAfterWipe.contains("deleted-did"), "the deleted did came back, coreV2 = \(coreV2)")
            XCTAssertNil(StubURLProtocol.requests(to: "/init", shop: shop).last?.query["did"])
        }
    }

    func test_work_queued_behind_the_earlier_init_waits_for_the_new_one_and_never_goes_without_a_did() {
        let shop = newShop()
        let first = DispatchSemaphore(value: 0)
        let second = DispatchSemaphore(value: 0)
        _ = initAnswers(dids: ["deleted-did", "next-did"], gates: [0: first, 1: second])
        let sdk = StubSDK.make(shopId: shop)
        XCTAssertTrue(eventually { StubURLProtocol.requests(to: "/init", shop: shop).count == 1 })
        sdk.recommend(blockId: "queued") { _ in }
        sdk.setPushTokenNotification(token: "fcm-token", isFirebaseNotification: true) { _ in }

        sdk.deleteUserCredentials()
        XCTAssertTrue(eventually { StubURLProtocol.requests(to: "/init", shop: shop).count == 2 })
        // The answer to the earlier /init comes: it belongs to the deleted customer and lets nothing go.
        expectNoRequest(to: "/recommend/queued", shop: shop, within: 0.5) { first.signal() }
        XCTAssertTrue(tokens(shop).isEmpty)

        second.signal()
        XCTAssertTrue(eventually { !StubURLProtocol.requests(to: "/recommend/queued", shop: shop).isEmpty })
        XCTAssertEqual(StubURLProtocol.requests(to: "/recommend/queued", shop: shop).first?.query["did"], "next-did")
        XCTAssertTrue(eventually { !self.tokens(shop).isEmpty })
        XCTAssertEqual(tokens(shop).map { $0.body["did"] as? String }, ["next-did"])
    }

    // MARK: - The push token

    func test_the_push_token_waits_for_a_did_when_the_first_init_fails_and_claims_no_week_meanwhile() {
        for coreV2 in [false, true] {
            let shop = newShop()
            StubURLProtocol.handler = { $0.path == "/init" ? StubReply(500) : StubReply() }
            let ready = expectation(description: "init")
            let sdk = StubSDK.make(shopId: shop, coreV2: coreV2) { _ in ready.fulfill() }
            wait(for: [ready], timeout: 5)
            XCTAssertEqual(sdk.deviceId, "")

            NotificationRegistrar(sdk: sdk).registerWithDeviceToken(deviceToken: Data([0x0A, 0x0B]))
            let direct = expectation(description: "direct")
            let outcome = Locked<Result<Void, SdkError>?>(nil)
            sdk.setPushTokenNotification(token: "fcm-token", isFirebaseNotification: true) { outcome.current = $0; direct.fulfill() }
            if coreV2 {
                // Waiting for the did is no failure on the new core: the caller hears once it went.
                XCTAssertNil(outcome.current)
            } else {
                // The old core tells at once that it waits, as it always has.
                wait(for: [direct], timeout: 5)
                guard case let .failure(error)? = outcome.current else { return XCTFail("the call should say the token waits") }
                XCTAssertTrue(error.isPushTokenWaitingForDeviceId)
            }
            // Kept on the caller's thread, or before the old core's call answered: nothing went or can go.
            // Each provider waits in its own slot: the FCM token does not replace the APNs one.
            XCTAssertEqual(sdk.pendingPushTokens[.fcm], .direct(token: "fcm-token", isFirebase: true))
            XCTAssertEqual(sdk.pendingPushTokens[.apns], .device(Data([0x0A, 0x0B])), "coreV2 = \(coreV2)")
            XCTAssertTrue(tokens(shop).isEmpty, "a push token went out without a did, coreV2 = \(coreV2)")
            XCTAssertNil(UserDefaults.standard.object(forKey: NotificationRegistrar.lastUploadDateKey(shopId: shop)), "the week was claimed")

            // A did comes: the token goes with it.
            _ = initAnswers(dids: ["fresh-did"])
            sdk.deleteUserCredentials()
            // Both go, each with its platform, once the new did is stored.
            XCTAssertTrue(eventually { self.tokens(shop).count == 2 }, "coreV2 = \(coreV2)")
            let sent = Dictionary(uniqueKeysWithValues: tokens(shop).map { ($0.body["platform"] as? String ?? "", $0.body) })
            XCTAssertEqual(sent["ios"]?["token"] as? String, "0a0b")
            XCTAssertEqual(sent["ios_firebase"]?["token"] as? String, "fcm-token")
            XCTAssertTrue(tokens(shop).allSatisfy { $0.body["did"] as? String == "fresh-did" })
            XCTAssertNil(sdk.pendingPushToken)
            XCTAssertTrue(sdk.pendingPushTokens.isEmpty)
            if coreV2 {
                wait(for: [direct], timeout: 5)
                guard case .success? = outcome.current else { return XCTFail("\(String(describing: outcome.current))") }
            }
        }
    }

    func test_an_init_answer_without_a_did_sends_no_push_token_and_claims_no_week() {
        let shop = newShop()
        _ = initAnswers(dids: [""])
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: shop) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)

        expectNoRequest(to: "/mobile_push_tokens", shop: shop, within: 0.3) {
            NotificationRegistrar(sdk: sdk).registerWithDeviceToken(deviceToken: Data([0x0C]))
        }

        XCTAssertTrue(tokens(shop).isEmpty)
        XCTAssertNil(UserDefaults.standard.object(forKey: NotificationRegistrar.lastUploadDateKey(shopId: shop)))
        XCTAssertEqual(sdk.pendingPushToken, .device(Data([0x0C])))
    }

    // MARK: - Outside the partition

    func test_deleting_the_credentials_wipes_the_customer_where_an_older_sdk_kept_it_and_nothing_else() throws {
        let shop = newShop()
        let key = "old-key-\(UUID().uuidString.prefix(6))"
        suites.append(key)
        suites.append(StoragePartition.suiteName(for: shop, storageKey: key))
        let old = try XCTUnwrap(UserDefaults(suiteName: key))
        old.set("old-did", forKey: StoragePartition.deviceIdKey)
        old.set("old-seance", forKey: StoragePartition.seanceKey)
        old.set(Date(), forKey: StoragePartition.seanceLastActKey)
        old.set("the app's", forKey: "app.own.key")
        UserDefaults.standard.set("standard-did", forKey: StoragePartition.deviceIdKey)
        UserDefaults.standard.set("standard-seance", forKey: StoragePartition.seanceKey)
        UserDefaults.standard.set(Date(), forKey: StoragePartition.seanceLastActKey)
        UserDefaults.standard.set(["boots"], forKey: RecentSearches.key(shopKey: shop))
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            return StubReply(json: #"{"did":"\#(request.query["did"] ?? "next-did")"}"#, delay: request.query["did"] == nil ? 1 : 0)
        }
        CoreFlag.reset(to: false)
        let ready = expectation(description: "init")
        let sdk = SimplePersonalizationSDK(
            shopId: shop, apiDomain: "stub.test", autoSendPushToken: false, enableAutoPopupPresentation: false,
            storageKey: key, keychainStore: InMemoryKeychainInitStore()
        ) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)
        XCTAssertEqual(sdk.deviceId, "old-did", "the old suite gave its did")
        XCTAssertEqual(StoragePartition.deviceId(for: shop, storageKey: key), "old-did")

        sdk.deleteUserCredentials()

        for name in StorageMigrations.customerKeys {
            XCTAssertNil(old.object(forKey: name), name)
            XCTAssertNil(UserDefaults.standard.object(forKey: name), name)
        }
        XCTAssertEqual(old.string(forKey: "app.own.key"), "the app's", "only the customer's keys go")
        XCTAssertEqual(StoragePartition.deviceId(for: shop, storageKey: key), "", "a pending shop's push finds no deleted did")
        XCTAssertNil(UserDefaults.standard.object(forKey: RecentSearches.key(shopKey: shop)), "the customer's recent searches go")
        XCTAssertTrue(eventually { sdk.deviceId == "next-did" })
        if let folder = sdk.storage.directory {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    // MARK: - release()

    func test_a_released_instance_wipes_nothing_sends_nothing_and_fails_every_call_on_both_cores() {
        for coreV2 in [false, true] {
            let shop = newShop()
            let identity = InMemoryUserIdentityRepository()
            let ready = expectation(description: "init")
            let sdk = StubSDK.make(shopId: shop, identity: identity, coreV2: coreV2) { _ in ready.fulfill() }
            wait(for: [ready], timeout: 5)
            XCTAssertEqual(identity.deviceId, "stub-did")

            sdk.release()
            sdk.deleteUserCredentials()

            XCTAssertEqual(identity.deviceId, "stub-did", "nothing is wiped, coreV2 = \(coreV2)")
            XCTAssertEqual(sdk.deviceId, "stub-did")
            let done = expectation(description: "calls")
            done.expectedFulfillmentCount = 3
            var outcomes: [SdkError?] = []
            let lock = NSLock()
            func record(_ error: SdkError?) { lock.lock(); outcomes.append(error); lock.unlock(); done.fulfill() }
            sdk.recommend(blockId: "after-release") { result in
                if case let .failure(error) = result { record(error) } else { record(nil) }
            }
            sdk.postRequest(path: "push", params: ["event": "view"]) { result in
                if case let .failure(error) = result { record(error) } else { record(nil) }
            }
            sdk.setPushTokenNotification(token: "t") { result in
                if case let .failure(error) = result { record(error) } else { record(nil) }
            }
            wait(for: [done], timeout: 5)
            XCTAssertEqual(outcomes.count, 3)
            for outcome in outcomes {
                guard case .initializationFailed? = outcome else { return XCTFail("expected initializationFailed, got \(String(describing: outcome))") }
            }
            expectNoRequest(to: "/init", shop: shop, within: 0.3)
            XCTAssertEqual(StubURLProtocol.requests(to: "/init", shop: shop).count, 1, "no /init after release, coreV2 = \(coreV2)")
            XCTAssertTrue(StubURLProtocol.requests(to: "/recommend/after-release", shop: shop).isEmpty)
            XCTAssertTrue(StubURLProtocol.requests(to: "/push", shop: shop).isEmpty)
        }
    }

    // MARK: - sendIDFARequest

    func test_a_late_sendIDFARequest_answer_does_not_write_the_deleted_customer() {
        let shop = newShop()
        let keychain = InMemoryKeychainInitStore()
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: shop, keychain: keychain) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            // sendIDFARequest goes with the did it has; the /init after the wipe has none.
            if request.query["did"] != nil {
                return StubReply(json: #"{"did":"deleted-did"}"#, delay: 1)
            }
            return StubReply(json: #"{"did":"next-did"}"#)
        }
        let answered = expectation(description: "idfa")
        sdk.sendIDFARequest(idfa: UUID()) { _ in answered.fulfill() }
        XCTAssertTrue(eventually { StubURLProtocol.requests(to: "/init", shop: shop).contains { $0.query["ios_advertising_id"] != nil } })

        sdk.deleteUserCredentials()
        // The answer is saved, or not, before the call hears it.
        wait(for: [answered], timeout: 5)

        XCTAssertNil(keychain.data, "the keychain got the deleted customer back")
        XCTAssertNil(sdk.storage.readSavedInitAnswer(), "the saved answer got the deleted customer back")
        XCTAssertTrue(eventually { sdk.deviceId == "next-did" })
    }
}
