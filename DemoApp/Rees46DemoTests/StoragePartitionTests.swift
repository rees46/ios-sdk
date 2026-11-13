//
//  StoragePartitionTests.swift
//  REES46Tests
//
//  Covers the per-shop storage partition naming (R2). Pure logic — mirror of the stability guarantees
//  Android pins for `PreferencesPartition`.
//

import XCTest
@testable import REES46

final class StoragePartitionTests: XCTestCase {

    private var createdSuites: [String] = []

    override func tearDown() {
        for name in createdSuites {
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        createdSuites.removeAll()
        super.tearDown()
    }

    func test_suiteName_carries_the_shared_prefix() {
        XCTAssertEqual(StoragePartition.suiteName(for: "shop-a"), "personalization_sdk_shop-a")
    }

    func test_sanitize_replaces_unsafe_characters_with_underscore() {
        XCTAssertEqual(StoragePartition.sanitize("com.foo/bar id"), "com_foo_bar_id")
    }

    func test_sanitize_preserves_safe_characters() {
        XCTAssertEqual(StoragePartition.sanitize("Shop_123-AB"), "Shop_123-AB")
    }

    func test_suiteName_is_stable_for_the_same_shop() {
        XCTAssertEqual(
            StoragePartition.suiteName(for: "shop-42"),
            StoragePartition.suiteName(for: "shop-42")
        )
    }

    func test_store_reads_back_what_it_writes() {
        let shopId = "roundtrip-\(UUID().uuidString)"
        createdSuites.append(StoragePartition.suiteName(for: shopId))

        let store = StoragePartition.store(for: shopId)
        store.set("value", forKey: "k")

        XCTAssertEqual(store.string(forKey: "k"), "value")
    }

    func test_a_storage_key_is_the_prefix_of_the_shops_partition() {
        let custom = "custom-\(UUID().uuidString)-"
        let name = StoragePartition.suiteName(for: "shop/a", storageKey: custom)
        createdSuites.append(name)
        XCTAssertEqual(name, custom + "_personalization_sdk_shop_a", "the same name as on Android")
        XCTAssertEqual(StoragePartition.suiteName(for: "shop-a", storageKey: ""), "personalization_sdk_shop-a", "an empty key is none")

        let store = StoragePartition.store(for: "shop/a", storageKey: custom)
        store.set("v", forKey: "k")

        // The value must be visible through a separately-opened handle on the same partition, and the
        // suite named exactly by the key stays untouched.
        XCTAssertEqual(UserDefaults(suiteName: name)?.string(forKey: "k"), "v")
        XCTAssertNil(UserDefaults.standard.persistentDomain(forName: custom))
    }

    func test_the_sdks_keys_are_told_from_an_apps_own() {
        for key in ["device_id", "seance_id", "seance_last_act", "IDFA", "segment_ab_testing",
                    "recomendedCode", "recomendedType", "timeStartSave",
                    "viewed.slide.1", "cached.slide.2", "cart.product.3", "favorites.product.4"] {
            XCTAssertTrue(StoragePartition.isShopKey(key), key)
        }
        for key in ["app.token", "personalization_sdk.migrated.storage_key_suite", "AppleLanguages"] {
            XCTAssertFalse(StoragePartition.isShopKey(key), key)
        }
    }
}
