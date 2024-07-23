import XCTest
import REES46

class SdkTests: XCTestCase {
    
    var sdk: PersonalizationSDK?
    let shopId = "357382bf66ac0ce2f1722677c59511"
    let TAG = "Tests"
    
    override func setUp() {
        super.setUp()
        sdk = createPersonalizationSDK(shopId: shopId)
    }

    override func tearDown() {
        super.tearDown()
    }

    func test_device_id_initialization() {
        if let sdk = sdk {
            sdk.track(event: .productView(id: "123")) { (response) in
                let deviceId = sdk.getDeviceId()
                if deviceId.isEmpty{
                    XCTAssert(false, "Tests: deviceId bad")
                } else {
                    XCTAssert(true, "Tests: deviceId good")
                }
            }
        }
    }

    func test_device_id_rewrite() {
        let oldDeviceId = sdk?.getDeviceId() // Get the old saved deviceId
        sdk = createPersonalizationSDK(shopId: shopId) // We reinitialize SDK (as if we are reloading the app)
        if let sdk = sdk {
            sdk.track(event: .productView(id: "")) { (response) in
                let deviceId = sdk.getDeviceId()
                if oldDeviceId == deviceId {
                    XCTAssert(true, "Tests: deviceId bad")
                } else {
                    XCTAssert(false, "Tests: deviceId good")
                }
            }
        } else {
            XCTAssert(false, "Tests: use this test when you have inited sdk")
        }
    }

    func test_session_generated() {
        let oldSession = sdk?.getSession() // Get the old saved sessionId
        sdk = createPersonalizationSDK(shopId: shopId) // We reinitialize SDK (as if we are reloading the app)
        if let sdk = sdk {
            sdk.track(event: .productView(id: "")) { (response) in
                let session = sdk.getSession() // Check session
                if oldSession != session{
                    XCTAssert(false, "Tests:session bad")
                } else {
                    XCTAssert(true, "Tests:session good")
                }
            }
        } else {
            XCTAssert(false, "Tests:use this test when you have inited sdk")
        }
    }
}
