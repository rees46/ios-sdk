import XCTest
import REES46

/// Integration tests for the loyalty methods (`loyalty/members/join`, `loyalty/members/status`).
///
/// NOTE: real responses require a shop configured with a loyalty program, which is not guaranteed
/// in the test environment, so the calls may fail. The tests only assert that each request
/// completes (success or failure) without hanging or crashing.
class LoyaltyTests: XCTestCase {

    var sdk: PersonalizationSDK?
    let TAG = "LoyaltyTests"

    // Allow CI / local runs to point at a real shop via env vars, falling back to the shared constants.
    var shopId: String {
        return ProcessInfo.processInfo.environment[Constants.testShopIdKey] ?? Constants.testShopId
    }

    var apiDomain: String {
        return ProcessInfo.processInfo.environment[Constants.testApiUrlKey] ?? Constants.testApiDomain
    }

    override func setUp() {
        super.setUp()
        sdk = nil
    }

    override func tearDown() {
        sdk = nil
        super.tearDown()
    }

    private func initSdk() -> Bool {
        let initExpectation = XCTestExpectation(description: "SDK initialized")
        sdk = createPersonalizationSDK(
            shopId: shopId,
            apiDomain: apiDomain,
            parentViewController: nil,
            needReInitialization: true
        ) { error in
            XCTAssertNil(error, "\(self.TAG): init failed: \(error?.localizedDescription ?? "unknown")")
            initExpectation.fulfill()
        }
        let initResult = XCTWaiter.wait(for: [initExpectation], timeout: Constants.defaultTimeout)
        if initResult != .completed {
            XCTFail("\(TAG): Timeout during SDK initialization: \(initResult)")
            return false
        }
        return true
    }

    func test_join_loyalty_completes() {
        guard initSdk() else { return }

        let expectation = XCTestExpectation(description: "joinLoyalty completion")
        sdk?.joinLoyalty(
            phone: "79991234567",
            email: "demo@rees46.ru",
            firstName: "Demo",
            lastName: "User"
        ) { result in
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
            case .failure:
                // Expected when the shop has no loyalty program configured.
                break
            }
            expectation.fulfill()
        }
        let result = XCTWaiter.wait(for: [expectation], timeout: Constants.defaultTimeout)
        if result != .completed {
            XCTFail("\(TAG): Timeout in joinLoyalty: \(result)")
        }
    }

    func test_loyalty_status_completes() {
        guard initSdk() else { return }

        let expectation = XCTestExpectation(description: "getLoyaltyStatus completion")
        sdk?.getLoyaltyStatus(identifier: "79991234567") { result in
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
            case .failure:
                // Expected when the shop has no loyalty program configured.
                break
            }
            expectation.fulfill()
        }
        let result = XCTWaiter.wait(for: [expectation], timeout: Constants.defaultTimeout)
        if result != .completed {
            XCTFail("\(TAG): Timeout in getLoyaltyStatus: \(result)")
        }
    }
}
