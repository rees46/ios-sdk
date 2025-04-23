import XCTest
@testable import REES46

class UnsubscribePriceDrop: XCTestCase {
    
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
    
    func testUnsubscribePriceDrop_withEmailOnly() {
        let expectation = XCTestExpectation(description: "Unsubscribe PriceDrop with email")
        
        sdk.unsubscribeForPriceDrop(
            itemIds: testItemIds,
            currentPrice: testCurrentPrice,
            email: testEmail,
            completion: { result in
                switch result {
                    case .success:
                        print("Unsubscribe PriceDrop with email succeeded")
                    case .failure(let error):
                        XCTFail("Unsubscribe PriceDrop with email failed: \(error.localizedDescription)")
                }
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testUnsubscribePriceDrop_withPhoneOnly() {
        let expectation = XCTestExpectation(description: "Unsubscribe PriceDrop with phone")
        
        sdk.unsubscribeForPriceDrop(
            itemIds: testItemIds,
            currentPrice: testCurrentPrice,
            phone: testPhone,
            completion: { result in
                switch result {
                    case .success:
                        print("Unsubscribe PriceDrop with phone succeeded")
                    case .failure(let error):
                        XCTFail("Unsubscribe PriceDrop with phone failed: \(error.localizedDescription)")
                }
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testUnsubscribePriceDrop_withEmailAndPhone() {
        let expectation = XCTestExpectation(description: "Unsubscribe PriceDrop with email and phone")
        
        sdk.unsubscribeForPriceDrop(
            itemIds: testItemIds,
            currentPrice: testCurrentPrice,
            email: testEmail,
            phone: testPhone,
            completion: { result in
                switch result {
                    case .success:
                        print("Unsubscribe PriceDrop with email and phone succeeded")
                    case .failure(let error):
                        XCTFail("Unsubscribe PriceDrop with email and phone failed: \(error.localizedDescription)")
                }
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testUnsubscribePriceDrop_withoutContactInfo() {
        let expectation = XCTestExpectation(description: "Unsubscribe PriceDrop without contact info")
        
        sdk.unsubscribeForPriceDrop(
            itemIds: testItemIds,
            currentPrice: testCurrentPrice,
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
