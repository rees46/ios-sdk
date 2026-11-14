//
//  StubServer.swift
//  REES46Tests
//
//  Answers the SDK's requests inside the test process, so a real `SimplePersonalizationSDK` can be
//  driven end to end offline: its `/init`, its session queue, its sessions and timeouts.
//

import Foundation
import ObjectiveC
import XCTest
@testable import REES46

/// What the stub server does with one request.
struct StubReply {
    let status: Int
    let body: Data
    /// Response headers, `Retry-After` say.
    let headers: [String: String]
    /// Sends only the first `cutAfter` bytes of the body, then fails with `cutWith`: a dropped
    /// connection by default, `.timedOut` for a body cut by the read timeout.
    let cutAfter: Int?
    let cutWith: URLError.Code
    /// Holds the answer back this many seconds; one held past the request's timeout fails as timed out.
    let delay: TimeInterval

    init(
        _ status: Int = 200,
        json: String = "{}",
        headers: [String: String] = [:],
        cutAfter: Int? = nil,
        cutWith: URLError.Code = .networkConnectionLost,
        delay: TimeInterval = 0
    ) {
        self.status = status
        self.body = Data(json.utf8)
        self.headers = headers
        self.cutAfter = cutAfter
        self.cutWith = cutWith
        self.delay = delay
    }

    /// No answer: the connection is never made — a connect that timed out. The new client calls it
    /// `network`; a held or cut answer reached the server and is `timeout`.
    static let noAnswer: StubReply? = nil
}

/// A request as the stub server saw it.
struct StubRequest {
    let method: String
    let url: URL?
    let path: String
    let query: [String: String]
    let body: [String: Any]
    let timeout: TimeInterval
    let time: Date
}

/// Serves every session the SDK builds from `URLSessionConfiguration.default` (and `URLSession.shared`)
/// while installed. The handler runs off the loading thread, so it may block to hold an answer back.
final class StubURLProtocol: URLProtocol {

    private static let lock = NSLock()
    private static var recorded: [StubRequest] = []
    /// Requests whose answer the stub handed to the client in full.
    private static var finished: [StubRequest] = []
    private static var installed = false

    private static var currentHandler: (StubRequest) -> StubReply? = defaultHandler

    /// Answers a request; `nil` fails it as a timed-out connection. `/init` gets a device id by default.
    /// Set by the test, read on the loading threads: under the lock.
    static var handler: (StubRequest) -> StubReply? {
        get { lock.lock(); defer { lock.unlock() }; return currentHandler }
        set { lock.lock(); currentHandler = newValue; lock.unlock() }
    }

    static let defaultHandler: (StubRequest) -> StubReply? = { request in
        request.path == "/init" ? StubReply(json: #"{"did":"stub-did","seance":"stub-seance"}"#) : StubReply()
    }

    static var requests: [StubRequest] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    static func requests(to path: String) -> [StubRequest] {
        requests.filter { $0.path == path }
    }

    /// Requests of one shop to `path`. An SDK left from an earlier test may still be sending: its
    /// requests must not count in this one.
    static func requests(to path: String, shop shopId: String) -> [StubRequest] {
        requests(to: path).filter { ($0.query["shop_id"] ?? $0.body["shop_id"] as? String) == shopId }
    }

    /// How many answers of `shop` to `path` the stub handed to the client in full: what a test waits
    /// for instead of sleeping.
    static func answered(to path: String, shop shopId: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return finished.filter { $0.path == path && ($0.query["shop_id"] ?? $0.body["shop_id"] as? String) == shopId }.count
    }

    static func install() {
        lock.lock()
        recorded.removeAll()
        finished.removeAll()
        lock.unlock()
        handler = defaultHandler
        guard !installed else { return }
        installed = true
        URLProtocol.registerClass(StubURLProtocol.self)
        swapDefaultConfiguration()
        // A URL protocol has no metrics of the request's phases: the stub says which reached it.
        NetworkClient.reachedServerOverride = { task, _ in
            StubURLProtocol.reached(task) ? true : nil
        }
    }

    static func uninstall() {
        handler = defaultHandler
        guard installed else { return }
        installed = false
        URLProtocol.unregisterClass(StubURLProtocol.self)
        swapDefaultConfiguration()
        NetworkClient.reachedServerOverride = nil
    }

    /// Tasks the stub server answered or held: their request reached it.
    private static let reachedTasks = NSHashTable<URLSessionTask>.weakObjects()

    static func reached(_ task: URLSessionTask) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return reachedTasks.contains(task)
    }

