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
        // A class of the new core that ran before left the process's core as it found it.
        XCTAssertNotEqual(CoreFlag.current, true, "the old core's tests start on the old core")
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

    func test_instant_search_sends_excluded_merchants_only_with_locations() {
        let sdk = initializedSDK()
        let answered = expectation(description: "answered")
        answered.expectedFulfillmentCount = 2
        sdk.suggest(query: "shoes", excludedMerchants: ["m1", "m2"]) { _ in answered.fulfill() }
        sdk.suggest(query: "boots", locations: "10", excludedMerchants: ["m1", "m2"]) { _ in answered.fulfill() }
        wait(for: [answered], timeout: 5)

        let requests = StubURLProtocol.requests(to: "/search", shop: sdk.shopId)
        let withoutLocations = requests.first { $0.query["search_query"] == "shoes" }?.query ?? [:]
        let withLocations = requests.first { $0.query["search_query"] == "boots" }?.query ?? [:]
        // Without locations the server's merchant filter matches no product: the search would be empty.
        XCTAssertNil(withoutLocations["excluded_merchants"])
        XCTAssertEqual(withLocations["excluded_merchants"], "m1,m2")
        XCTAssertEqual(withLocations["locations"], "10")
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

        XCTAssertTrue(eventually { !StubURLProtocol.requests(to: "/profile/set", shop: shopId).isEmpty }, "the contacts went nowhere")
        let body = StubURLProtocol.requests(to: "/profile/set", shop: shopId).first?.body ?? [:]
        XCTAssertEqual(body["email"] as? String, "buyer@example.com")
        XCTAssertEqual(body["phone"] as? String, "+79990001122")
        XCTAssertEqual(body["loyalty_id"] as? String, "card-1")
        XCTAssertEqual(body["did"] as? String, "stub-did")
        withExtendedLifetime(sdk) {}
    }

    @available(*, deprecated)
    func test_without_contacts_no_profile_is_sent() {
        let ready = expectation(description: "init")
        let shopId = newShopId()
        let sdk = createPersonalizationSDK(shopId: shopId, apiDomain: "stub.test", autoSendPushToken: false) { _ in
            ready.fulfill()
        }
        wait(for: [ready], timeout: 5)
        // A profile the init completion sends is queued before the completion runs: once what the
        // queue holds is done and a later request came back, it would have gone.
        sdk.sessionQueue.waitUntilAllOperationsAreFinished()
        let later = expectation(description: "a later request")
        sdk.getProductInfo(id: "1") { _ in later.fulfill() }
        wait(for: [later], timeout: 10)

        XCTAssertTrue(StubURLProtocol.requests(to: "/profile/set", shop: shopId).isEmpty)
        withExtendedLifetime(sdk) {}
    }

    // MARK: - Push token and the popup widget

    func test_a_registered_push_token_is_sent_on_its_own_at_the_next_launch() {
        let first = initializedSDK()
        let token = Data([0xAB, 0xCD, 0x01])
        NotificationRegistrar(sdk: first).registerWithDeviceToken(deviceToken: token)
        XCTAssertTrue(eventually { StubURLProtocol.requests(to: "/mobile_push_tokens", shop: first.shopId).count == 1 })

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
            eventually { StubURLProtocol.requests(to: "/mobile_push_tokens", shop: shopId).count == 1 },
            "the token the SDK was given never went out on its own"
        )
        let sent = StubURLProtocol.requests(to: "/mobile_push_tokens", shop: shopId).first?.body ?? [:]
        XCTAssertEqual(sent["token"] as? String, "abcd01")
        XCTAssertEqual(sent["shop_id"] as? String, shopId)
        withExtendedLifetime(next) {}
    }

    func test_a_token_given_twice_at_once_goes_out_once() {
        let sdk = initializedSDK()
        let token = Data([0x01, 0x02])
        // Each call says when it is over: a request it sent reached the server before that.
        let both = expectation(description: "both calls")
        both.expectedFulfillmentCount = 2
        NotificationRegistrar(sdk: sdk).registerWithDeviceToken(deviceToken: token) { _ in both.fulfill() }
        NotificationRegistrar(sdk: sdk).registerWithDeviceToken(deviceToken: token) { _ in both.fulfill() }
        wait(for: [both], timeout: 10)
        XCTAssertEqual(StubURLProtocol.requests(to: "/mobile_push_tokens", shop: sdk.shopId).count, 1)
    }

    func test_a_token_that_did_not_go_out_is_sent_again() {
        let sdk = initializedSDK()
        StubURLProtocol.handler = { request in request.path == "/mobile_push_tokens" ? StubReply(500) : StubReply() }
        let token = Data([0x03, 0x04])
        // The failed upload has given the week back when its completion runs.
        let failed = expectation(description: "the failed upload")
        NotificationRegistrar(sdk: sdk).registerWithDeviceToken(deviceToken: token) { _ in failed.fulfill() }
        wait(for: [failed], timeout: 10)
        XCTAssertEqual(StubURLProtocol.requests(to: "/mobile_push_tokens", shop: sdk.shopId).count, 1)
        XCTAssertNil(UserDefaults.standard.object(forKey: NotificationRegistrar.lastUploadDateKey(shopId: sdk.shopId)))

        StubURLProtocol.handler = StubURLProtocol.defaultHandler
        NotificationRegistrar(sdk: sdk).registerWithDeviceToken(deviceToken: token)

        XCTAssertTrue(eventually { StubURLProtocol.requests(to: "/mobile_push_tokens", shop: sdk.shopId).count == 2 }, "a failed upload held the token back for a week")
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
        // A test before may leave the modal slot held by a popup.
        PopupV3Slots.shared.reset()

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

    // MARK: - Popups

    /// Hands every popup the SDK asks about the screen; presents nothing itself.
    private final class PopupHost: UIViewController, PopupPresentationDelegate {
        let asked = Locked(0)
        override func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {}
        func sdk(_ sdk: PersonalizationSDK, shouldPresentPopup popup: Popup) -> UIViewController? {
            asked.mutate { $0 += 1 }
            return self
        }
    }

    private static func popup(_ id: Int, drawn: Bool = true, delay: Int = 0) -> Popup {
        var json: [String: Any] = ["id": id, "position": "centered", "delay": delay, "popup_actions": #"{"close": {"button_text": "Close"}}"#]
        if drawn {
            json["components"] = #"{"header": "Title", "text": "Text"}"#
        }
        return Popup(json: json)
    }

    func test_a_popup_with_nothing_to_draw_is_not_counted_as_shown_and_the_same_popup_drawn_shows_at_once() {
        let sdk = initializedSDK()
        let host = PopupHost()
        sdk.popupPresentationDelegate = host
        PopupV3Slots.shared.reset()

        sdk.popupPresenter.presentPopup(Self.popup(41, drawn: false))
        XCTAssertTrue(eventually { host.asked.current == 1 })
        XCTAssertNil(sdk.getNotificationWidget(), "nothing to draw holds no slot")

        sdk.popupPresenter.presentPopup(Self.popup(41))
        XCTAssertTrue(eventually { sdk.getNotificationWidget() != nil }, "not remembered as shown: it shows within the minute")
        XCTAssertTrue(eventually { StubURLProtocol.requests(to: "/popup/showed", shop: sdk.shopId).count == 1 })
        XCTAssertEqual(StubURLProtocol.requests(to: "/popup/showed", shop: sdk.shopId).first?.body["popup"] as? Int, 41, "only the drawn one is sent")
        sdk.popupPresenter.dismissCurrentPopup()
        XCTAssertTrue(eventually { sdk.getNotificationWidget() == nil })
        withExtendedLifetime(host) {}
    }

    func test_a_popup_of_the_server_waits_its_delay_and_one_handed_back_does_not() {
        let sdk = initializedSDK()
        let host = PopupHost()
        sdk.popupPresentationDelegate = host
        PopupV3Slots.shared.reset()
        XCTAssertEqual(Popup(json: ["id": 1, "delay": "2"]).delay, 2, "a number in a string")

        let arrived = Date()
        sdk.popupPresenter.popupArrived(Self.popup(42, delay: 1))
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        XCTAssertEqual(host.asked.current, 0, "neither shown nor handed to the delegate before its delay")
        XCTAssertTrue(eventually { sdk.getNotificationWidget() != nil })
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(arrived), 1)
        sdk.popupPresenter.dismissCurrentPopup()
        XCTAssertTrue(eventually { sdk.getNotificationWidget() == nil })

        sdk.popupPresenter.presentPopup(Self.popup(43, delay: 30))
        XCTAssertTrue(eventually(timeout: 3) { sdk.getNotificationWidget() != nil }, "handed back: shown without its delay")
        sdk.popupPresenter.dismissCurrentPopup()
        XCTAssertTrue(eventually { sdk.getNotificationWidget() == nil })
        withExtendedLifetime(host) {}
    }

    func test_dismissCurrentPopup_takes_the_popup_off_the_screen() {
        final class Presenting: PopupPresentationDelegate {
            let root = UIViewController()
            func sdk(_ sdk: PersonalizationSDK, shouldPresentPopup popup: Popup) -> UIViewController? { root }
        }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let host = Presenting()
        window.rootViewController = host.root
        window.isHidden = false
        let sdk = initializedSDK()
        sdk.popupPresentationDelegate = host
        PopupV3Slots.shared.reset()

        sdk.popupPresenter.presentPopup(Self.popup(44))
        XCTAssertTrue(eventually { host.root.presentedViewController != nil }, "the popup is on screen")
        sdk.popupPresenter.dismissCurrentPopup()
        XCTAssertTrue(eventually { host.root.presentedViewController == nil }, "closed from the app's code")
        XCTAssertNil(sdk.getNotificationWidget())
        window.isHidden = true
    }
}
