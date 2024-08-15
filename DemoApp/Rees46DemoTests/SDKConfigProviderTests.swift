import XCTest
import REES46

class SDKConfigProviderTests: XCTestCase {
    
    var sdk: PersonalizationSDK?
    let shopId = "357382bf66ac0ce2f1722677c59511"
    
    override func setUp() {
        super.setUp()
        sdk = createPersonalizationSDK(shopId: shopId)
    }
    
    override func tearDown() {
        sdk = nil
        super.tearDown()
    }
    
    private func assertSupportsSDKConfigProvider() {
        guard let _ = sdk as? SDKConfigProvider else {
            XCTFail("SDK does not support SDKConfigProvider")
            return
        }
    }
    
    func test_getConfigShopId() {
        guard let sdk = sdk as? SDKConfigProvider else { return }
        let shopId = sdk.getConfigShopId
        XCTAssertEqual(shopId, self.shopId, "shopId does not match expected value")
    }
    
    func test_getConfigDeviceId() {
        var sdkDeviceId = sdk?.deviceId
        guard let sdk = sdk as? SDKConfigProvider else { return }
        let deviceId = sdk.getConfigDeviceId
        XCTAssertEqual(deviceId, sdkDeviceId, "deviceId does not match expected value")
    }
    
    func test_getConfigUserSeance() {
        var seance = sdk?.userSeance
        guard let sdk = sdk as? SDKConfigProvider else { return }
        let userSeance = sdk.getConfigUserSeance
        XCTAssertEqual(userSeance, seance, "userSeance does not match expected value")
    }
}
