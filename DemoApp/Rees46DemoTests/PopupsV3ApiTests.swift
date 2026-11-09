import XCTest
@_spi(PersonalizationV3) @testable import REES46

/// Popups v3, the network: the requests of the shared `requests.json` (list, one popup, events,
/// promo code, reviews) and the error rules of `error-responses.json` — through the API v3
/// transport seam shared with stories and polls.
final class PopupsV3ApiTests: XCTestCase {

    private var savedTransport: ((URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> Void)!
    private var sdk: FakeSDK!
    private var requests: [URLRequest] = []
    private let lock = NSLock()
    /// What the fake server answers: status and JSON per request (by order; the last one repeats).
    private var answers: [(Int, Any?)] = [(200, ["status": "success"])]

    override func setUp() {
        super.setUp()
        savedTransport = StoriesApiV3.transport
        requests = []
        answers = [(200, ["status": "success"])]
        let context = (PopupsV3Fixtures.json("requests")["_fixture"] as? [String: Any])?["context"] as? [String: Any] ?? [:]
        sdk = FakeSDK(shopId: context["shop_id"] as? String ?? "")
        sdk.deviceId = context["did"] as? String ?? ""
        sdk.userSeance = context["sid"] as? String ?? ""
        StoriesApiV3.transport = { [weak self] request, completion in
            guard let self else { return }
            self.lock.lock()
            self.requests.append(request)
            let index = min(self.requests.count - 1, self.answers.count - 1)
            let (status, body) = self.answers[index]
            self.lock.unlock()
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)
            let data = body.flatMap { try? JSONSerialization.data(withJSONObject: $0) }
            completion(data, response, nil)
        }
    }

    override func tearDown() {
        StoriesApiV3.transport = savedTransport
        super.tearDown()
    }

    private func api() -> PopupsV3API {
        PopupsV3API(sdk: sdk, appHost: { "app.rees46.ru" }, apiHost: "https://api.rees46.ru/")
    }

    private func fixture(_ key: String) -> [String: Any] {
        PopupsV3Fixtures.json("requests")[key] as? [String: Any] ?? [:]
    }

