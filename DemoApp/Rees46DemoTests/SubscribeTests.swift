import XCTest
@testable import REES46

class SubscibeTests: XCTestCase {

    var sdk: PersonalizationSDK!
    
    let shopId = "357382bf66ac0ce2f1722677c59511"

    override func setUp() {
        super.setUp()
        sdk = createPersonalizationSDK(
            shopId: shopId,
            apiDomain: "api.rees46.ru",
            enableLogs: true
        )
    }
    
    override func tearDown() {
        sdk = nil
        super.tearDown()
    }
    
    func testSubscribe_withoutPhone() {
        let expectation = XCTestExpectation(description: "Subscribe for back in stock completion")
        
        sdk?.subscribeForBackInStock(
            id: "486",
            email: "testemail@mail.ru",
            completion: { result in
                switch result {
                case .success:
                    print("Unsubscribe succeeded")
                case .failure(let error):
                    XCTFail("Unsubscribe failed with error: \(error.localizedDescription)")
                }
                
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSubscribe_withoutEmail() {
        let expectation = XCTestExpectation(description: "Subscribe for back in stock completion")
        
        sdk?.subscribeForBackInStock(
            id: "486",
            phone: "+79966999666",
            completion: { result in
                switch result {
                case .success:
                    print("Subscribe succeeded")
                case .failure(let error):
                    XCTFail("Subscribe failed with error: \(error.localizedDescription)")
                }
                
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSubscribe_withoutParams() {
        let expectation = XCTestExpectation(description: "Subscribe for back in stock completion")
        
        sdk?.subscribeForBackInStock(
            id: "486",
            completion: { result in
                switch result {
                case .success:
                    XCTFail("Subscribe should fail when no email or phone provided")
                case .failure(let error):
                    print("Subscribe failed as expected with error: \(error.localizedDescription)")
                }
                
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testUnsubscribe_withoutEmail() {
        let expectation = XCTestExpectation(description: "Subscribe for back in stock completion")
        
        sdk?.unsubscribeForBackInStock(
            itemIds: ["486"],
            phone: "+79966999666",
            completion: { result in
                switch result {
                case .success:
                    print("Unsubscribe succeeded")
                case .failure(let error):
                    XCTFail("Unsubscribe failed with error: \(error.localizedDescription)")
                }
                
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 5.0)
    }
    func testUnsubscribe_withoutPhone() {
        let expectation = XCTestExpectation(description: "Subscribe for back in stock completion")
        
        sdk?.unsubscribeForBackInStock(
            itemIds: ["486"],
            email: "aaaaaa@mail.ru",
            completion: { result in
                switch result {
                case .success:
                    print("Unsubscribe succeeded")
                case .failure(let error):
                    XCTFail("Unsubscribe failed with error: \(error.localizedDescription)")
                }
                
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testUnsubscribe_withoutParams() {
        let expectation = XCTestExpectation(description: "Subscribe for back in stock completion")
        
        sdk?.unsubscribeForBackInStock(
            itemIds: ["486"],
            completion: { result in
                switch result {
                case .success:
                    XCTFail("Subscribe should fail when no email or phone provided")
                case .failure(let error):
                    print("Subscribe failed as expected with error: \(error.localizedDescription)")
                }
                
                expectation.fulfill()
            }
        )
        wait(for: [expectation], timeout: 5.0)
    }
}
