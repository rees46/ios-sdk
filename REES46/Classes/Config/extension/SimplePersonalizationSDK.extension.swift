import Foundation

extension SimplePersonalizationSDK: SDKConfigProvider {
    var getConfigShopId: String {
        return self.shopId
    }

    var getConfigDeviceId: String {
        return self.deviceId
    }

    var getConfigUserSeance: String {
        return self.userSeance
    }
}
