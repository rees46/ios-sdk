import XCTest
@testable import REES46

/// Integration tests for the loyalty methods (`loyalty/members/join`, `loyalty/members/status`).
///
/// Mirrors `SearchServiceImplTests`: the shop is taken from the `TEST_SHOP_ID` / `TEST_API_URL`
/// environment (injected by CI) with a fallback to the shared constants. Requires the configured
/// shop to have a loyalty program enabled.
class LoyaltyTests: XCTestCase {

    var sdk: PersonalizationSDK!

    var shopId: String {
        return ProcessInfo.processInfo.environment[Constants.testShopIdKey] ?? Constants.testShopId
    }

    var apiDomain: String {
        return ProcessInfo.processInfo.environment[Constants.testApiUrlKey] ?? Constants.testApiDomain
    }

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

    func testJoinLoyalty_returnsSuccess() {
        let expectation = self.expectation(description: "joinLoyalty completion")

        sdk?.joinLoyalty(
            phone: "79991234567",
            email: "demo@rees46.ru",
            firstName: "Demo",
            lastName: "User"
        ) { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.status, "success")
            case .failure(let error):
                XCTFail("joinLoyalty failed with error: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)
    }

    func testGetLoyaltyStatus_returnsSuccess() {
        let expectation = self.expectation(description: "getLoyaltyStatus completion")

        sdk?.getLoyaltyStatus(identifier: "79991234567") { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.status, "success")
            case .failure(let error):
                XCTFail("getLoyaltyStatus failed with error: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)
    }
}
