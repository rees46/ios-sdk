import XCTest
@testable import REES46

class SubscribeForBackInStock: XCTestCase {
    
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
            enableLogs: true,
            needReInitialization: true
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

    /// Each test starts on a fresh did (`needReInitialization`), which has no email yet. The server
    /// sends this subscription by email, so a request without an email is refused with `400` ("The
    /// client doesn't have email"), with a phone in it or in the profile alike. The profile gives the
    /// did its email first, so a request without one relies on the did.
    private func giveTheDidAnEmail(_ email: String) {
        let registered = XCTestExpectation(description: "Profile gives the did an email")

        sdk.setProfileData(userEmail: email) { result in
            if case .failure(let error) = result {
                XCTFail("setProfileData failed: \(error.localizedDescription)")
            }
            registered.fulfill()
        }

        wait(for: [registered], timeout: Constants.defaultTimeout)
    }

    func testSubscribeForBackInStock_withEmailOnly() {
        let expectation = XCTestExpectation(description: "Subscribe with email only")
        
        sdk.subscribeForBackInStock(
            id: Constants.testItemId,
            email: testEmail
        ) { result in
            switch result {
            case .success:
                print("Subscribe with email succeeded")
            case .failure(let error):
                XCTFail("Subscribe with email failed: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: Constants.defaultTimeout)
    }
    
    func testSubscribeForBackInStock_withPhoneOnly() {
        giveTheDidAnEmail(testEmail)

        let expectation = XCTestExpectation(description: "Subscribe with phone only")
        
        sdk.subscribeForBackInStock(
            id: Constants.testItemId,
            phone: testPhone
        ) { result in
            switch result {
            case .success:
                print("Subscribe with phone succeeded")
            case .failure(let error):
                XCTFail("Subscribe with phone failed: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: Constants.defaultTimeout)
    }
    
    func testSubscribeForBackInStock_withEmailAndPhone() {
        let expectation = XCTestExpectation(description: "Subscribe with email and phone")
        
        sdk.subscribeForBackInStock(
            id: Constants.testItemId,
            email: testEmail,
            phone: testPhone
        ) { result in
            switch result {
            case .success:
                print("Subscribe with email+phone succeeded")
            case .failure(let error):
                XCTFail("Subscribe with email+phone failed: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: Constants.defaultTimeout)
    }
    
    func testSubscribeForBackInStock_withoutContactInfo() {
        giveTheDidAnEmail(testEmail)

        let expectation = XCTestExpectation(description: "Subscribe without contact info")
        
        sdk.subscribeForBackInStock(
            id: Constants.testItemId
        ) { result in
            switch result {
            case .success:
                print("Subscribe without contact info succeeded")
            case .failure(let error):
                XCTFail("Subscribe without contact info failed: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: Constants.defaultTimeout)
    }
}
