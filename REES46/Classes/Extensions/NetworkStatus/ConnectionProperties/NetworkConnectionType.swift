import Foundation

public enum NetworkConnectionType: Equatable, CustomStringConvertible {
    case cellular(radioType: NetworkRadioType)
    case wifi
    case ethernet
    case notdetected
    
    public var description: String {
        switch self {
        case .cellular(let radioType):
            return "Cellular(" + radioType.description + ")"
        case .wifi:
            return "WiFi"
        case .ethernet:
            return "Ethernet"
        case .notdetected:
            return "AirplaneMode"
        }
    }
}
