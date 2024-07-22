import XCTest
import REES46

class SdkTests: XCTestCase {
    
    var sdk: PersonalizationSDK?
    let shopId = "357382bf66ac0ce2f1722677c59511"
    let TAG = "Tests"
    
    func test_session_generated() {
        let oldSession = sdk?.getSession()
        sdk = createPersonalizationSDK(shopId: shopId)
        trackEventAndCheck(
            eventId: "",
            getValue: { self.sdk?.getSession() },
            checkValue: { newSession in
                oldSession == newSession
            },
            failureMessage: "session did not generate correctly"
        )
    }
    
    func test_device_id_initialization() {
        trackEventAndCheck(
            eventId: "123",
            getValue: { self.sdk?.getDeviceId() },
            checkValue: { deviceId in
                !deviceId!.isEmpty
            },
            failureMessage: "deviceId is empty after initialization"
        )
    }
    
    func test_device_id_rewrite() {
        let oldDeviceId = sdk?.getDeviceId()
        sdk = createPersonalizationSDK(shopId: shopId)
        trackEventAndCheck(
            eventId: "",
            getValue: { self.sdk?.getDeviceId() },
            checkValue: { deviceId in
                oldDeviceId == deviceId
            },
            failureMessage: "deviceId did not rewrite as expected"
        )
    }
    
    func trackEventAndCheck<T>(
        eventId: String,
        getValue: @escaping () -> T?,
        checkValue: @escaping (T?) -> Bool,
        failureMessage: String
    ) {
        sdk?.track(event: .productView(id: eventId)) { (response) in
            let value = getValue()
            let result = checkValue(value)
            print("\(self.TAG): Checking value \(String(describing: value)), result: \(result)")
            XCTAssert(result, "\(self.TAG): \(failureMessage)")
        }
    }
}
