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

    init(_ status: Int = 200, json: String = "{}") {
        self.status = status
        self.body = Data(json.utf8)
    }

    /// No answer: the connection fails as a timed-out one.
    static let noAnswer: StubReply? = nil
}

/// A request as the stub server saw it.
struct StubRequest {
    let method: String
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
    private static var installed = false

    /// Answers a request; `nil` fails it as a timed-out connection. `/init` gets a device id by default.
    static var handler: (StubRequest) -> StubReply? = defaultHandler

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

    static func install() {
        lock.lock()
        recorded.removeAll()
        lock.unlock()
        handler = defaultHandler
        guard !installed else { return }
        installed = true
        URLProtocol.registerClass(StubURLProtocol.self)
        swapDefaultConfiguration()
    }

    static func uninstall() {
        handler = defaultHandler
        guard installed else { return }
        installed = false
        URLProtocol.unregisterClass(StubURLProtocol.self)
        swapDefaultConfiguration()
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
            guard let reply = reply else {
                client.urlProtocol(self, didFailWithError: URLError(.timedOut))
                return
            }
            let response = HTTPURLResponse(
                url: self.request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: nil
            )!
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: reply.body)
            client.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}

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
        completion: ((SdkError?) -> Void)? = nil
    ) -> SimplePersonalizationSDK {
        SimplePersonalizationSDK(
            shopId: shopId,
            apiDomain: "stub.test",
            autoSendPushToken: false,
            enableAutoPopupPresentation: false,
            needReInitialization: needReInitialization,
            userIdentity: identity,
            keychainStore: keychain,
            localState: LocalStateRepositoryImpl(store: UserDefaults(suiteName: "test-\(shopId)")!),
            completion: completion
        )
    }

    /// The saved init answer of `shopId` in the SDK's documents folder.
    static func savedInitFile(shopId: String) -> URL {
        SdkGlobalHelper.sharedInstance.getSdkDocumentsDirectory().appendingPathComponent(shopId + ".json")
    }

    static func removeSavedInit(shopId: String) {
        try? FileManager.default.removeItem(at: savedInitFile(shopId: shopId))
        UserDefaults.standard.removePersistentDomain(forName: "test-\(shopId)")
    }
}

extension XCTestCase {
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