    /// Sessions the SDK builds itself do not see `registerClass`: their configuration has to list
    /// the stub, so `URLSessionConfiguration.default` hands out one that does.
    private static func swapDefaultConfiguration() {
        guard
            let original = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.default)),
            let stubbed = class_getClassMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration.stubServedDefault))
        else { return }
        method_exchangeImplementations(original, stubbed)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let seen = Self.describe(request)
        Self.lock.lock()
        Self.recorded.append(seen)
        Self.lock.unlock()

        let handler = Self.handler
        DispatchQueue.global().async { [weak self] in
            let reply = handler(seen)
            guard let self = self, let client = self.client else { return }
            if reply != nil, let task = self.task {
                Self.lock.lock()
                Self.reachedTasks.add(task)
                Self.lock.unlock()
            }
            guard let reply = reply else {
                client.urlProtocol(self, didFailWithError: URLError(.timedOut))
                return
            }
            if reply.delay > 0 {
                // An answer held past the request's timeout fails as the session would fail it.
                let timedOut = seen.timeout > 0 && reply.delay >= seen.timeout
                Thread.sleep(forTimeInterval: timedOut ? seen.timeout : reply.delay)
                guard !self.isStopped else { return }
                if timedOut {
                    client.urlProtocol(self, didFailWithError: URLError(.timedOut))
                    return
                }
            }
            let response = HTTPURLResponse(
                url: self.request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers
            )!
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let cut = reply.cutAfter {
                client.urlProtocol(self, didLoad: reply.body.prefix(cut))
                client.urlProtocol(self, didFailWithError: URLError(reply.cutWith))
                return
            }
            client.urlProtocol(self, didLoad: reply.body)
            client.urlProtocolDidFinishLoading(self)
            Self.lock.lock()
            Self.finished.append(seen)
            Self.lock.unlock()
        }
    }

    private let stopLock = NSLock()
    private var stopped = false
    /// The session gave up on the request: cancelled or timed out. Nothing more goes to its client.
    private var isStopped: Bool {
        stopLock.lock(); defer { stopLock.unlock() }
        return stopped
    }

    override func stopLoading() {
        stopLock.lock()
        stopped = true
        stopLock.unlock()
    }

    private static func describe(_ request: URLRequest) -> StubRequest {
        let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        var query: [String: String] = [:]
        components?.queryItems?.forEach { query[$0.name] = $0.value ?? "" }
        var bodyData = request.httpBody
        if bodyData == nil, let stream = request.httpBodyStream {
            bodyData = Data(reading: stream)
        }
        let body = bodyData.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        return StubRequest(
            method: request.httpMethod ?? "GET",
            url: request.url,
            path: components?.path ?? "",
            query: query,
            body: body,
            timeout: request.timeoutInterval,
            time: Date()
        )
    }
}

extension URLSessionConfiguration {
    /// Swapped in for `default` while the stub is installed; calling itself reaches the original.
    @objc class func stubServedDefault() -> URLSessionConfiguration {
        let configuration = stubServedDefault()
        configuration.protocolClasses = [StubURLProtocol.self] + (configuration.protocolClasses ?? [])
        return configuration
    }
}

private extension Data {
    init(reading stream: InputStream) {
        self.init()
        stream.open()
        defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }
            append(buffer, count: read)
        }
    }
}

/// The keychain backup of the init answer, in memory.
final class InMemoryKeychainInitStore: KeychainInitStore {
    var data: Data?
    init(_ data: Data? = nil) { self.data = data }
    func readInitData() -> Data? { data }
    func writeInitData(_ data: Data) { self.data = data }
    func clear() { data = nil }
}

/// A real SDK over the stub server, with in-memory identity and keychain.
enum StubSDK {

    static func shopId() -> String { "stub-\(UUID().uuidString.prefix(8))" }

