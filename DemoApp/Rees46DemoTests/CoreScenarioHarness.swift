//
//  CoreScenarioHarness.swift
//  REES46Tests
//
//  A base for tests of whole scenarios over the stub server, on either core: the clock, the scheduler,
//  the network and the app's lifecycle in the test's hands, replies queued per path, and the log the
//  handler heard — read only once the handler got everything logged before (`SdkLogger.awaitDelivery`).
//

import XCTest
@_spi(Bridge) @testable import REES46

class CoreScenarioTestCase: XCTestCase {

    var shops: [String] = []
    var clock = FakeClock()
    var scheduler: ManualScheduler!
    var lifecycle = ManualAppLifecycle()
    var network = FakeConnectivity(online: true)
    /// Replies queued per path; the last one repeats. `.some(nil)` is no answer.
    let replies = Locked<[String: [StubReply?]]>([:])
    /// Requests of a path the stub holds until the test lets them go.
    let holds = Locked<[String: DispatchSemaphore]>([:])
    private let logs = Locked<[Rees46.SdkLogMessage]>([])
    /// How many `/init`s the default answer gave.
    let initCalls = Locked(0)
    /// The shops of this test: the replies and holds it sets are theirs. An SDK an earlier test left may
    /// still send to the stub server; it gets the default answer.
    let ownShops = Locked<Set<String>>([])

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        Rees46.reset()
        SdkRegistry.shared.reset()
        clock = FakeClock()
        scheduler = ManualScheduler(clock: clock)
        lifecycle = ManualAppLifecycle()
        network = FakeConnectivity(online: true)
        replies.current = [:]
        holds.current = [:]
        logs.current = []
        initCalls.current = 0
        ownShops.current = []
        let logs = self.logs
        Rees46.setLogHandler { message in logs.mutate { $0.append(message) } }
        let network = self.network
        let lifecycle = self.lifecycle
        let clock = self.clock
        PendingPushEvents.connectivity = { network }
        PendingPushEvents.lifecycle = { lifecycle }
        PendingPushEvents.clock = { clock }
        // No identity of the time before the partitions: what other tests or the host left there is not
        // this test's.
        let noLegacy = UserDefaults(suiteName: "test-no-legacy-identity") ?? .standard
        noLegacy.removePersistentDomain(forName: "test-no-legacy-identity")
        PendingPushEvents.legacyIdentity = { noLegacy }
        let replies = self.replies
        let holds = self.holds
        let inits = self.initCalls
        let ownShops = self.ownShops
        StubURLProtocol.handler = { request in
            let shop = request.query["shop_id"] ?? request.body["shop_id"] as? String
            guard shop.map({ ownShops.current.contains($0) }) ?? true else {
                return request.path == "/init" ? StubReply(json: #"{"did":"other-did","seance":"other"}"#) : StubReply(json: #"{"status":"success"}"#)
            }
            if let hold = holds.current[request.path] {
                _ = hold.wait(timeout: .now() + 20)
            }
            var reply: StubReply??
            replies.mutate { queued in
                guard var list = queued[request.path], !list.isEmpty else { return }
                reply = .some(list.count > 1 ? list.removeFirst() : list[0])
                queued[request.path] = list
            }
            if let reply = reply {
                return reply
            }
            if request.path == "/init" {
                var call = 0
                inits.mutate { $0 += 1; call = $0 }
                // The did it is sent stays; a device without one gets a new one.
                return StubReply(json: #"{"did":"\#(request.query["did"] ?? "d-\(call)")","seance":"s-\#(call)"}"#)
            }
            return StubReply(json: #"{"status":"success"}"#)
        }
    }

    override func tearDown() {
        holds.current.values.forEach { $0.signal() }
        holds.current = [:]
        Rees46.setLogHandler(nil)
        Rees46.reset()
        SdkRegistry.shared.reset()
        StubURLProtocol.uninstall()
        CoreFlag.reset()
        for shop in shops {
            StubSDK.removeSavedInit(shopId: shop)
            UserDefaults.standard.removePersistentDomain(forName: StoragePartition.suiteName(for: shop))
            UserDefaults.standard.removeObject(forKey: NotificationRegistrar.lastUploadDateKey(shopId: shop))
        }
        shops.removeAll()
        super.tearDown()
    }

    // MARK: - Seams

    var environment: CoreEnvironment {
        CoreEnvironment(clock: clock, scheduler: scheduler, lifecycle: lifecycle, random: { 0.5 })
    }

    func newShop() -> String {
        let shop = StubSDK.shopId()
        shops.append(shop)
        ownShops.mutate { _ = $0.insert(shop) }
        return shop
    }

    /// Queues `list` as the answers of `path`; the last one repeats.
    func answer(_ path: String, _ list: StubReply?...) {
        replies.mutate { $0[path] = list }
    }

    /// Holds every request to `path` until `release(path)`.
    func hold(_ path: String) {
        holds.mutate { $0[path] = DispatchSemaphore(value: 0) }
    }

    /// Lets the held requests to `path` go, and the next ones too.
    func release(_ path: String) {
        var gate: DispatchSemaphore?
        holds.mutate { gate = $0.removeValue(forKey: path) }
        // Generous: every request waiting on it goes.
        for _ in 0..<64 { gate?.signal() }
    }

    // MARK: - Instances

    /// An identity with a known device inside its session's window.
    func knownIdentity(did: String = "d", sid: String = "s-0") -> InMemoryUserIdentityRepository {
        let identity = InMemoryUserIdentityRepository()
        identity.deviceId = did
        identity.seance = sid
        identity.seanceLastActTime = clock.now()
        return identity
    }

    /// An instance of the new core, registered, its launch's `/init` answered and heard, its queue
    /// settled; a known device inside its window unless `identity` says otherwise.
    func makeV2(
        _ shop: String,
        identity: UserIdentityRepository? = nil,
        deviceStore: DeviceStore? = nil,
        shopStorage: ShopStorage? = nil,
        settled: Bool = true,
        register: Bool = true
    ) -> SimplePersonalizationSDK {
        let chosen = identity ?? knownIdentity()
        let sdk = StubSDK.make(
            shopId: shop, identity: chosen, logLevel: .debug, connectivity: network,
            coreV2: true, environment: environment, shopStorage: shopStorage, deviceStore: deviceStore
        )
        if register {
            SdkRegistry.shared.register(shopId: shop, sdk: sdk)
        }
        if settled {
            let settles = (chosen.deviceId ?? "").isEmpty ? 1 : 2
            XCTAssertTrue(eventually { sdk.settledInitCount >= settles }, "the launch's /init answered")
            sdk.eventQueue?.settle()
        }
        return sdk
    }

    /// An instance of the old core over the stub server, registered, its `/init` answered.
    func makeLegacy(
        _ shop: String,
        identity: UserIdentityRepository = InMemoryUserIdentityRepository(),
        keychain: KeychainInitStore = InMemoryKeychainInitStore(),
        connectivity: ConnectivityMonitor? = nil,
        settled: Bool = true,
        completion: ((SdkError?) -> Void)? = nil
    ) -> SimplePersonalizationSDK {
        let done = settled ? expectation(description: "legacy init of \(shop)") : nil
        let sdk = StubSDK.make(
            shopId: shop, identity: identity, keychain: keychain, logLevel: .debug,
            connectivity: connectivity ?? network, coreV2: false
        ) { error in
            completion?(error)
            done?.fulfill()
        }
        SdkRegistry.shared.register(shopId: shop, sdk: sdk)
        XCTAssertEqual(sdk.core.kind, .legacy)
        if let done = done {
            wait(for: [done], timeout: 10)
        }
        return sdk
    }

    /// Whether two instances are the same object.
    func same(_ lhs: PersonalizationSDK?, _ rhs: PersonalizationSDK?) -> Bool {
        (lhs as AnyObject?) === (rhs as AnyObject?)
    }

    // MARK: - What the stub saw

    func requests(_ path: String, _ shop: String) -> [StubRequest] {
        StubURLProtocol.requests(to: path, shop: shop)
    }

    func inits(_ shop: String) -> [StubRequest] {
        requests("/init", shop)
    }

    func itemIds(_ requests: [StubRequest]) -> [String] {
        requests.compactMap { (($0.body["items"] as? [[String: Any]])?.first?["id"]) as? String }
    }

    func files(_ storage: ShopStorage) -> [String] {
        guard let folder = storage.queueDirectory,
              let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        return names.filter { $0.hasSuffix(".json") }.sorted()
    }

    /// Whether the queue sent all it can: nothing waits and nothing is on its way — once it holds, no
    /// request of an event can come any more.
    func queueIdle(_ sdk: SimplePersonalizationSDK) -> Bool {
        eventually { sdk.eventQueue.map { $0.inFlightCount == 0 && $0.waiting.isEmpty } ?? true }
    }

    // MARK: - The log

    /// What the log handler heard: every message logged before the call — the handler hears them on a
    /// queue of its own, after what the SDK did next.
    var heard: [Rees46.SdkLogMessage] {
        SdkLogger.awaitDelivery()
        return logs.current
    }

    func logged(_ shop: String?, _ code: String) -> [Rees46.SdkLogMessage] {
        heard.filter { $0.shopId == shop && $0.code == code }
    }

    /// Waits until the handler heard `code` for `shop` with `reason`, when one is given.
    @discardableResult
    func waitForLog(_ shop: String?, _ code: String, reason: String? = nil, timeout: TimeInterval = 5) -> Bool {
        eventually(timeout: timeout) {
            self.logged(shop, code).contains { reason == nil || $0.context["reason"] == reason }
        }
    }

    // MARK: - Pushes

    func pushPayload(_ shop: String?, type: String = "bulk", code: String = "m-1") -> [AnyHashable: Any] {
        var payload: [AnyHashable: Any] = [
            "type": type, "id": code, "title": "Sale", "body": "Today only",
            "event": #"{"type":"product","uri":"37"}"#,
        ]
        if let shop = shop {
            payload["shop_id"] = shop
        }
        return payload
    }

    /// A shop registered and not created, as the app registers it, with `did` stored when one is given.
    func registerPending(did: String?, coreV2: Bool = true, deviceId: String? = nil, storageKey: String? = nil) -> (shop: String, storage: ShopStorage) {
        CoreFlag.reset(to: coreV2)
        let shop = newShop()
        if let did = did {
            StoragePartition.store(for: shop, storageKey: storageKey).set(did, forKey: StoragePartition.deviceIdKey)
        }
        Rees46.register(shops: [Rees46Config(
            shopId: shop, apiDomain: "stub.test", deviceId: deviceId, autoSendPushToken: false, storageKey: storageKey, coreV2: coreV2
        )])
        let logger = SdkLogger(shopId: shop, level: .none)
        return (shop, ShopStorage(shopId: shop, storageKey: storageKey, logger: logger))
    }

    // MARK: - Calls

    /// `getProductInfo` and what it got.
    func getProduct(_ sdk: PersonalizationSDK, timeout: TimeInterval = 5) -> Result<ProductInfo, SdkError>? {
        let done = expectation(description: "products/get")
        let outcome = Locked<Result<ProductInfo, SdkError>?>(nil)
        sdk.getProductInfo(id: "item-1") { outcome.current = $0; done.fulfill() }
        wait(for: [done], timeout: timeout)
        return outcome.current
    }

    /// `flush` and what it heard.
    func flush(_ sdk: PersonalizationSDK, timeout: TimeInterval = 5) -> Rees46.SdkError?? {
        let done = expectation(description: "flush")
        let outcome = Locked<Rees46.SdkError??>(nil)
        sdk.flush { outcome.current = .some($0); done.fulfill() }
        wait(for: [done], timeout: timeout)
        return outcome.current
    }
}
