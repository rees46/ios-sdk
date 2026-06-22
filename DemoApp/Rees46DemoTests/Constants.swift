import Foundation

struct Constants {
    static let phonePrefix = "+7"
    static let phoneLength = 10
    static let testItemIds = ["486"]
    static let testCurrentPrice = 170.0
    static let testItemId = "486"
    // Network-backed integration tests can be slow/flaky on CI runners.
    static let defaultTimeout = 20.0

    static let testShopIdKey = "TEST_SHOP_ID"
    static let testApiUrlKey = "TEST_API_URL"

    /// Shop id used by the integration tests. Resolved from the CI-injected environment
    /// (`TEST_SHOP_ID`), falling back to the local default when the variable is not set.
    static var testShopId: String {
        ProcessInfo.processInfo.environment[testShopIdKey] ?? defaultShopId
    }

    /// API domain used by the integration tests. Resolved from the CI-injected environment
    /// (`TEST_API_URL`), falling back to the local default when the variable is not set.
    static var testApiDomain: String {
        ProcessInfo.processInfo.environment[testApiUrlKey] ?? defaultApiDomain
    }

    private static let defaultShopId = "357382bf66ac0ce2f1722677c59511"
    private static let defaultApiDomain = "api.rees46.ru"
}
