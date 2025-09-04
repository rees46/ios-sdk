import XCTest
import REES46

class SdkTests: XCTestCase {
    
    var sdk: PersonalizationSDK?
    let shopId = "357382bf66ac0ce2f1722677c59511"
    let TAG = "SdkTests"

    override func setUp() {
        super.setUp()
        sdk = nil
    }

    override func tearDown() {
        sdk = nil
        super.tearDown()
    }

    func trackEventAndCheck<T>(
        eventId: String,
        getValue: @escaping () -> T?,
        checkValue: @escaping (T?) -> Bool,
        failureMessage: String
    ) {
        let expectation = XCTestExpectation(description: "Track event completion")
        sdk?.track(event: .productView(id: eventId)) { response in
            let value = getValue()
            let result = checkValue(value)
            print("\(self.TAG): Checking value \(String(describing: value)), result: \(result)")
            XCTAssert(result, "\(self.TAG): \(failureMessage)")
            expectation.fulfill()
        }
        let result = XCTWaiter.wait(for: [expectation], timeout: 10.0)
        if result != .completed {
            XCTFail("Timeout in trackEventAndCheck: \(result)")
        }
    }

    func test_device_id_initialization() {
        sdk = createPersonalizationSDK(
            shopId: shopId,
            apiDomain: Constants.testApiDomain, // Унифицируем с другими тестами
            parentViewController: nil
        )
        trackEventAndCheck(
            eventId: "123",
            getValue: { self.sdk?.getDeviceId() },
            checkValue: { deviceId in
                guard let deviceId = deviceId else { return false }
                return !deviceId.isEmpty
            },
            failureMessage: "\(self.TAG): deviceId is empty after initialization"
        )
    }

    func test_device_id_rewrite() {
        sdk = createPersonalizationSDK(
            shopId: shopId,
            apiDomain: Constants.testApiDomain,
            parentViewController: nil
        )
        let oldDeviceId = sdk?.getDeviceId()
        sdk = createPersonalizationSDK(
            shopId: shopId,
            apiDomain: Constants.testApiDomain,
            parentViewController: nil
        )
        trackEventAndCheck(
            eventId: "",
            getValue: { self.sdk?.getDeviceId() },
            checkValue: { deviceId in
                oldDeviceId == deviceId
            },
            failureMessage: "\(self.TAG): deviceId did not rewrite as expected"
        )
    }

    func test_init_with_reinitialization_true_calls_completion() {
        let expectation = XCTestExpectation(description: "Completion called with needReInitialization true")
        
        sdk = createPersonalizationSDK(
            shopId: shopId,
            apiDomain: Constants.testApiDomain,
            parentViewController: nil,
            needReInitialization: true
        ) { error in
            print("\(self.TAG): test_init_with_reinitialization_true_calls_completion: error = \(error?.localizedDescription ?? "nil")")
            XCTAssertNil(error, "Initialization failed with error: \(error?.localizedDescription ?? "unknown")")
            expectation.fulfill()
        }
        
        let result = XCTWaiter.wait(for: [expectation], timeout: 10.0)
        if result != .completed {
            XCTFail("Timeout in test_init_with_reinitialization_true_calls_completion: \(result)")
        }
    }

    func test_init_with_reinitialization_false_calls_completion() {
        let expectation = XCTestExpectation(description: "Completion called with needReInitialization false")
        
        sdk = createPersonalizationSDK(
            shopId: shopId,
            apiDomain: Constants.testApiDomain,
            parentViewController: nil,
            needReInitialization: false
        ) { error in
            print("\(self.TAG): test_init_with_reinitialization_false_calls_completion: error = \(error?.localizedDescription ?? "nil")")
            XCTAssertNil(error, "Initialization failed with error: \(error?.localizedDescription ?? "unknown")")
            expectation.fulfill()
        }
        
        let result = XCTWaiter.wait(for: [expectation], timeout: 10.0)
        if result != .completed {
            XCTFail("Timeout in test_init_with_reinitialization_false_calls_completion: \(result)")
        }
    }
}
