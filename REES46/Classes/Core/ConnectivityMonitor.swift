//
//  ConnectivityMonitor.swift
//  REES46
//

import Foundation

/// Whether the device is online, and when that changes. The SDK reads it through this protocol rather
/// than the `NetworkStatus` singleton, so tests can be offline on demand.
protocol ConnectivityMonitor: AnyObject {
    var isOnline: Bool { get }
    /// Calls `handler` with the current state at once, then on every change, until cancelled.
    func observe(_ handler: @escaping (Bool) -> Void) -> Cancellable
}

/// The production monitor over `NetworkStatus`.
final class SystemConnectivityMonitor: ConnectivityMonitor {

    static let shared = SystemConnectivityMonitor()

    var isOnline: Bool {
        NetworkStatus.nManager.connectionStatus != .Offline
    }

    func observe(_ handler: @escaping (Bool) -> Void) -> Cancellable {
        let observer = Observer(handler)
        observer.startObserving()
        return Cancellable { observer.stopObserving() }
    }

    private final class Observer: NetworkStatusObserver {
        private let handler: (Bool) -> Void
        init(_ handler: @escaping (Bool) -> Void) { self.handler = handler }
        func didChangeConnectionStatus(_ status: NetworkConnectionStatus) { handler(status != .Offline) }
        func didChangeConnectionType(_ type: NetworkConnectionType?) {}
    }
}
