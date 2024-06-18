import XCTest
import REES46

class DeviceIdSaveTest: XCTestCase {
    
    // First we start the application so that the deviceId is saved, then we run this test
    func test_is_device_id_haved_second_run() {
        let deviceId = UserDefaults.standard.string(forKey: "device_id") ?? "" // Get DeviceId from storage
        XCTAssertFalse(deviceId.isEmpty, "deviceId bad, init sdk, rerun test")
    }
}


class Tests: XCTestCase {
    
    let shopId = "357382bf66ac0ce2f1722677c59511"
    var sdk: PersonalizationSDK?
    
    override func setUp() {
        super.setUp()
        sdk = createPersonalizationSDK(shopId: shopId)
    }
    
    override func tearDown() {
        sdk = nil
        super.tearDown()
    }
    
    func test_device_id_initialization() {
        let expectation = self.expectation(description: "Device ID Initialization")
        
        if let sdk = sdk {
            sdk.track(event: .productView(id: "123")) { (response) in
                let deviceId = sdk.getDeviceId()
                XCTAssertFalse(deviceId.isEmpty, "deviceId bad")
                expectation.fulfill()
            }
        } else {
            XCTFail("SDK not initialized")
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func test_device_id_rewrite() {
        let expectation = self.expectation(description: "Device ID Rewrite")
        
        if let oldDeviceId = sdk?.getDeviceId() {
            sdk = createPersonalizationSDK(shopId: shopId) // Reinitialize SDK
            if let sdk = sdk {
                sdk.track(event: .productView(id: "")) { (response) in
                    let deviceId = sdk.getDeviceId()
                    XCTAssertEqual(oldDeviceId, deviceId, "deviceId should not be rewritten")
                    expectation.fulfill()
                }
            } else {
                XCTFail("SDK not reinitialized")
            }
        } else {
            XCTFail("use this test when you have inited sdk")
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func test_session_generated() {
        let expectation = self.expectation(description: "Session Generated")
        
        if let oldSession = sdk?.getSession() {
            sdk = createPersonalizationSDK(shopId: shopId) // Reinitialize SDK
            if let sdk = sdk {
                sdk.track(event: .productView(id: "")) { (response) in
                    let session = sdk.getSession()
                    XCTAssertNotEqual(oldSession, session, "session should be regenerated")
                    expectation.fulfill()
                }
            } else {
                XCTFail("SDK not reinitialized")
            }
        } else {
            XCTFail("use this test when you have inited sdk")
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
}
