import XCTest
@testable import REES46

class ManageSubscription: XCTestCase {
    
    private var testEmail: String!
    private var testPhone: String!
    
    var sdk: PersonalizationSDK!
    
    override func setUp() {
        super.setUp()
        
        testEmail = MockGenerator.generateEmail()
        testPhone = MockGenerator.generatePhoneNumber()
        
        sdk = createPersonalizationSDK(
            shopId: Constants.testShopId,
            apiDomain: Constants.testApiDomain,
            enableLogs: true
        )
    }
    
    override func tearDown() {
        sdk = nil
        super.tearDown()
    }
    
    func testManageSubscription_withEmailOnly() {
        let expectation = XCTestExpectation(description: "Manage subscription with email only")
        
        self.sdk.manageSubscription(
            email: testEmail,
            completion: { result in
                switch result {
                    case .success:
                        print("Manage subscription with email succeeded")
                    case .failure(let error):
                        XCTFail("Manage subscription with email failed: \(error.localizedDescription)")
                }
                expectation.fulfill()
            }
        )
        
        wait(for: [expectation], timeout: Constants.defaultTimeout)
    }
    
    func testManageSubscription_withPhoneOnly() {
        let expectation = XCTestExpectation(description: "Manage subscription with phone only")
        
        self.sdk.manageSubscription(
            phone: testPhone,
            completion: { result in
                switch result {
                    case .success:
                        print("Manage subscription with phone succeeded")
                    case .failure(let error):
                        XCTFail("Manage subscription with phone failed: \(error.localizedDescription)")
                }
                expectation.fulfill()
            }
        )
        
        wait(for: [expectation], timeout: Constants.defaultTimeout)
    }
    
    func testManageSubscription_withEmailAndPhone() {
        let expectation = XCTestExpectation(description: "Manage subscription with email and phone")
        
        self.sdk.manageSubscription(
            email: testEmail,
            phone: testPhone,
            completion: { result in
                switch result {
                case .success:
                    print("Manage subscription with email and phone succeeded")
                case .failure(let error):
                    XCTFail("Manage subscription with email and phone failed: \(error.localizedDescription)")
                }
                expectation.fulfill()
            }
        )
        
        wait(for: [expectation], timeout: Constants.defaultTimeout)
    }
    
    func testManageSubscription_withoutContactInfo() {
        let expectation = XCTestExpectation(description: "Manage subscription without contact info")
        
        self.sdk.manageSubscription(
            completion: { result in
                switch result {
                    case .success:
                        print("Manage subscription without contact info succeeded")
                    case .failure(let error):
                        XCTFail("Manage subscription without contact info failed: \(error.localizedDescription)")
                }
                expectation.fulfill()
            }
        )
        
        wait(for: [expectation], timeout: Constants.defaultTimeout)
    }
}
