import XCTest
import REES46

class DeviceIdSaveTest: XCTestCase {
    
    // First we start the application so that the deviceId is saved, then we run this test
    func test_is_device_id_haved_second_run() {
        let deviceId = UserDefaults.standard.string(forKey: "device_id") ?? "No did token" // Get DeviceId from storage
        if deviceId.isEmpty{
            XCTAssert(false, "deviceId bad, init sdk, rerun test")
        } else {
            XCTAssert(true, "deviceId good")
        }
    }
}
