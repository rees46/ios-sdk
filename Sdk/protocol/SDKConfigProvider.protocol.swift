import Foundation

protocol SDKConfigProvider {
    var getConfigShopId: String { get }
    var getConfigDeviceId: String { get }
    var getConfigUserSeance: String { get }
}
