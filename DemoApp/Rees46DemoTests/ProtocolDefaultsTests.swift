//
//  ProtocolDefaultsTests.swift
//  REES46Tests
//
//  The protocol's methods with default arguments call the method the conformer implements. A
//  conformer without one of them — an app's own mock — gets an error from the call, not an endless
//  loop of the default calling itself.
//

import XCTest
import UIKit
@testable import REES46

final class ProtocolDefaultsTests: XCTestCase {

    private let sdk = BareSDK()

    private func assertFails(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ call: (@escaping (Result<Void, SdkError>) -> Void) -> Void
    ) {
        var outcome: Result<Void, SdkError>?
        call { outcome = $0 }
        guard case .failure(let error)? = outcome else {
            return XCTFail("\(name): expected an error, got \(String(describing: outcome))", file: file, line: line)
        }
        XCTAssertTrue(error.description.contains("not implemented"), "\(name): \(error)", file: file, line: line)
    }

    func test_a_conformer_without_a_method_gets_an_error_instead_of_a_loop() {
        assertFails("recommend") { done in sdk.recommend(blockId: "b") { done($0.map { _ in }) } }
        assertFails("suggest") { done in sdk.suggest(query: "q") { done($0.map { _ in }) } }
        assertFails("search") { done in sdk.search(query: "q") { done($0.map { _ in }) } }
        assertFails("getProductsList") { done in sdk.getProductsList { done($0.map { _ in }) } }
        assertFails("getProductsFromCart") { done in sdk.getProductsFromCart { done($0.map { _ in }) } }
        assertFails("getUserOrders") { done in sdk.getUserOrders(shopSecret: "s") { done($0.map { _ in }) } }
        assertFails("joinLoyalty") { done in sdk.joinLoyalty(phone: "1") { done($0.map { _ in }) } }
        assertFails("getCategory") { done in sdk.getCategory(category: "c") { done($0.map { _ in }) } }
        assertFails("getCollection") { done in sdk.getCollection(collectionId: "c") { done($0.map { _ in }) } }
        assertFails("getProbabilityToPurchase") { done in sdk.getProbabilityToPurchase { done($0.map { _ in }) } }
        assertFails("setPushTokenNotification") { done in sdk.setPushTokenNotification(token: "t", completion: done) }
        assertFails("review") { done in sdk.review(rate: 5, channel: "c", category: "c", completion: done) }
        assertFails("setProfileData") { done in sdk.setProfileData(userEmail: "a@b.c", completion: done) }
        assertFails("notificationClicked") { done in sdk.notificationClicked(type: "t", code: "c", completion: done) }
        assertFails("subscribeForBackInStock") { done in sdk.subscribeForBackInStock(id: "i", completion: done) }
        assertFails("unsubscribeForBackInStock") { done in sdk.unsubscribeForBackInStock(itemIds: ["i"], completion: done) }
        assertFails("subscribeForPriceDrop") { done in sdk.subscribeForPriceDrop(id: "i", currentPrice: 1, completion: done) }
        assertFails("unsubscribeForPriceDrop") { done in sdk.unsubscribeForPriceDrop(itemIds: ["i"], currentPrice: 1, completion: done) }
        assertFails("addToSegment") { done in sdk.addToSegment(segmentId: "s", completion: done) }
        assertFails("removeFromSegment") { done in sdk.removeFromSegment(segmentId: "s", completion: done) }
        assertFails("manageSubscription") { done in sdk.manageSubscription(email: "a@b.c", completion: done) }
    }

    @available(*, deprecated)
    func test_a_conformer_without_a_tracking_method_gets_an_error_instead_of_a_loop() {
        assertFails("track") { done in sdk.track(event: .productView(id: "1"), completion: done) }
        assertFails("trackEvent") { done in sdk.trackEvent(event: "e", completion: done) }
        assertFails("trackEvent with fields") { done in sdk.trackEvent(event: "e", time: 1, completion: done) }
    }

    func test_a_conformer_without_deleteUserCredentials_returns() {
        sdk.deleteUserCredentials()
    }

    func test_a_wrapper_passing_a_call_on_to_another_instance_reaches_it() {
        let outer = BareSDK()
        let inner = BareSDK()
        var reached = false
        ProtocolDefault.forward("recommend()", on: outer, to: {
            ProtocolDefault.forward("recommend()", on: inner, to: { reached = true }, orFail: { (_: Result<Void, SdkError>) in })
        }, orFail: { (_: Result<Void, SdkError>) in })

        XCTAssertTrue(reached, "the inner instance's call was taken for the outer one's loop")
    }

    func test_a_conformer_with_a_method_gets_its_own_method() {
        let mock = NotificationsMockSDK()
        mock.getCategory(category: "c") { _ in }
        XCTAssertEqual(mock.categoryCalls.map(\.category), ["c"])
    }
}

/// A conformer like an app's own minimal mock: it implements only what the protocol leaves no
/// default for, and none of the methods the protocol gives default arguments.
final class BareSDK: PersonalizationSDK {
    var shopId = "bare-shop"
    var deviceId = "bare-device-id"
    var userSeance = "bare-seance"
    var segment = "A"
    var storiesCode: String?
    let sessionQueue: SessionQueue = SessionQueue.manager
    var parentViewController: UIViewController?
    var urlSession: URLSession = .shared
    var popupPresentationDelegate: PopupPresentationDelegate?
    var enableAutoPopupPresentation = true
    lazy var popupPresenter: PopupPresenter = PopupPresenter(sdk: self)

    func postRequest(path: String, params: [String: Any], completion: @escaping (Result<[String: Any], SdkError>) -> Void) {}
    func getRequest(path: String, params: [String: String], _ isInit: Bool, completion: @escaping (Result<[String: Any], SdkError>) -> Void) {}
    func configureURLSession(configuration: URLSessionConfiguration) {}
    func generateString(array: [String]) -> String { "" }
    func trackPurchase(_ request: PurchaseTrackingRequest, recommendedBy: RecomendedBy?, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func trackSource(source: RecommendedByCase, code: String) {}
    func trackPopupShown(popupId: Int, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func getProductInfo(id: String, completion: @escaping (Result<ProductInfo, SdkError>) -> Void) {}
    func getLastOrderProducts(completion: @escaping (Result<LastOrderProductsResponse, SdkError>) -> Void) {}
    func getLoyaltyStatus(identifier: String, completion: @escaping (Result<LoyaltyStatusResponse, SdkError>) -> Void) {}
    func getProfile(completion: @escaping (Result<GetProfileResponse, SdkError>) -> Void) {}
    func getProductCounters(item: String, completion: @escaping (Result<ProductCountersResponse, SdkError>) -> Void) {}
    func getDeviceId() -> String { deviceId }
    func setParentViewController(controller: UIViewController, completion: @escaping () -> Void) {}
    func getNotificationWidget() -> NotificationWidget? { nil }
    func getSession() -> String { userSeance }
    func getCurrentSegment() -> String { segment }
    func getShopId() -> String { shopId }
    func searchBlank(completion: @escaping (Result<SearchBlankResponse, SdkError>) -> Void) {}
    func notificationDelivered(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func notificationReceived(type: String, code: String, completion: @escaping (Result<Void, SdkError>) -> Void) {}
    func getStories(code: String, completion: @escaping (Result<StoryContent, SdkError>) -> Void) {}
    func configuration() -> SdkConfiguration.Type { SdkConfiguration.self }
    func sendIDFARequest(idfa: UUID, completion: @escaping (Result<InitResponse, SdkError>) -> Void) {}
}
