import XCTest
@testable import REES46

class SubscribeForBackInStock: XCTestCase {
    
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

    func testSubscribeForBackInStock_withEmailOnly() {
        let expectation = XCTestExpectation(description: "Subscribe with email only")
        
        sdk.subscribeForBackInStock(
            id: Constants.testItemId,
            email: testEmail,
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
        wait(for: [expectation], timeout: Constants.defaultTimeout)
    }
    
    func testSubscribeForBackInStock_withPhoneOnly() {
        let expectation = XCTestExpectation(description: "Subscribe with phone only")
        
        sdk.subscribeForBackInStock(
            id: Constants.testItemId,
            phone: testPhone,
            completion: { result in
                switch result {
                    case .success:
                        print("Subscribe with phone succeeded")
                    case .failure(let error):
                        XCTFail("Subscribe with phone failed: \(error.localizedDescription)")
                    }
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: Constants.defaultTimeout)
    }
    
    func testSubscribeForBackInStock_withEmailAndPhone() {
        let expectation = XCTestExpectation(description: "Subscribe with email and phone")
        
        sdk.subscribeForBackInStock(
            id: Constants.testItemId,
            email: testEmail,
            phone: testPhone,
            completion: { result in
                switch result {
                    case .success:
                        print("Subscribe with email and phone succeeded")
                    case .failure(let error):
                        XCTFail("Subscribe with email and phone failed: \(error.localizedDescription)")
                }
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: Constants.defaultTimeout)
    }
    
    func testSubscribeForBackInStock_withoutContactInfo() {
        let expectation = XCTestExpectation(description: "Subscribe without contact info")
        
        sdk.subscribeForBackInStock(
            id: Constants.testItemId,
            completion: { result in
                switch result {
                    case .success:
                        print("Subscribe with did succeeded")
                    case .failure(let error):
                        XCTFail("Subscribe with did failed: \(error.localizedDescription)")
                }
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: Constants.defaultTimeout)
    }
}
