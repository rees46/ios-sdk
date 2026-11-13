//
//  Core.swift
//  REES46
//
//  The engine under one SDK instance. Two of them run side by side while the new one is built:
//  `LegacyCore` — the request paths the SDK has always had — and `CoreV2`, the core of
//  `sdk/core/*.md`, behind `Rees46Config.coreV2`. The SDK's request funnel (`sendGet`,
//  `postRequest`, `getRequest`) asks the instance's core, so no namespace is written twice.
//

import Foundation

/// One request of the SDK's funnel, as the active core sends it.
struct CoreRequest {

    enum Method: String {
        case get = "GET"
        case post = "POST"
    }

    let method: Method
    /// The path under the API host, without a leading slash: `products/get`.
    let path: String
    /// The query of a `GET`.
    var query: [String: String] = [:]
    /// The JSON body of a `POST`; the funnel has checked that it is JSON.
    var body: [String: Any] = [:]
    /// The read timeout of this request alone; `nil` is the default one.
    var timeout: TimeInterval?
    /// Whether the request waits for the network rather than failing at once without it. The old
    /// sessions wait for every request but the ones that ask not to; `CoreV2` lets only `/init` wait
    /// (as long as the init itself is the old one), every other request fails at once with `network`.
    var waitsForNetwork = true

    /// `/init`: its own timeout, and in `CoreV2` the only request that may wait for the network.
    var isInit: Bool { path == "init" }
}

/// What a core got for a request.
struct CoreResponse {
    /// The HTTP status; `nil` when no answer came.
    let status: Int?
    /// The body as it came; empty without one.
    let body: Data
    /// The decoded JSON, or the error the old methods return.
    let result: Result<Any, SdkError>
}

/// Which core an instance runs.
enum CoreKind: Equatable {
    case legacy
    case v2
}

/// The engine of one SDK instance: how its requests go out and what comes back. Init, session and
/// queue stay with the instance until the stages that move them here.
protocol Core: AnyObject {
    var kind: CoreKind { get }

    /// Sends `request`. `completion` is called exactly once, off the main thread.
    func send(_ request: CoreRequest, completion: @escaping (CoreResponse) -> Void)

    /// Stops the core: requests in flight end, and later ones are not sent.
    func release()
}

/// Which core the process runs. The first `Rees46.initialize`, `Rees46.register` or SDK made decides,
/// and the value holds until the process ends: the two cores share storage, and switching a running
/// app between them would mix their state. An instance that asks for the other core gets the
/// process's one, and the log says so with `core_flag_mismatch`.
enum CoreFlag {

    private static let lock = NSLock()
    private static var decided: Bool?

    /// The value of `coreV2` for an instance of `shopId` that asks for `requested`.
    static func resolve(requested: Bool, shopId: String?) -> Bool {
        lock.lock()
        let active = decided ?? requested
        decided = active
        lock.unlock()
        if active != requested {
            let logger = shopId.map { SdkLogger.forShop($0) } ?? SdkLogger.process
            logger.warning(
                LogCode.coreFlagMismatch,
                "the instance asks for coreV2 = \(requested), the process runs coreV2 = \(active) until it restarts",
                ["requested": String(requested), "active": String(active)]
            )
        }
        return active
    }

    /// The process's value, once something decided it.
    static var current: Bool? {
        lock.lock(); defer { lock.unlock() }
        return decided
    }

    /// Test-only: forgets the process's value, or sets it.
    static func reset(to value: Bool? = nil) {
        lock.lock()
        decided = value
        lock.unlock()
    }
}
