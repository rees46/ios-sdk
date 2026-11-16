import XCTest
@testable import REES46

class SDKConfigProviderTests: XCTestCase {
    var sdk: PersonalizationSDK?
    var shopId = ""

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        shopId = StubSDK.shopId()
        let ready = expectation(description: "init")
        sdk = StubSDK.make(shopId: shopId) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)
    }

    override func tearDown() {
        (sdk as? SimplePersonalizationSDK)?.release()
        sdk = nil
        StubURLProtocol.uninstall()
        CoreFlag.reset()
        StubSDK.removeSavedInit(shopId: shopId)
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
