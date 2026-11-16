//
//  LiveServerGuard.swift
//  REES46Tests
//
//  No test reaches a real server: the tests check the contract — what the SDK sends and what it
//  makes of an answer — against the stub server, never the server's own work. A request no stub
//  answered fails here as offline, and the test that sent it fails with its URL.
//

import Foundation
import ObjectiveC
import XCTest
@testable import REES46

/// The test bundle's principal class (`NSPrincipalClass` in its Info.plist): XCTest makes it once,
/// before the first test, and it installs the guard.
final class TestBundleSetup: NSObject {
    override init() {
        super.init()
        LiveServerGuard.install()
    }
}

/// Takes every http(s) request no `StubURLProtocol` took — the stub, while installed, is asked first —
/// and fails it as offline, failing the running test with the request's URL.
final class LiveServerGuard: URLProtocol {

    private static let lock = NSLock()
    private static var installed = false
    private static var runningTest: XCTestCase?
    private static var observer: Observer?
    /// Shops the test host made SDKs for before the bundle loaded. Under XCTest the demo app initializes
    /// nothing (`AppDelegate.isRunningTests`); an SDK it made would reach a real server from sessions
    /// built before the guard, and its answers would land in whatever test runs.
    private static var hostShops: [String] = []
    private static var hostReported = false

    /// Requests that reached the guard, with the test that was running: what a run prints at its end.
    private(set) static var reached: [(test: String, url: String)] = []

    static func install() {
        lock.lock()
        defer { lock.unlock() }
        guard !installed else { return }
        installed = true
        URLProtocol.registerClass(LiveServerGuard.self)
        // Sessions the SDK builds itself do not see `registerClass`: their configuration has to list
        // the guard, as `StubURLProtocol` does for itself.
        if let original = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: URLSessionConfiguration.default)),
           let guarded = class_getClassMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration.liveServerGuardedDefault)) {
            method_exchangeImplementations(original, guarded)
        }
        SdkURLSession.reset()
        hostShops = (Array(SdkRegistry.shared.shopIds()) + Array(Rees46.pendingShopIds())).sorted()
        if !hostShops.isEmpty {
            print("LiveServerGuard: the test host initialized an SDK for \(hostShops) before the tests")
        }
        let observer = Observer()
        Self.observer = observer
        XCTestObservationCenter.shared.addTestObserver(observer)
    }

    /// Every http(s) request but one to this machine: a test may run a server of its own on loopback.
    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url, let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        return !isLoopback(url.host)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url
        let address = url?.absoluteString ?? "<no url>"
        // A host reserved for tests and examples (RFC 2606, RFC 6761) names no server: such a request
        // fails as offline, as nothing would answer it, and fails no test.
        if !Self.isReservedForExamples(url?.host) {
            Self.lock.lock()
            let test = Self.runningTest
            Self.reached.append((test?.name ?? "between tests", address))
            Self.lock.unlock()
            print("LiveServerGuard: \(test?.name ?? "between tests") sent \(address)")
            test?.record(XCTIssue(
                type: .assertionFailure,
                compactDescription: "The test reached a real server: \(address). Answer the request with StubURLProtocol."
            ))
        }
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    private static func isLoopback(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
    }

    private static func isReservedForExamples(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        let names = ["example.com", "example.net", "example.org"]
        let suffixes = [".test", ".example", ".invalid", ".localhost"]
        return names.contains { host == $0 || host.hasSuffix("." + $0) }
            || suffixes.contains { host.hasSuffix($0) }
            || ["test", "example", "invalid", "localhost"].contains(host)
    }

    override func stopLoading() {}

    private final class Observer: NSObject, XCTestObservation {
        func testCaseWillStart(_ testCase: XCTestCase) {
            LiveServerGuard.lock.lock()
            LiveServerGuard.runningTest = testCase
            let hostShops = LiveServerGuard.hostReported ? [] : LiveServerGuard.hostShops
            LiveServerGuard.hostReported = true
            LiveServerGuard.lock.unlock()
            // Told once, on the first test, for what it is: not this test's request.
            if !hostShops.isEmpty {
                testCase.record(XCTIssue(
                    type: .assertionFailure,
                    compactDescription: "The test host initialized an SDK for \(hostShops) before the tests: it reaches a real server and its answers land in the tests. Under XCTest the demo app must initialize nothing (AppDelegate.isRunningTests)."
                ))
            }
        }

        func testCaseDidFinish(_ testCase: XCTestCase) {
            LiveServerGuard.lock.lock()
            LiveServerGuard.runningTest = nil
            LiveServerGuard.lock.unlock()
        }

        func testBundleDidFinish(_ testBundle: Bundle) {
            LiveServerGuard.lock.lock()
            let reached = LiveServerGuard.reached
            LiveServerGuard.lock.unlock()
            print("LiveServerGuard: \(reached.count) request(s) reached the guard")
        }
    }
}

extension URLSessionConfiguration {
    /// Swapped in for `default` for the whole run; calling itself reaches the original.
    @objc class func liveServerGuardedDefault() -> URLSessionConfiguration {
        let configuration = liveServerGuardedDefault()
        configuration.protocolClasses = [LiveServerGuard.self] + (configuration.protocolClasses ?? [])
        return configuration
    }
}
