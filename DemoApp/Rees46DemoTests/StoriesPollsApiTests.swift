import XCTest
import UIKit
@_spi(PersonalizationV3) @testable import REES46

/// Polls on Stories V2 slides, the network and data side (the web SDK's `polls.test.ts`): the
/// `poll` element is parsed from the v3 feed tolerantly (numbers as strings, nulls, unknown
/// kinds skipped), answers go to `/api/v3/polls/...` on the feed's host with `shop_id`, `did`
/// and `sid`, and any failure (network, HTTP ≥ 400, not JSON, `fail` / `error`) is an error.
final class StoriesPollsApiTests: XCTestCase {

    private var savedTransport: ((URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> Void)!
    private var savedDidTimeout: TimeInterval = 0

    override func setUp() {
        super.setUp()
        savedTransport = StoriesApiV3.transport
        savedDidTimeout = StoriesApiV3.deviceIdTimeout
    }

    override func tearDown() {
        StoriesApiV3.transport = savedTransport
        StoriesApiV3.deviceIdTimeout = savedDidTimeout
        super.tearDown()
    }

    // MARK: - The shared feed fixture

    /// `fixture-feed.json` of the spec, bundled with the demo app (the tests' host).
    private func fixtureStories() throws -> [PersonalizationStory] {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "StoriesPollsFixture", withExtension: "json"), "the demo bundles the fixture")
        let payload = try StoriesApiV3.payload(data: Data(contentsOf: url), response: response(200), error: nil).get()
        return PersonalizationStory.list(json: payload)
    }

    func testTheFixtureHasEveryKindAndSkipsTheUnknownOne() throws {
        let slides = try XCTUnwrap(fixtureStories().first).slides
        XCTAssertEqual(slides.map(\.id), ["900", "901", "902", "903", "904", "905", "906", "907"])
        XCTAssertEqual(slides.map { $0.poll?.kind }, [
            .singleChoice, .multipleChoice, .text, .scale(.nps), .scale(.csat), .scale(.ces), .singleChoice, nil
        ])
        XCTAssertNil(slides[7].poll, "poll_type quiz is not drawn, the slide stays")
        XCTAssertEqual(slides.map { $0.poll?.yOffset }, [50, 40, 30, 60, 90, 5, 50, nil], "y_offset \"40\" is a number too")
    }

    func testNumbersAsStringsAndNullsAreTolerated() throws {
        let slides = try XCTUnwrap(fixtureStories().first).slides
        let text = try XCTUnwrap(slides[2].poll)
        XCTAssertEqual(text.maxLength, 120, "\"120\"")
        XCTAssertEqual(text.placeholder, "Ваш ответ")
        XCTAssertNil(text.submitLabel)
        XCTAssertEqual(text.labels, .init(reanswer: "Ответить заново", error: "Не удалось отправить ответ. Попробуйте еще раз"))

        let csat = try XCTUnwrap(slides[4].poll)
        XCTAssertNil(csat.channel)
        XCTAssertNil(csat.rateMin)
        XCTAssertEqual(csat.scaleValues, [1, 2, 3, 4, 5], "null range — the default")
        XCTAssertEqual(csat.labels, .init())
        XCTAssertFalse(csat.allowReanswer)

        let ces = try XCTUnwrap(slides[5].poll)
        XCTAssertEqual(ces.rateMin, 1, "\"1\"")
        XCTAssertEqual(ces.scaleValues, [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(ces.bands, [], "bands: null")

        let nps = try XCTUnwrap(slides[3].poll)
        XCTAssertEqual(nps.code, "test")
        XCTAssertEqual(nps.channel, "test")
        XCTAssertEqual(nps.bandText(rate: 8), "Спасибо за оценку")

        let multi = try XCTUnwrap(slides[1].poll)
        XCTAssertEqual(multi.options.map(\.id), [1, 2, 3, 4, 5])
        XCTAssertEqual(multi.submitLabel, "Отправить ответ")
        XCTAssertTrue(multi.showResults)
    }

    func testTheAnsweredPollOfTheFeedCarriesItsAnswerAndResults() throws {
        let poll = try XCTUnwrap(fixtureStories().first?.slides[6].poll)
        XCTAssertEqual(poll.answer, .init(optionIds: [2]))
        XCTAssertEqual(poll.results, .init(total: 120, options: [.init(id: 1, percent: 40), .init(id: 2, percent: 60)]))
        XCTAssertTrue(PersonalizationStoryPoll.hasAnswer(poll.answer))
        XCTAssertNil(try XCTUnwrap(fixtureStories().first?.slides[0].poll).answer, "answer: null")
    }

    func testBrokenElementsDoNotBreakTheSlide() {
        let slide = PersonalizationStorySlide(json: ["id": "39_0", "type": "", "elements": [
            ["type": "poll", "poll_type": "mini_poll", "poll": "broken"],
            ["type": "poll", "poll_type": "emoji", "poll": ["code": "x"]],
            ["type": "poll", "poll_type": "mini_poll", "poll": ["code": "x", "kind": "quiz"]],
            ["type": "poll", "poll_type": "nps", "poll": NSNull()],
            ["type": "poll", "poll_type": "csat", "y_offset": NSNull(), "allow_reanswer": NSNull(), "answer": ["rate": "4"],
             "poll": ["code": "shop", "bands": [["from": "1", "to": "3", "success": "Жаль"], ["to": 5]], "options": NSNull()]]
        ]])
        XCTAssertEqual(slide?.id, "39_0", "a product slide keeps its string id")
        let poll = slide?.poll
        XCTAssertEqual(poll?.kind, .scale(.csat), "the first poll that parses")
        XCTAssertNil(poll?.yOffset)
        XCTAssertEqual(poll?.answer?.rate, 4)
        XCTAssertEqual(poll?.bands, [.init(from: 1, to: 3, success: "Жаль")], "a band without from is skipped")
        XCTAssertNil(PersonalizationStorySlide(json: ["id": 1, "elements": []])?.poll)
    }

    /// The web does not check the code: the card is drawn, the server turns the answer down.
    func testAPollWithoutACodeIsDrawnWithAnEmptyCode() {
        let nps = PersonalizationStoryPoll(json: ["type": "poll", "poll_type": "nps", "poll": ["code": NSNull()]])
        XCTAssertEqual(nps?.kind, .scale(.nps))
        XCTAssertEqual(nps?.code, "")
        let mini = PersonalizationStoryPoll(json: ["type": "poll", "poll_type": "mini_poll", "poll": ["kind": "text"]])
        XCTAssertEqual(mini?.kind, .text)
        XCTAssertEqual(mini?.code, "")
        XCTAssertEqual(PersonalizationStoryPoll(json: ["poll_type": "nps", "poll": ["code": 15]])?.code, "15", "a number code")
        XCTAssertNil(PersonalizationStoryPoll(json: ["type": "poll", "poll_type": "nps"]), "no poll object — nothing to draw")
    }

    func testTypeAndKindAreComparedAsTheyAre() {
        func kind(_ type: String, _ kind: String? = nil) -> PersonalizationStoryPoll.Kind? {
            PersonalizationStoryPoll(json: ["poll_type": type, "poll": ["code": "x", "kind": kind.map { $0 as Any } ?? NSNull()] as [String: Any]])?.kind
        }
        XCTAssertEqual(kind("nps"), .scale(.nps))
        XCTAssertEqual(kind("mini_poll", "text"), .text)
        XCTAssertNil(kind(" nps"), "no trimming")
        XCTAssertNil(kind("NPS"), "case counts")
        XCTAssertNil(kind("mini_poll ", "text"))
        XCTAssertNil(kind("mini_poll", "Text"))
        XCTAssertNil(kind("mini_poll", "single_choice "))
    }

    /// A string of spaces is a text too, like a truthy string of the web: shown and sent as is.
    func testTextsAreTakenAsIs() throws {
        let options: [[String: Any]] = [["id": 1, "label": "Себе"], ["id": "2"], ["id": 3, "label": NSNull()], ["id": 1.5, "label": "?"], ["label": "?"]]
        let poll = try XCTUnwrap(PersonalizationStoryPoll(json: ["poll_type": "mini_poll", "poll": [
            "code": " gift ", "kind": "multiple_choice", "question": "  ", "placeholder": " ", "submit_label": " ",
            "thanks_text": " Спасибо ", "options": options
        ] as [String: Any]]))
        XCTAssertEqual(poll.code, " gift ")
        XCTAssertEqual(poll.question, "  ")
        XCTAssertEqual(poll.placeholder, " ")
        XCTAssertEqual(poll.submitLabel, " ")
        XCTAssertEqual(poll.thanksText, " Спасибо ")
        XCTAssertEqual(poll.options, [.init(id: 1, label: "Себе"), .init(id: 2, label: ""), .init(id: 3, label: "")],
                       "an option without a label stays, like the web; without a whole id — skipped")

        let scale = try XCTUnwrap(PersonalizationStoryPoll(json: ["poll_type": "nps", "poll": [
            "code": "x", "channel": " ", "question": "", "bands": [["from": 0, "to": 10, "success": " "]]
        ] as [String: Any]]))
        XCTAssertEqual(scale.channel, " ")
        XCTAssertNil(scale.question, "an empty string is no text")
        XCTAssertEqual(scale.bandText(rate: 5), " ")
    }

    func testFlagsAreTrueOnlyForTrueAndOne() throws {
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(
            #"[true, 1, 1.0, "true", "1", false, 0, 2, 0.5, "TRUE", " true", "yes", "", null]"#.utf8
        )) as? [Any])
        XCTAssertEqual(json.map { PersonalizationStoryPoll.flag($0) },
                       [true, true, true, true, false, false, false, false, false, false, false, false, false, false])
        XCTAssertFalse(PersonalizationStoryPoll.flag(nil))
        let poll = PersonalizationStoryPoll(json: ["poll_type": "mini_poll", "allow_reanswer": 2, "poll": ["kind": "text", "show_results": "true"]])
        XCTAssertEqual(poll?.allowReanswer, false, "2 is not true")
        XCTAssertEqual(poll?.showResults, true)
    }

    func testMaxLengthTakesTheWholePartOfAPositiveNumber() {
        func limit(_ value: Any) -> Int? {
            PersonalizationStoryPoll(json: ["poll_type": "mini_poll", "poll": ["kind": "text", "max_length": value]])?.maxLength
        }
        XCTAssertEqual(limit("10.7"), 10)
        XCTAssertEqual(limit(5), 5)
        XCTAssertNil(limit(0.5), "less than one — no limit")
        XCTAssertNil(limit("0"))
        XCTAssertNil(limit(-3))
        XCTAssertNil(limit(NSNull()))
    }

    func testLabelsAreOnlyNonEmptyStrings() {
        func labels(_ value: Any) -> PersonalizationStoryPoll.Labels? {
            PersonalizationStoryPoll(json: ["poll_type": "nps", "poll": ["code": "x"], "labels": value])?.labels
        }
        XCTAssertEqual(labels(["reanswer": 5, "error": "", "submit": "Ок"] as [String: Any]), .init(submit: "Ок"), "a number and an empty string do not count")
        XCTAssertEqual(labels(["reanswer": " Ещё "]), .init(reanswer: " Ещё "), "taken as is, like the web")
        XCTAssertEqual(labels("Ещё"), .init(), "not an object")
        XCTAssertEqual(labels(NSNull()), .init())
    }

    // MARK: - Scales

    func testScaleBoundsMustBeWholeNumbers() {
        func values(_ type: String, _ min: Any, _ max: Any) -> [Int]? {
            PersonalizationStoryPoll(json: ["poll_type": type, "poll": ["code": "x", "rate_min": min, "rate_max": max]])?.scaleValues
        }
        XCTAssertEqual(values("nps", 0.5, "10"), Array(0...10), "a fraction — the default, \"10\" is 10")
        XCTAssertEqual(values("csat", "2.5", 4), [1, 2, 3, 4])
        XCTAssertEqual(values("ces", "2", "3.0"), [2, 3], "3.0 is whole")
        XCTAssertEqual(values("csat", 3, 1), [], "min > max — an empty scale")
        XCTAssertEqual(values("nps", -10, 100)?.count, 21)
        XCTAssertEqual(values("ces", NSNull(), "abc"), Array(1...7))
    }

    func testScaleRangesDefaultsAndTheLimit() {
        XCTAssertEqual(PersonalizationStoryPoll.scaleRange(.csat, min: nil, max: nil), [1, 2, 3, 4, 5])
        XCTAssertEqual(PersonalizationStoryPoll.scaleRange(.nps, min: nil, max: nil).count, 11)
        XCTAssertEqual(PersonalizationStoryPoll.scaleRange(.ces, min: nil, max: nil), Array(1...7))
        XCTAssertEqual(PersonalizationStoryPoll.scaleRange(.nps, min: 0, max: 100).count, 21, "not more than 21 values")
        XCTAssertEqual(PersonalizationStoryPoll.scaleRange(.csat, min: 5, max: 1), [])
        XCTAssertEqual(PersonalizationStoryPoll.scaleRange(.csat, min: 2, max: nil), [2, 3, 4, 5])
    }

    func testScaleColors() {
        let nps = (0...10).map { PersonalizationStoryPoll.scaleColor(.nps, value: $0, min: 0, max: 10) }
        XCTAssertEqual(nps, ["#FCA5A5", "#FCA5A5", "#FCA5A5", "#FDBA74", "#FDBA74", "#FDBA74", "#FCD34D",
                             "#FDE68A", "#FDE68A", "#86EFAC", "#86EFAC"])
        XCTAssertEqual((1...5).map { PersonalizationStoryPoll.scaleColor(.csat, value: $0, min: 1, max: 5) },
                       ["#FCA5A5", "#FCA5A5", "#FDE68A", "#86EFAC", "#86EFAC"], "by thirds: 4 of 1...5 is 0.75")
        XCTAssertEqual((1...7).map { PersonalizationStoryPoll.scaleColor(.ces, value: $0, min: 1, max: 7) },
                       ["#FCA5A5", "#FCA5A5", "#FCA5A5", "#FDE68A", "#FDE68A", "#86EFAC", "#86EFAC"])
        XCTAssertEqual(PersonalizationStoryPoll.scaleColor(.nps, value: 3, min: 1, max: 5), "#FDE68A", "NPS of another range — by thirds")
        XCTAssertEqual(PersonalizationStoryPoll.scaleColor(.csat, value: 3, min: 3, max: 3), "#86EFAC", "one value")
    }

    func testBandTextFindsTheBandOfTheRate() {
        let poll = PersonalizationStoryPoll(kind: .scale(.nps), code: "x", bands: [.init(from: 0, to: 6, success: "A"), .init(from: 7, to: 8, success: nil)])
        XCTAssertEqual(poll.bandText(rate: 6), "A")
        XCTAssertEqual(poll.bandText(rate: 0), "A", "the edges are inside")
        XCTAssertNil(poll.bandText(rate: 7), "a band without success")
        XCTAssertNil(poll.bandText(rate: 9), "no band")
        XCTAssertNil(poll.bandText(rate: nil))
        XCTAssertEqual(poll.bandText(rate: 5.5), "A", "a fractional rate finds its band too")
    }

    func testHasAnswer() {
        XCTAssertFalse(PersonalizationStoryPoll.hasAnswer(nil))
        XCTAssertFalse(PersonalizationStoryPoll.hasAnswer(.init(optionIds: [], text: "")))
        XCTAssertTrue(PersonalizationStoryPoll.hasAnswer(.init(optionIds: [1])))
        XCTAssertTrue(PersonalizationStoryPoll.hasAnswer(.init(text: "ok")))
        XCTAssertTrue(PersonalizationStoryPoll.hasAnswer(.init(rate: 0)), "rate 0 is an answer")
        XCTAssertTrue(PersonalizationStoryPoll.hasAnswer(PersonalizationStoryPoll.Answer(json: ["text": "  "])), "a non-empty text, like the web")
        let empty: [String: Any] = ["option_ids": [Any](), "text": NSNull(), "rate": NSNull()]
        XCTAssertFalse(PersonalizationStoryPoll.hasAnswer(PersonalizationStoryPoll.Answer(json: empty)))
        XCTAssertTrue(PersonalizationStoryPoll.hasAnswer(PersonalizationStoryPoll.Answer(json: ["rate": "4"])))
        let fraction = PersonalizationStoryPoll.Answer(json: ["rate": 3.5])
        XCTAssertEqual(fraction?.rate, 3.5)
        XCTAssertTrue(PersonalizationStoryPoll.hasAnswer(fraction), "any number is a rate, a fraction too")
        let bare = PersonalizationStoryPoll.Answer(json: ["id": 77])
        XCTAssertNotNil(bare, "any object is an answer of the server")
        XCTAssertFalse(PersonalizationStoryPoll.hasAnswer(bare))
    }

    func testPercentsAreRoundedAndClampedAndOnlyWithAnOptionsArray() throws {
        let options: [[String: Any]] = [
            ["id": 1, "percent": 33.5], ["id": 2, "percent": "120"], ["id": 3, "percent": -5], ["id": "4", "percent": "60.4"], ["id": 5]
        ]
        let results = try XCTUnwrap(PersonalizationStoryPoll.Results(json: ["total": 3, "options": options] as [String: Any]))
        XCTAssertEqual((1...6).map { results.percent(of: $0) }, [34, 100, 0, 60, 0, 0], "no percent or not in the results — 0%")
        XCTAssertNotNil(PersonalizationStoryPoll.Results(json: ["options": [Any]()]))
        XCTAssertNil(PersonalizationStoryPoll.Results(json: ["total": 5, "options": NSNull()] as [String: Any]), "no array — no percents at all")
        XCTAssertNil(PersonalizationStoryPoll.Results(json: ["total": 5]))
        XCTAssertNil(PersonalizationStoryPoll.Results(json: NSNull()))
    }

    // MARK: - Requests

    /// Records the requests and answers each with `answer`.
    private func capture(answer: @escaping (URLRequest) -> (Data?, Int, Error?)) -> () -> [URLRequest] {
        let lock = NSLock()
        var requests: [URLRequest] = []
        StoriesApiV3.transport = { request, completion in
            lock.lock()
            requests.append(request)
            lock.unlock()
            let (data, status, error) = answer(request)
            completion(data, error == nil ? self.response(status) : nil, error)
        }
        return {
            lock.lock()
            defer { lock.unlock() }
            return requests
        }
    }

    private func body(_ request: URLRequest?) -> [String: Any] {
        request?.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
    }

    private typealias Outcome = Result<PersonalizationStoryPoll.Reply, Error>

    /// Sends one answer of a mini poll and waits for the result on the main queue.
    private func answer(sdk: PersonalizationSDK = FakeSDK(shopId: "shop"), code: String = "gift",
                        body: [String: Any] = ["option_ids": [2], "story_id": 5, "slide_id": "101"]) -> Outcome? {
        let done = expectation(description: "answer")
        var outcome: Outcome?
        StoriesPollsApi(api: StoriesApiV3(domain: "app.test"), sdk: sdk).answerMiniPoll(code: code, body: body) {
            XCTAssertTrue(Thread.isMainThread)
            outcome = $0
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return outcome
    }

    private func review(_ kind: PersonalizationStoryPoll.Scale, sdk: PersonalizationSDK = FakeSDK(shopId: "shop"),
                        body: [String: Any]) -> Outcome? {
        let done = expectation(description: "review")
        var outcome: Outcome?
        StoriesPollsApi(api: StoriesApiV3(domain: "app.test"), sdk: sdk).review(kind: kind, body: body) {
            outcome = $0
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return outcome
    }

    func testAMiniPollAnswerGoesToItsCodeWithTheIdentity() throws {
        let requests = capture { _ in
            (Data(#"{"status":"success","payload":{"answer":{"id":77,"option_ids":[2],"text":null},"results":{"total":121,"options":[{"id":1,"percent":40},{"id":2,"percent":"60"}]}}}"#.utf8), 200, nil)
        }
        let reply = try XCTUnwrap(answer()?.get())
        XCTAssertEqual(reply.answer, .init(optionIds: [2]))
        XCTAssertEqual(reply.results?.percent(of: 2), 60)
        XCTAssertEqual(reply.results?.total, 121)

        let request = try XCTUnwrap(requests().first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://app.test/api/v3/polls/mini_polls/gift/answers")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertFalse(request.httpShouldHandleCookies, "no cookies, like the web")
        let json = try JSONSerialization.data(withJSONObject: body(request), options: .sortedKeys)
        XCTAssertEqual(String(data: json, encoding: .utf8),
                       #"{"did":"fake-device-id","option_ids":[2],"shop_id":"shop","sid":"fake-seance","slide_id":"101","story_id":5}"#)
    }

    func testTheCodeIsOnePathSegment() {
        let requests = capture { _ in (Data(#"{"status":"success","payload":{}}"#.utf8), 200, nil) }
        _ = answer(code: "a/b c")
        XCTAssertEqual(requests().first?.url?.absoluteString, "https://app.test/api/v3/polls/mini_polls/a%2Fb%20c/answers")
    }

    func testAnEmptySeanceSendsAnEmptySid() {
        let sdk = FakeSDK(shopId: "shop")
        sdk.userSeance = ""
        let requests = capture { _ in (Data(#"{"status":"success","payload":{}}"#.utf8), 200, nil) }
        _ = answer(sdk: sdk, body: ["text": "Книга", "story_id": 5, "slide_id": "39_0"])
        let sent = body(requests().first)
        XCTAssertEqual(sent["sid"] as? String, "", "sid goes always, like the web's identity()")
        XCTAssertEqual(sent["text"] as? String, "Книга")
        XCTAssertEqual(sent["slide_id"] as? String, "39_0")
    }

    func testAnEmptyCodeGoesToAnEmptySegment() {
        let requests = capture { _ in (Data(#"{"status":"fail","message":"Not found"}"#.utf8), 404, nil) }
        guard case .failure? = answer(code: "") else { return XCTFail("the server turns it down") }
        XCTAssertEqual(requests().first?.url?.absoluteString, "https://app.test/api/v3/polls/mini_polls//answers")
    }

    func testA200WithoutAnAnswerIsASuccessWithNothing() throws {
        _ = capture { _ in (Data(#"{"status":"success"}"#.utf8), 200, nil) }
        XCTAssertEqual(try answer()?.get(), PersonalizationStoryPoll.Reply(), "the card falls back to what it sent")
        _ = capture { _ in (Data("{}".utf8), 200, nil) }
        XCTAssertEqual(try answer()?.get(), PersonalizationStoryPoll.Reply())
    }

    func testReviewsGoToTheirScaleWithCategoryOrCampaign() throws {
        let requests = capture { _ in (Data(#"{"status":"success","payload":{"review":{"id":7}}}"#.utf8), 200, nil) }
        XCTAssertEqual(try review(.nps, body: ["channel": "stories", "category": "delivery", "rate": 9])?.get(), PersonalizationStoryPoll.Reply())
        _ = review(.csat, body: ["channel": "stories", "campaign": "support", "rate": 4])
        _ = review(.ces, body: ["channel": "stories", "campaign": "checkout", "rate": 2])
        let all = requests()
        XCTAssertEqual(all.map { $0.url?.path }, ["/api/v3/polls/nps/reviews", "/api/v3/polls/csat/reviews", "/api/v3/polls/ces/reviews"])
        XCTAssertEqual(body(all[0])["category"] as? String, "delivery")
        XCTAssertEqual(body(all[0])["rate"] as? Int, 9)
        XCTAssertEqual(body(all[0])["shop_id"] as? String, "shop")
        XCTAssertEqual(body(all[0])["sid"] as? String, "fake-seance")
        XCTAssertEqual(all[0].value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertFalse(all[0].httpShouldHandleCookies)
        XCTAssertEqual(body(all[1])["campaign"] as? String, "support")
        XCTAssertEqual(body(all[2])["did"] as? String, "fake-device-id")
    }

    func testEveryFailureIsAnError() {
        let cases: [(String, Data?, Int, Error?)] = [
            ("400", Data(#"{"status":"fail","message":"Bad request"}"#.utf8), 400, nil),
            ("402", Data(#"{"status":"fail","message":"Payment required"}"#.utf8), 402, nil),
            ("404", Data("<html>Not found</html>".utf8), 404, nil),
            ("429", Data(#"{"status":"fail","message":"Too many requests"}"#.utf8), 429, nil),
            ("500", nil, 500, nil),
            ("network", nil, 0, URLError(.notConnectedToInternet)),
            ("not JSON", Data("ok".utf8), 200, nil),
            ("fail at 200", Data(#"{"status":"fail","message":"Poll not found"}"#.utf8), 200, nil),
            ("error at 200", Data(#"{"status":"error"}"#.utf8), 200, nil)
        ]
        for (name, data, status, error) in cases {
            _ = capture { _ in (data, status, error) }
            guard case .failure? = answer() else { return XCTFail("\(name) is an error") }
            guard case .failure? = review(.nps, body: ["rate": 1]) else { return XCTFail("\(name) is an error for a review") }
        }
    }

    func testTheErrorCarriesTheCodeAndTheMessage() {
        let result = StoriesApiV3.response(data: Data(#"{"status":"fail","message":"Payment required"}"#.utf8), response: response(402), error: nil)
        guard case .failure(let error) = result else { return XCTFail("402 is an error") }
        XCTAssertEqual("\(error)", "\(SdkError.custom(error: "Stories v3: HTTP 402: Payment required"))")
    }

    func testNoDidInTimeFailsWithoutARequest() {
        StoriesApiV3.deviceIdTimeout = 0.3
        let sdk = FakeSDK()
        sdk.deviceId = ""
        let requests = capture { _ in (nil, 500, nil) }
        guard case .failure? = answer(sdk: sdk) else { return XCTFail("no did — an error") }
        XCTAssertTrue(requests().isEmpty)
    }

    private func response(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://app.test/")!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }
}
