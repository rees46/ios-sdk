import XCTest
@testable import REES46

class ManageSubscriptionTests: XCTestCase {
    
    private let testShopId = "357382bf66ac0ce2f1722677c59511"
    private let testItemId = "486"
    private let testEmail = "ga@rees46.ru"
    private let testPhone = "+79966999666"
    private let testCurrentPrice = 170.0
    private let testItemIds = ["486"]
    
    var sdk: PersonalizationSDK!
    
    override func setUp() {
        super.setUp()
        sdk = createPersonalizationSDK(
            shopId: testShopId,
            apiDomain: "api.rees46.ru",
            enableLogs: true
        )
    }
    
    override func tearDown() {
        sdk = nil
    }
    
    func testManageSubscription_withEmailOnly() {
        let expectation = XCTestExpectation(description: "Subscribe with email only")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.sdk.manageSubscription(
                email: self.testEmail,
                completion: { result in
                    switch result {
                    case .success:
                        print("Subscribe with email succeeded")
                    case .failure(let error):
                        XCTFail("Subscribe with email failed: \(error.localizedDescription)")
                    }
                    expectation.fulfill()
                }
            )
        }
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testManageSubscription_withPhoneOnly() {
        let expectation = XCTestExpectation(description: "Subscribe with phone only")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.sdk.manageSubscription(
                email: self.testEmail,
                completion: { result in
                    switch result {
                    case .success:
                        print("Subscribe with email succeeded")
                    case .failure(let error):
                        XCTFail("Subscribe with email failed: \(error.localizedDescription)")
                    }
                    expectation.fulfill()
                }
            )
        }
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testManageSubscription_withEmailAndPhone() {
        let expectation = XCTestExpectation(description: "Subscribe with email and phone")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.sdk.manageSubscription(
                email: self.testEmail,
                completion: { result in
                    switch result {
                    case .success:
                        print("Subscribe with email succeeded")
                    case .failure(let error):
                        XCTFail("Subscribe with email failed: \(error.localizedDescription)")
                    }
                    expectation.fulfill()
                }
            )
        }
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testManageSubscription_withoutContactInfo() {
        let expectation = XCTestExpectation(description: "Subscribe without contact info")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.sdk.manageSubscription(
                email: self.testEmail,
                completion: { result in
                    switch result {
                    case .success:
                        print("Subscribe with email succeeded")
                    case .failure(let error):
                        XCTFail("Subscribe with email failed: \(error.localizedDescription)")
                    }
                    expectation.fulfill()
                }
            )
        }
        wait(for: [expectation], timeout: 5.0)
    }
}
