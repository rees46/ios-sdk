import XCTest
import REES46

/// Integration test for `getUserOrders` (`orders/by_user`).
///
/// NOTE: a real response requires a valid server-side `shop_secret`, which is not available
/// in the test environment, so the call is expected to fail (e.g. 403). The test only asserts
/// that the request completes (success or failure) without hanging or crashing.
class GetUserOrdersTests: XCTestCase {

    var sdk: PersonalizationSDK?
    let TAG = "GetUserOrdersTests"

    override func setUp() {
        super.setUp()
        sdk = nil
    }

    override func tearDown() {
        sdk = nil
        super.tearDown()
    }

    func test_get_user_orders_completes() {
        let initExpectation = XCTestExpectation(description: "SDK initialized")
        sdk = createPersonalizationSDK(
            shopId: Constants.testShopId,
            apiDomain: Constants.testApiDomain,
            parentViewController: nil,
            needReInitialization: true
        ) { error in
            XCTAssertNil(error, "\(self.TAG): init failed: \(error?.localizedDescription ?? "unknown")")
            initExpectation.fulfill()
        }
        let initResult = XCTWaiter.wait(for: [initExpectation], timeout: Constants.defaultTimeout)
        if initResult != .completed {
            XCTFail("\(TAG): Timeout during SDK initialization: \(initResult)")
            return
        }

        let expectation = XCTestExpectation(description: "getUserOrders completion")
        // Placeholder secret — call is expected to fail without a valid shop_secret.
        sdk?.getUserOrders(shopSecret: "demo-shop-secret") { result in
            switch result {
            case .success(let orders):
                XCTAssertGreaterThanOrEqual(orders.count, 0)
            case .failure:
                // Expected without a valid shop_secret.
                break
            }
            expectation.fulfill()
        }
        let result = XCTWaiter.wait(for: [expectation], timeout: Constants.defaultTimeout)
        if result != .completed {
            XCTFail("\(TAG): Timeout in getUserOrders: \(result)")
        }
    }
}
