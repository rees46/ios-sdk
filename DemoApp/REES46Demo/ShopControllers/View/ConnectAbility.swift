import SystemConfiguration
import Foundation

public enum ConnectAbilityError: Error {
    case FailedToCreateWithAddress(sockaddr_in)
    case FailedToCreateWithHostname(String)
    case UnableToSetCallback
    case UnableToSetDispatchQueue
}

public let ConnectAbilityChangedNotification = NSNotification.Name("ConnectAbilityChangedNotification")

func callback(reachability:SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer?) {

    guard let info = info else { return }
    
    let reachability = Unmanaged<ConnectAbility>.fromOpaque(info).takeUnretainedValue()

    DispatchQueue.main.async { 
        reachability.reachabilityChanged()
    }
}

public class ConnectAbility {

    public typealias NetworkReachable = (ConnectAbility) -> ()
    public typealias NetworkUnreachable = (ConnectAbility) -> ()

    public enum NetworkStatus: CustomStringConvertible {

        case notReachable, reachableViaWiFi, reachableViaWWAN

        public var description: String {
            switch self {
            case .reachableViaWWAN: return "Cellular"
            case .reachableViaWiFi: return "WiFi"
            case .notReachable: return "No Connection"
            }
        }
    }

    public var whenReachable: NetworkReachable?
    public var whenUnreachable: NetworkUnreachable?
    public var reachableOnWWAN: Bool

    public var currentConnectAbilityString: String {
        return "\(currentConnectAbilityStatus)"
    }

    public var currentConnectAbilityStatus: NetworkStatus {
        guard isReachable else { return .notReachable }
        
        if isReachableViaWiFi {
            return .reachableViaWiFi
        }
        if isRunningOnDevice {
            return .reachableViaWWAN
        }
        
        return .notReachable
    }
    
    fileprivate var previousFlags: SCNetworkReachabilityFlags?
    
    fileprivate var isRunningOnDevice: Bool = {
        #if (arch(i386) || arch(x86_64)) && os(iOS)
            return false
        #else
            return true
    #endif
    }()
    
    fileprivate var notifierRunning = false
    fileprivate var reachabilityRef: SCNetworkReachability?
    
    fileprivate let reachabilitySerialQueue = DispatchQueue(label: "net.personal.reach")
    
    required public init(reachabilityRef: SCNetworkReachability) {
        reachableOnWWAN = true
        self.reachabilityRef = reachabilityRef
    }
    
    public convenience init?(hostname: String) {
        
        guard let ref = SCNetworkReachabilityCreateWithName(nil, hostname) else { return nil }
        
        self.init(reachabilityRef: ref)
    }
    
    public convenience init?() {
        
        var zeroAddress = sockaddr()
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)
        
        guard let ref: SCNetworkReachability = withUnsafePointer(to: &zeroAddress, {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
        }) else { return nil }
        
        self.init(reachabilityRef: ref)
    }
    
    deinit {
        stopNotifier()

        reachabilityRef = nil
        whenReachable = nil
        whenUnreachable = nil
    }
}

public extension ConnectAbility {
    func startNotifier() throws {
        
        guard let reachabilityRef = reachabilityRef, !notifierRunning else { return }
        
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = UnsafeMutableRawPointer(Unmanaged<ConnectAbility>.passUnretained(self).toOpaque())        
        if !SCNetworkReachabilitySetCallback(reachabilityRef, callback, &context) {
            stopNotifier()
            throw ConnectAbilityError.UnableToSetCallback
        }
        
        if !SCNetworkReachabilitySetDispatchQueue(reachabilityRef, reachabilitySerialQueue) {
            stopNotifier()
            throw ConnectAbilityError.UnableToSetDispatchQueue
        }
        
        reachabilitySerialQueue.async {
            self.reachabilityChanged()
        }
        
        notifierRunning = true
    }
    
    func stopNotifier() {
        defer { notifierRunning = false }
        guard let reachabilityRef = reachabilityRef else { return }
        
        SCNetworkReachabilitySetCallback(reachabilityRef, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachabilityRef, nil)
    }
    
