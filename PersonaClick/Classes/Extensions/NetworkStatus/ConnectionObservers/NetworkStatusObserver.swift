import Foundation

public protocol NetworkStatusObserver {
    func startObserving()
    func stopObserving()
    func didChangeConnectionStatus(_ status: NetworkConnectionStatus)
    func didChangeConnectionType(_ type: NetworkConnectionType?)
}


public extension NetworkStatusObserver {
    internal var connectionObserverId: String {
        get {
            return String(unsafeBitCast(self, to: Int.self))
        }
    }
    
    func startObserving() {
        NetworkStatus.nManager.addObserver(observer: self)
    }
    
    func stopObserving() {
        NetworkStatus.nManager.removeObserver(observer: self)
    }
}
