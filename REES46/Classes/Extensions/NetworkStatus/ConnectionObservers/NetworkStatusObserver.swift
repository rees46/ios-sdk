import Foundation

public protocol NetworkStatusObserver {
    func startObserving()
    func stopObserving()
    func didChangeConnectionStatus(_ status: NetworkConnectionStatus)
    func didChangeConnectionType(_ type: NetworkConnectionType?)
}

@available(iOS 12.0, *)
public extension NetworkStatusObserver {
    internal var connectionObserverId : String {
        get {
            return String(unsafeBitCast(self, to: Int.self))
        }
    }
    
    func startObserving() {
        NetworkStatus.shared.addObserver(observer: self)
    }
    
    func stopObserving() {
        NetworkStatus.shared.removeObserver(observer: self)
    }
}