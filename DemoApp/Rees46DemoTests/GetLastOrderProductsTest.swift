import XCTest
import REES46

/// Integration test for `getLastOrderProducts` hitting the real `orders/last_for_user` endpoint.
class GetLastOrderProductsTests: XCTestCase {

    var sdk: PersonalizationSDK?
    let TAG = "GetLastOrderProductsTests"

    override func setUp() {
        super.setUp()
        sdk = nil
    }

    override func tearDown() {
        sdk = nil
        super.tearDown()
    }

    func test_get_last_order_products_returns_result() {
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

        let expectation = XCTestExpectation(description: "getLastOrderProducts completion")
        sdk?.getLastOrderProducts { result in
            switch result {
            case .success(let response):
                // A fresh device usually has no orders, so an empty list is a valid result.
                XCTAssertGreaterThanOrEqual(response.products.count, 0)
            case .failure(let error):
                XCTFail("\(self.TAG): getLastOrderProducts failed: \(error)")
            }
            expectation.fulfill()
        }
        let result = XCTWaiter.wait(for: [expectation], timeout: Constants.defaultTimeout)
        if result != .completed {
            XCTFail("\(TAG): Timeout in getLastOrderProducts: \(result)")
        }
    }
}
