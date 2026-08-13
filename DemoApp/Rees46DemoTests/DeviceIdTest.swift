//
//  DeviceIdTest.swift
//  REES46Tests
//
//  R2: the did is no longer stored in the shared `UserDefaults.standard` under "device_id" — it lives
//  in the shop's partition (`personalization_sdk_<shopId>`). This pins that location and that two shops
//  keep their dids apart, so a regression back to a global key would fail here.
//

import XCTest
@testable import REES46

final class DeviceIdSaveTest: XCTestCase {

    private var shops: [String] = []

    private func freshShop() -> String {
        let shop = "device-id-test-\(UUID().uuidString)"
        shops.append(shop)
        return shop
    }

    override func tearDown() {
        for shop in shops {
            UserDefaults.standard.removePersistentDomain(forName: StoragePartition.suiteName(for: shop))
        }
        shops.removeAll()
        super.tearDown()
    }

    func test_device_id_persists_in_the_shop_partition() {
        let shop = freshShop()
        let repo = UserIdentityRepositoryImpl(shopId: shop)

        repo.deviceId = "did-token"

        XCTAssertEqual(
            StoragePartition.store(for: shop).string(forKey: StoragePartition.deviceIdKey),
            "did-token",
            "the did must persist in the shop's partition"
        )
    }

    func test_two_shops_do_not_share_a_device_id() {
        let shopA = freshShop()
        let shopB = freshShop()

        UserIdentityRepositoryImpl(shopId: shopA).deviceId = "did-A"
        UserIdentityRepositoryImpl(shopId: shopB).deviceId = "did-B"

        XCTAssertEqual(UserIdentityRepositoryImpl(shopId: shopA).deviceId, "did-A")
        XCTAssertEqual(UserIdentityRepositoryImpl(shopId: shopB).deviceId, "did-B", "each shop keeps its own did")
    }
}
