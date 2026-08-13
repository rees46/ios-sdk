//
//  UserIdentityRepositoryTests.swift
//  REES46Tests
//
//  Covers the typed identity port and its UserDefaults adapter (R2). The accessor↔key mapping and
//  clear semantics are pinned here; the legacy migration itself is covered by StorageMigrationTests.
//

import XCTest
@testable import REES46

/// In-memory identity store — proves the port is fake-able for future two-shop SDK isolation tests.
final class InMemoryUserIdentityRepository: UserIdentityRepository {
    var deviceId: String?
    var seance: String?
    var seanceLastActTime: Date?
    var advertisingId: String?
    func removeDeviceId() { deviceId = nil }
    func clearIdentity() { deviceId = nil; seance = nil; seanceLastActTime = nil }
}

final class UserIdentityRepositoryTests: XCTestCase {

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

    func test_reads_back_what_it_writes() {
        let repo = UserIdentityRepositoryImpl(store: freshSuite())

        repo.deviceId = "did-1"
        repo.seance = "seance-1"
        repo.advertisingId = "idfa-1"

        XCTAssertEqual(repo.deviceId, "did-1")
        XCTAssertEqual(repo.seance, "seance-1")
        XCTAssertEqual(repo.advertisingId, "idfa-1")
    }

    func test_removeDeviceId_clears_only_the_device_id() {
        let repo = UserIdentityRepositoryImpl(store: freshSuite())
        repo.deviceId = "did-1"
        repo.seance = "seance-1"

        repo.removeDeviceId()

        XCTAssertNil(repo.deviceId)
        XCTAssertEqual(repo.seance, "seance-1")
    }

    func test_seance_last_act_time_round_trips_and_is_cleared_with_identity() {
        let repo = UserIdentityRepositoryImpl(store: freshSuite())
        let timestamp = Date(timeIntervalSince1970: 1_234_567)

        repo.seanceLastActTime = timestamp
        XCTAssertEqual(repo.seanceLastActTime?.timeIntervalSince1970, timestamp.timeIntervalSince1970)

        repo.clearIdentity()
        XCTAssertNil(repo.seanceLastActTime)
    }

    func test_clearIdentity_clears_device_id_and_seance_but_not_advertising_id() {
        let repo = UserIdentityRepositoryImpl(store: freshSuite())
        repo.deviceId = "did-1"
        repo.seance = "seance-1"
        repo.advertisingId = "idfa-1"

        repo.clearIdentity()

        XCTAssertNil(repo.deviceId)
        XCTAssertNil(repo.seance)
        XCTAssertEqual(repo.advertisingId, "idfa-1")
    }

    func test_writes_land_in_the_custom_suite_when_a_storage_key_is_given() {
        let custom = "custom-\(UUID().uuidString)"
        suiteNames.append(custom)

        let repo = UserIdentityRepositoryImpl(shopId: "ignored-shop", storageKey: custom)
        repo.deviceId = "did-custom"

        XCTAssertEqual(
            UserDefaults(suiteName: custom)?.string(forKey: StoragePartition.deviceIdKey),
            "did-custom"
        )
    }

    func test_persists_into_the_shop_partition_suite() {
        let shopId = "shop-\(UUID().uuidString)"
        suiteNames.append(StoragePartition.suiteName(for: shopId))

        let repo = UserIdentityRepositoryImpl(shopId: shopId, storageKey: nil)
        repo.deviceId = "did-shop"

        let partition = UserDefaults(suiteName: StoragePartition.suiteName(for: shopId))
        XCTAssertEqual(partition?.string(forKey: StoragePartition.deviceIdKey), "did-shop")
    }

    func test_in_memory_fake_round_trips() {
        let repo: UserIdentityRepository = InMemoryUserIdentityRepository()
        repo.deviceId = "did"
        repo.clearIdentity()
        XCTAssertNil(repo.deviceId)
    }
}
