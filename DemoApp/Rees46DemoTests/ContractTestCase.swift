//
//  ContractTestCase.swift
//  REES46Tests
//
//  The API contract on the stub server: what a method sends — its method, path and parameters as the
//  API documentation names them — and what it makes of the answer the documentation shows. The
//  server's own work is not the SDK's to test; no test here reaches it (`LiveServerGuard`).
//

import XCTest
@testable import REES46

class ContractTestCase: XCTestCase {

    private var shops: [String] = []
    /// Released at the end of the test: an instance left running would keep its queues, timers and
    /// observers busy through the tests after it.
    private var made: [SimplePersonalizationSDK] = []

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
    }

    override func tearDown() {
        made.forEach { $0.release() }
        made.removeAll()
        StubURLProtocol.uninstall()
        CoreFlag.reset()
        shops.forEach { StubSDK.removeSavedInit(shopId: $0) }
        shops.removeAll()
        super.tearDown()
    }

    /// Runs `body` with a ready SDK of a new shop on each core: the contract is the same on both.
    func onBothCores(appDomain: String = Rees46Config.defaultAppDomain, _ body: (SimplePersonalizationSDK) -> Void) {
        for coreV2 in [false, true] {
            XCTContext.runActivity(named: coreV2 ? "the new core" : "the old core") { _ in
                body(readySDK(coreV2: coreV2, appDomain: appDomain))
            }
        }
    }

    /// A ready SDK of a new shop over the stub server: its `/init` answered with the stub's device id.
    func readySDK(coreV2: Bool, appDomain: String = Rees46Config.defaultAppDomain) -> SimplePersonalizationSDK {
        let shop = StubSDK.shopId()
        shops.append(shop)
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: shop, coreV2: coreV2, appDomain: appDomain) { _ in ready.fulfill() }
        made.append(sdk)
        wait(for: [ready], timeout: 5)
        return sdk
    }

    /// Answers `path` with `json` and `status`; every other request as the stub server does by default.
    func answer(_ path: String, status: Int = 200, json: String) {
        StubURLProtocol.handler = { request in
            request.path == path ? StubReply(status, json: json) : StubURLProtocol.defaultHandler(request)
        }
    }

    /// The outcome `call` hands its completion, once.
    func outcome<T>(
        file: StaticString = #filePath,
        line: UInt = #line,
        of call: (@escaping (Result<T, SdkError>) -> Void) -> Void
    ) -> Result<T, SdkError>? {
        let done = expectation(description: "completion")
        var result: Result<T, SdkError>?
        call { value in
            result = value
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        if result == nil { XCTFail("no outcome", file: file, line: line) }
        return result
    }

    /// The value of a successful outcome; a failure fails the test.
    func success<T>(_ result: Result<T, SdkError>?, file: StaticString = #filePath, line: UInt = #line) -> T? {
        switch result {
        case .success(let value): return value
        case .failure(let error): XCTFail("failed: \(error)", file: file, line: line); return nil
        case nil: return nil
        }
    }

    /// The last request of `sdk`'s shop to `path`.
    func request(_ sdk: SimplePersonalizationSDK, _ path: String, file: StaticString = #filePath, line: UInt = #line) -> StubRequest? {
        let sent = StubURLProtocol.requests(to: path, shop: sdk.shopId).last
        if sent == nil { XCTFail("nothing went to \(path)", file: file, line: line) }
        return sent
    }
}
