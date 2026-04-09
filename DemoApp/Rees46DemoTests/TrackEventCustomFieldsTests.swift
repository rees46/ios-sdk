import XCTest
@testable import REES46

final class TrackEventCustomFieldsTests: XCTestCase {
    func test_trackEvent_withTimeAndCustomFields_buildsTopLevelAndPayload() {
        let sdk = MockPersonalizationSDK()
        let service = TrackEventServiceImpl(sdk: sdk)
        
        let expectation = expectation(description: "trackEvent completion")
        
        let event = "my_event"
        let time = 123456
        let category = "event category"
        let label = "event label"
        let value = 100
        let customFields: [String: Any] = [
            "foo": "bar",
            "baz": 42
        ]
        
        service.trackEvent(
            event: event,
            time: time,
            category: category,
            label: label,
            value: value,
            customFields: customFields
        ) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                XCTFail("Expected success, got error: \(error)")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
        
        XCTAssertEqual(sdk.postCallCount, 1)
        XCTAssertEqual(sdk.lastPostPath, "push/custom")
        
        guard let params = sdk.lastPostParams else {
            XCTFail("Expected lastPostParams to be captured")
            return
        }
        
        XCTAssertEqual(params["event"] as? String, event)
        XCTAssertEqual(params["time"] as? Int, time)
        XCTAssertEqual(params["category"] as? String, category)
        XCTAssertEqual(params["label"] as? String, label)
        XCTAssertEqual(params["value"] as? String, String(value))
        
        XCTAssertEqual(params["foo"] as? String, "bar")
        XCTAssertEqual(params["baz"] as? Int, 42)
        
        guard let payload = params["payload"] as? [String: Any] else {
            XCTFail("Expected payload to be present")
            return
        }
        
        XCTAssertEqual(payload["foo"] as? String, "bar")
        XCTAssertEqual(payload["baz"] as? Int, 42)
        XCTAssertEqual(payload.count, customFields.count)
    }
    
