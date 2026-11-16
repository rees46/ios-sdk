//
//  CoreLiveE2ETest.swift
//  REES46Tests
//
//  Live end-to-end check of the SDK's cores against the real API and the demo shop. Mirror of the
//  Android `CoreLiveE2ETest`.
//
//  A process has one core, decided by its first initialization, and the demo app initializes the demo
//  shop itself at launch; so these tests run only in a process the app left alone (`CLEAN_PROCESS=true`,
//  see `AppDelegate`), one core per run, each selected by its own variable. The shop comes from
//  `TEST_SHOP_ID`. Without them every test here is skipped. xcodebuild hands a variable to the test
//  process with the prefix `TEST_RUNNER_`.
//
//  A fresh install is a new `storageKey`, no keychain backup of the shop and no cookies of the API: the
//  server answers an `/init` without a did by the `did` cookie it set before (see `freshInstall`).
//
//  `test_roundTrip`, with `CORE_V2=true` or `CORE_V2=false`: a fresh install initializes the demo shop,
//  runs a live instant search, tracks a product view, an add to cart, a purchase and a custom event, and
//  checks that every request got a `2xx`:
//  ```
//  TEST_RUNNER_CLEAN_PROCESS=true TEST_RUNNER_CORE_V2=true TEST_RUNNER_TEST_SHOP_ID=<shop> \
//    xcodebuild test -workspace DemoApp/REES46.xcworkspace -scheme REES46Demo \
//    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:REES46Tests/CoreLiveE2ETest
//  ```
//
//  The new core's queue across a restart without a network, in two runs (the end of a run ends the
//  process). The simulator shares the Mac's network, so the network the SDK sees is the test's
//  (`FakeConnectivity`), and a `URLProtocol` of the test fails whatever would reach the wire while it is
//  off; once it is on, the requests go to the real server:
//  - `OFFLINE_STEP=1` (`test_offlineRestart1_queueWithoutNetwork`): initializes online, turns the network
//    off, tracks a purchase and a custom event, and checks they wait on disk;
//  - `OFFLINE_STEP=2` (`test_offlineRestart2_deliverAfterRestart`): a new process initializes offline on
//    the stored `did`, turns the network on, and checks that the queue goes in order without a flush.
//
//  Every purchase is a real order of the demo shop, named `sdk-core-e2e-ios-<core>-<time>`. The `did`
//  and the order id are printed under the tag `[SdkCoreE2E]` (`RESULT` lines), for a check on the
//  server. The shop id is never printed.
//

import XCTest
@testable import REES46

final class CoreLiveE2ETest: XCTestCase {

    private let recorder = Recorder()
    private var stateSubscription: Cancellable?

    override func tearDown() {
        stateSubscription?.cancel()
        stateSubscription = nil
        Rees46.setLogHandler(nil)
        WireTap.setOffline(false)
        super.tearDown()
    }

    // MARK: - Round trip

