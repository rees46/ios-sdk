import XCTest
@testable import REES46

/// `GET /notifications` is server-to-server: without `shop_secret` the API answers 400
/// "Incorrect shop credentials". `getAllNotifications(shopSecret:…)` sends it, and conformers that
/// predate the method (here `FakeSDK`, which does not implement it) get a working default.
final class NotificationHistoryTests: XCTestCase {

    /// What `call` sends through the SDK's `getRequest`; the request runs on the session queue.
    private func request(_ call: (PersonalizationSDK) -> Void) -> (path: String, params: [String: String])? {
        let sdk = FakeSDK(shopId: "shop-1")
        let sent = expectation(description: "notifications request")
        var captured: (path: String, params: [String: String])?
        sdk.onGetRequest = { path, params in
            captured = (path, params)
            sent.fulfill()
        }
        call(sdk)
        wait(for: [sent], timeout: 5)
        return captured
    }

    func testRequest_carriesShopSecret() {
        let sent = request { sdk in
            sdk.getAllNotifications(shopSecret: "secret-key", type: "email") { _ in }
        }

        XCTAssertEqual(sent?.path, "notifications")
        XCTAssertEqual(sent?.params["shop_secret"], "secret-key")
        XCTAssertEqual(sent?.params["shop_id"], "shop-1")
        XCTAssertEqual(sent?.params["type"], "email")
    }

    func testRequest_passesTheFilters() {
        let sent = request { sdk in
            sdk.getAllNotifications(
                shopSecret: "secret-key",
                type: "email,sms",
                phone: "+70000000000",
                email: "user@example.com",
                userExternalId: "ext-1",
                userLoyaltyId: "loyal-1",
                channel: "bulk",
                limit: 10,
                page: 2,
                dateFrom: "2026-10-01"
            ) { _ in }
        }

        XCTAssertEqual(sent?.params["shop_secret"], "secret-key")
        XCTAssertEqual(sent?.params["phone"], "+70000000000")
        XCTAssertEqual(sent?.params["email"], "user@example.com")
        XCTAssertEqual(sent?.params["external_id"], "ext-1")
        XCTAssertEqual(sent?.params["loyalty_id"], "loyal-1")
        XCTAssertEqual(sent?.params["channel"], "bulk")
        XCTAssertEqual(sent?.params["limit"], "10")
        XCTAssertEqual(sent?.params["page"], "2")
        XCTAssertEqual(sent?.params["date_from"], "2026-10-01")
    }

    func testService_withoutSecret_sendsNone() {
        let sent = request { sdk in
            NotificationHandlerServiceImpl(sdk: sdk).getAllNotifications(type: "email") { _ in }
        }

        XCTAssertNotNil(sent)
        XCTAssertNil(sent?.params["shop_secret"])
    }
}
