//
//  UpgradeMigrationTests.swift
//  REES46Tests
//
//  iOS-20 — the non-breaking upgrade guarantee at the SDK's real construction path.
//
//  StorageMigrationTests unit-tests the pure `migrateLegacyIfNeeded(into:legacy:)` with an *injected*
//  legacy suite, and KeychainInitStoreTests uses a stand-in service — both deliberately bypass the
//  production wiring. This test seeds a pre-partition install's real state (did/seance/IDFA in
//  `.standard` plus a legacy keychain blob) and drives it through the exact constructors
//  `SimplePersonalizationSDK.init` uses — `UserIdentityRepositoryImpl(shopId:)` (hardcoded
//  `legacy: .standard`, real `personalization_sdk_<shopId>` suite naming) and
//  `KeychainInitStoreImpl(shopId:service:)`. It pins the two guarantees an upgrade must keep:
//    1. the existing install's identity is inherited by the default shop — `repo.deviceId` is the
//       legacy did, which is exactly what the SDK reads into `deviceId` and sends to `/init`, so no
//       silent re-registration happens;
//    2. a second shop never clones that identity.
//
//  `.standard` is snapshotted and restored around each test so the host app's real identity is never
//  disturbed; partition suites and keychain services are unique per test and wiped in tearDown.
//

import XCTest
import Security
@testable import REES46

final class UpgradeMigrationTests: XCTestCase {

    private let standardKeys = [
        StoragePartition.deviceIdKey,
        StoragePartition.seanceKey,
        StoragePartition.idfaKey,
        StoragePartition.legacyConsumedFlag
    ]
    private var standardSnapshot: [String: Any] = [:]
    private var partitionShops: [String] = []
    private var keychainServices: [String] = []

    override func setUp() {
        super.setUp()
        // Snapshot then clear the legacy `.standard` keys so each test starts from a clean
        // pre-partition slate without disturbing the host app's real identity (restored in tearDown).
        standardSnapshot = [:]
        for key in standardKeys {
            if let value = UserDefaults.standard.object(forKey: key) {
                standardSnapshot[key] = value
            }
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for shop in partitionShops {
            UserDefaults.standard.removePersistentDomain(forName: StoragePartition.suiteName(for: shop))
        }
        partitionShops.removeAll()
        for service in keychainServices {
            SecItemDelete([
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service
            ] as CFDictionary)
        }
        keychainServices.removeAll()
        for key in standardKeys {
            if let value = standardSnapshot[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        standardSnapshot = [:]
        super.tearDown()
    }

    /// A random, filename-safe shop id whose partition suite is removed in tearDown.
    private func freshShop() -> String {
        let shop = "upgrade-\(UUID().uuidString)"
        partitionShops.append(shop)
        return shop
    }

    private func uniqueService() -> String {
        let service = "test-keychain-\(UUID().uuidString)"
        keychainServices.append(service)
        return service
    }

    private func blob(_ s: String) -> Data { Data(s.utf8) }

    /// Seed a pre-partition install's identity in the real `.standard` domain.
    private func seedLegacyStandard(did: String, seance: String, idfa: String) {
        UserDefaults.standard.set(did, forKey: StoragePartition.deviceIdKey)
        UserDefaults.standard.set(seance, forKey: StoragePartition.seanceKey)
        UserDefaults.standard.set(idfa, forKey: StoragePartition.idfaKey)
    }

    // MARK: - UserDefaults identity

    func test_existing_install_keeps_identity_through_the_real_repository_constructor() {
        seedLegacyStandard(did: "did-upgrade", seance: "seance-upgrade", idfa: "idfa-upgrade")

        // The exact expression SimplePersonalizationSDK.init uses for the default shop.
        let repo = UserIdentityRepositoryImpl(shopId: freshShop())

        // `repo.deviceId` is what the SDK reads into `deviceId` at init and sends to `/init`; being the
        // legacy did, no new registration is triggered — the core non-breaking guarantee.
        XCTAssertEqual(repo.deviceId, "did-upgrade")
        XCTAssertEqual(repo.seance, "seance-upgrade")
        XCTAssertEqual(repo.advertisingId, "idfa-upgrade")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: StoragePartition.legacyConsumedFlag),
                      "the one-time adoption must mark the legacy source consumed")
    }

    func test_second_shop_after_upgrade_gets_a_fresh_identity() {
        seedLegacyStandard(did: "did-upgrade", seance: "seance-upgrade", idfa: "idfa-upgrade")

        let first = UserIdentityRepositoryImpl(shopId: freshShop())
        let second = UserIdentityRepositoryImpl(shopId: freshShop())

        XCTAssertEqual(first.deviceId, "did-upgrade", "the default shop inherits the pre-partition did")
        XCTAssertNil(second.deviceId, "a second shop must not clone the upgraded identity")
    }

    func test_a_fresh_install_starts_without_an_inherited_identity() {
        // No legacy `.standard` seed — a brand-new install has nothing to adopt.
        let repo = UserIdentityRepositoryImpl(shopId: freshShop())

        XCTAssertNil(repo.deviceId)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: StoragePartition.legacyConsumedFlag),
                       "nothing to consume on a fresh install")
    }

    // MARK: - Keychain

    func test_keychain_did_backup_survives_upgrade_for_the_default_shop() {
        let service = uniqueService()
        // A pre-partition install stored its only keychain item at the bundle-id (legacy) account.
        try? InitService.upsertKeychainDidToken(
            blob("keychain-did"),
            identifier: KeychainPartition.legacyAccount(service: service),
            instanceKeychainService: service
        )

        // The exact expression SimplePersonalizationSDK.init uses for the keychain backup.
        let store = KeychainInitStoreImpl(shopId: freshShop(), service: service)
        XCTAssertEqual(store.readInitData(), blob("keychain-did"))

        // Consumed by the first shop, so a reinstall under a second shop can't clone the identity.
        let second = KeychainInitStoreImpl(shopId: freshShop(), service: service)
        XCTAssertNil(second.readInitData())
    }

    // MARK: - Combined

    func test_full_identity_did_seance_idfa_and_keychain_survive_together() {
        seedLegacyStandard(did: "did-full", seance: "seance-full", idfa: "idfa-full")
        let service = uniqueService()
        try? InitService.upsertKeychainDidToken(
            blob("did-full"),
            identifier: KeychainPartition.legacyAccount(service: service),
            instanceKeychainService: service
        )
        let shop = freshShop()

        // Construct identity + keychain the way SimplePersonalizationSDK.init does for one shop.
        let repo = UserIdentityRepositoryImpl(shopId: shop)
        let keychain = KeychainInitStoreImpl(shopId: shop, service: service)

        XCTAssertEqual(repo.deviceId, "did-full")
        XCTAssertEqual(repo.seance, "seance-full")
        XCTAssertEqual(repo.advertisingId, "idfa-full")
        XCTAssertEqual(keychain.readInitData(), blob("did-full"))
    }
}