    func test_roundTrip() throws {
        guard let coreV2 = Self.environment(Self.coreV2Key).flatMap(Bool.init) else {
            throw XCTSkip("needs CORE_V2=true or CORE_V2=false")
        }
        let shopId = try requireCleanProcess()
        let core = coreV2 ? "v2" : "legacy"
        let storageKey = "sdk_core_e2e_\(core)_\(Self.millis())"
        let previousDid = freshInstall(shopId)

        Rees46.setLogHandler(recorder.record)
        let sdk = Rees46.initialize(config(shopId, coreV2: coreV2, storageKey: storageKey))
        observeStates(sdk)
        XCTAssertEqual(awaitState(sdk, .ready, timeout: Self.readyTimeout), .ready, "first state")
        if let previousDid = previousDid {
            XCTAssertNotEqual(sdk.deviceId, previousDid, "a fresh install gets a new did")
        }

        let (itemId, price) = try searchItem(sdk)

        let orderId = "sdk-core-e2e-ios-\(core)-\(Self.millis())"
        let view = Completion("productView")
        let cart = Completion("addToCart")
        let purchase = Completion("purchase")
        let custom = Completion("custom")
        sdk.tracking.productView(itemId: itemId, completion: view.done)
        sdk.tracking.addToCart(item: TrackingItem(id: itemId, quantity: 1, price: price), completion: cart.done)
        sdk.tracking.purchase(purchaseOf(orderId, itemId: itemId, price: price), completion: purchase.done)
        sdk.tracking.custom(
            event: Self.customEvent,
            category: Self.customCategory,
            label: core,
            value: 1,
            completion: custom.done
        )
        // Before any check can fail: the order is on its way and the server can be asked for it.
        Self.say("TRACKED core=\(core) did=\(sdk.deviceId) order=\(orderId) item=\(itemId)")

        // The new core sends its queue now; the legacy one has none and answers at once.
        let flushed = flush(sdk)
        XCTAssertTrue(flushed.answered, "flush: no answer")
        XCTAssertNil(flushed.error, "flush failed")

        for completion in [view, cart, purchase, custom] {
            XCTAssertTrue(completion.await(Self.listenerTimeout), "\(completion.name): no answer within \(Int(Self.listenerTimeout)) s")
            XCTAssertNil(completion.failure, "\(completion.name) failed")
        }

        let did = sdk.deviceId
        XCTAssertFalse(did.isEmpty, "deviceId after READY")
        XCTAssertNotNil(sdk.sessionId, "sessionId after READY")
        // The log handler runs on a queue of its own: the last answers may reach it after the completions.
        awaitCondition(Self.logSettle) {
            let sent = self.recorder.requests().filter { $0.method == "POST" }
            return sent.filter { $0.path == "push" }.count >= 3 && sent.contains { $0.path == "push/custom" }
        }
        let requests = recorder.requests()
        requests.forEach { Self.say("request core=\(core) \($0.method) \($0.path) \($0.status.map(String.init) ?? "-")") }
        let failures = recorder.failures()
        failures.forEach { Self.say("failure core=\(core) \($0.code) \($0.context)") }
        XCTAssertTrue(failures.isEmpty, "failures in the log: \(failures.map { "\($0.code) \($0.context)" })")
        let not2xx = requests.filter { !$0.succeeded }
        XCTAssertTrue(not2xx.isEmpty, "requests without a 2xx: \(not2xx)")
        // Both cores log each answer by method and path.
        assertSent(requests, "GET", "init", atLeast: 1)
        assertSent(requests, "GET", "search", atLeast: 1)
        assertSent(requests, "POST", "push", exactly: 3)
        assertSent(requests, "POST", "push/custom", exactly: 1)
        if coreV2 {
            XCTAssertEqual(queuedEvents(shopId, storageKey: storageKey), 0, "queued events left")
        }
        Self.say("RESULT core=\(core) did=\(did) order=\(orderId) item=\(itemId) states=\(recorder.statesLine) requests=\(requests.count)")
    }

    // MARK: - Offline across a restart (CoreV2)

