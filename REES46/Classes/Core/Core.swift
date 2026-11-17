//
//  Core.swift
//  REES46
//
//  The engine under one SDK instance. Two of them run side by side while the new one is built:
//  `LegacyCore` — the request paths the SDK has always had — and `CoreV2`, the core of
//  `sdk/core/*.md`, behind `Rees46Config.coreV2`, which only the bridges' `Rees46.initializeBridge`
//  sets. The SDK's request funnel (`sendGet`, `postRequest`, `getRequest`) asks the instance's core,
//  so no namespace is written twice.
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
    /// `CoreV2`: once the instance is usable, the device id and session the request goes with — `nil`
    /// when it must not go any more (the customer it was made for was deleted). `nil` here: the stored
    /// ones when it is built.
    var identity: (() -> CommonFields.Identity?)?
    /// Whether the request waits for the network rather than failing at once without it. The old
    /// sessions wait for every request but the ones that ask not to; `CoreV2` lets only `/init` wait
    /// (as long as the init itself is the old one), every other request fails at once with `network`.
    var waitsForNetwork = true
    /// `CoreV2`: whether the request goes with the session — renewed first when its window ended. An
    /// event of a push carries none (`EventQueue.sessionlessPaths`): it renews no session and asks no
    /// `/init`, the one it is sent once as when the disk refused it included.
    var needsSession = true

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
    /// The failure as the new core classifies it (`Rees46.SdkError`), which the old error loses: the
    /// HTTP code, network or timeout. What the bridges hand on (`Rees46.BridgeErrors`). `nil` on success.
    var error: Rees46.SdkError? = nil
}

/// Which core an instance runs.
enum CoreKind: Equatable {
    case legacy
    case v2
}

/// The engine of one SDK instance: how its requests go out and what comes back. `CoreV2` runs its own
/// `/init` (`InitMachine`); the old init, the session and the queue stay with the instance until the
/// stages that move them here.
protocol Core: AnyObject {
    var kind: CoreKind { get }

    /// Sends `request`. `completion` is called exactly once, off the main thread.
    func send(_ request: CoreRequest, completion: @escaping (CoreResponse) -> Void)

    /// Stops the core: later requests are not sent and fail as `notInitialized`; on `CoreV2` the ones
    /// in flight end as `cancelled`.
    func release()

    /// Sends the next requests with the app's session configuration (`configureURLSession`).
    func use(_ configuration: URLSessionConfiguration)
}

/// Which core the process runs. The first `Rees46.initialize`, `Rees46.register` or SDK made decides,
/// and the value holds until the process ends: the two cores share storage, and switching a running
/// app between them would mix their state. An instance that asks for the other core gets the
/// process's one, and its log says so with `core_flag_mismatch`, once per shop.
enum CoreFlag {

    private static let lock = NSLock()
    private static var decided: Bool?
    /// Shops whose mismatch is already in the log.
    private static var reported: Set<String> = []

    /// The value of `coreV2` for an instance that asks for `requested`.
    static func resolve(requested: Bool) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let active = decided ?? requested
        decided = active
        return active
    }

    /// Writes `core_flag_mismatch` through the instance's own `logger`, so its log level applies, the
    /// first time an instance of its shop asks for another core than the process runs.
    static func reportMismatch(requested: Bool, active: Bool, logger: SdkLogger) {
        guard requested != active else { return }
        let shop = logger.shopId ?? ""
        lock.lock()
        let first = reported.insert(shop).inserted
        lock.unlock()
        guard first else { return }
        logger.warning(
            LogCode.coreFlagMismatch,
            "the instance asks for coreV2 = \(requested), the process runs coreV2 = \(active) until it restarts",
            ["requested": String(requested), "active": String(active)]
        )
    }

    /// The process's value, once something decided it.
    static var current: Bool? {
        lock.lock(); defer { lock.unlock() }
        return decided
    }

    /// Test-only: forgets the process's value, or sets it, and the shops already reported.
    static func reset(to value: Bool? = nil) {
        lock.lock()
        decided = value
        reported.removeAll()
        lock.unlock()
    }
}
