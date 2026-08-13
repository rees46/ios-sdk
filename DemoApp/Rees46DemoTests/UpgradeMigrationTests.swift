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
    /// Real SDKs built by the assembled-upgrade tests, retained against the registry's weak reference.
    private var retained: [PersonalizationSDK] = []
    /// A non-routable API domain so an assembled SDK's background `/init` never leaves the machine (the
    /// upgrade assertions are synchronous and independent of it either way).
    private let unroutableDomain = "invalid.rees46.test"

    override func setUp() {
        super.setUp()
        // The multi-instance registry is process-global (the test host registers its own shop at
        // launch); reset it so the assembled-SDK upgrade tests observe only the shop they build.
        Rees46.reset()
        SdkRegistry.shared.reset()
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
        Rees46.reset()
        SdkRegistry.shared.reset()
        retained.removeAll()
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

    @discardableResult
    private func retain(_ sdk: PersonalizationSDK) -> PersonalizationSDK {
        retained.append(sdk)
        return sdk
    }

    private func same(_ lhs: PersonalizationSDK?, _ rhs: PersonalizationSDK?) -> Bool {
        (lhs as AnyObject?) === (rhs as AnyObject?)
    }

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

    // MARK: - The single-shop upgrade through the public SDK (assembled, no backend)

    /// The guarantee a single-shop host cares about most on upgrade: the code it already ships —
    /// `createPersonalizationSDK(shopId:)` — keeps returning an SDK whose did is the pre-partition did,
    /// so the user is not silently re-registered as a new device. This drives the real construction path
    /// end-to-end (not just the repository), closing the gap where `repo.deviceId` was only *assumed* to
    /// be what the SDK reads. Asserted synchronously, before the SDK's background `/init` runs, so it
    /// needs no backend. (The seance is a rolling session, not permanent identity, and may roll on
    /// upgrade — only the did is pinned here.)
    func test_a_single_shop_upgrade_keeps_its_did_through_the_public_sdk() {
        seedLegacyStandard(did: "did-upgrade", seance: "seance-upgrade", idfa: "idfa-upgrade")

        // Exactly the call an existing single-shop integration already ships.
        let sdk = retain(createPersonalizationSDK(shopId: freshShop(), apiDomain: unroutableDomain))

        XCTAssertEqual(sdk.getDeviceId(), "did-upgrade",
                       "an upgraded single-shop install must keep its did — no silent re-registration")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: StoragePartition.legacyConsumedFlag),
                      "the one-time legacy adoption ran through the real construction path")
    }

    /// The upgraded single-shop install is also reachable through the new facade with no host change:
    /// with exactly one live shop, `Rees46.instance()` resolves to that same instance. The legacy entry
    /// point and the new API interoperate, so a host can adopt `Rees46` incrementally.
    func test_an_upgraded_single_shop_is_reachable_through_the_new_facade() throws {
        let sdk = retain(createPersonalizationSDK(shopId: freshShop(), apiDomain: unroutableDomain))

        XCTAssertTrue(same(try Rees46.instance(), sdk),
                      "one shop built the legacy way resolves as the default via Rees46.instance()")
    }
}