    func test_offlineRestart1_queueWithoutNetwork() throws {
        guard Self.environment(Self.offlineStepKey) == "1" else { throw XCTSkip("needs OFFLINE_STEP=1") }
        let shopId = try requireCleanProcess()
        let storageKey = "sdk_core_e2e_offline_\(Self.millis())"
        let previousDid = freshInstall(shopId)

        let network = FakeConnectivity(online: true)
        Rees46.setLogHandler(recorder.record)
        let sdk = makeSDK(shopId, storageKey: storageKey, connectivity: network)
        XCTAssertEqual(awaitState(sdk, .ready, timeout: Self.readyTimeout), .ready, "first state")
        let (itemId, price) = try searchItem(sdk)
        let did = sdk.deviceId
        XCTAssertFalse(did.isEmpty, "deviceId after READY")
        if let previousDid = previousDid {
            XCTAssertNotEqual(did, previousDid, "a fresh install gets a new did")
        }

        setNetwork(network, online: false)
        let mark = recorder.count
        let orderId = "sdk-core-e2e-ios-v2-offline-\(Self.millis())"
        let purchase = Completion("purchase")
        let custom = Completion("custom")
        sdk.tracking.purchase(purchaseOf(orderId, itemId: itemId, price: price), completion: purchase.done)
        sdk.tracking.custom(
            event: Self.customEvent,
            category: Self.customCategory,
            label: "v2-offline",
            value: 1,
            completion: custom.done
        )
        // Saved before any check can fail: the next process needs the partition, the server the order.
        UserDefaults.standard.set(
            ["storageKey": storageKey, "did": did, "order": orderId, "item": itemId],
            forKey: Self.offlineRunKey
        )
        Self.say("TRACKED step=offline1 core=v2 did=\(did) order=\(orderId) item=\(itemId)")

        XCTAssertTrue(awaitCondition(10) { self.queuedEvents(shopId, storageKey: storageKey) == 2 }, "both events written to the queue")
        // Tried at once and held by the missing network.
        let flushed = flush(sdk)
        XCTAssertTrue(flushed.answered, "flush: no answer")
        XCTAssertNil(flushed.error, "flush failed")
        spin(3)
        let sentWhileOffline = recorder.requests(from: mark).filter { $0.path.hasPrefix("push") }
        XCTAssertTrue(sentWhileOffline.isEmpty, "events sent without a network: \(sentWhileOffline)")
        XCTAssertTrue(WireTap.seenWhileOffline.isEmpty, "requests on the wire without a network: \(WireTap.seenWhileOffline)")
        XCTAssertEqual(queuedEvents(shopId, storageKey: storageKey), 2, "queued events")
        XCTAssertTrue(purchase.pending, "the purchase's completion is kept until the event goes")
        XCTAssertTrue(custom.pending, "the custom event's completion is kept until the event goes")
        // The network stays off: the end of this run ends the process with the queue on disk.
        Self.say("RESULT step=offline1 core=v2 did=\(did) order=\(orderId) item=\(itemId) queued=\(queuedEvents(shopId, storageKey: storageKey))")
    }

    func test_offlineRestart2_deliverAfterRestart() throws {
        guard Self.environment(Self.offlineStepKey) == "2" else { throw XCTSkip("needs OFFLINE_STEP=2") }
        let shopId = try requireCleanProcess()
        let saved = try XCTUnwrap(UserDefaults.standard.dictionary(forKey: Self.offlineRunKey) as? [String: String], "step 1 ran")
        let storageKey = try XCTUnwrap(saved["storageKey"])
        let storedDid = try XCTUnwrap(saved["did"])
        XCTAssertEqual(queuedEvents(shopId, storageKey: storageKey), 2, "events left on disk by step 1")

        let network = FakeConnectivity(online: false)
        WireTap.setOffline(true)
        Rees46.setLogHandler(recorder.record)
        let sdk = makeSDK(shopId, storageKey: storageKey, connectivity: network)
        // A stored did is READY at once; its /init waits for the network.
        XCTAssertEqual(awaitState(sdk, .ready, timeout: Self.readyTimeout), .ready, "READY on the stored did")
        XCTAssertEqual(sdk.deviceId, storedDid, "did kept across the restart")

        spin(5)
        let sentWhileOffline = recorder.requests().filter { $0.path.hasPrefix("push") }
        XCTAssertTrue(sentWhileOffline.isEmpty, "events sent without a network: \(sentWhileOffline)")
        XCTAssertTrue(WireTap.seenWhileOffline.isEmpty, "requests on the wire without a network: \(WireTap.seenWhileOffline)")
        XCTAssertEqual(queuedEvents(shopId, storageKey: storageKey), 2, "queued events while offline")

        setNetwork(network, online: true)
        let online = Date()
        // No flush: the network's return is the queue's trigger.
        let delivered = awaitCondition(Self.deliveryTimeout) {
            let sent = self.recorder.requests().filter { $0.method == "POST" }
            return sent.contains { $0.path == "push" && $0.succeeded } && sent.contains { $0.path == "push/custom" && $0.succeeded }
        }
        let afterMs = Int(Date().timeIntervalSince(online) * 1000)
        let requests = recorder.requests()
        requests.forEach { Self.say("request step=offline2 \($0.method) \($0.path) \($0.status.map(String.init) ?? "-")") }
        recorder.failures().forEach { Self.say("failure step=offline2 \($0.code) \($0.context)") }
        XCTAssertTrue(delivered, "queue not delivered within \(Int(Self.deliveryTimeout)) s of the network's return")
        XCTAssertTrue(awaitCondition(10) { self.queuedEvents(shopId, storageKey: storageKey) == 0 }, "queue files removed")
        let pushes = requests.filter { $0.method == "POST" && $0.path.hasPrefix("push") }
        XCTAssertTrue(pushes.allSatisfy { $0.succeeded }, "pushes without a 2xx: \(pushes)")
        XCTAssertEqual(pushes.map(\.path), ["push", "push/custom"], "each queued event sent once, in the order it was tracked")
        Self.say("RESULT step=offline2 core=v2 did=\(sdk.deviceId) order=\(saved["order"] ?? "-") deliveredAfterMs=\(afterMs) states=\(recorder.statesLine) requests=\(requests.count)")
    }

