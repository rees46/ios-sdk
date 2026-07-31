//
//  MultiInstanceE2ETest.swift
//  REES46Tests
//
//  On-device E2E for multi-instance (iOS-21) against the live REES46 API. Initializes two distinct,
//  real shops in one process through the public `Rees46` facade and asserts their isolation and the
//  fail-fast resolution contracts. Mirror of the Android `MultiInstanceE2ETest`.
//
//  `Rees46` / `SdkRegistry` are process-global, and the demo app registers its own shop at launch, so
//  each test resets the registry in setUp and makes the shops it needs live itself — assertions are
//  order-independent. The session-isolation test needs the backend; the resolution-contract tests do
//  not (registration is synchronous), so they hold even offline.
//

import XCTest
@testable import REES46

final class MultiInstanceE2ETest: XCTestCase {

    private let shopA = Constants.testShopId
    private let shopB = Constants.testShopIdB
    private let apiDomain = Constants.testApiDomain

    override func setUp() {
        super.setUp()
        Rees46.reset()
        SdkRegistry.shared.reset()
    }

    override func tearDown() {
        Rees46.reset()
        SdkRegistry.shared.reset()
        super.tearDown()
    }

    private func config(_ shopId: String) -> Rees46Config {
        Rees46Config(
            shopId: shopId,
            apiDomain: apiDomain,
            enableAutoPopupPresentation: false,
            needReInitialization: true
        )
    }

    private func same(_ lhs: PersonalizationSDK?, _ rhs: PersonalizationSDK?) -> Bool {
        (lhs as AnyObject?) === (rhs as AnyObject?)
    }

    // MARK: - Resolution contracts (no backend needed)

    func test_both_shops_resolve_to_distinct_instances() throws {
        let a = Rees46.initialize(config(shopA))
        let b = Rees46.initialize(config(shopB))

        XCTAssertFalse(same(a, b), "each shop must have its own SDK instance")
        XCTAssertTrue(same(try Rees46.instance(for: shopA), a))
        XCTAssertTrue(same(try Rees46.instance(for: shopB), b))
    }

    func test_default_instance_is_ambiguous_with_two_shops_live() {
        _ = Rees46.initialize(config(shopA))
        _ = Rees46.initialize(config(shopB))

        XCTAssertThrowsError(try Rees46.instance()) { error in
            guard case Rees46Error.ambiguousShop = error else {
                return XCTFail("expected ambiguousShop, got \(error)")
            }
        }
    }

    func test_instance_for_an_unknown_shop_throws_unknownShopId() {
        _ = Rees46.initialize(config(shopA))

        XCTAssertThrowsError(try Rees46.instance(for: "nope-not-a-shop")) { error in
            guard case Rees46Error.unknownShopId = error else {
                return XCTFail("expected unknownShopId, got \(error)")
            }
        }
    }

    // MARK: - Session isolation (live backend)

    func test_two_shops_have_isolated_sessions() {
        let (didA, sidA) = initAndWaitSession(shopA)
        let (didB, sidB) = initAndWaitSession(shopB)

        // Both shops complete /init against the live backend, each carrying its own session.
        XCTAssertFalse(didA.isEmpty, "shop A did not receive a did")
        XCTAssertFalse(didB.isEmpty, "shop B did not receive a did")
        // The did is a device-level identifier — the backend assigns one did per device, shared across
        // the shops on it (neither shop sends the other's did: prepareRequestParameters drops it under
        // needReInitialization). Per-shop isolation shows in the session: each shop's partition holds
        // its own client-owned seance, so the two seances differ.
        XCTAssertNotEqual(sidA, sidB, "each shop must keep its own session (seance)")
    }

    /// Initializes one shop and blocks until its `/init` completes, returning its live session.
    private func initAndWaitSession(_ shopId: String) -> (did: String, seance: String) {
        let ready = expectation(description: "\(shopId) /init")
        var err: SdkError?
        let sdk = Rees46.initialize(config(shopId)) { err = $0; ready.fulfill() }
        wait(for: [ready], timeout: Constants.defaultTimeout)
        XCTAssertNil(err, "\(shopId) init error: \(String(describing: err))")
        return (sdk.getDeviceId(), sdk.getSession())
    }
}
