//
//  StorageUpgradeTests.swift
//  REES46Tests
//
//  Stage 2 of the new core (`sdk/core/storage.md`), through the SDK's real construction path: every
//  layout an older SDK left — the pre-partition keys in `.standard`, the per-shop suite, the suite an
//  app's `storageKey` named, the legacy keychain item, `Documents/<shopId>.json` — comes through the
//  upgrade with its did, and nothing an older SDK or the old core reads is deleted. Then what
//  `deleteUserCredentials()` wipes and keeps on both cores.
//
//  The host app's own state in `.standard`, the device's store and the legacy keychain item is put
//  aside before each test and back after it.
//

import XCTest
import Security
@testable import REES46

final class StorageUpgradeTests: XCTestCase {

    private let standardKeys = [
        StoragePartition.deviceIdKey,
        StoragePartition.seanceKey,
        StoragePartition.seanceLastActKey,
        StoragePartition.idfaKey,
        StoragePartition.legacyConsumedFlag,
        SdkConstants.deviceToken,
        TrackingSourceStoreImpl.Keys.code,
        TrackingSourceStoreImpl.Keys.type,
        TrackingSourceStoreImpl.Keys.savedAt,
        "mainPushTokenLastUploadDateKey"
    ]
    private var standardSnapshot: [String: Any] = [:]
    private var deviceSnapshot: [String: Any]?
    private var legacyKeychainItem: Data?
    private var shops: [(shop: String, storageKey: String?)] = []
    private var suites: [String] = []
    private var retained: [AnyObject] = []

