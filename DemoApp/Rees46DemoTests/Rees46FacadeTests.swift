//
//  Rees46FacadeTests.swift
//  REES46Tests
//
//  Covers the public `Rees46` facade (R3 / iOS-11): shop resolution, the `Rees46Error` contract, lazy
//  registration bookkeeping, and the reactive `awaitInstance` path. Mirror of the Android `Rees46Test`.
//
//  Resolution is exercised with `FakeSDK` instances registered into `SdkRegistry` directly, so no real
//  (network-spawning) SDK is constructed. The registry holds instances weakly, so each fake is bound
//  to a retained local for the test's duration. Materialization of a pending shop (which would build a
//  real SDK) is intentionally not driven here — it is covered by the demo E2E (iOS-21).
//

import XCTest
@testable import REES46

final class Rees46FacadeTests: XCTestCase {

    private var registry: SdkRegistry { SdkRegistry.shared }
    private var retained: [FakeSDK] = []

    override func setUp() {
        super.setUp()
        Rees46.reset()
        registry.reset()
    }

    override func tearDown() {
        Rees46.reset()
        registry.reset()
        retained.removeAll()
        super.tearDown()
    }

    private func same(_ lhs: PersonalizationSDK?, _ rhs: PersonalizationSDK?) -> Bool {
        (lhs as AnyObject?) === (rhs as AnyObject?)
    }

    /// Registers a live `FakeSDK` for `shopId`, retaining it against the registry's weak reference.
    @discardableResult
    private func live(_ shopId: String) -> FakeSDK {
        let sdk = FakeSDK(shopId: shopId)
        retained.append(sdk)
        registry.register(shopId: shopId, sdk: sdk)
        return sdk
    }

    // MARK: - instance(for:) resolution

    func test_instance_with_nothing_registered_throws_unknownShopId() {
        XCTAssertThrowsError(try Rees46.instance()) { error in
            guard case Rees46Error.unknownShopId = error else {
                return XCTFail("expected unknownShopId, got \(error)")
            }
        }
    }

    func test_instance_for_an_unknown_shop_throws_unknownShopId() {
        live("shop-a")

        XCTAssertThrowsError(try Rees46.instance(for: "shop-x")) { error in
            guard case Rees46Error.unknownShopId(let shopId) = error else {
                return XCTFail("expected unknownShopId, got \(error)")
            }
            XCTAssertEqual(shopId, "shop-x")
        }
    }

    func test_a_single_shop_resolves_without_an_explicit_shopId() throws {
        let a = live("shop-a")
        XCTAssertTrue(same(try Rees46.instance(), a))
    }

    func test_an_explicit_shopId_resolves_to_its_own_instance() throws {
        let a = live("shop-a")
        let b = live("shop-b")

        XCTAssertTrue(same(try Rees46.instance(for: "shop-a"), a))
        XCTAssertTrue(same(try Rees46.instance(for: "shop-b"), b))
    }

    func test_no_shopId_with_several_shops_throws_ambiguousShop_listing_them() {
        live("shop-a")
        live("shop-b")

        XCTAssertThrowsError(try Rees46.instance()) { error in
            guard case Rees46Error.ambiguousShop(let shopIds) = error else {
                return XCTFail("expected ambiguousShop, got \(error)")
            }
            XCTAssertEqual(Set(shopIds), ["shop-a", "shop-b"])
        }
    }

    // MARK: - isInitialized

    func test_isInitialized_reflects_the_live_instances() {
        XCTAssertFalse(Rees46.isInitialized(), "nothing registered")

        live("shop-a")
        XCTAssertTrue(Rees46.isInitialized(), "exactly one shop → default is unambiguous")
        XCTAssertTrue(Rees46.isInitialized(shopId: "shop-a"))
        XCTAssertFalse(Rees46.isInitialized(shopId: "shop-x"))

        live("shop-b")
        XCTAssertFalse(Rees46.isInitialized(), "two shops → default is ambiguous")
        XCTAssertTrue(Rees46.isInitialized(shopId: "shop-b"))
    }

    // MARK: - lazy registration

    func test_register_shops_stays_pending_and_uninitialized() {
        Rees46.register(shops: [Rees46Config(shopId: "shop-a"), Rees46Config(shopId: "shop-b")])

        XCTAssertEqual(Rees46.pendingShopIds(), ["shop-a", "shop-b"])
        XCTAssertTrue(registry.shopIds().isEmpty, "register(shops:) must not initialize anything")
        XCTAssertFalse(Rees46.isInitialized(shopId: "shop-a"), "pending is not initialized")
    }

    // MARK: - awaitInstance

    func test_awaitInstance_fires_immediately_for_a_live_shop() {
        let a = live("shop-a")

        var delivered: PersonalizationSDK?
        let handle = Rees46.awaitInstance(for: "shop-a") { delivered = $0 }

        XCTAssertTrue(same(delivered, a))
        handle.cancel()
    }

    func test_awaitInstance_drops_an_ambiguous_request() {
        live("shop-a")
        live("shop-b")

        var fired = false
        let handle = Rees46.awaitInstance { _ in fired = true }

        XCTAssertFalse(fired, "an ambiguous await must not deliver the wrong shop")
        handle.cancel()
    }

    func test_awaitInstance_fires_on_a_later_registration() {
        var delivered: PersonalizationSDK?
        let handle = Rees46.awaitInstance(for: "shop-late") { delivered = $0 }
        XCTAssertNil(delivered, "nothing registered yet")

        let late = live("shop-late")
        XCTAssertTrue(same(delivered, late))
        handle.cancel()
    }

    func test_awaitInstance_cancel_prevents_a_later_delivery() {
        var fired = false
        let handle = Rees46.awaitInstance(for: "shop-late") { _ in fired = true }
        handle.cancel()

        live("shop-late")
        XCTAssertFalse(fired, "a cancelled await must not fire")
    }
}
