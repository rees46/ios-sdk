//
//  SdkLogger.swift
//  REES46
//
//  The one way the SDK logs: a level per instance, the shop on every message, the system log and
//  the app's handler. See documentation-unified `sdk/core/logging.md`.
//

import Foundation
import os.log

/// The stable codes of the SDK's log, as in the "Коды" table of `sdk/core/logging.md`. A code is part
/// of the contract: the same on Android and iOS, and it goes into the table before it goes here.
enum LogCode {
    static let request = "request"
    static let requestFailed = "request_failed"
    static let requestBuildFailed = "request_build_failed"
    static let invalidArgument = "invalid_argument"
    static let invalidConfig = "invalid_config"
    static let decodingFailed = "decoding_failed"
    static let callbackFailed = "callback_failed"
    static let initSucceeded = "init_succeeded"
    static let initSavedAnswer = "init_saved_answer"
    static let initRetry = "init_retry"
    static let initFailed = "init_failed"
    static let initRefused = "init_refused"
    static let deviceIdReset = "device_id_reset"
    static let storageFailed = "storage_failed"
    static let queueDropped = "queue_dropped"
    static let pushReceived = "push_received"
    static let pushDropped = "push_dropped"
    static let pushFailed = "push_failed"
    static let pushPermission = "push_permission"
    static let pushPermissionFailed = "push_permission_failed"
    static let pushTokenSent = "push_token_sent"
    static let pushTokenSkipped = "push_token_skipped"
    static let pushTokenFailed = "push_token_failed"
    static let advertisingIdSent = "advertising_id_sent"
    static let advertisingIdFailed = "advertising_id_failed"
    static let popupNotShown = "popup_not_shown"
    static let coreFlagMismatch = "core_flag_mismatch"
    static let notImplemented = "not_implemented"
}

/// The logger of one SDK instance. Messages below `level` are dropped before their text is built.
final class SdkLogger {

    let shopId: String?
    let level: Rees46.LogLevel

    init(shopId: String?, level: Rees46.LogLevel) {
        self.shopId = shopId
        self.level = level
    }

    func debug(_ code: String, _ message: @autoclosure () -> String, _ context: [String: String] = [:]) {
        log(.debug, code, message(), context)
    }

    func info(_ code: String, _ message: @autoclosure () -> String, _ context: [String: String] = [:]) {
        log(.info, code, message(), context)
    }

    func warning(_ code: String, _ message: @autoclosure () -> String, _ context: [String: String] = [:]) {
        log(.warning, code, message(), context)
    }

    func error(_ code: String, _ message: @autoclosure () -> String, _ context: [String: String] = [:]) {
        log(.error, code, message(), context)
    }

    /// Writes one message. `force` writes it whatever the level, `none` included: for lines the app
    /// asked for explicitly, the decisions of popups v3 with `debug` on.
    func log(
        _ messageLevel: Rees46.LogLevel,
        _ code: String,
        _ message: @autoclosure () -> String,
        _ context: [String: String] = [:],
        force: Bool = false
    ) {
        guard messageLevel != .none else { return }
        guard force || (level != .none && messageLevel >= level) else { return }
        let entry = Rees46.SdkLogMessage(level: messageLevel, code: code, message: message(), shopId: shopId, context: context)
        Self.writeToSystemLog(entry)
        Self.deliver(entry)
    }

    /// A request as the log may show it: method and path, never the query or the body.
    static func requestLine(_ method: String, _ path: String) -> String {
        "\(method) \(path)"
    }

    /// One request once it is over: `request` at `debug` when it succeeded; `request_failed` when the
    /// answer was not a success (`error` on `4xx`, `warning` otherwise) or no answer came (`status` is
    /// `nil`). Method, path and HTTP code only.
    func requestFinished(_ method: String, _ path: String, status: Int?, succeeded: Bool) {
        let line = Self.requestLine(method, path)
        var context = ["method": method, "path": path]
        if let status = status {
            context["status"] = String(status)
        }
        if succeeded {
            debug(LogCode.request, line, context)
            return
        }
        guard let status = status else {
            warning(LogCode.requestFailed, "no answer: \(line)", context)
            return
        }
        log((400..<500).contains(status) ? .error : .warning, LogCode.requestFailed, "\(status): \(line)", context)
    }

    // MARK: - Data-free descriptions