    private var service: String { KeychainPartition.service }

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        StubURLProtocol.handler = Self.echoingInit
        Rees46.reset()
        SdkRegistry.shared.reset()
        standardSnapshot = [:]
        for key in standardKeys {
            if let value = UserDefaults.standard.object(forKey: key) {
                standardSnapshot[key] = value
            }
            UserDefaults.standard.removeObject(forKey: key)
        }
        deviceSnapshot = UserDefaults.standard.persistentDomain(forName: DeviceStore.suiteName)
        UserDefaults.standard.removePersistentDomain(forName: DeviceStore.suiteName)
        legacyKeychainItem = try? InitService.getKeychainDidToken(identifier: KeychainPartition.legacyAccount(service: service), instanceKeychainService: service)
        try? InitService.deleteKeychainDidToken(identifier: KeychainPartition.legacyAccount(service: service), instanceKeychainService: service)
    }

    override func tearDown() {
        StubURLProtocol.uninstall()
        retained.removeAll()
        Rees46.reset()
        SdkRegistry.shared.reset()
        CoreFlag.reset()
        for (shop, storageKey) in shops {
            if let folder = ShopStorage(shopId: shop, storageKey: storageKey, logger: SdkLogger(shopId: shop, level: .none)).directory {
                try? FileManager.default.removeItem(at: folder)
            }
            UserDefaults.standard.removePersistentDomain(forName: StoragePartition.suiteName(for: shop, storageKey: storageKey))
            try? InitService.deleteKeychainDidToken(identifier: KeychainPartition.account(shopId: shop, service: service), instanceKeychainService: service)
            try? FileManager.default.removeItem(at: StubSDK.savedInitFile(shopId: shop))
            UserDefaults.standard.removeObject(forKey: NotificationRegistrar.lastUploadDateKey(shopId: shop))
        }
        shops.removeAll()
        suites.forEach { UserDefaults.standard.removePersistentDomain(forName: $0) }
        suites.removeAll()
        try? InitService.deleteKeychainDidToken(identifier: KeychainPartition.legacyAccount(service: service), instanceKeychainService: service)
        if let item = legacyKeychainItem {
            try? InitService.upsertKeychainDidToken(item, identifier: KeychainPartition.legacyAccount(service: service), instanceKeychainService: service)
        }
        for key in standardKeys {
            if let value = standardSnapshot[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        if let deviceSnapshot = deviceSnapshot {
            UserDefaults.standard.setPersistentDomain(deviceSnapshot, forName: DeviceStore.suiteName)
        } else {
            UserDefaults.standard.removePersistentDomain(forName: DeviceStore.suiteName)
        }
        super.tearDown()
    }

    // MARK: - Fixtures

    private func freshShop(storageKey: String? = nil) -> String {
        let shop = "upgrade-\(UUID().uuidString.prefix(8))"
        shops.append((shop, storageKey))
        return shop
    }

    private func partition(_ shop: String, storageKey: String? = nil) -> UserDefaults {
        StoragePartition.store(for: shop, storageKey: storageKey)
    }

    /// The SDK as an app makes it, on the stub server, once its `/init` is over.
    private func makeSDK(_ shop: String, storageKey: String? = nil, coreV2: Bool = false) -> SimplePersonalizationSDK {
        CoreFlag.reset(to: coreV2)
        let ready = expectation(description: "init \(shop)")
        let sdk = SimplePersonalizationSDK(
            shopId: shop,
            apiDomain: "stub.test",
            autoSendPushToken: false,
            enableAutoPopupPresentation: false,
            storageKey: storageKey,
            coreV2: coreV2
        ) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)
        retained.append(sdk)
        return sdk
    }

    private func initDid(_ shop: String) -> String? {
        StubURLProtocol.requests(to: "/init", shop: shop).first?.query["did"]
    }

    private func json(_ text: String) -> Data { Data(text.utf8) }

    // MARK: - Layouts of older versions

    func test_the_pre_partition_keys_in_standard_give_the_shop_its_did_and_stay() {
        UserDefaults.standard.set("did-standard", forKey: StoragePartition.deviceIdKey)
        UserDefaults.standard.set("seance-standard", forKey: StoragePartition.seanceKey)
        UserDefaults.standard.set("idfa-standard", forKey: StoragePartition.idfaKey)
        let shop = freshShop()

        let sdk = makeSDK(shop)

        XCTAssertEqual(sdk.getDeviceId(), "did-standard")
        XCTAssertEqual(initDid(shop), "did-standard", "no silent re-registration")
        XCTAssertEqual(UserDefaults.standard.string(forKey: StoragePartition.deviceIdKey), "did-standard", "an older SDK still reads it")
        XCTAssertEqual(UserDefaults.standard.string(forKey: StoragePartition.idfaKey), "idfa-standard")
        XCTAssertEqual(partition(shop).string(forKey: StoragePartition.idfaKey), "idfa-standard", "the old core reads the shop's copy")
        XCTAssertEqual(DeviceStore.shared.advertisingId, "idfa-standard")
        // Without a storageKey, a keychain item (its flag holds the service) or a configured did: the rest.
        for step in StorageMigrations.Step.allCases where ![.storageKeySuite, .keychainItem, .configuredDeviceId].contains(step) {
            XCTAssertTrue(StorageMigrations.isDone(step, in: partition(shop)), step.rawValue)
        }
        XCTAssertEqual(partition(shop).string(forKey: StorageMigrations.flagKey(.keychainItem)), KeychainPartition.service)
    }

    func test_the_per_shop_suites_keep_their_values_and_the_first_shops_group_is_the_devices() {
        let shopA = freshShop()
        let shopB = freshShop()
        let shopC = freshShop()
        let a = partition(shopA)
        a.set("did-A", forKey: StoragePartition.deviceIdKey)
        a.set("idfa-A", forKey: StoragePartition.idfaKey)
        a.set("B", forKey: StoragePartition.abSegmentKey)
        a.set(["slide-1"], forKey: "viewed.slide.7")
        let b = partition(shopB)
        b.set("did-B", forKey: StoragePartition.deviceIdKey)
        b.set("A", forKey: StoragePartition.abSegmentKey)

        let sdkA = makeSDK(shopA)
        let sdkB = makeSDK(shopB)
        let sdkC = makeSDK(shopC)

        XCTAssertEqual(sdkA.getDeviceId(), "did-A")
        XCTAssertEqual(sdkB.getDeviceId(), "did-B")
        XCTAssertEqual(DeviceStore.shared.abGroup, "B", "the device's group is the first shop's")
        XCTAssertEqual(sdkA.segment, "B")
        XCTAssertEqual(sdkB.segment, "A", "a shop keeps its own group: the old core reads what it read before")
        XCTAssertEqual(b.string(forKey: StoragePartition.abSegmentKey), "A")
        XCTAssertEqual(sdkC.segment, "B", "a shop without a group takes the device's")
        XCTAssertEqual(partition(shopC).string(forKey: StoragePartition.abSegmentKey), "B")
        XCTAssertEqual(DeviceStore.shared.advertisingId, "idfa-A")
        XCTAssertEqual(a.string(forKey: StoragePartition.idfaKey), "idfa-A")
        XCTAssertNil(b.string(forKey: StoragePartition.idfaKey), "one shop's advertising id is not another's")
        XCTAssertEqual(sdkA.localStateStore.viewedSlides(storyId: "7"), ["slide-1"])
    }

    func test_the_suite_an_apps_storage_key_named_comes_into_the_prefixed_partition_once_and_stays() {
        let key = "app-suite-\(UUID().uuidString.prefix(8))-"
        suites.append(key)
        let old = UserDefaults(suiteName: key) ?? .standard
        old.set("did-custom", forKey: StoragePartition.deviceIdKey)
        old.set(["slide-9"], forKey: "viewed.slide.9")
        old.set(Date().timeIntervalSince1970, forKey: TrackingSourceStoreImpl.Keys.savedAt)
        old.set("chain", forKey: TrackingSourceStoreImpl.Keys.type)
        old.set("c-1", forKey: TrackingSourceStoreImpl.Keys.code)
        old.set("the app's", forKey: "app.own.key")
        let shop = freshShop(storageKey: key)

        let sdk = makeSDK(shop, storageKey: key)

        XCTAssertEqual(sdk.getDeviceId(), "did-custom")
        XCTAssertEqual(initDid(shop), "did-custom")
        let prefixed = partition(shop, storageKey: key)
        XCTAssertEqual(prefixed.string(forKey: StoragePartition.deviceIdKey), "did-custom")
        XCTAssertNil(prefixed.object(forKey: "app.own.key"), "only the SDK's keys come")
        XCTAssertEqual(sdk.localStateStore.viewedSlides(storyId: "9"), ["slide-9"])
        XCTAssertEqual(sdk.sourceStore.currentSource()?.code, "c-1")
        XCTAssertEqual(old.string(forKey: StoragePartition.deviceIdKey), "did-custom", "an older SDK still reads the old suite")
        XCTAssertEqual(old.string(forKey: "app.own.key"), "the app's")
        XCTAssertTrue(StorageMigrations.isDone(.storageKeySuite, in: prefixed))

        // Once: a later value in the old suite does not come again.
        old.set("did-later", forKey: StoragePartition.deviceIdKey)
        prefixed.removeObject(forKey: StoragePartition.deviceIdKey)
        _ = UserIdentityRepositoryImpl(shopId: shop, storageKey: key)
        XCTAssertNil(prefixed.string(forKey: StoragePartition.deviceIdKey))
    }

    func test_the_legacy_keychain_item_gives_the_first_shop_its_did_after_a_reinstall_and_is_consumed() {
        let legacyAccount = KeychainPartition.legacyAccount(service: service)
        try? InitService.upsertKeychainDidToken(json(#"{"did":"did-keychain"}"#), identifier: legacyAccount, instanceKeychainService: service)
        let first = freshShop()
        let second = freshShop()

        let sdk = makeSDK(first)

        XCTAssertEqual(sdk.getDeviceId(), "did-keychain")
        XCTAssertEqual(initDid(first), "did-keychain")
        XCTAssertNil(try? InitService.getKeychainDidToken(identifier: legacyAccount, instanceKeychainService: service),
                     "consumed, so a second shop cannot clone the did")
        XCTAssertEqual(partition(first).string(forKey: StorageMigrations.flagKey(.keychainItem)), service)

        let other = makeSDK(second)
        XCTAssertEqual(other.getDeviceId(), "new-did", "the second shop gets its own did from the server")
    }

    func test_a_switch_of_the_link_mode_adopts_the_backup_under_the_other_id_also_after_the_adoption_ran() {
        let shop = freshShop()
        let pods = "test.pods.\(shop)"
        let app = "test.app.\(shop)"
        defer {
            for service in [pods, app] {
                try? InitService.deleteKeychainDidToken(identifier: KeychainPartition.account(shopId: shop, service: service), instanceKeychainService: service)
            }
        }
        // Linked one way: nothing to adopt, and the adoption is marked as run under that id.
        _ = KeychainInitStoreImpl(shopId: shop, service: pods, previousServices: [app], partition: partition(shop))
        XCTAssertEqual(partition(shop).string(forKey: StorageMigrations.flagKey(.keychainItem)), pods)

        // Linked the other way, the backup is written under that id.
        let other = KeychainInitStoreImpl(shopId: shop, service: app, previousServices: [pods], partition: partition(shop))
        other.writeInitData(json(#"{"did":"did-app"}"#))

        // Back to the first way: the flag of the first run does not hold the backup back.
        let back = KeychainInitStoreImpl(shopId: shop, service: pods, previousServices: [app], partition: partition(shop))
        XCTAssertEqual(back.readInitData(), json(#"{"did":"did-app"}"#))
        XCTAssertEqual(partition(shop).string(forKey: StorageMigrations.flagKey(.keychainItem)), pods)
    }

    func test_a_keychain_that_does_not_answer_leaves_the_adoption_for_the_next_launch() {
        let shop = freshShop()
        let original = InitService.copyMatching
        InitService.copyMatching = { _, _ in errSecInteractionNotAllowed }
        _ = KeychainInitStoreImpl(shopId: shop, service: service, partition: partition(shop))
        InitService.copyMatching = original
        XCTAssertNil(partition(shop).string(forKey: StorageMigrations.flagKey(.keychainItem)))

        _ = KeychainInitStoreImpl(shopId: shop, service: service, partition: partition(shop))
        XCTAssertEqual(partition(shop).string(forKey: StorageMigrations.flagKey(.keychainItem)), service)
    }

    func test_the_saved_answer_in_documents_moves_to_the_sdks_folder_and_stands_in_without_an_answer() throws {
        let shop = freshShop()
        let legacy = StubSDK.savedInitFile(shopId: shop)
        let saved = json(#"{"did":"did-saved","seance":"s"}"#)
        try saved.write(to: legacy)
        partition(shop).set("did-saved", forKey: StoragePartition.deviceIdKey)
        StubURLProtocol.handler = { $0.path == "/init" ? StubReply.noAnswer : StubReply() }

        let sdk = makeSDK(shop)

        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path), "out of the app's Documents")
        let file = try XCTUnwrap(sdk.storage.savedInitFile)
        XCTAssertTrue(file.path.contains("Application Support/personalization_sdk/"), file.path)
        XCTAssertEqual(try Data(contentsOf: file), saved)
        XCTAssertEqual(sdk.userInfo.deviceId, "did-saved", "no answer: the saved one stood in")
        XCTAssertTrue(StorageMigrations.isDone(.savedInitFile, in: partition(shop)))
    }

    func test_the_keychain_service_is_pinned_to_the_value_it_has_always_had() {
        XCTAssertEqual(KeychainPartition.service, Bundle(for: SimplePersonalizationSDK.self).bundleIdentifier)
        XCTAssertEqual(instanceKeychainService, KeychainPartition.service)
        XCTAssertEqual(KeychainPartition.service, "org.cocoapods.REES46", "the demo links the SDK as a CocoaPods framework")
    }

    // MARK: - deleteUserCredentials

    func test_deleting_the_user_credentials_wipes_the_customer_and_keeps_the_device_on_both_cores() throws {
        for coreV2 in [false, true] {
            let shop = freshShop()
            let sdk = makeSDK(shop, coreV2: coreV2)
            let identity = sdk.userIdentity
            XCTAssertEqual(sdk.deviceId, "new-did")
            // What the customer left.
            sdk.sourceStore.store(type: "chain", code: "c-1")
            sdk.storage.refused = true
            sdk.storage.writeSavedInitAnswer(json(#"{"did":"new-did"}"#))
            sdk.keychainStore.writeInitData(json(#"{"did":"new-did"}"#))
            UserDefaults.standard.set(Date(), forKey: NotificationRegistrar.lastUploadDateKey(shopId: shop))
            UserDefaults.standard.set(Date(), forKey: "mainPushTokenLastUploadDateKey")
            let queue = try XCTUnwrap(sdk.storage.makeQueueDirectory())
            // What the device, the shop's stories and the migrations keep.
            sdk.localStateStore.setViewedSlides(["slide-1"], storyId: "7")
            DeviceStore.shared.pushToken = Data([9, 9])
            identity.advertisingId = "idfa-kept"
            let group = sdk.segment
            let session = sdk.userSeance
            // The next /init answers a moment later: the wipe is seen before the new did comes.
            StubURLProtocol.handler = { request in
                request.path == "/init" ? StubReply(json: #"{"did":"next-did"}"#, delay: 1) : StubReply()
            }

            sdk.deleteUserCredentials()

            XCTAssertNil(identity.deviceId)
            XCTAssertEqual(sdk.deviceId, "", "the instance forgets the did too")
            if coreV2 {
                // The new core makes no session: the next /init brings the new customer's.
                XCTAssertEqual(sdk.userSeance, "")
                XCTAssertNil(identity.seance)
                XCTAssertNil(identity.seanceLastActTime)
            } else {
                XCTAssertFalse(sdk.userSeance.isEmpty)
                XCTAssertNotEqual(sdk.userSeance, session, "the new customer has a session of their own")
                XCTAssertEqual(identity.seance, sdk.userSeance)
            }
            XCTAssertNil(sdk.storage.readSavedInitAnswer())
            XCTAssertNil(sdk.keychainStore.readInitData())
            XCTAssertFalse(sdk.storage.refused)
            XCTAssertNil(sdk.sourceStore.currentSource())
            XCTAssertNil(UserDefaults.standard.object(forKey: NotificationRegistrar.lastUploadDateKey(shopId: shop)),
                         "the push token goes to the shop again, for the new customer")
            XCTAssertNil(UserDefaults.standard.object(forKey: "mainPushTokenLastUploadDateKey"))
            XCTAssertEqual(FileManager.default.fileExists(atPath: queue.path), !coreV2, "the queue goes with the customer on the new core")

            XCTAssertEqual(sdk.localStateStore.viewedSlides(storyId: "7"), ["slide-1"])
            XCTAssertEqual(DeviceStore.shared.pushToken, Data([9, 9]))
            XCTAssertEqual(identity.advertisingId, "idfa-kept")
            XCTAssertEqual(DeviceStore.shared.advertisingId, "idfa-kept")
            XCTAssertEqual(identity.abSegment, group)
            XCTAssertEqual(DeviceStore.shared.abGroup, group)
            XCTAssertTrue(StorageMigrations.isDone(.savedInitFile, in: partition(shop)), "the migration flags stay")
            XCTAssertTrue(SdkLogger.registeredShopIds.contains(shop), "the instance goes on")

            // It asks /init again, without a did, and keeps the new one.
            XCTAssertTrue(eventually { identity.deviceId == "next-did" && sdk.deviceId == "next-did" })
            XCTAssertNil(StubURLProtocol.requests(to: "/init", shop: shop).last?.query["did"])
            StubURLProtocol.handler = Self.echoingInit
        }
    }

    func test_after_deleting_the_user_credentials_requests_wait_for_the_new_did_and_a_late_answer_changes_nothing() throws {
        let shop = freshShop()
        let lock = NSLock()
        var calls = 0
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            lock.lock(); calls += 1; let call = calls; lock.unlock()
            // The first /init answers late, with the did of the customer about to be deleted.
            return call == 1 ? StubReply(json: #"{"did":"deleted-did"}"#, delay: 1.5) : StubReply(json: #"{"did":"next-did"}"#, delay: 0.3)
        }
        CoreFlag.reset(to: false)
        let first = expectation(description: "the first init")
        let sdk = try XCTUnwrap(Rees46.initialize(Rees46Config(shopId: shop, apiDomain: "stub.test", autoSendPushToken: false)) { _ in
            first.fulfill()
        } as? SimplePersonalizationSDK)
        retained.append(sdk)
        XCTAssertTrue(eventually { StubURLProtocol.requests(to: "/init", shop: shop).count == 1 })

        sdk.deleteUserCredentials()
        let request = expectation(description: "a request made meanwhile")
        sdk.getProductInfo(id: "item-1") { _ in request.fulfill() }
        wait(for: [request, first], timeout: 5)

        XCTAssertEqual(StubURLProtocol.requests(to: "/products/get", shop: shop).first?.query["did"], "next-did",
                       "the request waited for the new did instead of going out without one")
        XCTAssertEqual(sdk.userIdentity.deviceId, "next-did", "the late answer of the earlier /init changes nothing")
        XCTAssertEqual(sdk.deviceId, "next-did")
        XCTAssertTrue(SdkRegistry.shared.shopIds().contains(shop), "the instance stays registered")
    }

    func test_after_deleting_the_user_credentials_the_push_token_goes_with_the_new_did() {
        DeviceStore.shared.pushToken = Data([1, 2, 3])
        let shop = freshShop()
        CoreFlag.reset(to: false)
        let ready = expectation(description: "init")
        let sdk = SimplePersonalizationSDK(shopId: shop, apiDomain: "stub.test", autoSendPushToken: true, enableAutoPopupPresentation: false) { _ in
            ready.fulfill()
        }
        retained.append(sdk)
        wait(for: [ready], timeout: 5)
        func tokens() -> [StubRequest] { StubURLProtocol.requests(to: "/mobile_push_tokens", shop: shop) }
        XCTAssertTrue(eventually { !tokens().isEmpty })
        StubURLProtocol.handler = { request in
            request.path == "/init" ? StubReply(json: #"{"did":"next-did"}"#, delay: 0.3) : StubReply()
        }

        sdk.deleteUserCredentials()

        XCTAssertTrue(eventually { tokens().contains { $0.body["did"] as? String == "next-did" } }, "sent again, for the new customer")
        XCTAssertFalse(tokens().contains { ($0.body["did"] as? String ?? "").isEmpty }, "never without a did")
    }

    /// The server knows the did it is sent, and makes a new one only for a new device.
    private static let echoingInit: (StubRequest) -> StubReply? = { request in
        guard request.path == "/init" else { return StubReply() }
        return StubReply(json: #"{"did":"\#(request.query["did"] ?? "new-did")","seance":"server-seance"}"#)
    }
}
