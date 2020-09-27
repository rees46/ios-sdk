import XCTest
import REES46

class DeviceIDSaveTest: XCTestCase {
    
    //Сначала запускаем приложение чтобы сохранился deviceID, потом запускаем этот тест
    func test_is_device_id_haved_second_run() {
        let deviceID = UserDefaults.standard.string(forKey: "device_id") ?? "" //Получаем из хранилища DeviceID
        if deviceID.isEmpty{
            XCTAssert(false, "deviceID bad, init sdk, rerun test")
        }else{
            XCTAssert(true, "deviceID good")
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
                let deviceID = sdk.getDeviceID()
                if deviceID.isEmpty{
                    XCTAssert(false, "deviceID bad")
                }else{
                    XCTAssert(true, "deviceID good")
                }
            }
        }
    }
    
    func test_device_id_rewrite() {
        let oldDeviceID = sdk?.getDeviceID() //получаем старый сохраненный deviceID
        sdk = createPersonalizationSDK(shopId: "357382bf66ac0ce2f1722677c59511") //переиницализируем сдк ( как будто пергружаем приложение)
        if let sdk = sdk {
            sdk.track(event: .productView(id: "")) { (response) in
                let deviceID = sdk.getDeviceID()
                if oldDeviceID == deviceID {
                    XCTAssert(true, "deviceID bad")
                }else{
                    XCTAssert(false, "deviceID good")
                }
            }
        }else{
            XCTAssert(false, "use this test when you have inited sdk")
        }
    }
    
    func test_session_genterated() {
        let oldSession = sdk?.getSession() //получаем старый сохраненный ссид
        sdk = createPersonalizationSDK(shopId: "357382bf66ac0ce2f1722677c59511") //переиницализируем сдк ( как будто пергружаем приложение)
        if let sdk = sdk {
            sdk.track(event: .productView(id: "")) { (response) in
                let session = sdk.getSession() //проверяем сессию
                if oldSession != session{
                    XCTAssert(false, "session bad")
                }else{
                    XCTAssert(true, "session good")
                }
            }
        }else{
            XCTAssert(false, "use this test when you have inited sdk")
        }
    }
    
}
