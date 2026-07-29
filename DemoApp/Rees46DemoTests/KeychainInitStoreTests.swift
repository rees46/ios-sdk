//
//  KeychainInitStoreTests.swift
//  REES46Tests
//
//  Covers the per-shop keychain init-secret store (R2) against the real keychain. Each test uses a
//  unique service so items never collide with the app's own keychain or with other tests, and wipes
//  that service in tearDown.
//

import XCTest
import Security
@testable import REES46

final class KeychainInitStoreTests: XCTestCase {

    private var services: [String] = []

    private func uniqueService() -> String {
        let service = "test-keychain-\(UUID().uuidString)"
        services.append(service)
        return service
    }

    private func blob(_ s: String) -> Data { Data(s.utf8) }

    override func tearDown() {
        for service in services {
            let query = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service
            ] as CFDictionary
            SecItemDelete(query)
        }
        services.removeAll()
        super.tearDown()
    }

    func test_writes_and_reads_back_the_init_blob() {
        let store = KeychainInitStoreImpl(shopId: "A", service: uniqueService())

        store.writeInitData(blob("init-A"))

        XCTAssertEqual(store.readInitData(), blob("init-A"))
    }

    func test_clear_removes_the_blob() {
        let store = KeychainInitStoreImpl(shopId: "A", service: uniqueService())
        store.writeInitData(blob("init-A"))

        store.clear()

        XCTAssertNil(store.readInitData())
    }

    func test_two_shops_have_isolated_keychain_items() {
        let service = uniqueService()
        let storeA = KeychainInitStoreImpl(shopId: "A", service: service)
        let storeB = KeychainInitStoreImpl(shopId: "B", service: service)

        storeA.writeInitData(blob("init-A"))
        storeB.writeInitData(blob("init-B"))

        XCTAssertEqual(storeA.readInitData(), blob("init-A"))
        XCTAssertEqual(storeB.readInitData(), blob("init-B"))

        storeA.clear()
        XCTAssertNil(storeA.readInitData())
        XCTAssertEqual(storeB.readInitData(), blob("init-B"), "clearing one shop must not touch another")
    }

    func test_first_shop_adopts_the_legacy_item_then_consumes_it() {
        let service = uniqueService()
        // Seed a pre-partition item at the legacy account (== the service).
        try? InitService.upsertKeychainDidToken(
            blob("legacy-did"),
            identifier: KeychainPartition.legacyAccount(service: service),
            instanceKeychainService: service
        )

        // The first shop adopts it on construction.
        let storeA = KeychainInitStoreImpl(shopId: "A", service: service)
        XCTAssertEqual(storeA.readInitData(), blob("legacy-did"))

        // The legacy item is consumed, so a second shop does not clone the identity.
        let storeB = KeychainInitStoreImpl(shopId: "B", service: service)
        XCTAssertNil(storeB.readInitData())

        // And the legacy account itself is gone.
        let legacy = try? InitService.getKeychainDidToken(
            identifier: KeychainPartition.legacyAccount(service: service),
            instanceKeychainService: service
        )
        XCTAssertNil(legacy)
    }

    func test_does_not_adopt_legacy_when_the_shop_already_has_its_own() {
        let service = uniqueService()
        let storeA = KeychainInitStoreImpl(shopId: "A", service: service)
        storeA.writeInitData(blob("own-A"))

        // Now a legacy item appears; re-constructing the same shop must keep its own blob.
        try? InitService.upsertKeychainDidToken(
            blob("legacy-did"),
            identifier: KeychainPartition.legacyAccount(service: service),
            instanceKeychainService: service
        )
        let reopened = KeychainInitStoreImpl(shopId: "A", service: service)

        XCTAssertEqual(reopened.readInitData(), blob("own-A"))
    }
}
