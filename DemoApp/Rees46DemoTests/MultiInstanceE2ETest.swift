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
//  order-independent. Only `test_two_shops_have_isolated_sessions` needs the live backend (it waits on
//  `/init` for the did); every other test here is deterministic without the network. The lifecycle
//  tests (lazy materialization, eagerInit, awaitInstance-on-pending) and the offline session-isolation
//  test build real SDKs but never await `/init` — they assert only the synchronous registry/session
//  state the facade establishes at construction, so they hold even with no backend.
//

import XCTest
@testable import REES46

final class MultiInstanceE2ETest: XCTestCase {

    private let shopA = Constants.testShopId
    private let shopB = Constants.testShopIdB
    private let apiDomain = Constants.testApiDomain

    /// The registry holds instances weakly, so real SDKs built by these tests are retained here for the
    /// test's duration (an in-flight `/init` also retains them, but this keeps assertions robust).
    private var retained: [PersonalizationSDK] = []

    override func setUp() {
        super.setUp()
        Rees46.reset()
        SdkRegistry.shared.reset()
    }

    override func tearDown() {
        Rees46.reset()
        SdkRegistry.shared.reset()
        retained.removeAll()
        super.tearDown()
    }

    @discardableResult
    private func retain(_ sdk: PersonalizationSDK) -> PersonalizationSDK {
        retained.append(sdk)
        return sdk
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

    // MARK: - Lifecycle: lazy materialization / eagerInit / awaitInstance (no backend)

    /// The core lazy-multi-instance promise: `register(shops:)` only records the config; the SDK is not
    /// built until the first `instance(for:)`, which materializes it and clears the pending entry.
    func test_a_lazily_registered_shop_materializes_on_first_use() throws {
        Rees46.register(shops: [config(shopA)])

        XCTAssertEqual(Rees46.pendingShopIds(), [shopA], "register(shops:) leaves the shop pending")
        XCTAssertFalse(Rees46.isInitialized(shopId: shopA), "a pending shop is not initialized")
        XCTAssertTrue(SdkRegistry.shared.shopIds().isEmpty, "nothing is built until first use")

        let sdk = retain(try Rees46.instance(for: shopA))

        XCTAssertEqual(sdk.getShopId(), shopA, "first use builds the SDK for the pending shop")
        XCTAssertTrue(Rees46.pendingShopIds().isEmpty, "materialization consumes the pending entry")
        XCTAssertTrue(Rees46.isInitialized(shopId: shopA), "the shop is live after first use")
        XCTAssertTrue(SdkRegistry.shared.shopIds().contains(shopA))
    }

    /// A pending shop must materialize exactly once — the second resolution returns the same instance,
    /// never a rebuild (guards the atomic claim in `Rees46.materialize`).
    func test_materialization_is_idempotent_and_returns_the_same_instance() throws {
        Rees46.register(shops: [config(shopA)])

        let first = retain(try Rees46.instance(for: shopA))
        let second = try Rees46.instance(for: shopA)

        XCTAssertTrue(same(first, second), "a pending shop must materialize once, not rebuild")
    }

    /// `eagerInit: true` is the super-shop case — every shop is built up front, none left pending.
    func test_eagerInit_initializes_every_shop_up_front() throws {
        Rees46.register(shops: [config(shopA), config(shopB)], eagerInit: true)

        XCTAssertTrue(Rees46.pendingShopIds().isEmpty, "eagerInit leaves nothing pending")
        XCTAssertEqual(SdkRegistry.shared.shopIds(), [shopA, shopB], "both shops are live immediately")
        XCTAssertTrue(Rees46.isInitialized(shopId: shopA))
        XCTAssertTrue(Rees46.isInitialized(shopId: shopB))
        XCTAssertEqual(retain(try Rees46.instance(for: shopA)).getShopId(), shopA)
        XCTAssertEqual(retain(try Rees46.instance(for: shopB)).getShopId(), shopB)
    }

    /// `awaitInstance` on a pending shop builds it on the spot and delivers it, consuming the pending
    /// entry — the reactive path a UI element uses to resolve its SDK without the host wiring it in.
    func test_awaitInstance_materializes_a_pending_shop_on_the_spot() {
        Rees46.register(shops: [config(shopA)])

        var delivered: PersonalizationSDK?
        let handle = Rees46.awaitInstance(for: shopA) { delivered = self.retain($0) }

        XCTAssertEqual(delivered?.getShopId(), shopA, "awaitInstance builds the pending shop and delivers it")
        XCTAssertTrue(Rees46.pendingShopIds().isEmpty, "the pending entry is consumed")
        XCTAssertTrue(Rees46.isInitialized(shopId: shopA))
        handle.cancel()
    }

    // MARK: - Session isolation without the backend

    /// The seance is client-owned and assigned synchronously at construction from each shop's own
    /// storage partition (the `/init` response deliberately does not adopt it — see SimplePersonalizationSDK),
    /// so per-shop isolation is observable immediately, with no network. This is the deterministic
    /// sibling of `test_two_shops_have_isolated_sessions`, which waits on `/init` only for the did.
    func test_two_shops_keep_isolated_sessions_without_the_backend() {
        let a = retain(Rees46.initialize(config(shopA)))
        let b = retain(Rees46.initialize(config(shopB)))

        XCTAssertNotEqual(a.getShopId(), b.getShopId(), "each shop keeps its own id")
        XCTAssertFalse(a.getSession().isEmpty, "each shop is given a seance at construction")
        XCTAssertFalse(b.getSession().isEmpty)
        XCTAssertNotEqual(a.getSession(), b.getSession(), "each shop keeps its own seance — no cross-shop leak")
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
