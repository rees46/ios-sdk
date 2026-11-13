import Foundation
import Network
#if os(iOS)
import CoreTelephony
#endif


public class NetworkStatus {
    
    public static var nManager: NetworkStatus = NetworkStatus()
    
    private let monitor: NWPathMonitor
    
    public var semaphore: DispatchSemaphore? = DispatchSemaphore(value: 0)
    
    public var connectionStatus: NetworkConnectionStatus {
        didSet {
            for observer in observers.values {
                observer.didChangeConnectionStatus(connectionStatus)
            }
        }
    }
    
    public var connectionType: NetworkConnectionType? {
        didSet {
            for observer in observers.values {
                observer.didChangeConnectionType(connectionType)
            }
        }
    }
    
    private var observers: [String: NetworkStatusObserver]
    
    /// How long the first reader waits for the monitor's first path.
    static let firstPathTimeout: DispatchTimeInterval = .seconds(1)

    private init() {
        connectionStatus = .Offline
        connectionType = .none
        observers = [:]
        monitor = NWPathMonitor.init()
        
        monitor.pathUpdateHandler = { path in
            self.setConnection(path: path)
        }
        
        monitor.start(queue: DispatchQueue.global(qos: .default))
        
        // Waits for the first path so the first reader gets a real status, but never longer than
        // `firstPathTimeout`: a path update that never signals would block this thread for good.
        _ = semaphore?.wait(timeout: .now() + Self.firstPathTimeout)
        semaphore = nil
    }
    
    private func setConnection(path: NWPath) {
        var newConnectionStatus: NetworkConnectionStatus = .Offline
        var newConnectionType: NetworkConnectionType? = nil
        
        guard path.status == .satisfied else {
            newConnectionStatus = .Offline
            newConnectionType = .none
            if self.connectionStatus != newConnectionStatus {
                self.connectionStatus = newConnectionStatus
            }
            if self.connectionType != newConnectionType {
                self.connectionType = newConnectionType
            }
            semaphore?.signal()
            return
        }
        
        newConnectionStatus = .Online
        
        if path.usesInterfaceType(.cellular) {
            #if os(iOS)
                // A cellular path without a reported radio is still online: it used to return here
                // without updating the status or signalling the first reader, who then waited forever.
                let networkInfo = CTTelephonyNetworkInfo()
                newConnectionType = Self.cellularType(currentRadio: networkInfo.serviceCurrentRadioAccessTechnology?.values.first)
            #else
                newConnectionType = .cellular(radioType: .notdeterminedcellular)
            #endif
        } else if path.usesInterfaceType(.wifi) {
            newConnectionType = .wifi
        } else if path.usesInterfaceType(.wiredEthernet) {
            newConnectionType = .ethernet
        }
        
        if self.connectionStatus != newConnectionStatus {
            self.connectionStatus = newConnectionStatus
        }
        
        if self.connectionType != newConnectionType {
            self.connectionType = newConnectionType
        }
        semaphore?.signal()
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
            if #available(iOS 14.1, *) {
                switch currentRadio {
                case CTRadioAccessTechnologyNRNSA, CTRadioAccessTechnologyNR:
                    return .cellular(radioType: ._5G)
                default:
                    return .cellular(radioType: .notdeterminedcellular)
                }
            } else {
                return .cellular(radioType: .notdeterminedcellular)
            }
        }
    }
    #endif

    internal func addObserver(observer: NetworkStatusObserver) {
        observer.didChangeConnectionStatus(connectionStatus)
        observer.didChangeConnectionType(connectionType)
        observers[observer.connectionObserverId] = observer
    }
    
    internal func removeObserver(observer: NetworkStatusObserver) {
        observers[observer.connectionObserverId] = nil
    }
    
    deinit {
        monitor.cancel()
    }
}
