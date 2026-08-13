//
//  StorageMigrationTests.swift
//  REES46Tests
//
//  Covers the one-time legacy→partition migration (R2). Uses isolated `UserDefaults` suites so the
//  real `.standard` domain is never touched. Pins the identity guarantee (an upgrade keeps its did)
//  and the consume-once rule (two shops never clone one identity).
//

import XCTest
@testable import REES46

final class StorageMigrationTests: XCTestCase {

    private var suiteNames: [String] = []

    private func freshSuite() -> UserDefaults {
        let name = "test-\(UUID().uuidString)"
        suiteNames.append(name)
        return UserDefaults(suiteName: name)!
    }

    override func tearDown() {
        for name in suiteNames {
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        suiteNames.removeAll()
        super.tearDown()
    }

    func test_migrates_legacy_identity_into_an_empty_partition() {
        let legacy = freshSuite()
        let store = freshSuite()
        legacy.set("did-legacy", forKey: StoragePartition.deviceIdKey)
        legacy.set("seance-legacy", forKey: StoragePartition.seanceKey)
        legacy.set("idfa-legacy", forKey: StoragePartition.idfaKey)

        StorageMigration.migrateLegacyIfNeeded(into: store, legacy: legacy)

        XCTAssertEqual(store.string(forKey: StoragePartition.deviceIdKey), "did-legacy")
        XCTAssertEqual(store.string(forKey: StoragePartition.seanceKey), "seance-legacy")
        XCTAssertEqual(store.string(forKey: StoragePartition.idfaKey), "idfa-legacy")
        XCTAssertTrue(legacy.bool(forKey: StoragePartition.legacyConsumedFlag))
    }

    func test_a_second_shop_does_not_inherit_after_the_first_consumed_the_legacy() {
        let legacy = freshSuite()
        let storeA = freshSuite()
        let storeB = freshSuite()
        legacy.set("did-legacy", forKey: StoragePartition.deviceIdKey)

        StorageMigration.migrateLegacyIfNeeded(into: storeA, legacy: legacy)
        StorageMigration.migrateLegacyIfNeeded(into: storeB, legacy: legacy)

        XCTAssertEqual(storeA.string(forKey: StoragePartition.deviceIdKey), "did-legacy")
        XCTAssertNil(storeB.string(forKey: StoragePartition.deviceIdKey))
    }

    func test_does_not_overwrite_an_already_partitioned_identity() {
        let legacy = freshSuite()
        let store = freshSuite()
        store.set("did-existing", forKey: StoragePartition.deviceIdKey)
        legacy.set("did-legacy", forKey: StoragePartition.deviceIdKey)

        StorageMigration.migrateLegacyIfNeeded(into: store, legacy: legacy)

        XCTAssertEqual(store.string(forKey: StoragePartition.deviceIdKey), "did-existing")
    }

    func test_no_migration_and_no_consume_when_legacy_is_empty() {
        let legacy = freshSuite()
        let store = freshSuite()

        StorageMigration.migrateLegacyIfNeeded(into: store, legacy: legacy)

        XCTAssertNil(store.string(forKey: StoragePartition.deviceIdKey))
        XCTAssertFalse(legacy.bool(forKey: StoragePartition.legacyConsumedFlag))
    }

    func test_copies_only_device_id_when_seance_and_idfa_are_absent() {
        let legacy = freshSuite()
        let store = freshSuite()
        legacy.set("did-legacy", forKey: StoragePartition.deviceIdKey)

        StorageMigration.migrateLegacyIfNeeded(into: store, legacy: legacy)

        XCTAssertEqual(store.string(forKey: StoragePartition.deviceIdKey), "did-legacy")
        XCTAssertNil(store.string(forKey: StoragePartition.seanceKey))
        XCTAssertNil(store.string(forKey: StoragePartition.idfaKey))
    }
}
