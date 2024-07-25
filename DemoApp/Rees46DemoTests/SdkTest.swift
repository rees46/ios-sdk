import XCTest
import REES46

class SdkTests: XCTestCase {
    
    var sdk: PersonalizationSDK?
    let shopId = "357382bf66ac0ce2f1722677c59511"
    let TAG = "Tests"
    
    func trackEventAndCheck<T>(
        eventId: String,
        getValue: @escaping () -> T?,
        checkValue: @escaping (T?) -> Bool,
        failureMessage: String
    ) {
        sdk?.track(event: .productView(id: eventId)) { [weak self] response in
            guard let self = self else { return }
            let value = getValue()
            let result = checkValue(value)
            print("\(self.TAG): Checking value \(String(describing: value)), result: \(result)")
            XCTAssert(result, "\(self.TAG): \(failureMessage)")
        }
    }
    
    func test_device_id_initialization() {
        sdk = createPersonalizationSDK(shopId: shopId)
        trackEventAndCheck(
            eventId: "123",
            getValue: { [weak self] in self?.sdk?.getDeviceId() },
            checkValue: { deviceId in
                guard let deviceId = deviceId else { return false }
                return !deviceId.isEmpty
            },
            failureMessage: "deviceId is empty after initialization"
        )
    }
    
    func test_device_id_rewrite() {
        sdk = createPersonalizationSDK(shopId: shopId)
        let oldDeviceId = sdk?.getDeviceId()
        sdk = createPersonalizationSDK(shopId: shopId)
        trackEventAndCheck(
            eventId: "",
            getValue: { [weak self] in self?.sdk?.getDeviceId() },
            checkValue: { deviceId in
                guard let oldDeviceId = oldDeviceId, let deviceId = deviceId else { return false }
                return oldDeviceId == deviceId
            },
            failureMessage: "deviceId did not rewrite as expected"
        )
    }
    
    func test_session_generated() {
        sdk = createPersonalizationSDK(shopId: shopId)
        let oldSession = sdk?.getSession()
        sdk = createPersonalizationSDK(shopId: shopId)
        trackEventAndCheck(
            eventId: "",
            getValue: { [weak self] in self?.sdk?.getSession() },
            checkValue: { newSession in
                guard let oldSession = oldSession, let newSession = newSession else { return false }
                return oldSession == newSession
            },
            failureMessage: "session did not generate correctly"
        )
    }
}
