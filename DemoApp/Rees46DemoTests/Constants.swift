import Foundation

struct Constants {
    static let phonePrefix = "+7"
    static let phoneLength = 10
    static let testItemIds = ["300275"]
    static let testCurrentPrice = 170.0
    static let testItemId = "300275"
    // Network-backed integration tests can be slow/flaky on CI runners.
    static let defaultTimeout = 20.0

    static let testShopIdKey = "TEST_SHOP_ID"
    static let testShopIdKey2 = "TEST_SHOP_ID_2"
    static let testApiUrlKey = "TEST_API_URL"

    /// Shop id used by the integration tests. Resolved from the CI-injected environment
    /// (`TEST_SHOP_ID`), falling back to the local default when the variable is not set.
    static var testShopId: String {
        ProcessInfo.processInfo.environment[testShopIdKey] ?? defaultShopId
    }

    /// Second (distinct, real) shop id for the multi-instance E2E. Resolved from `TEST_SHOP_ID_2`,
    /// falling back to a real demo shop — parity with Android's `SHOP_ID_2`.
    static var testShopIdB: String {
        ProcessInfo.processInfo.environment[testShopIdKey2] ?? defaultShopIdB
    }

    /// API domain used by the integration tests. Resolved from the CI-injected environment
    /// (`TEST_API_URL`), falling back to the local default when the variable is not set.
    static var testApiDomain: String {
        ProcessInfo.processInfo.environment[testApiUrlKey] ?? defaultApiDomain
    }

    private static let defaultShopId = "c1140c8254976de297c3caf971701a"
    private static let defaultShopIdB = "4b464e7c386120d4b621bf7cb79293"
    private static let defaultApiDomain = "api.rees46.ru"
}
