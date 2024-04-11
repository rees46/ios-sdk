import Foundation

class ConnectAbilityManager: NSObject {
    
    static let shared = ConnectAbilityManager()
    
    var isNetworkAvailable : Bool {
        return reachabilityStatus != .notReachable
    }
    
    var reachabilityStatus: ConnectAbility.NetworkStatus = .notReachable
    
    let reachability = ConnectAbility()!
    
    @objc func reachabilityChanged(notification: Notification) {
        let reachability = notification.object as! ConnectAbility
        switch reachability.currentConnectAbilityStatus {
        case .notReachable:
            debugPrint("Network became unreachable")
        case .reachableViaWiFi:
            debugPrint("Network reachable through WiFi")
        case .reachableViaWWAN:
            debugPrint("Network reachable through Cellular Data")
        }
    }
    
    func startMonitoring() {
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.reachabilityChanged),
                                               name: ConnectAbilityChangedNotification,
                                               object: reachability)
        do {
            try reachability.startNotifier()
        } catch {
            debugPrint("SDK: Could not start reachability notifier")
        }
    }
    
    func stopMonitoring(){
        reachability.stopNotifier()
        NotificationCenter.default.removeObserver(self, name: ConnectAbilityChangedNotification,
                                                  object: reachability)
    }
}
