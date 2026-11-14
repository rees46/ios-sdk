import XCTest
import Fakery
@testable import REES46

class SubscribeForPriceDrop: XCTestCase {
    
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
    
    /// The did here is whatever an earlier test left in the store, and may be a fresh one without an
    /// email. The server sends this subscription by email, so a request without an email is then
    /// refused with `400` ("Email or item id incorrect"), with a phone in it or in the profile alike.
    /// The profile gives the did its email first, so a request without one relies on the did and the
    /// test does not depend on the ones before it.
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

    func testSubscribeForPriceDrop_withEmailOnly() {
        let expectation = XCTestExpectation(description: "Subscribe with email only")
        
        sdk.subscribeForPriceDrop(
            id: Constants.testItemId,
            currentPrice: Constants.testCurrentPrice,
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
    
    func testSubscribeForPriceDrop_withPhoneOnly() {
        giveTheDidAnEmail(testEmail)

        let expectation = XCTestExpectation(description: "Subscribe with phone only")
        
        sdk.subscribeForPriceDrop(
            id: Constants.testItemId,
            currentPrice: Constants.testCurrentPrice,
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
    
    func testSubscribeForPriceDrop_withEmailAndPhone() {
        let expectation = XCTestExpectation(description: "Subscribe with email and phone")
        
        sdk.subscribeForPriceDrop(
            id: Constants.testItemId,
            currentPrice: Constants.testCurrentPrice,
            email: testEmail,
            phone: testPhone
        ) { result in
            switch result {
            case .success:
                print("Subscribe with email and phone succeeded")
            case .failure(let error):
                XCTFail("Subscribe with email and phone failed: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: Constants.defaultTimeout)
    }
    
    func testSubscribeForPriceDrop_withoutContactInfo() {
        giveTheDidAnEmail(testEmail)

        let expectation = XCTestExpectation(description: "Subscribe without contact info")
        
        sdk.subscribeForPriceDrop(
            id: Constants.testItemId,
            currentPrice: Constants.testCurrentPrice
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