    static func make(
        shopId: String = StubSDK.shopId(),
        identity: UserIdentityRepository = InMemoryUserIdentityRepository(),
        keychain: KeychainInitStore = InMemoryKeychainInitStore(),
        needReInitialization: Bool = false,
        logLevel: Rees46.LogLevel = .warning,
        connectivity: ConnectivityMonitor? = nil,
        coreV2: Bool = false,
        sendAdvertisingId: Bool = false,
        deviceId: String? = nil,
        environment: CoreEnvironment? = nil,
        shopStorage: ShopStorage? = nil,
        deviceStore: DeviceStore? = nil,
        completion: ((SdkError?) -> Void)? = nil
    ) -> SimplePersonalizationSDK {
        // The core a stub SDK asks for is the one it gets: the process's flag is the test's to set.
        CoreFlag.reset(to: coreV2)
        InitSettles.install()
        return SimplePersonalizationSDK(
            shopId: shopId,
            apiDomain: "stub.test",
            logLevel: logLevel,
            autoSendPushToken: false,
            sendAdvertisingId: sendAdvertisingId,
            enableAutoPopupPresentation: false,
            needReInitialization: needReInitialization,
            coreV2: coreV2,
            deviceId: deviceId,
            environment: environment,
            userIdentity: identity,
            keychainStore: keychain,
            shopStorage: shopStorage,
            localState: LocalStateRepositoryImpl(store: UserDefaults(suiteName: "test-\(shopId)")!),
            connectivity: connectivity,
            // The new core's push token: the shop's own device, not the push token other tests left.
            deviceStore: deviceStore ?? StubSDK.deviceStore(shopId: shopId),
            completion: completion
        )
    }

    /// A device store of its own for `shopId`'s test.
    static func deviceStore(shopId: String) -> DeviceStore {
        let suite = UserDefaults(suiteName: "test-device-\(shopId)") ?? .standard
        return DeviceStore(defaults: suite, pushTokenDefaults: suite)
    }

    /// Where earlier SDK versions saved the init answer of `shopId`: the app's Documents.
    static func savedInitFile(shopId: String) -> URL {
        SdkGlobalHelper.sharedInstance.getSdkDocumentsDirectory().appendingPathComponent(shopId + ".json")
    }

    static func removeSavedInit(shopId: String) {
        try? FileManager.default.removeItem(at: savedInitFile(shopId: shopId))
        UserDefaults.standard.removePersistentDomain(forName: "test-\(shopId)")
        UserDefaults.standard.removePersistentDomain(forName: "test-device-\(shopId)")
        // The shop's partition and its folder in Application Support.
        if let folder = ShopStorage(shopId: shopId, logger: SdkLogger(shopId: shopId, level: .none)).directory {
            try? FileManager.default.removeItem(at: folder)
        }
        UserDefaults.standard.removePersistentDomain(forName: StoragePartition.suiteName(for: shopId))
    }
}

/// How often each instance's `/init` settled, counted through the core's test seam
/// (`InitMachine.settleObserver`): what the tests wait for instead of sleeping.
enum InitSettles {
    private static let lock = NSLock()
    /// Weak keys: a machine that is gone takes its count with it.
    private static let counts = NSMapTable<AnyObject, NSNumber>(keyOptions: [.weakMemory, .objectPointerPersonality], valueOptions: .strongMemory)

    static func install() {
        guard InitMachine.settleObserver == nil else { return }
        InitMachine.settleObserver = { machine in
            lock.lock(); defer { lock.unlock() }
            counts.setObject(NSNumber(value: (counts.object(forKey: machine)?.intValue ?? 0) + 1), forKey: machine)
        }
    }

    static func count(of machine: InitMachine?) -> Int {
        guard let machine = machine else { return 0 }
        lock.lock(); defer { lock.unlock() }
        return counts.object(forKey: machine)?.intValue ?? 0
    }
}

extension SimplePersonalizationSDK {
    /// How many times this instance's `/init` settled (`initMachine(didSettle:)`).
    var settledInitCount: Int { InitSettles.count(of: initMachine) }
}

extension XCTestCase {
    /// Runs `trigger` and fails if a request of `shop` to `path` reaches the stub server within
    /// `timeout`: an inverted expectation, not a sleep and a count.
    func expectNoRequest(to path: String, shop: String, within timeout: TimeInterval = 0.5, after trigger: () -> Void = {}) {
        let none = expectation(description: "no request to \(path)")
        none.isInverted = true
        let previous = StubURLProtocol.handler
        StubURLProtocol.handler = { request in
            if request.path == path, (request.query["shop_id"] ?? request.body["shop_id"] as? String) == shop {
                none.fulfill()
            }
            return previous(request)
        }
        trigger()
        wait(for: [none], timeout: timeout)
        StubURLProtocol.handler = previous
    }

    /// Runs what the main queue holds so far: whatever the SDK dispatched there before the call has run
    /// when it returns.
    func drainMainQueue() {
        let drained = expectation(description: "the main queue")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 5)
    }

    /// Spins the run loop until `condition` holds or `timeout` passes; returns the last answer.
    @discardableResult
    func eventually(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        return condition()
    }
}
