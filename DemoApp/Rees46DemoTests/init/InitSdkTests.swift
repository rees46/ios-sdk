import XCTest
@testable import REES46

final class InitSdkTests: XCTestCase {

    func testInitWithReInitializationTrue_CallsCompletion() {
        let expectation = self.expectation(description: "Completion called")

        _ = createPersonalizationSDK(
            shopId: Constants.testShopId,
            apiDomain: Constants.testApiDomain,
            needReInitialization: true
        ) {
            error in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testInitWithReInitializationFalse_CallsCompletion() {
        let expectation = self.expectation(description: "Completion called")

        _ = createPersonalizationSDK(
            shopId: Constants.testShopId,
            apiDomain: Constants.testApiDomain,
            needReInitialization: false
        ) {
            error in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testInitWithParentViewController_CallsCompletion() {
        let expectation = self.expectation(description: "Completion called")
        let vc = UIViewController()

        _ = createPersonalizationSDK(
            shopId: Constants.testShopId,
            parentViewController: vc,
            needReInitialization: true
        ) {
            error in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMultipleInits_CallsCompletionForAll() {
        let exp1 = expectation(description: "Completion 1")
        let exp2 = expectation(description: "Completion 2")

        _ = createPersonalizationSDK(
            shopId: Constants.testShopId,
            needReInitialization: true
        ) {
            error in
            XCTAssertNil(error)
            exp1.fulfill()
        }

        _ = createPersonalizationSDK(
            shopId: Constants.testShopId,
            needReInitialization: false
        ) {
            error in
            XCTAssertNil(error)
            exp2.fulfill()
        }

        wait(for: [exp1, exp2], timeout: 2.0)
    }
}
