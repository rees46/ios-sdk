struct Constants {
    static let phonePrefix = "+7"
    static let phoneLength = 10
    static let testShopId = "357382bf66ac0ce2f1722677c59511"
    static let testItemIds = ["486"]
    static let testCurrentPrice = 170.0
    static let testApiDomain = "api.rees46.ru"
    static let testItemId = "486"
    // Network-backed integration tests can be slow/flaky on CI runners.
    static let defaultTimeout = 20.0
    
    static let testShopIdKey = "TEST_SHOP_ID"
    static let testApiUrlKey = "TEST_API_URL"
}
