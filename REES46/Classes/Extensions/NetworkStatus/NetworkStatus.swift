import Network
#if os(iOS)
import CoreTelephony
#endif

@available(iOS 12.0, *)
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
    
    private init() {
        connectionStatus = .Offline
        connectionType = .none
        observers = [:]
        monitor = NWPathMonitor.init()
        
        monitor.pathUpdateHandler = { path in
            self.setConnection(path: path)
        }
        
        monitor.start(queue: DispatchQueue.global(qos: .default))
        
        semaphore?.wait()
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
                let networkInfo = CTTelephonyNetworkInfo()
                guard let currentRadio = networkInfo.serviceCurrentRadioAccessTechnology?.values.first else {
                    newConnectionType = .cellular(radioType: .notdeterminedcellular)
                    return
                }
                switch currentRadio {
                case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x:
                    newConnectionType = .cellular(radioType: ._2G)
                case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA, CTRadioAccessTechnologyCDMAEVDORev0, CTRadioAccessTechnologyCDMAEVDORevA, CTRadioAccessTechnologyCDMAEVDORevB, CTRadioAccessTechnologyeHRPD:
                    newConnectionType = .cellular(radioType: ._3G)
                case CTRadioAccessTechnologyLTE:
                    newConnectionType = .cellular(radioType: ._4G)
                default:
                    if #available(iOS 14.1, *) {
                        switch currentRadio {
                        case CTRadioAccessTechnologyNRNSA, CTRadioAccessTechnologyNR:
                            newConnectionType = .cellular(radioType: ._5G)
                        default:
                            newConnectionType = .cellular(radioType: .notdeterminedcellular)
                        }
                    } else {
                        newConnectionType = .cellular(radioType: .notdeterminedcellular)
                    }
                }
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
