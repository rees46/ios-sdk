//
//  CookieTests.swift
//  REES46Tests
//
//  The SDK neither sends nor keeps cookies, on either core. The API sets a `did` cookie on its domain
//  for a year and answers an `/init` without a did by the did of that cookie: through
//  `HTTPCookieStorage.shared`, `deleteUserCredentials()` and `needReInitialization` got the old did back,
//  and a second shop the first one's. The stub server here answers `/init` the way the API does, and
//  the app's cookie store holds a `did` cookie of the API's host before every test. A URL protocol gets
//  no cookies from the URL loading system: the stub does with them what the HTTP stack would, by the
//  request's and its session's settings, and the first test checks that it does.
//

import XCTest
@testable import REES46

final class CookieTests: XCTestCase {

    private static let host = "stub.test"
    private static let storedDid = "cookie-did"

    private var shops: [String] = []

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        Self.clearCookies()
        // What an earlier launch — of this app, of another shop — left in the app's cookie store.
        Self.storeCookie("did", Self.storedDid)
        Self.storeCookie("sid_1", "cookie-sid")
        answerLikeTheApi()
    }

    override func tearDown() {
        Self.clearCookies()
        StubURLProtocol.uninstall()
        CoreFlag.reset()
        shops.forEach { StubSDK.removeSavedInit(shopId: $0) }
        shops.removeAll()
        super.tearDown()
    }

    // MARK: - Helpers

    private func newShop() -> String {
        let shop = StubSDK.shopId()
        shops.append(shop)
        return shop
    }

    private static var apiURL: URL {
        URL(string: "https://\(host)/")!
    }

    private static func storeCookie(_ name: String, _ value: String) {
        let cookie = HTTPCookie(properties: [
            .domain: ".\(host)",
            .path: "/",
            .name: name,
            .value: value,
            .secure: "TRUE",
            .expires: Date().addingTimeInterval(365 * 24 * 3600),
        ])!
        HTTPCookieStorage.shared.setCookie(cookie)
    }

    private static func clearCookies() {
        let storage = HTTPCookieStorage.shared
        (storage.cookies(for: apiURL) ?? []).forEach { storage.deleteCookie($0) }
    }

    /// The `did` cookie the app's store holds for the API's host.
    private static var didInTheStore: String? {
        HTTPCookieStorage.shared.cookies(for: apiURL)?.first { $0.name == "did" }?.value
    }

    /// The value of the cookie `name` the request carried.
    private static func cookie(_ name: String, in request: StubRequest) -> String? {
        request.header("Cookie")?
            .components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.hasPrefix(name + "=") }
            .map { String($0.dropFirst(name.count + 1)) }
    }

    /// `/init` answers as the API does: the did it was asked for; without one, the did of its `did`
    /// cookie; without that, a new one. Every answer sets the cookie for a year.
    private func answerLikeTheApi() {
        let made = Locked(0)
        StubURLProtocol.handler = { request in
            guard request.path == "/init" else { return StubReply() }
            var did = request.query["did"].flatMap { $0.isEmpty ? nil : $0 } ?? Self.cookie("did", in: request)
            if did == nil {
                made.mutate { $0 += 1 }
                did = "server-did-\(made.current)"
            }
            let given = did ?? ""
            return StubReply(
                json: #"{"did":"\#(given)","seance":"seance-\#(given)"}"#,
                headers: ["Set-Cookie": "did=\(given); Domain=.\(Self.host); Path=/; Max-Age=31536000; Secure"]
            )
        }
    }

    /// The requests of `shop` that carried a cookie, by path.
    private func withCookies(_ shop: String) -> [String] {
        StubURLProtocol.requests
            .filter { ($0.query["shop_id"] ?? $0.body["shop_id"] as? String) == shop && $0.header("Cookie") != nil }
            .map { $0.path }
    }

    private func make(
        _ shop: String,
        coreV2: Bool,
        identity: UserIdentityRepository = InMemoryUserIdentityRepository(),
        needReInitialization: Bool = false
    ) -> SimplePersonalizationSDK {
        let ready = expectation(description: "init of \(shop)")
        let sdk = StubSDK.make(shopId: shop, identity: identity, needReInitialization: needReInitialization, coreV2: coreV2) { _ in
            ready.fulfill()
        }
        wait(for: [ready], timeout: 5)
        return sdk
    }

    private func getProduct(_ sdk: SimplePersonalizationSDK) {
        let done = expectation(description: "products/get")
        sdk.getProductInfo(id: "item-1") { _ in done.fulfill() }
        wait(for: [done], timeout: 5)
    }

    // MARK: - The stub sees cookies

    /// What the other tests count on: through the stub, a session with a cookie store sends the store's
    /// cookies and keeps a cookie the answer sets, as the HTTP stack does with the API; a request that
    /// turns cookies off does neither.
    func test_a_session_with_the_apps_cookie_store_sends_its_cookies_and_keeps_the_answers() {
        StubURLProtocol.handler = { _ in StubReply(headers: ["Set-Cookie": "probe=kept; Domain=.\(Self.host); Path=/; Max-Age=3600; Secure"]) }
        let session = URLSession(configuration: .default)
        let done = expectation(description: "probe")
        session.dataTask(with: URL(string: "https://\(Self.host)/probe")!) { _, _, _ in done.fulfill() }.resume()
        wait(for: [done], timeout: 5)
        session.finishTasksAndInvalidate()

        let sent = StubURLProtocol.requests(to: "/probe").last
        XCTAssertEqual(sent.flatMap { Self.cookie("did", in: $0) }, Self.storedDid, "the store's did went with the request")
        XCTAssertEqual(sent.flatMap { Self.cookie("sid_1", in: $0) }, "cookie-sid")
        XCTAssertEqual(HTTPCookieStorage.shared.cookies(for: Self.apiURL)?.first { $0.name == "probe" }?.value, "kept", "the answer's cookie was kept")

        StubURLProtocol.handler = { _ in StubReply(headers: ["Set-Cookie": "probe=flag; Domain=.\(Self.host); Path=/; Max-Age=3600; Secure"]) }
        var request = URLRequest(url: URL(string: "https://\(Self.host)/probe-off")!)
        request.httpShouldHandleCookies = false
        let off = expectation(description: "probe without cookies")
        URLSession.shared.dataTask(with: request) { _, _, _ in off.fulfill() }.resume()
        wait(for: [off], timeout: 5)
        XCTAssertNil(StubURLProtocol.requests(to: "/probe-off").last?.header("Cookie"))
        XCTAssertEqual(HTTPCookieStorage.shared.cookies(for: Self.apiURL)?.first { $0.name == "probe" }?.value, "kept")
    }

    // MARK: - Both cores

    func test_no_request_of_either_core_sends_a_cookie_and_the_first_init_gets_a_did_of_its_own() {
        for coreV2 in [false, true] {
            let shop = newShop()
            let sdk = make(shop, coreV2: coreV2)
            XCTAssertTrue(eventually { sdk.deviceId.hasPrefix("server-did-") }, "coreV2 = \(coreV2): \(sdk.deviceId)")
            XCTAssertNotEqual(sdk.deviceId, Self.storedDid, "coreV2 = \(coreV2)")

            getProduct(sdk)
            sdk.track(event: .productView(id: "item-1")) { _ in }
            XCTAssertTrue(eventually { !StubURLProtocol.requests(to: "/push", shop: shop).isEmpty }, "coreV2 = \(coreV2)")

            XCTAssertEqual(withCookies(shop), [], "coreV2 = \(coreV2)")
            XCTAssertEqual(Self.didInTheStore, Self.storedDid, "coreV2 = \(coreV2): the answer's cookie was not kept")
            sdk.release()
        }
    }

    func test_delete_user_credentials_gets_a_new_did_on_both_cores() {
        for coreV2 in [false, true] {
            let shop = newShop()
            let identity = InMemoryUserIdentityRepository()
            let sdk = make(shop, coreV2: coreV2, identity: identity)
            XCTAssertTrue(eventually { !(identity.deviceId ?? "").isEmpty }, "coreV2 = \(coreV2)")
            let first = identity.deviceId ?? ""

            sdk.deleteUserCredentials()
            XCTAssertTrue(eventually { StubURLProtocol.requests(to: "/init", shop: shop).count == 2 }, "coreV2 = \(coreV2)")
            XCTAssertTrue(eventually { !(identity.deviceId ?? "").isEmpty && identity.deviceId != first }, "coreV2 = \(coreV2)")

            let second = StubURLProtocol.requests(to: "/init", shop: shop)[1]
            XCTAssertNil(second.query["did"], "coreV2 = \(coreV2): the new /init asks for no did")
            XCTAssertNil(second.header("Cookie"), "coreV2 = \(coreV2): nor does a cookie")
            XCTAssertNotEqual(identity.deviceId, Self.storedDid, "coreV2 = \(coreV2)")
            XCTAssertEqual(withCookies(shop), [], "coreV2 = \(coreV2)")
            sdk.release()
        }
    }

    func test_need_reinitialization_gets_a_new_did_on_both_cores() {
        for coreV2 in [false, true] {
            let shop = newShop()
            let identity = InMemoryUserIdentityRepository()
            identity.deviceId = "old-did"
            let sdk = make(shop, coreV2: coreV2, identity: identity, needReInitialization: true)
            XCTAssertTrue(eventually { (identity.deviceId ?? "").hasPrefix("server-did-") }, "coreV2 = \(coreV2): \(identity.deviceId ?? "nil")")
            XCTAssertEqual(withCookies(shop), [], "coreV2 = \(coreV2)")
            sdk.release()
        }
    }

    func test_a_second_shop_gets_a_did_of_its_own_on_both_cores() {
        for coreV2 in [false, true] {
            let first = newShop()
            let second = newShop()
            let one = make(first, coreV2: coreV2)
            let other = make(second, coreV2: coreV2)
            XCTAssertTrue(eventually { !one.deviceId.isEmpty && !other.deviceId.isEmpty }, "coreV2 = \(coreV2)")
            XCTAssertNotEqual(one.deviceId, other.deviceId, "coreV2 = \(coreV2)")
            XCTAssertEqual(withCookies(first) + withCookies(second), [], "coreV2 = \(coreV2)")
            one.release()
            other.release()
        }
    }

    // MARK: - The app's session

    /// The app's configuration — the stubbed `default`, with the app's cookie store — marked by a header
    /// of its own, so its requests are told from the SDK's session's.
    private static func appConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["X-App-Session": "1"]
        return configuration
    }

    /// Sends `products/get` until the app's session serves one: on the new core the configuration
    /// reaches the client's actor a moment after the call. Returns that request.
    private func requestOfTheAppsSession(_ sdk: SimplePersonalizationSDK) -> StubRequest? {
        for _ in 0..<20 {
            getProduct(sdk)
            if let request = StubURLProtocol.requests(to: "/products/get", shop: sdk.shopId).last(where: { $0.header("X-App-Session") != nil }) {
                return request
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return nil
    }

    func test_a_configuration_the_app_gives_sends_no_cookie_on_either_core_and_is_left_as_it_was() {
        for coreV2 in [false, true] {
            let shop = newShop()
            let sdk = make(shop, coreV2: coreV2)
            let configuration = Self.appConfiguration()
            sdk.configureURLSession(configuration: configuration)

            let request = requestOfTheAppsSession(sdk)
            XCTAssertNotNil(request, "coreV2 = \(coreV2): the app's configuration is used")
            XCTAssertNil(request?.header("Cookie"), "coreV2 = \(coreV2)")
            XCTAssertTrue(configuration.httpShouldSetCookies, "coreV2 = \(coreV2): the app's object is not changed")
            XCTAssertTrue(configuration.httpCookieStorage === HTTPCookieStorage.shared, "coreV2 = \(coreV2)")
            if !coreV2 {
                XCTAssertNil(sdk.urlSession.configuration.httpCookieStorage)
            }
            XCTAssertEqual(withCookies(shop), [], "coreV2 = \(coreV2)")
            sdk.release()
        }
    }

    func test_a_session_the_app_sets_sends_no_cookie_on_either_core() {
        for coreV2 in [false, true] {
            let shop = newShop()
            let sdk = make(shop, coreV2: coreV2)
            let session = URLSession(configuration: Self.appConfiguration())
            // The old core sends through this very session, the new one through its configuration.
            sdk.urlSession = session

            let request = requestOfTheAppsSession(sdk)
            XCTAssertNotNil(request, "coreV2 = \(coreV2): the app's session is used")
            XCTAssertNil(request?.header("Cookie"), "coreV2 = \(coreV2)")
            XCTAssertEqual(withCookies(shop), [], "coreV2 = \(coreV2)")
            XCTAssertEqual(Self.didInTheStore, Self.storedDid, "coreV2 = \(coreV2): nothing was kept in the app's store")
            sdk.release()
            session.finishTasksAndInvalidate()
        }
    }

    // MARK: - Without an instance

    func test_the_sessions_without_an_instance_send_no_cookie() {
        // The old core's push event of a shop that is registered and not created.
        let config = Rees46Config(shopId: "pending-shop", apiDomain: Self.host)
        PushDeliveryTracker.track(PendingPush(shopId: "pending-shop", config: config, route: .event(.clicked), type: "bulk", code: "c-1", deviceId: "d-1"))

        // Stories and popups v3, polls: their transport, with a request that left cookies on.
        let transported = expectation(description: "v3")
        StoriesApiV3.transport(URLRequest(url: URL(string: "https://\(Self.host)/api/v3/storefront/stories/block?shop_id=v3-shop")!)) { _, _, _ in
            transported.fulfill()
        }

        // The new core's client, which a pending shop's push events go through too.
        let client = NetworkClient(baseURL: "https://\(Self.host)/", connectivity: FakeConnectivity(online: true), logger: SdkLogger(shopId: "cookies", level: .none)) {
            CommonFields(shopId: "client-shop", deviceId: "d-1", sessionId: "", stream: "ios", segment: "")
        }
        let sent = expectation(description: "client")
        _Concurrency.Task {
            _ = await client.send(.init(method: .post, path: "track/clicked", body: ["code": "c-1", "type": "bulk"]))
            sent.fulfill()
        }
        wait(for: [transported, sent], timeout: 5)

        let clicked = { StubURLProtocol.requests(to: "/track/clicked") }
        XCTAssertTrue(eventually { clicked().count == 2 })
        XCTAssertEqual(Set(clicked().compactMap { $0.body["shop_id"] as? String }), ["pending-shop", "client-shop"])
        XCTAssertEqual(clicked().filter { $0.header("Cookie") != nil }.count, 0)
        let v3 = StubURLProtocol.requests(to: "/api/v3/storefront/stories/block").first
        XCTAssertNotNil(v3)
        XCTAssertNil(v3?.header("Cookie"))
        XCTAssertEqual(Self.didInTheStore, Self.storedDid)
    }
}