    // MARK: - SDK

    /// The shop of `TEST_SHOP_ID`, in a process whose core nothing has decided yet.
    private func requireCleanProcess() throws -> String {
        guard Self.environment(Self.cleanProcessKey) == "true" else {
            throw XCTSkip("needs CLEAN_PROCESS=true: the demo app initializes its shop otherwise")
        }
        guard let shopId = Self.environment(Constants.testShopIdKey), !shopId.isEmpty else {
            throw XCTSkip("needs TEST_SHOP_ID")
        }
        XCTAssertNil(CoreFlag.current, "the process's core is already decided: the demo app initialized the SDK")
        return shopId
    }

    private func config(_ shopId: String, coreV2: Bool, storageKey: String) -> Rees46Config {
        Rees46Config(
            shopId: shopId,
            apiDomain: Self.apiDomain,
            logLevel: .debug,
            // No token of the simulator for the demo shop, and no permission prompt: the test is about the core.
            autoSendPushToken: false,
            enableAutoPopupPresentation: false,
            storageKey: storageKey,
            coreV2: coreV2
        )
    }

    /// The new core with the test's network: what `Rees46.initialize` makes, with a seam for the network.
    /// Its sessions go through `WireTap`, which fails whatever reaches the wire while the network is off.
    private func makeSDK(_ shopId: String, storageKey: String, connectivity: FakeConnectivity) -> SimplePersonalizationSDK {
        let config = config(shopId, coreV2: true, storageKey: storageKey)
        let sdk = SimplePersonalizationSDK(
            shopId: config.shopId,
            apiDomain: config.apiDomain,
            stream: config.stream,
            logLevel: config.logLevel,
            autoSendPushToken: config.autoSendPushToken,
            enableAutoPopupPresentation: config.enableAutoPopupPresentation,
            storageKey: config.storageKey,
            coreV2: true,
            connectivity: connectivity
        )
        sdk.resetSdkCache()
        sdk.configureURLSession(configuration: WireTap.configuration())
        observeStates(sdk)
        return sdk
    }

    private func observeStates(_ sdk: PersonalizationSDK) {
        stateSubscription = sdk.onStateChange { [recorder] state in recorder.addState(state) }
    }

    private func awaitState(_ sdk: PersonalizationSDK, _ wanted: Rees46.SdkState, timeout: TimeInterval) -> Rees46.SdkState {
        awaitCondition(timeout) { sdk.state == wanted }
        return sdk.state
    }

    /// The first product of a live instant search: its id and price.
    private func searchItem(_ sdk: PersonalizationSDK) throws -> (String, Double) {
        let done = expectation(description: "search")
        var result: Result<SearchResponse, SdkError>?
        sdk.suggest(query: Self.searchQuery) { answer in
            result = answer
            done.fulfill()
        }
        wait(for: [done], timeout: Self.listenerTimeout)
        switch try XCTUnwrap(result, "search: no answer") {
        case .success(let response):
            let product = try XCTUnwrap(response.products.first, "search found no product")
            XCTAssertFalse(product.id.isEmpty, "search: a product without an id")
            return (product.id, product.price)
        case .failure(let error):
            XCTFail("search failed: \(error)")
            throw error
        }
    }

    private func purchaseOf(_ orderId: String, itemId: String, price: Double) -> PurchaseTrackingRequest {
        PurchaseTrackingRequest(
            orderId: orderId,
            orderPrice: price,
            items: [PurchaseItemRequest(id: itemId, amount: 1, price: price)],
            deliveryType: Self.deliveryType,
            paymentType: Self.paymentType,
            isTaxFree: true
        )
    }

