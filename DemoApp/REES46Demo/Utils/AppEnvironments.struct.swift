import Foundation

struct AppEnvironments {
    static let blockId: String = ProcessInfo.processInfo.environment["BLOCK_ID"] ?? ""
    static let shopId: String = ProcessInfo.processInfo.environment["SHOP_ID"] ?? ""
    static let storiesCode: String = ProcessInfo.processInfo.environment["STORIES_CODE"] ?? ""
    static let apiDomain: String = ProcessInfo.processInfo.environment["BASE_PATH"] ?? ""
    static let recommendationId: String = ProcessInfo.processInfo.environment["RECOMMENDATION_ID"] ?? ""
}