    /// What kind of error `error` is, for a log line: the case of an SDK error, the code of a
    /// `URLError`, the domain and code of another `NSError`. Never its text: a description repeats
    /// URLs with their query (the device id, the session) or what the server sent back.
    static func errorKind(_ error: Error?) -> String {
        guard let error = error else { return "none" }
        if let sdkError = error as? SdkError {
            return sdkError.logKind
        }
        if let sdkError = error as? Rees46.SdkError {
            return sdkError.logKind
        }
        if let urlError = error as? URLError {
            return "URLError \(urlError.code.rawValue)"
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain || nsError.domain == NSURLErrorDomain || nsError.domain == NSPOSIXErrorDomain
            || nsError.domain == NSOSStatusErrorDomain {
            return "\(nsError.domain) \(nsError.code)"
        }
        return String(describing: type(of: error))
    }

    // MARK: - Loggers by shop

    /// A live instance of a shop and its logger.
    private struct Registration {
        let owner: ObjectIdentifier
        let logger: SdkLogger
    }

    private static let lock = NSLock()
    private static var byShop: [String: [Registration]] = [:]
    private static var processLogger = SdkLogger(shopId: nil, level: .warning)

    /// Messages about the SDK as a whole, with no shop: the facade, push routing, UI. Their level is
    /// the most verbose level of the live instances, `warning` when there are none.
    static var process: SdkLogger {
        lock.lock(); defer { lock.unlock() }
        return processLogger
    }

    /// Makes `logger` the one code without an instance at hand reaches through `forShop`, for as long
    /// as `owner` (the instance) is live: `unregister(owner:)` takes it back.
    static func register(_ logger: SdkLogger, owner: AnyObject) {
        guard let shopId = logger.shopId else { return }
        let id = ObjectIdentifier(owner)
        lock.lock(); defer { lock.unlock() }
        byShop[shopId] = (byShop[shopId] ?? []).filter { $0.owner != id } + [Registration(owner: id, logger: logger)]
        refreshProcessLevelLocked()
    }

    /// `owner` was released or torn down: its level no longer counts, for its shop or for messages
    /// about the SDK as a whole. Without this the process stayed at the most verbose level ever seen.
    static func unregister(owner: AnyObject) {
        let id = ObjectIdentifier(owner)
        lock.lock(); defer { lock.unlock() }
        for (shopId, registrations) in byShop {
            let kept = registrations.filter { $0.owner != id }
            byShop[shopId] = kept.isEmpty ? nil : kept
        }
        refreshProcessLevelLocked()
    }

    /// The logger of `shopId`: the most verbose of its live instances, one at the default level when
    /// the shop has none.
    static func forShop(_ shopId: String) -> SdkLogger {
        lock.lock(); defer { lock.unlock() }
        let loggers = (byShop[shopId] ?? []).map(\.logger)
        return loggers.min { $0.level < $1.level } ?? SdkLogger(shopId: shopId, level: .warning)
    }

    /// Shops with a live logger; for tests.
    static var registeredShopIds: Set<String> {
        lock.lock(); defer { lock.unlock() }
        return Set(byShop.keys)
    }

    private static func refreshProcessLevelLocked() {
        let mostVerbose = byShop.values.flatMap { $0 }.map(\.logger.level).min() ?? .warning
        if processLogger.level != mostVerbose {
            processLogger = SdkLogger(shopId: nil, level: mostVerbose)
        }
    }

    // MARK: - App handler

    private static var handler: ((Rees46.SdkLogMessage) -> Void)?
    private static let handlerQueue = DispatchQueue(label: "com.rees46.sdk.log", qos: .utility)

    static func setHandler(_ newHandler: ((Rees46.SdkLogMessage) -> Void)?) {
        lock.lock(); defer { lock.unlock() }
        handler = newHandler
    }

    /// The app's handler gets messages in order, off the caller's thread.
    private static func deliver(_ entry: Rees46.SdkLogMessage) {
        lock.lock()
        let current = handler
        lock.unlock()
        guard let current = current else { return }
        handlerQueue.async { current(entry) }
    }

    // MARK: - System log

    private static let systemLog = OSLog(subsystem: "com.rees46.sdk", category: "sdk")

    private static func writeToSystemLog(_ entry: Rees46.SdkLogMessage) {
        let type: OSLogType
        switch entry.level {
        case .debug: type = .debug
        case .info: type = .info
        case .warning: type = .default
        case .error, .none: type = .error
        }
        let shop = entry.shopId.map { " [\($0)]" } ?? ""
        os_log("REES46%{public}@ %{public}@: %{public}@", log: systemLog, type: type, shop, entry.code, entry.message)
    }
}

// MARK: - Areas

extension SdkLogger {

    /// The code of an area: a message of old code that has no event of its own goes under the code of
    /// the part of the SDK it comes from.
    enum Area: String {
        case sdkLog = "sdk_log"
        case ui
        case stories
        case storiesV3 = "stories_v3"
        case popupsV3 = "popups_v3"
    }

    /// Writes a message of `area`: through the shop's logger when the caller knows the shop, through
    /// the process one otherwise.
    static func area(
        _ area: Area,
        _ level: Rees46.LogLevel,
        _ message: @autoclosure () -> String,
        shopId: String? = nil,
        force: Bool = false
    ) {
        let logger = shopId.map { forShop($0) } ?? process
        logger.log(level, area.rawValue, message(), force: force)
    }
}

extension SdkError {

    /// The case of the error without what it carries: `.custom` holds the server's message.
    var logKind: String {
        switch self {
        case .noError: return "noError"
        case .incorrectAPIKey: return "incorrectAPIKey"
        case .initializationFailed: return "initializationFailed"
        case .responseError: return "responseError"
        case .invalidResponse: return "invalidResponse"
        case .decodeError: return "decodeError"
        case .networkOfflineError: return "networkOfflineError"
        case .airplaneModeError: return "airplaneModeError"
        case .custom: return "custom"
        }
    }
}