    private func flush(_ sdk: PersonalizationSDK) -> (answered: Bool, error: Rees46.SdkError?) {
        let done = expectation(description: "flush")
        var error: Rees46.SdkError?
        sdk.flush { answer in
            error = answer
            done.fulfill()
        }
        let answered = XCTWaiter().wait(for: [done], timeout: Self.listenerTimeout) == .completed
        return (answered, error)
    }

    private func assertSent(_ requests: [Request], _ method: String, _ path: String, exactly: Int? = nil, atLeast: Int = 0,
                            file: StaticString = #filePath, line: UInt = #line) {
        let sent = requests.filter { $0.method == method && $0.path == path && $0.succeeded }.count
        if let exactly = exactly {
            XCTAssertEqual(sent, exactly, "\(method) \(path) answered 2xx", file: file, line: line)
        }
        XCTAssertGreaterThanOrEqual(sent, atLeast, "\(method) \(path) answered 2xx \(sent) times, expected at least \(atLeast)", file: file, line: line)
    }

    // MARK: - Device

    /// A fresh install, with a new `storageKey` for a new partition: no keychain backup of the shop — the
    /// keychain outlives the app, and the SDK would take the did of an earlier run from it — and no
    /// cookies of the API. Every `/init` answer sets a `did` cookie on the API's domain, and an `/init`
    /// without a did but with that cookie is answered with the cookie's did; a new install has no cookies.
    /// Returns the did the cookie held, if any.
    @discardableResult
    private func freshInstall(_ shopId: String) -> String? {
        for service in [KeychainPartition.service] + KeychainPartition.previousServices {
            try? InitService.deleteKeychainDidToken(identifier: KeychainPartition.account(shopId: shopId, service: service), instanceKeychainService: service)
            try? InitService.deleteKeychainDidToken(identifier: KeychainPartition.legacyAccount(service: service), instanceKeychainService: service)
        }
        let storage = HTTPCookieStorage.shared
        let cookies = URL(string: "https://\(Self.apiDomain)/").flatMap { storage.cookies(for: $0) } ?? []
        cookies.forEach { storage.deleteCookie($0) }
        return cookies.first { $0.name == "did" }?.value
    }

    /// Events in the shop's queue on disk: one JSON file each.
    private func queuedEvents(_ shopId: String, storageKey: String) -> Int {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return -1 }
        let folder = support
            .appendingPathComponent(ShopStorage.folderName, isDirectory: true)
            .appendingPathComponent(StoragePartition.folderName(for: shopId, storageKey: storageKey), isDirectory: true)
            .appendingPathComponent(ShopStorage.queueFolderName, isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { $0.hasSuffix(".json") }.count
    }

    private func setNetwork(_ network: FakeConnectivity, online: Bool) {
        // The wire first when it goes off, last when it comes back: nothing slips through in between.
        if !online { WireTap.setOffline(true) }
        network.isOnline = online
        if online { WireTap.setOffline(false) }
        Self.say("network \(online ? "on" : "off")")
    }

