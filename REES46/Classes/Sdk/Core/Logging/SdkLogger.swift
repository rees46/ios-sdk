//
//  SdkLogger.swift
//  REES46
//
//  The one way the SDK logs: a level per instance, the shop on every message, the system log and
//  the app's handler. See documentation-unified `sdk/core/logging.md`.
//

import Foundation
import os.log

/// The logger of one SDK instance. Messages below `level` are dropped before their text is built.
final class SdkLogger {

    let shopId: String?
    let level: LogLevel

    init(shopId: String?, level: LogLevel) {
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

    func log(_ messageLevel: LogLevel, _ code: String, _ message: @autoclosure () -> String, _ context: [String: String] = [:]) {
        guard messageLevel != .none, level != .none, messageLevel >= level else { return }
        let entry = SdkLogMessage(level: messageLevel, code: code, message: message(), shopId: shopId, context: context)
        Self.writeToSystemLog(entry)
        Self.deliver(entry)
    }

    /// A request as the log may show it: method and path, never the query or the body.
    static func requestLine(_ method: String, _ path: String) -> String {
        "\(method) \(path)"
    }

    // MARK: - Loggers by shop

    private static let lock = NSLock()
    private static var byShop: [String: SdkLogger] = [:]

    /// Messages about the SDK as a whole, with no shop: the facade, push routing.
    static var process: SdkLogger {
        lock.lock(); defer { lock.unlock() }
        return processLogger
    }
    private static var processLogger = SdkLogger(shopId: nil, level: .warning)

    /// Makes `logger` the one code without an instance at hand reaches through `forShop`. The most
    /// verbose shop level also becomes the level of messages about the SDK as a whole.
    static func register(_ logger: SdkLogger) {
        guard let shopId = logger.shopId else { return }
        lock.lock(); defer { lock.unlock() }
        byShop[shopId] = logger
        let mostVerbose = byShop.values.map(\.level).min() ?? .warning
        processLogger = SdkLogger(shopId: nil, level: mostVerbose)
    }

    /// The logger of `shopId`'s instance; one at the default level when the shop has none yet.
    static func forShop(_ shopId: String) -> SdkLogger {
        lock.lock(); defer { lock.unlock() }
        return byShop[shopId] ?? SdkLogger(shopId: shopId, level: .warning)
    }

    // MARK: - App handler

    private static var handler: ((SdkLogMessage) -> Void)?
    private static let handlerQueue = DispatchQueue(label: "com.rees46.sdk.log", qos: .utility)

    static func setHandler(_ newHandler: ((SdkLogMessage) -> Void)?) {
        lock.lock(); defer { lock.unlock() }
        handler = newHandler
    }

    /// The app's handler gets messages in order, off the caller's thread.
    private static func deliver(_ entry: SdkLogMessage) {
        lock.lock()
        let current = handler
        lock.unlock()
        guard let current = current else { return }
        handlerQueue.async { current(entry) }
    }

    // MARK: - System log

    private static let systemLog = OSLog(subsystem: "com.rees46.sdk", category: "sdk")

    private static func writeToSystemLog(_ entry: SdkLogMessage) {
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
