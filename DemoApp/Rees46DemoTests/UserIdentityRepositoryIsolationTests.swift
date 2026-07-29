//
//  UserIdentityRepositoryIsolationTests.swift
//  REES46Tests
//
//  Multi-instance isolation for the identity repository: several shops live at once, and each must
//  keep its own did/seance/IDFA with no collision. Repos are built over the real per-shop suite
//  factory (`StoragePartition.store(for:)`) via the direct-store initializer, so the partition
//  mechanism itself is under test with no `.standard`/migration noise.
//

import XCTest
@testable import REES46

final class UserIdentityRepositoryIsolationTests: XCTestCase {

    private var suiteNames: [String] = []

    /// A repository over [shopId]'s real partition suite, tracked for cleanup.
    private func repo(forShop shopId: String) -> UserIdentityRepositoryImpl {
        suiteNames.append(StoragePartition.suiteName(for: shopId))
        return UserIdentityRepositoryImpl(store: StoragePartition.store(for: shopId))
    }

    private func uniqueShop(_ label: String) -> String {
        "\(label)-\(UUID().uuidString)"
    }

    override func tearDown() {
        for name in Set(suiteNames) {
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        suiteNames.removeAll()
        super.tearDown()
    }

    func test_two_shops_have_fully_isolated_identity() {
        let repoA = repo(forShop: uniqueShop("shop-a"))
        let repoB = repo(forShop: uniqueShop("shop-b"))

        repoA.deviceId = "did-A"; repoA.seance = "seance-A"; repoA.advertisingId = "idfa-A"
        repoB.deviceId = "did-B"; repoB.seance = "seance-B"; repoB.advertisingId = "idfa-B"

        XCTAssertEqual(repoA.deviceId, "did-A")
        XCTAssertEqual(repoA.seance, "seance-A")
        XCTAssertEqual(repoA.advertisingId, "idfa-A")

        XCTAssertEqual(repoB.deviceId, "did-B")
        XCTAssertEqual(repoB.seance, "seance-B")
        XCTAssertEqual(repoB.advertisingId, "idfa-B")
    }

    func test_writing_one_shop_does_not_leak_into_another() {
        let repoA = repo(forShop: uniqueShop("shop-a"))
        let repoB = repo(forShop: uniqueShop("shop-b"))

        repoA.deviceId = "did-A"

        XCTAssertEqual(repoA.deviceId, "did-A")
        XCTAssertNil(repoB.deviceId)
    }

    func test_clearing_one_shop_leaves_the_other_intact() {
        let repoA = repo(forShop: uniqueShop("shop-a"))
        let repoB = repo(forShop: uniqueShop("shop-b"))
        repoA.deviceId = "did-A"; repoA.seance = "seance-A"
        repoB.deviceId = "did-B"; repoB.seance = "seance-B"

        repoA.clearIdentity()

        XCTAssertNil(repoA.deviceId)
        XCTAssertNil(repoA.seance)
        XCTAssertEqual(repoB.deviceId, "did-B")
        XCTAssertEqual(repoB.seance, "seance-B")
    }

    /// Two repositories for the SAME shop share one partition — a re-resolved/re-created instance
    /// keeps the shop's identity (it is keyed by shop, not by object).
    func test_same_shop_id_shares_one_partition() {
        let shopId = uniqueShop("shop-shared")
        let first = repo(forShop: shopId)
        let second = repo(forShop: shopId)

        first.deviceId = "did-shared"

        XCTAssertEqual(second.deviceId, "did-shared")
    }

    func test_three_shops_are_mutually_isolated() {
        let repos = (0..<3).map { repo(forShop: uniqueShop("shop-\($0)")) }
        for (index, repo) in repos.enumerated() {
            repo.deviceId = "did-\(index)"
        }

        let readBack = repos.map { $0.deviceId }
        XCTAssertEqual(readBack, ["did-0", "did-1", "did-2"])
        XCTAssertEqual(Set(readBack.compactMap { $0 }).count, 3, "all three dids must be distinct")
    }

    /// Naming-level guarantee: distinct shop ids never alias to the same suite (no collision at the
    /// partition-name level for the realistic shop-id space — alphanumeric hex tokens plus `-`/`_`).
    func test_distinct_shop_ids_map_to_distinct_suites() {
        let shopIds = [
            "3704bd6e8a1a9a6dc65b75a5f01e5c8d",
            "9a1b2c3d4e5f60718293a4b5c6d7e8f9",
            "shop-a",
            "shop-b",
            "Shop_A",
            "shop-a-2",
        ]
        let suites = Set(shopIds.map { StoragePartition.suiteName(for: $0) })
        XCTAssertEqual(suites.count, shopIds.count, "each distinct shop id must get its own suite")
    }
}
