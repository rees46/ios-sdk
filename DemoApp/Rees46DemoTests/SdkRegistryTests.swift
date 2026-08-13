//
//  SdkRegistryTests.swift
//  REES46Tests
//
//  Covers `SdkRegistry`, the internal routing state behind multi-instance (R1). Pins the
//  single-instance behaviour (unchanged) and the shop-id resolution the public API will build on.
//  Mirror of the Android `SdkRegistryTest`, adapted for the iOS design difference: the registry
//  holds instances **weakly** (the host owns their lifetime), so tests bind each `FakeSDK` to a local
//  to keep it alive, and there is an extra test for the auto-drop on deallocation.
//
//  `PersonalizationSDK` is not class-constrained, so identity is compared through `same(_:_:)`, which
//  bridges to `AnyObject` — the same bridge the registry uses internally to key on reference identity.
//

import XCTest
@testable import REES46

final class SdkRegistryTests: XCTestCase {

    private var registry: SdkRegistry { SdkRegistry.shared }

    private func same(_ lhs: PersonalizationSDK?, _ rhs: PersonalizationSDK?) -> Bool {
        (lhs as AnyObject?) === (rhs as AnyObject?)
    }

    override func setUp() {
        super.setUp()
        registry.reset()
    }

    override func tearDown() {
        registry.reset()
        super.tearDown()
    }

    func test_a_registered_instance_becomes_current_and_is_resolvable_by_shop_id() {
        let sdk = FakeSDK(shopId: "shop-a")

        registry.register(shopId: "shop-a", sdk: sdk)

        XCTAssertTrue(same(registry.current(), sdk))
        XCTAssertTrue(same(registry.byShopId("shop-a"), sdk))
        XCTAssertEqual(registry.count(), 1)
    }

    func test_the_last_registered_instance_is_the_current_default() {
        let first = FakeSDK(shopId: "shop-a")
        let second = FakeSDK(shopId: "shop-b")

        registry.register(shopId: "shop-a", sdk: first)
        registry.register(shopId: "shop-b", sdk: second)

        XCTAssertTrue(same(registry.current(), second))
        XCTAssertEqual(registry.count(), 2)
    }

    func test_each_shop_id_resolves_to_its_own_instance() {
        let a = FakeSDK(shopId: "shop-a")
        let b = FakeSDK(shopId: "shop-b")
        registry.register(shopId: "shop-a", sdk: a)
        registry.register(shopId: "shop-b", sdk: b)

        XCTAssertTrue(same(registry.byShopId("shop-a"), a))
        XCTAssertTrue(same(registry.byShopId("shop-b"), b))
    }

    func test_an_unknown_shop_id_resolves_to_nil() {
        let a = FakeSDK(shopId: "shop-a")
        registry.register(shopId: "shop-a", sdk: a)

        XCTAssertNil(registry.byShopId("shop-x"))
    }

    func test_re_registering_the_same_instance_keeps_a_single_entry() {
        let sdk = FakeSDK(shopId: "shop-a")

        registry.register(shopId: "shop-a", sdk: sdk)
        registry.register(shopId: "shop-a", sdk: sdk)

        XCTAssertEqual(registry.count(), 1)
    }

    func test_re_registering_a_shop_evicts_the_superseded_instance_from_the_fan_out_set() {
        let old = FakeSDK(shopId: "shop-a")
        let new = FakeSDK(shopId: "shop-a")
        registry.register(shopId: "shop-a", sdk: old)
        registry.register(shopId: "shop-a", sdk: new)

        XCTAssertEqual(registry.count(), 1)
        XCTAssertTrue(same(registry.byShopId("shop-a"), new))
        let all = registry.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertTrue(same(all.first, new))
    }

    func test_onNextRegister_fires_immediately_when_the_shop_is_already_registered() {
        let sdk = FakeSDK(shopId: "shop-a")
        registry.register(shopId: "shop-a", sdk: sdk)

        var received: PersonalizationSDK?
        registry.onNextRegister(shopId: "shop-a") { received = $0 }

        XCTAssertTrue(same(received, sdk))
    }

    func test_onNextRegister_without_a_shop_fires_immediately_when_an_instance_is_current() {
        let sdk = FakeSDK(shopId: "shop-a")
        registry.register(shopId: "shop-a", sdk: sdk)

        var received: PersonalizationSDK?
        registry.onNextRegister(shopId: nil) { received = $0 }

        XCTAssertTrue(same(received, sdk))
    }

    func test_onNextRegister_waits_and_then_fires_on_the_next_matching_registration() {
        var received: PersonalizationSDK?
        registry.onNextRegister(shopId: "shop-a") { received = $0 }
        XCTAssertNil(received)

        let sdk = FakeSDK(shopId: "shop-a")
        registry.register(shopId: "shop-a", sdk: sdk)

        XCTAssertTrue(same(received, sdk))
    }

    func test_a_cancelled_onNextRegister_does_not_fire_on_a_later_registration() {
        var received: PersonalizationSDK?
        let handle = registry.onNextRegister(shopId: "shop-a") { received = $0 }
        handle.cancel()

        let sdk = FakeSDK(shopId: "shop-a")
        registry.register(shopId: "shop-a", sdk: sdk)

        XCTAssertNil(received)
    }

    func test_all_returns_every_registered_instance_for_push_fan_out() {
        let a = FakeSDK(shopId: "shop-a")
        let b = FakeSDK(shopId: "shop-b")
        registry.register(shopId: "shop-a", sdk: a)
        registry.register(shopId: "shop-b", sdk: b)

        let all = registry.all()

        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.contains { same($0, a) })
        XCTAssertTrue(all.contains { same($0, b) })
    }

    func test_unregister_drops_the_instance_from_the_fan_out_set_and_the_shop_mapping() {
        let a = FakeSDK(shopId: "shop-a")
        let b = FakeSDK(shopId: "shop-b")
        registry.register(shopId: "shop-a", sdk: a)
        registry.register(shopId: "shop-b", sdk: b)

        registry.unregister(a)

        XCTAssertEqual(registry.count(), 1)
        XCTAssertNil(registry.byShopId("shop-a"))
        XCTAssertTrue(same(registry.byShopId("shop-b"), b))
    }

    /// iOS-specific: the registry references instances weakly, so an instance the host stops
    /// retaining deallocs and drops out on its own — no explicit unregister required.
    func test_a_deallocated_instance_drops_out_of_the_registry() {
        do {
            let sdk = FakeSDK(shopId: "shop-a")
            registry.register(shopId: "shop-a", sdk: sdk)
            XCTAssertEqual(registry.count(), 1)
        }

        XCTAssertNil(registry.byShopId("shop-a"))
        XCTAssertNil(registry.current())
        XCTAssertEqual(registry.count(), 0)
        XCTAssertTrue(registry.all().isEmpty)
    }
}
