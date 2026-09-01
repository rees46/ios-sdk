import Foundation

/// Demo configuration.
///
/// Xcode passes these through the scheme's environment variables, which lets a developer point the
/// demo at another shop without touching the project. A build installed from TestFlight has no such
/// environment, so the same keys are baked into `Info.plist` and used whenever the variable is
/// missing or blank.
struct AppEnvironments {
    static let blockId: String = value(for: "BLOCK_ID")
    static let shopId: String = value(for: "SHOP_ID")
    static let storiesCode: String = value(for: "STORIES_CODE")
    static let apiDomain: String = value(for: "BASE_PATH")
    static let recommendationId: String = value(for: "RECOMMENDATION_ID")
    static let imageUrl: String = value(for: "POP_UP_IMAGE_URL")

    private static func value(for key: String) -> String {
        if let fromEnvironment = ProcessInfo.processInfo.environment[key], !fromEnvironment.isEmpty {
            return fromEnvironment
        }
        return Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}