    var isReachable: Bool {
        
        guard isReachableFlagSet else { return false }
        
        if isConnectionRequiredAndTransientFlagSet {
            return false
        }
        
        if isRunningOnDevice {
            if isOnWWANFlagSet && !reachableOnWWAN {
                return false
            }
        }
        
        return true
    }
    
    var isReachableViaWWAN: Bool {
        return isRunningOnDevice && isReachableFlagSet && isOnWWANFlagSet
    }
    
    var isReachableViaWiFi: Bool {
        
        guard isReachableFlagSet else { return false }
        
        guard isRunningOnDevice else { return true }
        
        return !isOnWWANFlagSet
    }
    
    var description: String {
        
        let W = isRunningOnDevice ? (isOnWWANFlagSet ? "W" : "-") : "X"
        let R = isReachableFlagSet ? "R" : "-"
        let c = isConnectionRequiredFlagSet ? "c" : "-"
        let t = isTransientConnectionFlagSet ? "t" : "-"
        let i = isInterventionRequiredFlagSet ? "i" : "-"
        let C = isConnectionOnTrafficFlagSet ? "C" : "-"
        let D = isConnectionOnDemandFlagSet ? "D" : "-"
        let l = isLocalAddressFlagSet ? "l" : "-"
        let d = isDirectFlagSet ? "d" : "-"
        
        return "\(W)\(R) \(c)\(t)\(i)\(C)\(D)\(l)\(d)"
    }
}


fileprivate extension ConnectAbility {
    func reachabilityChanged() {
        
        let flags = reachabilityFlags
        
        guard previousFlags != flags else { return }
        
        let block = isReachable ? whenReachable : whenUnreachable
        block?(self)
        
        NotificationCenter.default.post(name: ConnectAbilityChangedNotification, object:self)
        
        previousFlags = flags
    }
    
    var isOnWWANFlagSet: Bool {
#if os(iOS)
            return reachabilityFlags.contains(.isWWAN)
#else
            return false
#endif
    }
    var isReachableFlagSet: Bool {
        return reachabilityFlags.contains(.reachable)
    }
    var isConnectionRequiredFlagSet: Bool {
        return reachabilityFlags.contains(.connectionRequired)
    }
    var isInterventionRequiredFlagSet: Bool {
        return reachabilityFlags.contains(.interventionRequired)
    }
    var isConnectionOnTrafficFlagSet: Bool {
        return reachabilityFlags.contains(.connectionOnTraffic)
    }
    var isConnectionOnDemandFlagSet: Bool {
        return reachabilityFlags.contains(.connectionOnDemand)
    }
    var isConnectionOnTrafficOrDemandFlagSet: Bool {
        return !reachabilityFlags.intersection([.connectionOnTraffic, .connectionOnDemand]).isEmpty
    }
    var isTransientConnectionFlagSet: Bool {
        return reachabilityFlags.contains(.transientConnection)
    }
    var isLocalAddressFlagSet: Bool {
        return reachabilityFlags.contains(.isLocalAddress)
    }
    var isDirectFlagSet: Bool {
        return reachabilityFlags.contains(.isDirect)
    }
    var isConnectionRequiredAndTransientFlagSet: Bool {
        return reachabilityFlags.intersection([.connectionRequired, .transientConnection]) == [.connectionRequired, .transientConnection]
    }
    
    var reachabilityFlags: SCNetworkReachabilityFlags {
        
        guard let reachabilityRef = reachabilityRef else { return SCNetworkReachabilityFlags() }
        
        var flags = SCNetworkReachabilityFlags()
        let gotFlags = withUnsafeMutablePointer(to: &flags) {
            SCNetworkReachabilityGetFlags(reachabilityRef, UnsafeMutablePointer($0))
        }
        
        if gotFlags {
            return flags
        } else {
            return SCNetworkReachabilityFlags()
        }
    }
}
