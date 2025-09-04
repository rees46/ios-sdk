import XCTest
@testable import REES46

class UnsubscribeBackInStock: XCTestCase {
    
    private var testEmail: String!
    private var testPhone: String!
    
    private var sdk: PersonalizationSDK!
    
    override func setUp() {
        super.setUp()
        
        testEmail = MockGenerator.generateEmail()
        testPhone = MockGenerator.generatePhoneNumber()
        
        let expectation = XCTestExpectation(description: "SDK init")
        
        sdk = createPersonalizationSDK(
            shopId: Constants.testShopId,
            apiDomain: Constants.testApiDomain,
            enableLogs: true
        ) { error in
            if let error = error {
                XCTFail("SDK init failed: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: Constants.defaultTimeout)
    }
    
    override func tearDown() {
        sdk = nil
        super.tearDown()
    }

    func testUnsubscribeBackInStock_withEmailOnly() {
        let expectation = XCTestExpectation(description: "Unsubscribe with email only")
        
        sdk.unsubscribeForBackInStock(
            itemIds: Constants.testItemIds,
            email: testEmail
        ) { result in
            switch result {
            case .success:
                print("Unsubscribe with email succeeded")
            case .failure(let error):
                XCTFail("Unsubscribe with email failed: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: Constants.defaultTimeout)
    }
    
    func testUnsubscribeBackInStock_withPhoneOnly() {
        let expectation = XCTestExpectation(description: "Unsubscribe with phone only")
        
        sdk.unsubscribeForBackInStock(
            itemIds: Constants.testItemIds,
            phone: testPhone
        ) { result in
            switch result {
            case .success:
                print("Unsubscribe with phone succeeded")
            case .failure(let error):
                XCTFail("Unsubscribe with phone failed: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: Constants.defaultTimeout)
    }

    func testUnsubscribeBackInStock_withEmailAndPhone() {
        let expectation = XCTestExpectation(description: "Unsubscribe with email and phone")
        
        sdk.unsubscribeForBackInStock(
            itemIds: Constants.testItemIds,
            email: testEmail,
            phone: testPhone
        ) { result in
            switch result {
            case .success:
                print("Unsubscribe with email and phone succeeded")
            case .failure(let error):
                XCTFail("Unsubscribe with email and phone failed: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: Constants.defaultTimeout)
    }
    
    func testUnsubscribeBackInStock_withoutContactInfo() {
        let expectation = XCTestExpectation(description: "Unsubscribe without contact info")
        
        sdk.unsubscribeForBackInStock(
            itemIds: Constants.testItemIds
        ) { result in
            switch result {
            case .success:
                print("Unsubscribe without contact info succeeded")
            case .failure(let error):
                XCTFail("Unsubscribe without contact info failed: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: Constants.defaultTimeout)
    }
}
