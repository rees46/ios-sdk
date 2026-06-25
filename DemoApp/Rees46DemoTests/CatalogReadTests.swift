import XCTest
@testable import REES46

/// Integration tests for the catalog/profile read methods
/// (`GET /profile`, `GET /products/counters`, `GET /category/{slug}`).
///
/// Mirrors `LoyaltyTests`: the shop is taken from the `TEST_SHOP_ID` / `TEST_API_URL`
/// environment (injected by CI) with a fallback to the shared constants.
class CatalogReadTests: XCTestCase {

    var sdk: PersonalizationSDK!

    var shopId: String {
        return ProcessInfo.processInfo.environment[Constants.testShopIdKey] ?? Constants.testShopId
    }

    var apiDomain: String {
        return ProcessInfo.processInfo.environment[Constants.testApiUrlKey] ?? Constants.testApiDomain
    }

    /// Category slug present in the integration test shop's catalog.
    private let categorySlug = "smartfony-i-gadzhety"
    /// Item id present in the integration test shop's catalog.
    private let itemId = "300275"
    /// Collection id configured in the integration test shop's dashboard.
    private let collectionId = "1"

    override func setUp() {
        super.setUp()
        sdk = createPersonalizationSDK(
            shopId: shopId,
            apiDomain: apiDomain,
            parentViewController: nil
        )
    }

    override func tearDown() {
        sdk = nil
        super.tearDown()
    }

    func testGetProfile_returnsSuccess() {
        let expectation = self.expectation(description: "getProfile completion")

        sdk?.getProfile { result in
            switch result {
            case .success(let response):
                // Profile is freeform; custom_properties always parses (at least to [:]).
                XCTAssertNotNil(response.customProperties)
            case .failure(let error):
                XCTFail("getProfile failed with error: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)
    }

    func testGetProductCounters_returnsSuccess() {
        let expectation = self.expectation(description: "getProductCounters completion")

        sdk?.getProductCounters(item: itemId) { result in
            switch result {
            case .success(let response):
                XCTAssertNotNil(response.triggers)
            case .failure(let error):
                XCTFail("getProductCounters failed with error: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)
    }

    func testGetCategory_returnsProducts() {
        let expectation = self.expectation(description: "getCategory completion")

        sdk?.getCategory(category: categorySlug, limit: 5) { result in
            switch result {
            case .success(let response):
                XCTAssertGreaterThan(response.productsTotal, 0)
                XCTAssertFalse(response.products.isEmpty)
            case .failure(let error):
                XCTFail("getCategory failed with error: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)
    }

    func testGetCollection_returnsProducts() {
        let expectation = self.expectation(description: "getCollection completion")

        sdk?.getCollection(collectionId: collectionId) { result in
            switch result {
            case .success(let response):
                XCTAssertFalse(response.products.isEmpty)
            case .failure(let error):
                XCTFail("getCollection failed with error: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)
    }
}
