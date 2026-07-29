//
//  LocalStateRepositoryTests.swift
//  REES46Tests
//
//  Covers the per-shop stories UI state store (R2 / iOS-8): domain round-trips, clear-by-domain, and
//  two-shop isolation. Uses isolated UserDefaults suites so real domains are never touched.
//

import XCTest
@testable import REES46

final class LocalStateRepositoryTests: XCTestCase {

    private var suiteNames: [String] = []

    private func freshRepo() -> LocalStateRepositoryImpl {
        let name = "test-\(UUID().uuidString)"
        suiteNames.append(name)
        return LocalStateRepositoryImpl(store: UserDefaults(suiteName: name)!)
    }

    override func tearDown() {
        for name in suiteNames {
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        suiteNames.removeAll()
        super.tearDown()
    }

    func test_each_domain_round_trips_by_id() {
        let repo = freshRepo()

        repo.setViewedSlides(["s1", "s2"], storyId: "10")
        repo.setDownloadedMedia(["m1"], slideId: "20")
        repo.setCartProducts(["p1"], productId: "30")
        repo.setFavoriteProducts(["p2"], productId: "40")

        XCTAssertEqual(repo.viewedSlides(storyId: "10"), ["s1", "s2"])
        XCTAssertEqual(repo.downloadedMedia(slideId: "20"), ["m1"])
        XCTAssertEqual(repo.cartProducts(productId: "30"), ["p1"])
        XCTAssertEqual(repo.favoriteProducts(productId: "40"), ["p2"])
    }

    func test_missing_keys_return_empty() {
        let repo = freshRepo()
        XCTAssertEqual(repo.viewedSlides(storyId: "nope"), [])
        XCTAssertEqual(repo.cartProducts(productId: "nope"), [])
    }

    func test_clear_is_scoped_to_its_own_domain() {
        let repo = freshRepo()
        repo.setViewedSlides(["s1"], storyId: "1")
        repo.setDownloadedMedia(["m1"], slideId: "1")
        repo.setCartProducts(["p1"], productId: "1")
        repo.setFavoriteProducts(["f1"], productId: "1")

        repo.clearViewedSlides()

        XCTAssertEqual(repo.viewedSlides(storyId: "1"), [])
        XCTAssertEqual(repo.downloadedMedia(slideId: "1"), ["m1"], "clearing viewed must not touch downloaded")
        XCTAssertEqual(repo.cartProducts(productId: "1"), ["p1"])
        XCTAssertEqual(repo.favoriteProducts(productId: "1"), ["f1"])
    }

    func test_clear_removes_every_key_in_the_domain() {
        let repo = freshRepo()
        repo.setCartProducts(["a"], productId: "1")
        repo.setCartProducts(["b"], productId: "2")

        repo.clearCartProducts()

        XCTAssertEqual(repo.cartProducts(productId: "1"), [])
        XCTAssertEqual(repo.cartProducts(productId: "2"), [])
    }

    func test_two_shops_do_not_share_state() {
        let shopA = freshRepo()
        let shopB = freshRepo()

        shopA.setViewedSlides(["a"], storyId: "1")
        shopA.setCartProducts(["ca"], productId: "1")
        shopB.setViewedSlides(["b"], storyId: "1")

        XCTAssertEqual(shopA.viewedSlides(storyId: "1"), ["a"])
        XCTAssertEqual(shopB.viewedSlides(storyId: "1"), ["b"])
        XCTAssertEqual(shopB.cartProducts(productId: "1"), [], "shop B must not see shop A's cart")

        shopA.clearViewedSlides()
        XCTAssertEqual(shopA.viewedSlides(storyId: "1"), [])
        XCTAssertEqual(shopB.viewedSlides(storyId: "1"), ["b"], "clearing shop A must not touch shop B")
    }
}