    /// Waits on the main run loop, so the SDK's main-thread callbacks run meanwhile.
    @discardableResult
    private func awaitCondition(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            spin(Self.poll)
        }
        return condition()
    }

    private func spin(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private static func environment(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key]
    }

    private static func millis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    private static func say(_ line: String) {
        print("[\(tag)] \(line)")
    }

    // MARK: - Doubles

    /// A request's answer as the SDK logged it.
    private struct Request: CustomStringConvertible {
        let method: String
        let path: String
        let status: Int?
        var succeeded: Bool { status.map { (200..<300).contains($0) } ?? false }
        var description: String { "\(method) \(path) \(status.map(String.init) ?? "-")" }
    }

    /// The SDK's log, by code and context; it carries no personal data.
    private final class Recorder {
        private let lock = NSLock()
        private var messages: [Rees46.SdkLogMessage] = []
        private var states: [Rees46.SdkState] = []

        func record(_ message: Rees46.SdkLogMessage) {
            lock.lock()
            messages.append(message)
            lock.unlock()
            CoreLiveE2ETest.say("log \(message.level) \(message.code) \(message.context.sorted { $0.key < $1.key })")
        }

        func addState(_ state: Rees46.SdkState) {
            lock.lock(); defer { lock.unlock() }
            states.append(state)
        }

        var count: Int {
            lock.lock(); defer { lock.unlock() }
            return messages.count
        }

        var statesLine: String {
            lock.lock(); defer { lock.unlock() }
            return "[" + states.map { "\($0)" }.joined(separator: ",") + "]"
        }

        func requests(from start: Int = 0) -> [Request] {
            lock.lock(); defer { lock.unlock() }
            return messages.dropFirst(start).filter { $0.code == CoreLiveE2ETest.requestCode || $0.code == "request_failed" }.map {
                Request(method: $0.context["method"] ?? "", path: $0.context["path"] ?? "", status: $0.context["status"].flatMap { Int($0) })
            }
        }

        func failures() -> [Rees46.SdkLogMessage] {
            lock.lock(); defer { lock.unlock() }
            return messages.filter { CoreLiveE2ETest.failureCodes.contains($0.code) }
        }
    }

    /// A tracking completion: one answer, success or error.
    private final class Completion {
        let name: String
        private let lock = NSLock()
        private var answered = false
        private var error: SdkError?

        init(_ name: String) { self.name = name }

        var done: (Result<Void, SdkError>) -> Void {
            { [self] result in
                lock.lock()
                answered = true
                if case .failure(let failure) = result { error = failure }
                lock.unlock()
            }
        }

        var failure: SdkError? {
            lock.lock(); defer { lock.unlock() }
            return error
        }

        var pending: Bool {
            lock.lock(); defer { lock.unlock() }
            return !answered
        }

        /// Waits on the main run loop: the completions come on the main thread.
        func await(_ timeout: TimeInterval) -> Bool {
            let deadline = Date().addingTimeInterval(timeout)
            while pending && Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(CoreLiveE2ETest.poll))
            }
            return !pending
        }
    }

    /// The wire under the SDK's sessions: while the network is off it takes every request and fails it
    /// as `notConnectedToInternet`, recording its path; while it is on it takes none, and the request
    /// goes to the server.
    final class WireTap: URLProtocol {
        private static let lock = NSLock()
        private static var offline = false
        private static var seen: [String] = []

        static func setOffline(_ value: Bool) {
            lock.lock(); offline = value; lock.unlock()
        }

        static var seenWhileOffline: [String] {
            lock.lock(); defer { lock.unlock() }
            return seen
        }

        static func configuration() -> URLSessionConfiguration {
            let configuration = URLSessionConfiguration.default
            configuration.protocolClasses = [WireTap.self] + (configuration.protocolClasses ?? [])
            return configuration
        }

        override class func canInit(with request: URLRequest) -> Bool {
            lock.lock(); defer { lock.unlock() }
            guard offline else { return false }
            seen.append(request.url?.path ?? "")
            return true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        }

        override func stopLoading() {}
    }

    // MARK: - Constants

    private static let tag = "SdkCoreE2E"

    private static let cleanProcessKey = "CLEAN_PROCESS"
    private static let coreV2Key = "CORE_V2"
    private static let offlineStepKey = "OFFLINE_STEP"
    /// Where step 1 leaves its partition, did and order for step 2, in the app's own defaults.
    private static let offlineRunKey = "sdk_core_e2e.offline_run"

    private static let apiDomain = "api.rees46.ru"
    private static let searchQuery = "a"
    // An event registered for the demo shop: an unknown one is answered 400 "Event not found".
    private static let customEvent = "flutter_example"
    private static let customCategory = "sdk_core_e2e"
    private static let deliveryType = "courier"
    private static let paymentType = "card"

    fileprivate static let requestCode = "request"
    fileprivate static let failureCodes: Set<String> = [
        "request_failed", "request_cancelled", "decoding_failed", "queue_dropped",
        "init_failed", "init_refused", "init_retry", "callback_failed",
    ]

    private static let readyTimeout: TimeInterval = 30
    fileprivate static let listenerTimeout: TimeInterval = 60
    private static let deliveryTimeout: TimeInterval = 150
    private static let logSettle: TimeInterval = 5
    fileprivate static let poll: TimeInterval = 0.2
}
