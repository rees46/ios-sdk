//
//  AuditFixesTests.swift
//  REES46Tests
//
//  What the public API promised and did not do: the excluded merchants of instant search, the
//  contacts given to createPersonalizationSDK, the push token sent on its own, the widget of the
//  popup on screen.
//

import XCTest
@testable import REES46

final class AuditFixesTests: XCTestCase {

    private var shopIds: [String] = []

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
    }

    override func tearDown() {
        StubURLProtocol.uninstall()
        shopIds.forEach { shopId in
            StubSDK.removeSavedInit(shopId: shopId)
            UserIdentityRepositoryImpl(shopId: shopId).clearIdentity()
            UserDefaults.standard.removeObject(forKey: "\(NotificationRegistrar.Constants.mainPushTokenLastUploadDateKey).\(shopId)")
        }
        super.tearDown()
    }

    private func newShopId() -> String {
        let shopId = StubSDK.shopId()
        shopIds.append(shopId)
        return shopId
    }

    private func initializedSDK() -> SimplePersonalizationSDK {
        let ready = expectation(description: "init")
        let sdk = StubSDK.make(shopId: newShopId()) { _ in ready.fulfill() }
        wait(for: [ready], timeout: 5)
        return sdk
    }

    // MARK: - Instant search

    func test_instant_search_sends_excluded_merchants_without_locations() {
        let sdk = initializedSDK()
        let answered = expectation(description: "answered")
        sdk.suggest(query: "shoes", excludedMerchants: ["m1", "m2"]) { _ in answered.fulfill() }
        wait(for: [answered], timeout: 5)

        let query = StubURLProtocol.requests(to: "/search").first?.query ?? [:]
        XCTAssertNotNil(query["excluded_merchants"], "excluded merchants were dropped without locations")
        XCTAssertNil(query["locations"])
    }

    // MARK: - Contacts given to createPersonalizationSDK

    @available(*, deprecated)
    func test_contacts_given_at_creation_reach_the_profile() {
        let shopId = newShopId()
        let sdk = createPersonalizationSDK(
            shopId: shopId,
            userEmail: "buyer@example.com",
            userPhone: "+79990001122",
            userLoyaltyId: "card-1",
            apiDomain: "stub.test",
            autoSendPushToken: false
        )

        XCTAssertTrue(eventually { !StubURLProtocol.requests(to: "/profile/set").isEmpty }, "the contacts went nowhere")
        let body = StubURLProtocol.requests(to: "/profile/set").first?.body ?? [:]
        XCTAssertEqual(body["email"] as? String, "buyer@example.com")
        XCTAssertEqual(body["phone"] as? String, "+79990001122")
        XCTAssertEqual(body["loyalty_id"] as? String, "card-1")
        XCTAssertEqual(body["did"] as? String, "stub-did")
        withExtendedLifetime(sdk) {}
    }

    @available(*, deprecated)
    func test_without_contacts_no_profile_is_sent() {
        let ready = expectation(description: "init")
        let sdk = createPersonalizationSDK(shopId: newShopId(), apiDomain: "stub.test", autoSendPushToken: false) { _ in
            ready.fulfill()
        }
        wait(for: [ready], timeout: 5)
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(StubURLProtocol.requests(to: "/profile/set").isEmpty)
        withExtendedLifetime(sdk) {}
    }

    // MARK: - Push token and the popup widget

    func test_a_registered_push_token_is_sent_on_its_own_at_the_next_launch() {
        let first = initializedSDK()
        let token = Data([0xAB, 0xCD, 0x01])
        NotificationRegistrar(sdk: first).registerWithDeviceToken(deviceToken: token)
        XCTAssertTrue(eventually { StubURLProtocol.requests(to: "/mobile_push_tokens").count == 1 })

        // Another shop of the app starts with token sending on: it has the token without the app.
        let shopId = newShopId()
        let next = SimplePersonalizationSDK(
            shopId: shopId,
            apiDomain: "stub.test",
            autoSendPushToken: true,
            enableAutoPopupPresentation: false,
            userIdentity: InMemoryUserIdentityRepository(),
            keychainStore: InMemoryKeychainInitStore(),
            localState: LocalStateRepositoryImpl(store: UserDefaults(suiteName: "test-\(shopId)")!)
        )

        XCTAssertTrue(
            eventually { StubURLProtocol.requests(to: "/mobile_push_tokens").count == 2 },
            "the token the SDK was given never went out on its own"
        )
        let sent = StubURLProtocol.requests(to: "/mobile_push_tokens").dropFirst().first?.body ?? [:]
        XCTAssertEqual(sent["token"] as? String, "abcd01")
        XCTAssertEqual(sent["shop_id"] as? String, shopId)
        withExtendedLifetime(next) {}
    }

    func test_a_token_given_twice_at_once_goes_out_once() {
        let sdk = initializedSDK()
        let token = Data([0x01, 0x02])
        NotificationRegistrar(sdk: sdk).registerWithDeviceToken(deviceToken: token)
        NotificationRegistrar(sdk: sdk).registerWithDeviceToken(deviceToken: token)

        XCTAssertTrue(eventually { !StubURLProtocol.requests(to: "/mobile_push_tokens").isEmpty })
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(StubURLProtocol.requests(to: "/mobile_push_tokens").count, 1)
    }

    func test_a_token_that_did_not_go_out_is_sent_again() {
        let sdk = initializedSDK()
        StubURLProtocol.handler = { request in request.path == "/mobile_push_tokens" ? StubReply(500) : StubReply() }
        let token = Data([0x03, 0x04])
        NotificationRegistrar(sdk: sdk).registerWithDeviceToken(deviceToken: token)
        XCTAssertTrue(eventually { StubURLProtocol.requests(to: "/mobile_push_tokens").count == 1 })
        Thread.sleep(forTimeInterval: 0.3)

        StubURLProtocol.handler = StubURLProtocol.defaultHandler
        NotificationRegistrar(sdk: sdk).registerWithDeviceToken(deviceToken: token)

        XCTAssertTrue(eventually { StubURLProtocol.requests(to: "/mobile_push_tokens").count == 2 }, "a failed upload held the token back for a week")
    }

    func test_the_widget_of_the_popup_on_screen_is_returned() {
        final class Host: UIViewController, PopupPresentationDelegate {
            override func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {}
            func sdk(_ sdk: PersonalizationSDK, shouldPresentPopup popup: Popup) -> UIViewController? { self }
        }
        let sdk = initializedSDK()
        let host = Host()
        sdk.popupPresentationDelegate = host
        XCTAssertNil(sdk.getNotificationWidget())

        sdk.popupPresenter.presentPopup(Popup(json: [
            "id": 7,
            "position": "centered",
            "components": #"{"header": "Title", "text": "Text"}"#,
            "popup_actions": #"{"close": {"button_text": "Close"}}"#
        ]))

        XCTAssertTrue(eventually { sdk.getNotificationWidget() != nil }, "the popup on screen has no widget")
        sdk.popupPresenter.dismissCurrentPopup()
        withExtendedLifetime(host) {}
    }
}