    func test_trackEvent_withReservedKeyCollision_returnsErrorAndDoesNotPost() {
        let sdk = MockPersonalizationSDK()
        let service = TrackEventServiceImpl(sdk: sdk)
        
        let expectation = expectation(description: "trackEvent completion")
        
        service.trackEvent(
            event: "my_event",
            time: nil,
            category: nil,
            label: nil,
            value: nil,
            customFields: [
                "event": "bad"
            ]
        ) { result in
            switch result {
            case .success:
                XCTFail("Expected failure due to reserved key collision")
            case .failure:
                break
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
        
        XCTAssertEqual(sdk.postCallCount, 0)
        XCTAssertNil(sdk.lastPostParams)
    }
}

private final class MockPersonalizationSDK: PersonalizationSDK {
    var shopId: String = "shop"
    var deviceId: String = "device"
    var userSeance: String = "seance"
    var segment: String = "A"
    var storiesCode: String? = nil
    var sessionQueue: SessionQueue = .manager
    var parentViewController: UIViewController? = nil
    var urlSession: URLSession = .shared
    
    weak var popupPresentationDelegate: PopupPresentationDelegate?
    var enableAutoPopupPresentation: Bool = false
    lazy var popupPresenter: PopupPresenter = PopupPresenter(sdk: self)
    
    var postCallCount: Int = 0
    var lastPostPath: String?
    var lastPostParams: [String: Any]?
    
    func postRequest(path: String, params: [String: Any], completion: @escaping (Result<[String: Any], SdkError>) -> Void) {
        postCallCount += 1
        lastPostPath = path
        lastPostParams = params
        completion(.success(["status": "success"]))
    }
    
    func getRequest(path: String, params: [String: String], _ isInit: Bool, completion: @escaping (Result<[String: Any], SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func configureURLSession(configuration: URLSessionConfiguration) {
        fatalError("Not needed for these tests")
    }
    
    func generateString(array: [String]) -> String {
        fatalError("Not needed for these tests")
    }
    
    func setProfileData(userEmail: String?, userPhone: String?, userLoyaltyId: String?, birthday: Date?, age: Int?, firstName: String?, lastName: String?, location: String?, gender: Gender?, advertisingId: String?, fbID: String?, vkID: String?, telegramId: String?, loyaltyCardLocation: String?, loyaltyStatus: String?, loyaltyBonuses: Int?, loyaltyBonusesToNextLevel: Int?, boughtSomething: Bool?, userId: String?, customProperties: [String: Any?]?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func track(event: Event, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func trackSource(source: RecommendedByCase, code: String) {
        fatalError("Not needed for these tests")
    }
    
    func trackEvent(event: String, time: Int?, category: String?, label: String?, value: Int?, customFields: [String: Any]?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func trackPopupShown(popupId: Int, completion: @escaping (Result<Void, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func recommend(blockId: String, currentProductId: String?, currentCategoryId: String?, locations: String?, imageSize: String?, timeOut: Double?, withLocations: Bool, extended: Bool, completion: @escaping (Result<RecommenderResponse, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func suggest(query: String, locations: String?, excludedMerchants: [String]?, excludedBrands: [String]?, timeOut: Double?, extended: String?, completion: @escaping (Result<SearchResponse, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func getProductsList(brands: String?, merchants: String?, categories: String?, locations: String?, limit: Int?, page: Int?, filters: [String: Any]?, completion: @escaping (Result<ProductsListResponse, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func getProductsFromCart(completion: @escaping (Result<[CartItem], SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func getProductInfo(id: String, completion: @escaping (Result<ProductInfo, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func getDeviceId() -> String { deviceId }
    
    func setParentViewController(controller: UIViewController, completion: @escaping () -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func getNotificationWidget() -> NotificationWidget? { nil }
    func getSession() -> String { userSeance }
    func getCurrentSegment() -> String { segment }
    func getShopId() -> String { shopId }
    
    func setPushTokenNotification(token: String, isFirebaseNotification: Bool, completion: @escaping (Result<Void, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func review(rate: Int, channel: String, category: String, orderId: String?, comment: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func searchBlank(completion: @escaping (Result<SearchBlankResponse, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func search(query: String, limit: Int?, offset: Int?, categoryLimit: Int?, brandLimit: Int?, categories: [Int]?, extended: String?, sortBy: String?, sortDir: String?, locations: String?, excludedMerchants: [String]?, excludedBrands: [String]?, brands: String?, filters: [String: Any]?, priceMin: Double?, priceMax: Double?, colors: [String]?, fashionSizes: [String]?, exclude: String?, email: String?, timeOut: Double?, disableClarification: Bool?, completion: @escaping (Result<SearchResponse, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func notificationClicked(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func notificationDelivered(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func notificationReceived(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func subscribeForBackInStock(id: String, email: String?, phone: String?, fashionSize: String?, fashionColor: String?, barcode: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func unsubscribeForBackInStock(itemIds: [String], email: String?, phone: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func subscribeForPriceDrop(id: String, currentPrice: Double, email: String?, phone: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func unsubscribeForPriceDrop(itemIds: [String], currentPrice: Double, email: String?, phone: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func getStories(code: String, completion: @escaping (Result<StoryContent, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func addToSegment(segmentId: String, email: String?, phone: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func removeFromSegment(segmentId: String, email: String?, phone: String?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func manageSubscription(email: String?, phone: String?, userExternalId: String?, userLoyaltyId: String?, telegramId: String?, emailBulk: Bool?, emailChain: Bool?, emailTransactional: Bool?, smsBulk: Bool?, smsChain: Bool?, smsTransactional: Bool?, webPushBulk: Bool?, webPushChain: Bool?, webPushTransactional: Bool?, mobilePushBulk: Bool?, mobilePushChain: Bool?, mobilePushTransactional: Bool?, completion: @escaping (Result<Void, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func configuration() -> SdkConfiguration.Type { SdkConfiguration.self }
    
    func sendIDFARequest(idfa: UUID, completion: @escaping (Result<InitResponse, SdkError>) -> Void) {
        fatalError("Not needed for these tests")
    }
    
    func deleteUserCredentials() {
        fatalError("Not needed for these tests")
    }
}