    /// The same address up to the order of query parameters.
    private func assertSameURL(_ url: URL?, _ expected: String?, file: StaticString = #filePath, line: UInt = #line) {
        guard let url, let expected, let wanted = URLComponents(string: expected),
              let actual = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return XCTFail("no url", file: file, line: line)
        }
        XCTAssertEqual(actual.scheme, wanted.scheme, file: file, line: line)
        XCTAssertEqual(actual.host, wanted.host, file: file, line: line)
        XCTAssertEqual(actual.path, wanted.path, file: file, line: line)
        let items = { (components: URLComponents) in Set((components.queryItems ?? []).map { "\($0.name)=\($0.value ?? "")" }) }
        XCTAssertEqual(items(actual), items(wanted), file: file, line: line)
    }

    private func waitForRequests(_ count: Int, timeout: TimeInterval = 5) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            lock.lock()
            let done = requests.count >= count
            lock.unlock()
            if done { break }
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }

    // MARK: - Addresses

    func testListAndPopupURLs() {
        let shop = sdk.shopId, did = sdk.deviceId, sid = sdk.userSeance
        assertSameURL(PopupsV3API.listURL(host: "app.rees46.ru", shopId: shop, did: did, sid: sid, testMode: false, debug: false), fixture("list")["url"] as? String)
        assertSameURL(PopupsV3API.listURL(host: "https://app.rees46.ru/", shopId: shop, did: did, sid: sid, testMode: true, debug: true), fixture("list_testmode_debug")["url"] as? String)
        assertSameURL(PopupsV3API.popupURL(host: "app.rees46.ru", id: 516, shopId: shop, did: did, sid: sid, testMode: false), fixture("one")["url"] as? String)
        assertSameURL(PopupsV3API.popupURL(host: "app.rees46.ru", id: 516, shopId: shop, did: did, sid: sid, testMode: true), fixture("one_testmode")["url"] as? String)
        assertSameURL(PopupsV3API.promoURL(apiHost: "https://api.rees46.ru/", shopId: shop, did: did, sid: sid, listId: "7"), fixture("promo")["url"] as? String)
        assertSameURL(PopupsV3API.eventsURL(host: "app.rees46.ru", id: 512), fixture("event_show")["url"] as? String)
    }

    func testEventBodies() {
        let show = PopupsV3API.eventBody(shopId: sdk.shopId, did: sdk.deviceId, sid: sdk.userSeance, event: "show", channel: nil)
        XCTAssertEqual(show as NSDictionary, fixture("event_show")["json"] as? NSDictionary)
        let subscribe = PopupsV3API.eventBody(shopId: sdk.shopId, did: sdk.deviceId, sid: sdk.userSeance, event: "subscribe", channel: "email")
        XCTAssertEqual(subscribe as NSDictionary, fixture("event_subscribe")["json"] as? NSDictionary)
    }

    // MARK: - Responses

    func testListResponses() {
        let errors = PopupsV3Fixtures.json("error-responses")
        for (status, key) in [(400, "list_400"), (402, "list_402"), (403, "list_403"), (404, "list_404")] {
            guard case .clientError(let code) = PopupsV3API.listResult(status: status, json: errors[key] as? [String: Any], error: nil) else {
                XCTFail("\(status) is a client error, cached as an empty list"); continue
            }
            XCTAssertEqual(code, status)
        }
        guard case .failure = PopupsV3API.listResult(status: 500, json: nil, error: nil) else { return XCTFail("5xx is not cached") }
        guard case .failure = PopupsV3API.listResult(status: 0, json: nil, error: URLError(.notConnectedToInternet)) else { return XCTFail("offline") }
        guard case .list(let list) = PopupsV3API.listResult(status: 200, json: PopupsV3Fixtures.json("list-response"), error: nil) else {
            return XCTFail("the list")
        }
        XCTAssertEqual(list.popups.count, 6)
        XCTAssertNil(PopupsV3API.popupResult(status: 404, json: errors["one_404"] as? [String: Any]))
        XCTAssertNil(PopupsV3API.promoResult(status: 404, json: errors["promo_404"] as? [String: Any]))
        XCTAssertEqual(PopupsV3API.promoResult(status: 200, json: errors["promo_ok"] as? [String: Any]), "ABC123")
        XCTAssertEqual(PopupsV3API.promoResult(status: 200, json: ["code": "<A&B>"]), "AB", "a showcase value is markup-safe")
    }

    // MARK: - Requests through the transport

    func testListRequestThroughTheTransport() {
        answers = [(200, PopupsV3Fixtures.json("list-response"))]
        let done = expectation(description: "list")
        api().fetchList(testMode: true, debug: true) { result in
            if case .list(let list) = result { XCTAssertEqual(list.popups.map(\.id), [512, 513, 514, 515, 516, 519]) } else { XCTFail("\(result)") }
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        assertSameURL(requests.first?.url, fixture("list_testmode_debug")["url"] as? String)
        XCTAssertEqual(requests.first?.httpMethod ?? "GET", "GET")
    }

    func testEventIsPostedAsJSON() throws {
        api().sendEvent(popupId: 512, event: "subscribe", channel: "email")
        waitForRequests(1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(request.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? NSDictionary })
        XCTAssertEqual(body, fixture("event_subscribe")["json"] as? NSDictionary)
        assertSameURL(request.url, fixture("event_subscribe")["url"] as? String)
    }

    func testServerErrorIsRetriedOnceAndClientErrorIsNot() {
        answers = [(500, nil), (500, nil)]
        let api = self.api()
        api.sendEvent(popupId: 512, event: "show", channel: nil)
        waitForRequests(2)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertEqual(requests.count, 2, "one retry")

        requests = []
        answers = [(400, PopupsV3Fixtures.json("error-responses")["events_400_channel"])]
        api.sendEvent(popupId: 512, event: "show", channel: nil)
        waitForRequests(1)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertEqual(requests.count, 1, "4xx is not retried")
    }

    func testTooManyRequestsPausesEvents() {
        answers = [(429, PopupsV3Fixtures.json("error-responses")["events_429"])]
        let api = self.api()
        api.sendEvent(popupId: 512, event: "show", channel: nil)
        waitForRequests(1)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        api.sendEvent(popupId: 512, event: "click", channel: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertEqual(requests.count, 1, "events wait a minute after 429")
    }

    func testPromoCodeIsFetchedOnceAndCached() {
        answers = [(200, ["code": "ABC123"])]
        let api = self.api()
        let first = expectation(description: "first")
        api.fetchPromoCode(listId: "7") { code in
            XCTAssertEqual(code, "ABC123")
            first.fulfill()
        }
        wait(for: [first], timeout: 5)
        let second = expectation(description: "second")
        api.fetchPromoCode(listId: "7") { code in
            XCTAssertEqual(code, "ABC123")
            second.fulfill()
        }
        wait(for: [second], timeout: 5)
        XCTAssertEqual(requests.count, 1)
        assertSameURL(requests.first?.url, fixture("promo")["url"] as? String)
    }

    func testNoPromoCode() {
        answers = [(404, PopupsV3Fixtures.json("error-responses")["promo_404"])]
        let done = expectation(description: "promo")
        api().fetchPromoCode(listId: "7") { code in
            XCTAssertNil(code)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
    }

    func testSurveyReviewGoesToPollsV3() throws {
        let element = PopupsV3Fixtures.element("element-survey", "el-survey-nps")
        let spec = PopupV3SurveySpec(element, texts: .ru)
        let actions = PopupV3SDKActions(sdk: sdk, appHost: "app.rees46.ru", linkHandler: nil, onEvent: { _, _ in })
        let done = expectation(description: "review")
        actions.review(kind: spec.kind, body: spec.body(rate: 0, comment: "Долгая доставка")) { ok in
            XCTAssertTrue(ok)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.absoluteString, fixture("review_nps")["url"] as? String)
        let body = try XCTUnwrap(request.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? NSDictionary })
        XCTAssertEqual(body, fixture("review_nps")["json"] as? NSDictionary)
    }

    func testSurveyErrorIsReported() {
        answers = [(404, PopupsV3Fixtures.json("error-responses")["review_404_channel"])]
        let actions = PopupV3SDKActions(sdk: sdk, appHost: "app.rees46.ru", linkHandler: nil, onEvent: { _, _ in })
        let done = expectation(description: "review")
        actions.review(kind: .csat, body: ["channel": "popup", "rate": 5]) { ok in
            XCTAssertFalse(ok, "404 Channel not found")
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
    }
}
