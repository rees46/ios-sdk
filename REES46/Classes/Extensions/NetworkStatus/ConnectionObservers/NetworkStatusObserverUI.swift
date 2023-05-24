import Foundation

@available(iOS 13.0, macOS 10.15, *)
public class NetworkStatusObserverUI: ObservableObject {
    
    @Published
    public var connectionStatus: NetworkConnectionStatus
    
    @Published
    public var connectionType: NetworkConnectionType?
    
    private var hiddenObserver: HiddenObserver
    
    public init() {
        self.hiddenObserver = HiddenObserver()
        self.connectionStatus = .Offline
        self.connectionType = .none
        self.hiddenObserver.setExternalObserver(observer: self)
    }
    
    class HiddenObserver : NetworkStatusObserver {
        weak var externalObserver: NetworkStatusObserverUI?
        
        init() {
            startObserving()
        }
        
        func setExternalObserver(observer: NetworkStatusObserverUI) {
            self.externalObserver = observer
        }
        
        deinit {
            stopObserving()
        }
        
        public func didChangeConnectionStatus(_ status: NetworkConnectionStatus) {
            DispatchQueue.main.async {
                self.externalObserver?.connectionStatus = status
            }
        }
        
        public func didChangeConnectionType(_ type: NetworkConnectionType?) {
            DispatchQueue.main.async {
                self.externalObserver?.connectionType = type
            }
        }
    }
}
