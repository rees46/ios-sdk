import XCTest
import REES46

class SsidSaveTest: XCTestCase {
    
    //Сначала запускаем приложение чтобы сохранился ssid, потом запускаем этот тест
    func test_is_ssid_haved_second_run() {
        let ssid = UserDefaults.standard.string(forKey: "personalization_ssid") ?? "" //Получаем из хранилища SSID
        if ssid.isEmpty{
            XCTAssert(false, "ssid bad, init sdk, rerun test")
        }else{
            XCTAssert(true, "ssid good")
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
    
    func test_ssid_initialization() {
        if let sdk = sdk {
            sdk.track(event: .productView(id: "123")) { (response) in
                let ssid = sdk.getSSID()
                if ssid.isEmpty{
                    XCTAssert(false, "ssid bad")
                }else{
                    XCTAssert(true, "ssid good")
                }
            }
        }
    }
    
    func test_ssid_rewrite() {
        let oldSsid = sdk?.getSSID() //получаем старый сохраненный ссид
        sdk = createPersonalizationSDK(shopId: "357382bf66ac0ce2f1722677c59511") //переиницализируем сдк ( как будто пергружаем приложение)
        if let sdk = sdk {
            sdk.track(event: .productView(id: "")) { (response) in
                let ssid = sdk.getSSID()
                if oldSsid == ssid{
                    XCTAssert(true, "ssid bad")
                }else{
                    XCTAssert(false, "ssid good")
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
