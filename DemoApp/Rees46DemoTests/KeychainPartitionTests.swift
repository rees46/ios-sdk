//
//  KeychainPartitionTests.swift
//  REES46Tests
//
//  Covers the per-shop keychain account naming (R2). Pure logic.
//

import XCTest
@testable import REES46

final class KeychainPartitionTests: XCTestCase {

    func test_account_namespaces_the_shop_under_the_service() {
        XCTAssertEqual(KeychainPartition.account(shopId: "shop-a", service: "com.app"), "com.app.shop-a")
    }

    func test_legacy_account_is_the_service_itself() {
        XCTAssertEqual(KeychainPartition.legacyAccount(service: "com.app"), "com.app")
    }

    func test_distinct_shops_get_distinct_accounts() {
        let a = KeychainPartition.account(shopId: "shop-a", service: "com.app")
        let b = KeychainPartition.account(shopId: "shop-b", service: "com.app")
        XCTAssertNotEqual(a, b)
    }

    func test_a_shop_account_never_equals_the_legacy_account() {
        let account = KeychainPartition.account(shopId: "shop-a", service: "com.app")
        XCTAssertNotEqual(account, KeychainPartition.legacyAccount(service: "com.app"))
    }
}
