import Foundation
import Network
#if os(iOS)
import CoreTelephony
#endif

/// A network path as the monitor reports it: what `NetworkStatus` reads from an `NWPath`, which tests
/// cannot build.
struct NetworkPathSnapshot {
    let isSatisfied: Bool
    let usesCellular: Bool
    let usesWifi: Bool
    let usesWiredEthernet: Bool
    /// The radio of a cellular path as the system reports it; `nil` when it reports none.
    let cellularRadio: String?
}

/// Where network paths come from: `NWPathMonitor` in the app, a fake in tests.
protocol NetworkPathSource: AnyObject {
    /// Starts delivering paths to `handler`, one at a time, on the source's own queue.
    func start(_ handler: @escaping (NetworkPathSnapshot) -> Void)
    func cancel()
}

/// The production source: `NWPathMonitor` on a serial queue of its own.
final class SystemNetworkPathSource: NetworkPathSource {

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.rees46.sdk.network-status", qos: .utility)

    func start(_ handler: @escaping (NetworkPathSnapshot) -> Void) {
        monitor.pathUpdateHandler = { path in
            handler(Self.snapshot(of: path))
        }
        monitor.start(queue: queue)
    }

    func cancel() {
        monitor.cancel()
    }

    private static func snapshot(of path: NWPath) -> NetworkPathSnapshot {
        let cellular = path.usesInterfaceType(.cellular)
        var radio: String?
        #if os(iOS)
        if cellular {
            radio = CTTelephonyNetworkInfo().serviceCurrentRadioAccessTechnology?.values.first
        }
        #endif
        return NetworkPathSnapshot(
            isSatisfied: path.status == .satisfied,
            usesCellular: cellular,
            usesWifi: path.usesInterfaceType(.wifi),
            usesWiredEthernet: path.usesInterfaceType(.wiredEthernet),
            cellularRadio: radio
        )
    }
}

/// Whether the device is online and over what. Reading never blocks: until the monitor reports its
/// first path the status is unknown, and unknown counts as online — a request that then finds no
/// network fails as one. It used to wait for the first path on a semaphore that the timeout set to
/// `nil` while the monitor's queue signalled it, and to say `Offline` when that path came late.
public class NetworkStatus {

    public static var nManager: NetworkStatus = NetworkStatus()

    /// Nothing waits on it any more; kept so apps that touched it still compile.
    @available(*, deprecated, message: "Nothing waits on it: the status is read without blocking.")
    public var semaphore: DispatchSemaphore?

    private let source: NetworkPathSource
    private let lock = NSLock()
    /// Held while a change is made and told: observers hear the states in the order they came, and a
    /// new observer's first state never arrives after a newer one. Recursive: an observer may add
    /// another from its callback.
    private let delivery = NSRecursiveLock()
    /// `nil` until the first path: unknown.
    private var knownStatus: NetworkConnectionStatus?
    private var knownType: NetworkConnectionType?
    private var observers: [String: NetworkStatusObserver] = [:]

    /// `Online` while the first path has not come yet.
    public var connectionStatus: NetworkConnectionStatus {
        get {
            lock.lock(); defer { lock.unlock() }
            return knownStatus ?? .Online
        }
        set {
            update(status: newValue, type: nil, keepsType: true)
        }
    }

    /// `nil` while the first path has not come yet, and on a path that is not satisfied.
    public var connectionType: NetworkConnectionType? {
        get {
            lock.lock(); defer { lock.unlock() }
            return knownType
        }
        set {
            update(status: nil, type: newValue, keepsType: false)
        }
    }

    /// Whether the monitor has reported a path yet; for tests.
    var hasPath: Bool {
        lock.lock(); defer { lock.unlock() }
        return knownStatus != nil
    }

    private convenience init() {
        self.init(source: SystemNetworkPathSource())
    }

    /// A status over `source`; tests pass a fake one.
    init(source: NetworkPathSource) {
        self.source = source
        source.start { [weak self] path in
            self?.setConnection(path)
        }
    }

    func setConnection(_ path: NetworkPathSnapshot) {
        guard path.isSatisfied else {
            update(status: .Offline, type: nil, keepsType: false)
            return
        }
        var type: NetworkConnectionType?
        if path.usesCellular {
            // A cellular path without a reported radio is still online: it used to return here
            // without updating the status, and the first reader waited for a signal that never came.
            #if os(iOS)
            type = Self.cellularType(currentRadio: path.cellularRadio)
            #else
            type = .cellular(radioType: .notdeterminedcellular)
            #endif
        } else if path.usesWifi {
            type = .wifi
        } else if path.usesWiredEthernet {
            type = .ethernet
        }
        update(status: .Online, type: type, keepsType: false)
    }

    /// Changes the state under the lock, then tells the observers what changed, outside it: an
    /// observer may read the status or stop observing from its callback.
    private func update(status: NetworkConnectionStatus?, type: NetworkConnectionType?, keepsType: Bool) {
        delivery.lock()
        defer { delivery.unlock() }
        lock.lock()
        var statusChanged = false
        var typeChanged = false
        if let status = status, knownStatus != status {
            // Until the first path observers were told `Online`: a first path that is online is
            // no change for them.
            statusChanged = (knownStatus ?? .Online) != status
            knownStatus = status
        }
        if !keepsType, knownType != type {
            knownType = type
            typeChanged = true
        }
        let currentStatus = knownStatus ?? .Online
        let currentType = knownType
        let toNotify = Array(observers.values)
        lock.unlock()

        for observer in toNotify {
            if statusChanged {
                observer.didChangeConnectionStatus(currentStatus)
            }
            if typeChanged {
                observer.didChangeConnectionType(currentType)
            }
        }
    }

    #if os(iOS)
    /// The connection type of a cellular path from the radio the system reports; `nil` when it
    /// reports none.
    static func cellularType(currentRadio: String?) -> NetworkConnectionType {
        guard let currentRadio = currentRadio else {
            return .cellular(radioType: .notdeterminedcellular)
        }
        switch currentRadio {
        case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x:
            return .cellular(radioType: ._2G)
        case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA, CTRadioAccessTechnologyCDMAEVDORev0, CTRadioAccessTechnologyCDMAEVDORevA, CTRadioAccessTechnologyCDMAEVDORevB, CTRadioAccessTechnologyeHRPD:
            return .cellular(radioType: ._3G)
        case CTRadioAccessTechnologyLTE:
            return .cellular(radioType: ._4G)
        default:
            switch currentRadio {
            case CTRadioAccessTechnologyNRNSA, CTRadioAccessTechnologyNR:
                return .cellular(radioType: ._5G)
            default:
                return .cellular(radioType: .notdeterminedcellular)
            }
        }
    }
    #endif

    /// Adds `observer` and tells it the current state. Safe from any thread: the monitor's queue
    /// notifies a copy of the observers taken under the lock, and a change that comes meanwhile
    /// reaches the observer after its first state, never before.
    internal func addObserver(observer: NetworkStatusObserver) {
        delivery.lock()
        defer { delivery.unlock() }
        lock.lock()
        observers[observer.connectionObserverId] = observer
        let currentStatus = knownStatus ?? .Online
        let currentType = knownType
        lock.unlock()
        observer.didChangeConnectionStatus(currentStatus)
        observer.didChangeConnectionType(currentType)
    }

    internal func removeObserver(observer: NetworkStatusObserver) {
        lock.lock()
        observers[observer.connectionObserverId] = nil
        lock.unlock()
    }

    deinit {
        source.cancel()
    }
}
