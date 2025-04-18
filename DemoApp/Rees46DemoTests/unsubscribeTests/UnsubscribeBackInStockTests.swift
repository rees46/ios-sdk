import XCTest
@testable import REES46

class UnsubscribeBackInStockTests: XCTestCase {
    
    private let testShopId = "357382bf66ac0ce2f1722677c59511"
    private let testItemIds = ["486"]
    
    private var testEmail: String!
    private var testPhone: String!
    
    var sdk: PersonalizationSDK!
    
    override func setUp() {
        super.setUp()
        testEmail = MockGenerator.generateEmail()
        testPhone = MockGenerator.generatePhoneNumber()
        
        sdk = createPersonalizationSDK(
            shopId: testShopId,
            apiDomain: "api.rees46.ru",
            enableLogs: true
        )
    }
    
    override func tearDown() {
        sdk = nil
        super.tearDown()
    }

    func testUnsubscribeBackInStock_withEmailOnly() {
        let expectation = XCTestExpectation(description: "Unsubscribe with email only")
        
        sdk.unsubscribeForBackInStock(
            itemIds: testItemIds,
            email: testEmail,
            completion: { result in
                switch result {
                    case .success:
                        print("Unsubscribe with email succeeded")
                    case .failure(let error):
                        XCTFail("Unsubscribe with email failed: \(error.localizedDescription)")
                }
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testUnsubscribeBackInStock_withPhoneOnly() {
        let expectation = XCTestExpectation(description: "Unsubscribe with phone only")
        
        sdk.unsubscribeForBackInStock(
            itemIds: testItemIds,
            phone: testPhone,
            completion: { result in
                switch result {
                    case .success:
                        print("Unsubscribe with phone succeeded")
                    case .failure(let error):
                        XCTFail("Unsubscribe with phone failed: \(error.localizedDescription)")
                }
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 5.0)
    }

    func testUnsubscribeBackInStock_withEmailAndPhone() {
        let expectation = XCTestExpectation(description: "Unsubscribe with email and phone")
        
        sdk.unsubscribeForBackInStock(
            itemIds: testItemIds,
            email: testEmail,
            phone: testPhone,
            completion: { result in
                switch result {
                    case .success:
                        print("Unsubscribe with email and phone succeeded")
                    case .failure(let error):
                        XCTFail("Unsubscribe with email and phone failed: \(error.localizedDescription)")
                }
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testUnsubscribeBackInStock_withoutContactInfo() {
        let expectation = XCTestExpectation(description: "Unsubscribe without contact info")
        
        sdk.unsubscribeForBackInStock(
            itemIds: testItemIds,
            completion: { result in
                switch result {
                    case .success:
                        print("Unubscribe with did succeeded")
                    case .failure(let error):
                        XCTFail("Unubscribe with did failed: \(error.localizedDescription)")
                }
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 5.0)
    }
}
