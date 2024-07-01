
import Foundation

class RequestParamsBuilder {
    static func buildCommonParams(sdk: PersonalizationSDK) -> [String: String] {
        return [
            NotificationConstants.shopId: sdk.shopId,
            NotificationConstants.did: sdk.deviceId
        ]
    }
}
