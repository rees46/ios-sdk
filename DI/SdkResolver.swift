import Foundation
import Resolver

extension Resolver {
    static func registerSdkPartsImpl() {
        register { SearchServiceImpl(sdk: resolve()) as SearchService }.scope(.application)
        register { PushTokenHandlerServiceImpl(sdk: resolve()) as PushTokenNotificationService }.scope(.application)
    }
}
