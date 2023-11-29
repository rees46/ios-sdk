import XCTest
import REES46

class DeviceIdSaveTest: XCTestCase {
    
    // First we start the application so that the deviceId is saved, then we run this test
    func test_is_device_id_haved_second_run() {
        let deviceId = UserDefaults.standard.string(forKey: "device_id") ?? "" // Get DeviceId from storage
        if deviceId.isEmpty{
            XCTAssert(false, "deviceId bad, init sdk, rerun test")
        } else {
            XCTAssert(true, "deviceId good")
        }
    }
}

class Tests: XCTestCase {
    
    var sdk: PersonalizationSDK?
    
    override func setUp() {
        super.setUp()
        sdk = createPersonalizationSDK(shopId: "357382bf66ac0ce2f1722677c59511")
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func test_device_id_initialization() {
        if let sdk = sdk {
            sdk.track(event: .productView(id: "123")) { (response) in
                let deviceId = sdk.getDeviceId()
                if deviceId.isEmpty{
                    XCTAssert(false, "deviceId bad")
                } else {
                    XCTAssert(true, "deviceId good")
                }
            }
        }
    }
    
    func test_device_id_rewrite() {
        let oldDeviceId = sdk?.getDeviceId() // Get the old saved deviceId
        sdk = createPersonalizationSDK(shopId: "357382bf66ac0ce2f1722677c59511") // We reinitialize SDK (as if we are reloading the app)
        if let sdk = sdk {
            sdk.track(event: .productView(id: "")) { (response) in
                let deviceId = sdk.getDeviceId()
                if oldDeviceId == deviceId {
                    XCTAssert(true, "deviceId bad")
                } else {
                    XCTAssert(false, "deviceId good")
                }
            }
        } else {
            XCTAssert(false, "use this test when you have inited sdk")
        }
    }
    
    func test_session_generated() {
        let oldSession = sdk?.getSession() // Get the old saved sessionId
        sdk = createPersonalizationSDK(shopId: "357382bf66ac0ce2f1722677c59511") // We reinitialize SDK (as if we are reloading the app)
        if let sdk = sdk {
            sdk.track(event: .productView(id: "")) { (response) in
                let session = sdk.getSession() // Check session
                if oldSession != session{
                    XCTAssert(false, "session bad")
                } else {
                    XCTAssert(true, "session good")
                }
            }
        } else {
            XCTAssert(false, "use this test when you have inited sdk")
        }
    }
    
}
