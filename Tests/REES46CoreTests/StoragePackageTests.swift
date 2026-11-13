//
//  StoragePackageTests.swift
//  REES46CoreTests
//
//  A shop's storage (`sdk/core/storage.md`) without the demo app: the saved /init answer in the SDK's
//  folder, refused, the queue's folder, the device's store, the one-shot migrations and the
//  partition's name with an app's storageKey.
//

import XCTest
@testable import REES46

final class StoragePackageTests: XCTestCase {

    private var folders: [URL] = []
    private var suites: [String] = []
    private let logLock = NSLock()
    private var logged: [Rees46.SdkLogMessage] = []

    override func setUp() {
        super.setUp()
        logged = []
        Rees46.setLogHandler { [weak self] message in
            guard let self = self else { return }
            self.logLock.lock(); self.logged.append(message); self.logLock.unlock()
        }
    }

    override func tearDown() {
        Rees46.setLogHandler(nil)
        folders.forEach { try? FileManager.default.removeItem(at: $0) }
        folders.removeAll()
        suites.forEach { UserDefaults.standard.removePersistentDomain(forName: $0) }
        suites.removeAll()
        super.tearDown()
    }

    // MARK: - Fixtures

    private func folder() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("storage-\(UUID().uuidString)", isDirectory: true)
        folders.append(url)
        return url
    }

    private func suite(_ name: String = "storage-\(UUID().uuidString)") -> UserDefaults {
        suites.append(name)
        return UserDefaults(suiteName: name) ?? .standard
    }

    private func storage(shop: String = "shop-\(UUID().uuidString)", storageKey: String? = nil, root: URL? = nil, documents: URL? = nil) -> ShopStorage {
        ShopStorage(
            shopId: shop,
            storageKey: storageKey,
            logger: SdkLogger(shopId: shop, level: .warning),
            partition: suite(),
            root: root ?? folder(),
            documents: documents ?? folder()
        )
    }

    /// The messages of `shop` with `code`, once one of them has the operation `op`.
    private func messages(code: String, shop: String, op: String) -> [Rees46.SdkLogMessage] {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            logLock.lock()
            let found = logged.filter { $0.code == code && $0.shopId == shop }
            logLock.unlock()
            if found.contains(where: { $0.context["op"] == op }) { return found }
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        return []
    }

    private func data(_ text: String) -> Data { Data(text.utf8) }

    // MARK: - The saved /init answer

    func test_the_saved_answer_is_written_replaced_and_read_back_from_the_shops_folder() throws {
        let store = storage()
        XCTAssertNil(store.readSavedInitAnswer())

        XCTAssertTrue(store.writeSavedInitAnswer(data(#"{"did":"1"}"#)))
        XCTAssertTrue(store.writeSavedInitAnswer(data(#"{"did":"2"}"#)))

        XCTAssertEqual(store.readSavedInitAnswer(), data(#"{"did":"2"}"#))
        let file = try XCTUnwrap(store.savedInitFile)
        XCTAssertEqual(file.lastPathComponent, "init.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func test_the_old_cores_write_keeps_the_first_answer() {
        let store = storage()
        store.writeSavedInitAnswerIfAbsent(data(#"{"did":"first"}"#))
        store.writeSavedInitAnswerIfAbsent(data(#"{"did":"second"}"#))
        XCTAssertEqual(store.readSavedInitAnswer(), data(#"{"did":"first"}"#))
    }

    func test_an_answer_an_older_sdk_left_in_documents_is_read_and_moved() throws {
        let documents = folder()
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        let shop = "shop-\(UUID().uuidString)"
        let legacy = documents.appendingPathComponent(shop + ".json")
        try data(#"{"did":"old"}"#).write(to: legacy)
        let store = storage(shop: shop, documents: documents)

        XCTAssertEqual(store.readSavedInitAnswer(), data(#"{"did":"old"}"#))

        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path), "moved, not copied")
        XCTAssertEqual(try Data(contentsOf: try XCTUnwrap(store.savedInitFile)), data(#"{"did":"old"}"#))
    }

    func test_the_move_of_the_documents_file_is_done_when_nothing_is_left_and_drops_one_older_than_the_saved_answer() throws {
        let documents = folder()
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        let shop = "shop-\(UUID().uuidString)"
        let store = storage(shop: shop, documents: documents)
        XCTAssertTrue(store.moveLegacySavedInitAnswer(), "nothing to move")

        let legacy = documents.appendingPathComponent(shop + ".json")
        try data(#"{"did":"old"}"#).write(to: legacy)
        store.writeSavedInitAnswer(data(#"{"did":"new"}"#))
        XCTAssertTrue(store.moveLegacySavedInitAnswer())
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertEqual(store.readSavedInitAnswer(), data(#"{"did":"new"}"#))
    }

    func test_removing_the_saved_answer_removes_it_in_both_places() throws {
        let documents = folder()
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        let shop = "shop-\(UUID().uuidString)"
        let store = storage(shop: shop, documents: documents)
        store.writeSavedInitAnswer(data(#"{"did":"new"}"#))
        let legacy = documents.appendingPathComponent(shop + ".json")
        try data(#"{"did":"old"}"#).write(to: legacy)

        store.removeSavedInitAnswer()

        XCTAssertNil(store.readSavedInitAnswer())
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
    }

    func test_a_disk_that_refuses_is_storage_failed_with_its_operation() throws {
        // The SDK's folder is a file: nothing can be made under it.
        let blocked = folder()
        try data("not a folder").write(to: blocked)
        let shop = "blocked-\(UUID().uuidString)"
        let store = ShopStorage(shopId: shop, logger: SdkLogger(shopId: shop, level: .warning), partition: suite(), root: blocked, documents: folder())

        XCTAssertFalse(store.writeSavedInitAnswer(data(#"{"did":"1"}"#)))
        XCTAssertNil(store.makeQueueDirectory())

        let failures = messages(code: "storage_failed", shop: shop, op: "write_saved_init")
        XCTAssertFalse(failures.isEmpty)
        XCTAssertTrue(failures.allSatisfy { $0.level == .warning })
        XCTAssertFalse(messages(code: "storage_failed", shop: shop, op: "create_queue_dir").isEmpty)
    }

    // MARK: - refused, the queue's folder, the folder's name

    func test_refused_is_kept_in_the_shops_partition_until_cleared() {
        let store = storage()
        XCTAssertFalse(store.refused)
        store.refused = true
        XCTAssertTrue(store.partition.bool(forKey: ShopStorage.refusedKey))
        store.refused = false
        XCTAssertNil(store.partition.object(forKey: ShopStorage.refusedKey))
    }

    func test_the_queues_folder_is_made_in_the_shops_folder_and_removed_with_what_it_holds() throws {
        let store = storage()
        let queue = try XCTUnwrap(store.makeQueueDirectory())
        XCTAssertEqual(queue, store.queueDirectory)
        XCTAssertEqual(queue.deletingLastPathComponent().standardizedFileURL, store.directory?.standardizedFileURL)
        try data("event").write(to: queue.appendingPathComponent("1.json"))
        XCTAssertEqual(store.makeQueueDirectory(), queue, "an existing folder is kept")

        store.removeQueueDirectory()

        XCTAssertFalse(FileManager.default.fileExists(atPath: queue.path))
    }

    func test_each_partition_has_its_own_folder_named_after_it() {
        let root = folder()
        let plain = storage(shop: "shop/1", root: root)
        let prefixed = storage(shop: "shop/1", storageKey: "my.app", root: root)
        XCTAssertEqual(plain.directory?.lastPathComponent, "personalization_sdk_shop_1")
        XCTAssertEqual(prefixed.directory?.lastPathComponent, "my_app_personalization_sdk_shop_1")
        XCTAssertNotEqual(plain.directory, prefixed.directory)
    }

    // MARK: - The device's store

    func test_the_device_takes_the_group_of_the_first_shop_that_has_one() {
        let device = DeviceStore(defaults: suite(), pushTokenDefaults: suite())
        XCTAssertNil(device.abGroup)

        XCTAssertEqual(device.resolveAbGroup(candidate: "B"), "B")
        XCTAssertEqual(device.resolveAbGroup(candidate: "A"), "B", "a later shop gets the device's group")
        XCTAssertEqual(device.abGroup, "B")

        let fresh = DeviceStore(defaults: suite(), pushTokenDefaults: suite())
        XCTAssertTrue(DeviceStore.abGroups.contains(fresh.resolveAbGroup(candidate: "C")), "an unknown group is replaced")
    }

    func test_shops_made_at_once_get_one_group() {
        let device = DeviceStore(defaults: suite(), pushTokenDefaults: suite())
        let lock = NSLock()
        var groups = Set<String>()
        DispatchQueue.concurrentPerform(iterations: 64) { index in
            let group = device.resolveAbGroup(candidate: index % 2 == 0 ? "A" : "B")
            lock.lock(); groups.insert(group); lock.unlock()
        }
        XCTAssertEqual(groups.count, 1)
    }

    func test_the_device_keeps_the_first_advertising_id_it_is_given_by_a_migration() {
        let device = DeviceStore(defaults: suite(), pushTokenDefaults: suite())
        device.adoptAdvertisingId("")
        XCTAssertNil(device.advertisingId)
        device.adoptAdvertisingId("idfa-1")
        device.adoptAdvertisingId("idfa-2")
        XCTAssertEqual(device.advertisingId, "idfa-1")
        device.advertisingId = "idfa-3"
        XCTAssertEqual(device.advertisingId, "idfa-3", "the app's new id replaces it")
    }

    func test_the_push_token_is_the_devices_and_is_still_written_where_it_always_was() {
        let standard = suite()
        let own = suite()
        standard.set(Data([7]), forKey: SdkConstants.deviceToken)
        let device = DeviceStore(defaults: own, pushTokenDefaults: standard)
        XCTAssertEqual(device.pushToken, Data([7]), "a token an older version stored is read")

        device.pushToken = Data([1, 2])

        XCTAssertEqual(own.data(forKey: DeviceStore.pushTokenKey), Data([1, 2]))
        XCTAssertEqual(standard.data(forKey: SdkConstants.deviceToken), Data([1, 2]), "the old core reads it there")
    }

    func test_the_sdks_folder_is_kept_out_of_backups() throws {
        let root = folder()
        let store = storage(root: root)
        XCTAssertTrue(store.writeSavedInitAnswer(data(#"{"did":"1"}"#)))
        let values = try root.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }

    func test_the_identity_dual_writes_the_device_level_values_and_reads_the_shops_own() {
        let device = DeviceStore(defaults: suite(), pushTokenDefaults: suite())
        let shopA = suite()
        let shopB = suite()
        let shopC = suite()
        shopA.set("B", forKey: StoragePartition.abSegmentKey)
        shopB.set("A", forKey: StoragePartition.abSegmentKey)
        let repoA = UserIdentityRepositoryImpl(store: shopA, device: device)
        let repoB = UserIdentityRepositoryImpl(store: shopB, device: device)
        let repoC = UserIdentityRepositoryImpl(store: shopC, device: device)

        XCTAssertEqual(repoA.resolveAbSegment(), "B")
        XCTAssertEqual(device.abGroup, "B", "the first shop's group is the device's")
        XCTAssertEqual(repoB.resolveAbSegment(), "A", "a shop keeps its own: the old core reads what it read before")
        XCTAssertEqual(repoC.resolveAbSegment(), "B", "a shop without one takes the device's")
        XCTAssertEqual(shopC.string(forKey: StoragePartition.abSegmentKey), "B", "and keeps it in its key, for the old core")

        repoA.advertisingId = "idfa-A"
        XCTAssertEqual(device.advertisingId, "idfa-A")
        XCTAssertNil(repoB.advertisingId, "an id the app gave one shop is not another shop's")

        repoA.clearIdentity()
        XCTAssertEqual(repoA.advertisingId, "idfa-A")
        XCTAssertEqual(repoA.abSegment, "B")
    }

    // MARK: - Migrations

    func test_a_migration_runs_once_and_one_that_did_not_finish_runs_again() {
        let partition = suite()
        var runs = 0
        StorageMigrations.once(.savedInitFile, in: partition) { runs += 1; return false }
        StorageMigrations.once(.savedInitFile, in: partition) { runs += 1; return true }
        StorageMigrations.once(.savedInitFile, in: partition) { runs += 1; return true }
        XCTAssertEqual(runs, 2)
        XCTAssertTrue(partition.bool(forKey: "personalization_sdk.migrated.saved_init_file"))
    }

    func test_the_old_storage_key_suite_is_copied_once_without_the_apps_keys_and_stays() throws {
        let key = "app-suite-\(UUID().uuidString)"
        let old = suite(key)
        old.set("did-old", forKey: StoragePartition.deviceIdKey)
        old.set("seance-old", forKey: StoragePartition.seanceKey)
        old.set("B", forKey: StoragePartition.abSegmentKey)
        old.set("idfa-old", forKey: StoragePartition.idfaKey)
        old.set(["s1"], forKey: "viewed.slide.7")
        old.set("app value", forKey: "app.own.key")
        let shop = "shop-\(UUID().uuidString)"
        let name = StoragePartition.suiteName(for: shop, storageKey: key)
        let partition = suite(name)
        partition.set("seance-own", forKey: StoragePartition.seanceKey)
        let device = DeviceStore(defaults: suite(), pushTokenDefaults: suite())

        StorageMigrations.migrateIdentity(into: partition, partitionName: name, storageKey: key, legacy: suite(), device: device)

        XCTAssertEqual(partition.string(forKey: StoragePartition.deviceIdKey), "did-old")
        XCTAssertEqual(partition.string(forKey: StoragePartition.seanceKey), "seance-own", "the partition's own value wins")
        XCTAssertEqual(partition.stringArray(forKey: "viewed.slide.7"), ["s1"])
        XCTAssertNil(partition.object(forKey: "app.own.key"), "only the SDK's keys")
        XCTAssertEqual(device.advertisingId, "idfa-old")
        XCTAssertTrue(StorageMigrations.isDone(.storageKeySuite, in: partition))
        XCTAssertFalse(StorageMigrations.isDone(.standardIdentity, in: partition), "an app with its key had no pre-partition identity")
        XCTAssertEqual(old.string(forKey: StoragePartition.deviceIdKey), "did-old", "an older SDK still reads the old suite")

        old.set("did-changed", forKey: StoragePartition.deviceIdKey)
        partition.removeObject(forKey: StoragePartition.deviceIdKey)
        StorageMigrations.migrateIdentity(into: partition, partitionName: name, storageKey: key, legacy: suite(), device: device)
        XCTAssertNil(partition.string(forKey: StoragePartition.deviceIdKey), "once")
    }

    func test_the_pre_partition_identity_is_adopted_once_by_the_first_shop() {
        let legacy = suite()
        legacy.set("did-legacy", forKey: StoragePartition.deviceIdKey)
        legacy.set("idfa-legacy", forKey: StoragePartition.idfaKey)
        let device = DeviceStore(defaults: suite(), pushTokenDefaults: suite())
        let first = suite()
        let second = suite()

        StorageMigrations.migrateIdentity(into: first, partitionName: "a", storageKey: nil, legacy: legacy, device: device)
        StorageMigrations.migrateIdentity(into: second, partitionName: "b", storageKey: nil, legacy: legacy, device: device)

        XCTAssertEqual(first.string(forKey: StoragePartition.deviceIdKey), "did-legacy")
        XCTAssertNil(second.string(forKey: StoragePartition.deviceIdKey))
        XCTAssertEqual(legacy.string(forKey: StoragePartition.deviceIdKey), "did-legacy", "the source stays")
        XCTAssertEqual(device.advertisingId, "idfa-legacy")
        XCTAssertTrue(StorageMigrations.isDone(.standardIdentity, in: first))
        XCTAssertTrue(StorageMigrations.isDone(.deviceAdvertisingId, in: second))
    }

    func test_two_shops_made_at_once_never_both_take_the_pre_partition_did() {
        for _ in 0..<50 {
            let legacy = suite()
            legacy.set("did-legacy", forKey: StoragePartition.deviceIdKey)
            let partitions = [suite(), suite()]
            DispatchQueue.concurrentPerform(iterations: 2) { index in
                StorageMigrations.migrateIdentity(into: partitions[index], partitionName: "p\(index)", storageKey: nil, legacy: legacy, device: nil)
            }
            XCTAssertEqual(partitions.compactMap { $0.string(forKey: StoragePartition.deviceIdKey) }, ["did-legacy"])
        }
    }

    func test_a_pending_shop_finds_its_did_in_the_old_storage_key_suite() {
        let key = "pending-suite-\(UUID().uuidString)"
        let shop = "shop-\(UUID().uuidString)"
        suite(key).set("did-old", forKey: StoragePartition.deviceIdKey)
        suites.append(StoragePartition.suiteName(for: shop, storageKey: key))
        XCTAssertEqual(StoragePartition.deviceId(for: shop, storageKey: key), "did-old")

        StoragePartition.store(for: shop, storageKey: key).set("did-new", forKey: StoragePartition.deviceIdKey)
        XCTAssertEqual(StoragePartition.deviceId(for: shop, storageKey: key), "did-new")
        XCTAssertEqual(StoragePartition.deviceId(for: "none-\(UUID().uuidString)"), "")
    }

    // MARK: - An app group's storageKey

    func test_an_app_groups_key_is_the_partition_and_the_files_still_get_the_shops_folder() {
        XCTAssertEqual(StoragePartition.suiteName(for: "shop-1", storageKey: "group.com.app.shared"), "group.com.app.shared")
        XCTAssertEqual(StoragePartition.suiteName(for: "shop-1", storageKey: "app-key"), "app-key_personalization_sdk_shop-1")
        XCTAssertEqual(StoragePartition.folderName(for: "shop-1", storageKey: "group.com.app.shared"), "group_com_app_shared_personalization_sdk_shop-1")
        XCTAssertNotEqual(StoragePartition.folderName(for: "shop-1", storageKey: "group.x"), StoragePartition.folderName(for: "shop-2", storageKey: "group.x"))
        XCTAssertTrue(StoragePartition.isAppGroup("group.x"))
        XCTAssertFalse(StoragePartition.isAppGroup("groupie"))
        XCTAssertFalse(StoragePartition.isAppGroup(nil))
    }

    func test_an_app_groups_suite_keeps_its_did_and_is_not_copied() throws {
        let group = "group.test.\(UUID().uuidString.prefix(6))"
        let shop = "group-shop-\(UUID().uuidString.prefix(6))"
        defer { UserDefaults.standard.removePersistentDomain(forName: group) }
        try XCTUnwrap(UserDefaults(suiteName: group)).set("did-group", forKey: StoragePartition.deviceIdKey)

        let identity = UserIdentityRepositoryImpl(shopId: shop, storageKey: group)

        XCTAssertEqual(identity.deviceId, "did-group")
        XCTAssertEqual(StoragePartition.deviceId(for: shop, storageKey: group), "did-group")
    }

    func test_a_shop_made_with_a_storage_key_is_opened_with_it_by_code_that_has_only_the_shop() {
        let shop = "known-\(UUID().uuidString.prefix(6))"
        StoragePartition.remember(storageKey: "app-key", forShop: shop)
        defer { UserDefaults.standard.removePersistentDomain(forName: StoragePartition.suiteName(for: shop, storageKey: "app-key")) }
        StoragePartition.store(for: shop, storageKey: "app-key").set("v", forKey: "probe")

        XCTAssertEqual(StoragePartition.storageKey(ofShop: shop), "app-key")
        XCTAssertEqual(StoragePartition.store(ofShop: shop).string(forKey: "probe"), "v")
        XCTAssertNil(StoragePartition.storageKey(ofShop: "never-made"))
    }

    // MARK: - The keychain's service

    func test_the_keychain_service_is_the_bundle_of_the_sdks_binary_as_it_always_was() {
        XCTAssertEqual(KeychainPartition.service, Bundle(for: SimplePersonalizationSDK.self).bundleIdentifier ?? "com.rees46.sdk")
        XCTAssertEqual(instanceKeychainService, Bundle(for: SimplePersonalizationSDK.self).bundleIdentifier ?? "com.bundle.ident.sdk-instanceKeychainService")
    }

    func test_the_backup_is_looked_for_under_the_ids_of_the_other_link_modes() {
        // Linked through SwiftPM: the app's id; the CocoaPods framework's id is the other one.
        XCTAssertEqual(KeychainPartition.previousServices(current: "com.app", appBundleId: "com.app"), ["org.cocoapods.REES46"])
        // The CocoaPods framework: the app's id is the other one.
        XCTAssertEqual(KeychainPartition.previousServices(current: "org.cocoapods.REES46", appBundleId: "com.app"), ["com.app"])
        // The SDK in an app's own framework: both.
        XCTAssertEqual(KeychainPartition.previousServices(current: "com.app.kit", appBundleId: "com.app"), ["org.cocoapods.REES46", "com.app"])
        XCTAssertEqual(KeychainPartition.previousServices(current: "com.app", appBundleId: nil), ["org.cocoapods.REES46"])
    }
}
