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

    func test_store_uses_the_custom_suite_when_a_storage_key_is_given() {
        let custom = "custom-\(UUID().uuidString)"
        createdSuites.append(custom)

        let store = StoragePartition.store(for: "ignored-shop", storageKey: custom)
        store.set("v", forKey: "k")

        // The value must be visible through a separately-opened handle on the same custom suite.
        XCTAssertEqual(UserDefaults(suiteName: custom)?.string(forKey: "k"), "v")
    }
}
