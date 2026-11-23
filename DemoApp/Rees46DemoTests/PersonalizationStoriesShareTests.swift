import XCTest
import UIKit
@_spi(PersonalizationV3) @testable import REES46

/// Stories V2 "Share" and links (API v3, `PersonalizationStories.apiV3Domain`): the link is read
/// the way the web SDK reads it, a slide shares its own link or the campaign's, the v3 answer is
/// unwrapped from `payload` with the old feed's parser, events go to `…/events` with the campaign
/// id as a number, and `handleLink` only takes stories links while v3 is on.
final class PersonalizationStoriesShareTests: XCTestCase {

    private var savedTransport: ((URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> Void)!
    private var savedDomain: String?
    private var savedDidTimeout: TimeInterval = 0
    private var savedKeyRoot: (() -> UIViewController?)!
    private var savedSource: [String: Any?] = [:]
    private static let sourceKeys = ["recomendedCode", "recomendedType", "timeStartSave"]

    override func setUp() {
        super.setUp()
        savedTransport = StoriesApiV3.transport
        savedDomain = PersonalizationStories.apiV3Domain
        savedDidTimeout = StoriesApiV3.deviceIdTimeout
        savedKeyRoot = PersonalizationStories.keyRoot
        // A fake SDK keeps the attribution in the shared defaults: put back what was there.
        savedSource = Dictionary(uniqueKeysWithValues: Self.sourceKeys.map { ($0, UserDefaults.standard.object(forKey: $0)) })
    }

    override func tearDown() {
        StoriesApiV3.transport = savedTransport
        PersonalizationStories.apiV3Domain = savedDomain
        StoriesApiV3.deviceIdTimeout = savedDidTimeout
        PersonalizationStories.keyRoot = savedKeyRoot
        savedSource.forEach { UserDefaults.standard.set($0.value, forKey: $0.key) }
        super.tearDown()
    }

    private func response(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://app.test/")!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    // MARK: - Link (the table of the web SDK's stories-share.test.ts)

    private func link(_ query: String) -> StoriesShareLink? {
        URL(string: "https://shop.test/promo" + query).flatMap { StoriesShareLink(url: $0) }
    }

    func testALinkCarriesTheBlockTheCampaignAndTheSlide() {
        XCTAssertEqual(link("?utm_source=tg&r46_stories=main&r46_story=5&r46_slide=10"),
                       StoriesShareLink(code: "main", storyId: "5", slideId: "10"))
        XCTAssertEqual(link("?r46_stories=115bd0b67cf5989a1b60c841790b2af6&r46_story=40&r46_slide=37"),
                       StoriesShareLink(code: "115bd0b67cf5989a1b60c841790b2af6", storyId: "40", slideId: "37"))
    }

    func testALinkWithoutASlideAndVirtualSlidesOfProductCampaigns() {
        XCTAssertEqual(link("?r46_stories=main&r46_story=5"), StoriesShareLink(code: "main", storyId: "5", slideId: nil))
        XCTAssertEqual(link("?r46_stories=main&r46_story=5&r46_slide=5_2")?.slideId, "5_2")
    }

    func testOtherPagesAndBrokenLinksAreNotStoriesLinks() {
        XCTAssertNil(link(""))
        XCTAssertNil(link("?r46_story=5"))
        XCTAssertNil(link("?r46_stories=main&r46_story=abc"))
        XCTAssertNil(link("?r46_stories=&r46_story=5"), "an empty block code")
        XCTAssertNil(link("?r46_stories=main&r46_story=12345678901"), "more than 10 digits")
        XCTAssertNil(link("?r46_stories=main&r46_story=-5"))
        XCTAssertNil(link("?r46_stories=main"))
    }

    func testABrokenSlideStillOpensTheCampaign() {
        let broken = link("?r46_stories=main&r46_story=5&r46_slide=1;DROP")
        XCTAssertEqual(broken?.storyId, "5")
        XCTAssertNil(broken?.slideId)
        for slide in ["5_12345", "_2", "5_", "5_2_1", "12345678901", "abc", ""] {
            XCTAssertNotNil(link("?r46_stories=main&r46_story=5&r46_slide=\(slide)"), slide)
            XCTAssertNil(link("?r46_stories=main&r46_story=5&r46_slide=\(slide)")?.slideId, slide)
        }
    }

    // MARK: - Link of a slide

    private let campaign = "https://shop.test/?r46_story=5"

    /// As the web's `stories-share`: the slide's own link, else the campaign's as it is.
    func testTheSlideLinkWinsAndTheCampaignLinkIsTheFallbackAsItIs() {
        let story = PersonalizationStory(id: "5", name: "S", slides: [], shareUrl: campaign)
        let own = PersonalizationStorySlide(id: "1", kind: .content, shareUrl: "https://shop.test/?r46_slide=1")
        XCTAssertEqual(story.shareUrl(of: own)?.absoluteString, "https://shop.test/?r46_slide=1")
        XCTAssertEqual(story.shareUrl(of: PersonalizationStorySlide(id: "5_2", kind: .content))?.absoluteString, campaign,
                       "a product slide has no link of its own: the campaign's, nothing added")
        XCTAssertNotNil(story.shareUrl(of: PersonalizationStorySlide(id: "1", kind: .content, shareUrl: "HTTPS://SHOP.TEST/")),
                        "the scheme is matched in any case")
    }

    func testNoLinkWhenSharingIsOffOrTheLinkIsNotHttp() {
        let slide = PersonalizationStorySlide(id: "1", kind: .content, shareUrl: "https://shop.test/")
        XCTAssertNil(PersonalizationStory(id: "5", name: "S", slides: [], shareable: false, shareUrl: campaign).shareUrl(of: slide))
        XCTAssertNil(PersonalizationStory(id: "5", name: "S", slides: []).shareUrl(of: PersonalizationStorySlide(id: "1", kind: .content)))
        let story = PersonalizationStory(id: "5", name: "S", slides: [], shareUrl: "javascript:alert(1)")
        XCTAssertNil(story.shareUrl(of: PersonalizationStorySlide(id: "1", kind: .content)))
        XCTAssertNil(story.shareUrl(of: PersonalizationStorySlide(id: "1", kind: .content, shareUrl: "ftp://shop.test/")))
    }

    // MARK: - v3 answer

    /// The shape of the live feed: a product campaign with virtual slides and `null` media,
    /// a photo campaign whose slides have their own links and no `shareable` field.
    private let feed = """
    {"status":"success","payload":{"id":7,"settings":{"close_color":"#fff"},"stories":[
      {"id":39,"name":"Product","avatar":"https://img.test/a.jpg","pinned":false,"viewed":false,"start_position":0,
       "shareable":true,"share_url":"https://demo.test/?r46_stories=b&r46_story=39",
       "slides":[{"id":"39_0","type":"","background":null,"preview":null,"duration":10,
                  "elements":[{"type":"product","item":{"id":"1","name":"Pool","price":10,"price_formatted":"10 ₽"}}]}]},
      {"id":40,"name":"Photos","start_position":1,"share_url":"https://demo.test/?r46_stories=b&r46_story=40",
       "slides":[{"id":36,"type":"video","background":"https://cdn.test/v.mp4","preview":"https://cdn.test/p.jpg",
                  "share_url":"https://demo.test/?r46_stories=b&r46_story=40&r46_slide=36","elements":[]},
                 {"id":37,"type":"image","background":"https://cdn.test/37.jpg","preview":"",
                  "share_url":"https://demo.test/?r46_stories=b&r46_story=40&r46_slide=37","elements":[]}]},
      {"id":41,"name":"Off","shareable":false,"share_url":"https://demo.test/?r46_story=41",
       "slides":[{"id":50,"type":"image","background":"https://cdn.test/50.jpg","share_url":"https://demo.test/?r46_slide=50"}]}
    ]}}
    """

    func testTheFeedIsUnwrappedFromThePayloadWithTheOldParser() throws {
        let payload = try StoriesApiV3.payload(data: Data(feed.utf8), response: response(200), error: nil).get()
        let stories = PersonalizationStory.list(json: payload, v3: true)
        XCTAssertEqual(stories.map(\.id), ["39", "40", "41"])

        let product = stories[0].slides[0]
        XCTAssertEqual(product.id, "39_0")
        XCTAssertNil(product.background, "JSON null is no background, not the string \"null\"")
        XCTAssertNil(product.preview)
        XCTAssertNil(product.media)
        XCTAssertNotNil(product.offer)
        XCTAssertNil(product.shareUrl)
        XCTAssertEqual(stories[0].shareUrl(of: product)?.absoluteString, "https://demo.test/?r46_stories=b&r46_story=39",
                       "the campaign's link as it is")

        let photos = stories[1]
        XCTAssertTrue(photos.shareable, "no field — sharing is allowed")
        XCTAssertEqual(photos.startPosition, 1)
        XCTAssertEqual(photos.slides.map(\.id), ["36", "37"])
        XCTAssertEqual(photos.shareUrl(of: photos.slides[1])?.absoluteString, "https://demo.test/?r46_stories=b&r46_story=40&r46_slide=37")
        XCTAssertNil(photos.slides[1].preview)

        XCTAssertFalse(stories[2].shareable)
        XCTAssertNil(stories[2].shareUrl(of: stories[2].slides[0]))
    }

    func testFailuresOfTheV3Answer() {
        let fail = Data(#"{"status":"fail","message":"Story not found"}"#.utf8)
        let html = Data("<html><body>Not Found</body></html>".utf8)
        XCTAssertThrowsError(try StoriesApiV3.payload(data: fail, response: response(404), error: nil).get(), "unknown campaign or block")
        XCTAssertThrowsError(try StoriesApiV3.payload(data: fail, response: response(200), error: nil).get(), "status is not success")
        XCTAssertThrowsError(try StoriesApiV3.payload(data: html, response: response(404), error: nil).get(), "a non-numeric id")
        XCTAssertThrowsError(try StoriesApiV3.payload(data: html, response: response(200), error: nil).get())
        XCTAssertThrowsError(try StoriesApiV3.payload(data: Data(#"{"status":"success"}"#.utf8), response: response(200), error: nil).get())
        XCTAssertThrowsError(try StoriesApiV3.payload(data: nil, response: nil, error: URLError(.timedOut)).get())
        XCTAssertThrowsError(try StoriesApiV3.story(payload: ["id": 7]).get(), "a campaign answer without stories")
        XCTAssertEqual(try StoriesApiV3.story(payload: ["stories": []]).get().count, 0)
    }

    // MARK: - Requests

    private func identity(sid: String = "s1", segment: String = "B", stream: String = "ios", testMode: Bool = false) -> StoriesApiV3.Identity {
        StoriesApiV3.Identity(shopId: "shop", did: "d1", sid: sid, segment: segment, stream: stream, testMode: testMode)
    }

    /// Every request carries the identity of the web's `identity()` and `ajax`: shop, did, session,
    /// A/B segment and stream, and `testmode=true` only in the test mode.
    func testRequestAddresses() {
        let api = StoriesApiV3(domain: "app.test")
        let base = "https://app.test/api/v3/storefront/stories"
        let query = "shop_id=shop&did=d1&sid=s1&segment=B&stream=ios"
        XCTAssertEqual(api.feedURL(code: "abc", identity: identity())?.absoluteString, "\(base)/abc?\(query)")
        XCTAssertEqual(api.storyURL(StoriesShareLink(code: "abc", storyId: "40", slideId: "37"), identity: identity())?.absoluteString,
                       "\(base)/abc/story/40?\(query)&slide_id=37")
        XCTAssertEqual(api.storyURL(StoriesShareLink(code: "abc", storyId: "40"), identity: identity())?.absoluteString,
                       "\(base)/abc/story/40?\(query)")
        XCTAssertEqual(api.feedURL(code: "abc", identity: identity(sid: "", segment: "", stream: "flutter", testMode: true))?.absoluteString,
                       "\(base)/abc?shop_id=shop&did=d1&sid=&segment=&stream=flutter&testmode=true",
                       "no session and no group — empty values; the test mode adds testmode=true")
        XCTAssertEqual(api.eventsURL(code: "abc")?.absoluteString, "\(base)/abc/events")
        XCTAssertEqual(api.eventsURL(code: "a/b")?.absoluteString, "\(base)/a%2Fb/events", "the code is one path segment")
    }

    func testTheEventBodyHasTheIdentityANumericCampaignAndAStringSlide() throws {
        let body = StoriesApiV3.eventBody(identity: identity(), event: .view, storyId: "40", slideId: "37")
        let json = try JSONSerialization.data(withJSONObject: body, options: .sortedKeys)
        XCTAssertEqual(String(data: json, encoding: .utf8),
                       #"{"did":"d1","event":"view","segment":"B","shop_id":"shop","sid":"s1","slide_id":"37","story_id":40,"stream":"ios"}"#)

        let virtual = StoriesApiV3.eventBody(identity: identity(testMode: true), event: .sharedOpen, storyId: "39", slideId: "39_0")
        XCTAssertEqual(virtual["event"] as? String, "shared_open")
        XCTAssertEqual(virtual["story_id"] as? Int, 39)
        XCTAssertEqual(virtual["slide_id"] as? String, "39_0")
        XCTAssertEqual(virtual["testmode"] as? Bool, true)
        XCTAssertEqual(StoriesApiV3.eventBody(identity: identity(), event: .share, storyId: "x", slideId: "1")["story_id"] as? String, "x",
                       "a host's own non-numeric id goes as is")
    }

    /// Polls send the identity without the A/B segment, as the web's `PollsApi`.
    func testTheFieldsOfPollAnswersHaveNoSegment() throws {
        let json = try JSONSerialization.data(withJSONObject: identity().fields(segment: false), options: .sortedKeys)
        XCTAssertEqual(String(data: json, encoding: .utf8), #"{"did":"d1","shop_id":"shop","sid":"s1","stream":"ios"}"#)
        XCTAssertEqual(identity(testMode: true).fields(segment: false)["testmode"] as? Bool, true)
    }

    /// The identity of the moment: the SDK's session, its A/B group and stream, and the test mode of
    /// popups v3 — the flag that sends `testmode=true` with `/init`.
    func testTheCurrentIdentityTakesTheSdkAndThePopupsTestMode() {
        let sdk = FakeSDK(shopId: "shop")
        sdk.segment = "B"
        XCTAssertEqual(StoriesApiV3.Identity.current(sdk: sdk, did: "d1"),
                       .init(shopId: "shop", did: "d1", sid: "fake-seance", segment: "B", stream: "ios", testMode: false))
        sdk.popups.testMode = true
        defer { sdk.popups.testMode = false }
        XCTAssertTrue(StoriesApiV3.Identity.current(sdk: sdk, did: "d1").testMode)
    }

    /// Records what goes to the network and answers with `answer`.
    private func capture(answer: @escaping (URLRequest) -> (Data?, Int)) -> () -> [URLRequest] {
        let lock = NSLock()
        var requests: [URLRequest] = []
        StoriesApiV3.transport = { request, completion in
            lock.lock()
            requests.append(request)
            lock.unlock()
            let (data, status) = answer(request)
            completion(data, self.response(status), nil)
        }
        return {
            lock.lock()
            defer { lock.unlock() }
            return requests
        }
    }

    private func body(_ request: URLRequest) -> [String: Any] {
        request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
    }

    func testAV3SessionSendsEveryEventEvenForVirtualSlidesAndKeepsTheSource() {
        let sent = expectation(description: "events")
        sent.expectedFulfillmentCount = 4
        let requests = capture { _ in
            sent.fulfill()
            return (Data("{}".utf8), 200)
        }
        let session = StoriesSession(sdk: FakeSDK(shopId: "shop"), code: "block", v3Domain: "app.test")
        let slide = PersonalizationStorySlide(id: "39_0", kind: .content)
        let story = PersonalizationStory(id: "39", name: "P", slides: [slide])
        UserDefaults.standard.removeObject(forKey: "recomendedCode")

        session.slideShown(story, slide)
        session.track(.click, story, slide)
        session.track(.share, story, slide)
        session.sharedOpened(story, slide)
        wait(for: [sent], timeout: 5)

        let all = requests()
        XCTAssertEqual(Set(all.compactMap { body($0)["event"] as? String }), ["view", "click", "share", "shared_open"])
        for request in all {
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://app.test/api/v3/storefront/stories/block/events")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(body(request)["shop_id"] as? String, "shop")
            XCTAssertEqual(body(request)["did"] as? String, "fake-device-id")
            XCTAssertEqual(body(request)["story_id"] as? Int, 39)
            XCTAssertEqual(body(request)["slide_id"] as? String, "39_0")
            XCTAssertEqual(body(request)["sid"] as? String, "fake-seance")
            XCTAssertEqual(body(request)["segment"] as? String, "A")
            XCTAssertEqual(body(request)["stream"] as? String, "ios")
            XCTAssertNil(body(request)["testmode"], "only in the test mode")
        }
        XCTAssertEqual(UserDefaults.standard.string(forKey: "recomendedCode"), "block", "view and click attribute what follows to the block")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "recomendedType"), "stories")
    }

    func testWithoutV3TheSessionSendsNothingToV3() {
        _ = capture { _ in
            XCTFail("the old API has no v3 events")
            return (nil, 500)
        }
        let session = StoriesSession(sdk: FakeSDK(), code: "block")
        let slide = PersonalizationStorySlide(id: "39_0", kind: .content)
        session.track(.share, PersonalizationStory(id: "39", name: "P", slides: [slide]), slide)
        session.slideShown(PersonalizationStory(id: "39", name: "P", slides: [slide]), slide)
        let settled = expectation(description: "queue")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
    }

    func testTheFeedLoaderGoesToV3AndWaitsForTheDid() {
        let sdk = FakeSDK(shopId: "shop")
        sdk.deviceId = ""
        let requests = capture { _ in (Data(self.feed.utf8), 200) }
        let loaded = expectation(description: "feed")
        StoriesBlockLoader.load(sdk: sdk, code: "block", v3Domain: "app.test") { result in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual((try? result.get())?.map(\.id), ["39", "40", "41"])
            loaded.fulfill()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { sdk.deviceId = "late-did" }
        wait(for: [loaded], timeout: 5)
        XCTAssertEqual(requests().first?.url?.absoluteString,
                       "https://app.test/api/v3/storefront/stories/block?shop_id=shop&did=late-did&sid=fake-seance&segment=A&stream=ios")
        XCTAssertEqual(requests().first?.httpMethod, "GET")
    }

    func testNoDidInTimeIsALoadErrorWithoutARequest() {
        StoriesApiV3.deviceIdTimeout = 0.3
        let sdk = FakeSDK()
        sdk.deviceId = ""
        let requests = capture { _ in (nil, 500) }
        let failed = expectation(description: "error")
        StoriesBlockLoader.load(sdk: sdk, code: "block", v3Domain: "app.test") { result in
            if case .failure = result { failed.fulfill() }
        }
        wait(for: [failed], timeout: 5)
        XCTAssertTrue(requests().isEmpty)
    }

    // MARK: - handleLink

    private let demoLink = URL(string: "https://demo.rees46.ru/?r46_stories=115bd0b67cf5989a1b60c841790b2af6&r46_story=40&r46_slide=37")!

    func testHandleLinkTakesOnlyStoriesLinksAndOnlyWithV3() {
        _ = capture { _ in
            XCTFail("nothing is loaded")
            return (nil, 500)
        }
        PersonalizationStories.apiV3Domain = nil
        XCTAssertFalse(PersonalizationStories.handleLink(demoLink, sdk: FakeSDK()), "without apiV3Domain")
        PersonalizationStories.apiV3Domain = "  "
        XCTAssertFalse(PersonalizationStories.handleLink(demoLink, sdk: FakeSDK()), "a blank host is no host")
        PersonalizationStories.apiV3Domain = "app.test"
        XCTAssertFalse(PersonalizationStories.handleLink(demoLink, sdk: FakeSDK(), apiV3Domain: nil), "the call's own nil wins over the global host")
        XCTAssertFalse(PersonalizationStories.handleLink(URL(string: "https://demo.rees46.ru/catalog?utm_source=tg")!, sdk: FakeSDK()))
        XCTAssertFalse(PersonalizationStories.handleLink(URL(string: "https://demo.rees46.ru/?r46_stories=b&r46_story=x")!, sdk: FakeSDK()))
    }

    /// Calls `present`'s completion, so `shared_open` goes out the way it does after a real show.
    private final class PresentingHost: UIViewController {
        var shown: [UIViewController] = []
        override func present(_ controller: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
            shown.append(controller)
            completion?()
        }
    }

    func testALinkOpensItsCampaignFromTheLinkSlideAndReportsTheOpen() throws {
        // The call's own host wins over the global one.
        PersonalizationStories.apiV3Domain = "global.test"
        let story = """
        {"status":"success","payload":{"id":7,"stories":[{"id":40,"name":"Photos","start_position":1,"viewed":true,
          "share_url":"https://demo.test/?r46_story=40","slides":[
            {"id":36,"type":"image","background":"https://cdn.test/36.jpg"},
            {"id":37,"type":"image","background":"https://cdn.test/37.jpg"}]}]}}
        """
        let opened = expectation(description: "shared_open")
        let requests = capture { request in
            if self.body(request)["event"] as? String == "shared_open" { opened.fulfill() }
            return (request.httpMethod == "GET" ? Data(story.utf8) : Data("{}".utf8), 200)
        }
        let host = PresentingHost()
        var errors = 0
        XCTAssertTrue(PersonalizationStories.handleLink(demoLink, sdk: FakeSDK(shopId: "shop"), apiV3Domain: "app.test", from: host,
                                                        shareUrlTransform: { "app" + $0.dropFirst("https".count) },
                                                        onError: { _ in errors += 1 }))
        wait(for: [opened], timeout: 5)

        XCTAssertEqual(errors, 0)
        XCTAssertEqual(requests().first?.url?.absoluteString,
                       "https://app.test/api/v3/storefront/stories/115bd0b67cf5989a1b60c841790b2af6/story/40?shop_id=shop&did=fake-device-id&sid=fake-seance&segment=A&stream=ios&slide_id=37")
        let viewer = try XCTUnwrap(host.shown.first as? PersonalizationStoriesViewController)
        XCTAssertEqual(viewer.startSlideIndex(of: viewer.stories[0]), 1, "a viewed campaign still opens on the link slide")
        XCTAssertEqual((viewer.shareItem(for: URL(string: "https://demo.test/?r46_story=40")!) as? URL)?.absoluteString,
                       "app://demo.test/?r46_story=40", "the link's viewer shares through the call's transform")
        let sharedOpen = requests().map(body).first { $0["event"] as? String == "shared_open" }
        XCTAssertEqual(sharedOpen?["story_id"] as? Int, 40)
        XCTAssertEqual(sharedOpen?["slide_id"] as? String, "37")

        XCTAssertTrue(PersonalizationStories.handleLink(demoLink, sdk: FakeSDK(shopId: "shop"), apiV3Domain: "app.test", from: host),
                      "the same link while it is open")
        XCTAssertEqual(host.shown.count, 1)
        viewer.close()
    }

    func testAProductCampaignLinkOpensOnItsSlideThoughTheServerStartsAtTheFirst() throws {
        // The server does not know virtual slides: `slide_id=39_2` still answers `start_position: 0`.
        let story = """
        {"status":"success","payload":{"id":7,"stories":[{"id":39,"name":"Products","start_position":0,
          "share_url":"https://demo.test/?r46_story=39","slides":[
            {"id":"39_0","type":"","elements":[{"type":"product","item":{"id":"1","name":"A"}}]},
            {"id":"39_1","type":"","elements":[{"type":"product","item":{"id":"2","name":"B"}}]},
            {"id":"39_2","type":"","elements":[{"type":"product","item":{"id":"3","name":"C"}}]}]}]}}
        """
        let opened = expectation(description: "shared_open")
        let requests = capture { request in
            if self.body(request)["event"] as? String == "shared_open" { opened.fulfill() }
            return (request.httpMethod == "GET" ? Data(story.utf8) : Data("{}".utf8), 200)
        }
        let host = PresentingHost()
        let link = URL(string: "rees46://demo.test/?r46_stories=products&r46_story=39&r46_slide=39_2")!
        XCTAssertTrue(PersonalizationStories.handleLink(link, sdk: FakeSDK(shopId: "shop"), apiV3Domain: "app.test", from: host))
        wait(for: [opened], timeout: 5)

        let viewer = try XCTUnwrap(host.shown.first as? PersonalizationStoriesViewController)
        XCTAssertEqual(viewer.startSlideIndex(of: viewer.stories[0]), 2, "the slide that was shared, not the server's first")
        let sharedOpen = requests().map(body).first { $0["event"] as? String == "shared_open" }
        XCTAssertEqual(sharedOpen?["slide_id"] as? String, "39_2")
        viewer.close()
    }

    func testALinkSlideMissingFromTheFirstCampaignLeavesTheServersStart() throws {
        // Only the first campaign of the answer starts on the link slide; the rest start as in the feed
        // (no history here — their `start_position`).
        let story = """
        {"status":"success","payload":{"id":7,"stories":[
          {"id":40,"name":"Photos","start_position":1,"slides":[{"id":36,"type":"image","background":"https://cdn.test/36.jpg"},
            {"id":37,"type":"image","background":"https://cdn.test/37.jpg"}]},
          {"id":41,"name":"More","start_position":0,"slides":[{"id":50,"type":"image","background":"https://cdn.test/50.jpg"},
            {"id":99,"type":"image","background":"https://cdn.test/99.jpg"}]}]}}
        """
        let opened = expectation(description: "shared_open")
        let requests = capture { request in
            if self.body(request)["event"] as? String == "shared_open" { opened.fulfill() }
            return (request.httpMethod == "GET" ? Data(story.utf8) : Data("{}".utf8), 200)
        }
        let host = PresentingHost()
        let link = URL(string: "rees46://demo.test/?r46_stories=gone&r46_story=40&r46_slide=99")!
        XCTAssertTrue(PersonalizationStories.handleLink(link, sdk: FakeSDK(shopId: "shop"), apiV3Domain: "app.test", from: host))
        wait(for: [opened], timeout: 5)

        let viewer = try XCTUnwrap(host.shown.first as? PersonalizationStoriesViewController)
        XCTAssertEqual(viewer.startSlideIndex(of: viewer.stories[0]), 1, "no such slide in the campaign — the server's start_position")
        XCTAssertEqual(viewer.startSlideIndex(of: viewer.stories[1]), 0, "another campaign without history — its own start_position")
        let sharedOpen = requests().map(body).first { $0["event"] as? String == "shared_open" }
        XCTAssertEqual(sharedOpen?["story_id"] as? Int, 40)
        XCTAssertEqual(sharedOpen?["slide_id"] as? String, "37", "the open is reported with the slide it started on")
        viewer.close()
    }

    func testTheSameLinkWhileItLoadsIsIgnoredAndAFailureFreesIt() {
        PersonalizationStories.apiV3Domain = "app.test"
        let link = URL(string: "https://demo.test/?r46_stories=dedup&r46_story=40")!
        let requested = expectation(description: "request")
        let lock = NSLock()
        var pending: [(Data?, URLResponse?, Error?) -> Void] = []
        StoriesApiV3.transport = { _, completion in
            lock.lock()
            pending.append(completion)
            lock.unlock()
            requested.fulfill()
        }
        let failed = expectation(description: "error")
        XCTAssertTrue(PersonalizationStories.handleLink(link, sdk: FakeSDK(), onError: { _ in failed.fulfill() }))
        XCTAssertTrue(PersonalizationStories.handleLink(link, sdk: FakeSDK(), onError: { _ in XCTFail("a repeat is ignored") }))
        wait(for: [requested], timeout: 5)
        lock.lock()
        let answers = pending
        lock.unlock()
        XCTAssertEqual(answers.count, 1)
        answers.first?(Data(#"{"status":"fail","message":"Story not found"}"#.utf8), response(404), nil)
        wait(for: [failed], timeout: 5)

        let again = expectation(description: "loads again")
        StoriesApiV3.transport = { _, completion in
            completion(Data(#"{"status":"success","payload":{"stories":[]}}"#.utf8), self.response(200), nil)
        }
        XCTAssertTrue(PersonalizationStories.handleLink(link, sdk: FakeSDK(), onError: { _ in again.fulfill() }), "an empty campaign is an error too")
        wait(for: [again], timeout: 5)
    }

    // MARK: - No scene on screen yet (a cold start from a link)

    func testWithoutASceneOnScreenTheLinkWaitsForActivationAndThenShows() {
        PersonalizationStories.keyRoot = { nil }
        let story = """
        {"status":"success","payload":{"id":7,"stories":[{"id":41,"name":"Cold","start_position":0,
          "slides":[{"id":51,"type":"image","background":"https://cdn.test/51.jpg"}]}]}}
        """
        let loaded = expectation(description: "campaign")
        let opened = expectation(description: "shared_open")
        _ = capture { request in
            if request.httpMethod == "GET" { loaded.fulfill() }
            if self.body(request)["event"] as? String == "shared_open" { opened.fulfill() }
            return (request.httpMethod == "GET" ? Data(story.utf8) : Data("{}".utf8), 200)
        }
        let host = PresentingHost()
        var errors = 0
        let link = URL(string: "https://demo.test/?r46_stories=cold&r46_story=41")!
        XCTAssertTrue(PersonalizationStories.handleLink(link, sdk: FakeSDK(shopId: "shop"), apiV3Domain: "app.test",
                                                        onError: { _ in errors += 1 }))
        wait(for: [loaded], timeout: 5)
        let settled = expectation(description: "answer handled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
        XCTAssertTrue(host.shown.isEmpty, "no scene on screen — nothing to show from yet")
        XCTAssertEqual(errors, 0, "waiting is no error")

        PersonalizationStories.keyRoot = { host }
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: UIApplication.shared)
        wait(for: [opened], timeout: 5)
        XCTAssertEqual(host.shown.count, 1)
        XCTAssertEqual(errors, 0)
        (host.shown.first as? PersonalizationStoriesViewController)?.close()
    }

    func testThePresenterWaitEndsWithNothingAtTheDeadline() {
        PersonalizationStories.keyRoot = { nil }
        let done = expectation(description: "deadline")
        PersonalizationStories.awaitPresenter(nil, until: Date().addingTimeInterval(0.2)) { host in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(host)
            done.fulfill()
        }
        wait(for: [done], timeout: 2)
        let host = UIViewController()
        PersonalizationStories.awaitPresenter(host, until: Date()) { XCTAssertTrue($0 === host, "an explicit presenter needs no wait") }
    }

    // MARK: - The widget's host

    func testTheWidgetsHostWinsOverTheGlobalOne() {
        PersonalizationStories.apiV3Domain = "global.test"
        XCTAssertEqual(PersonalizationStories(code: "block").apiV3Domain, "global.test", "without its own, the global host")
        let requests = capture { _ in (Data(self.feed.utf8), 200) }
        let stories = PersonalizationStories(code: "block", apiV3Domain: "widget.test")
        let loaded = expectation(description: "feed")
        stories.onLoaded = { _ in loaded.fulfill() }
        stories.attach(FakeSDK(shopId: "shop"))
        wait(for: [loaded], timeout: 5)
        XCTAssertEqual(requests().map { $0.url?.host }, ["widget.test"])
    }

    func testAWidgetWithoutAHostStaysOnTheOldApiNextToAV3One() {
        PersonalizationStories.apiV3Domain = nil
        let requests = capture { _ in (Data(self.feed.utf8), 200) }
        let plain = PersonalizationStories(code: "plain")
        let sharing = PersonalizationStories(code: "sharing", apiV3Domain: "app.test")
        XCTAssertNil(plain.apiV3Domain)
        let oldApi = expectation(description: "old API")
        let oldSDK = FakeSDK(shopId: "shop")
        oldSDK.onGetRequest = { path, _ in
            XCTAssertEqual(path, "stories/plain")
            oldApi.fulfill()
        }
        let v3SDK = FakeSDK(shopId: "shop")
        v3SDK.onGetRequest = { path, _ in XCTFail("the v3 widget asked the old API for \(path)") }
        let loaded = expectation(description: "v3 feed")
        sharing.onLoaded = { _ in loaded.fulfill() }
        plain.attach(oldSDK)
        sharing.attach(v3SDK)
        wait(for: [oldApi, loaded], timeout: 5)
        XCTAssertEqual(requests().map { $0.url?.path }, ["/api/v3/storefront/stories/sharing"])
    }

    // MARK: - The shared link's transform

    func testTheTransformReachesTheViewerAndTheLinkGoesAsIsWithoutIt() {
        let link = URL(string: "https://demo.test/?r46_stories=b&r46_story=40&r46_slide=37")!
        let story = PersonalizationStory(id: "40", name: "S", slides: [PersonalizationStorySlide(id: "37", kind: .content)])
        let plain = StoriesSession(sdk: FakeSDK(), code: "b").makeViewer(stories: [story], startIndex: 0)
        XCTAssertEqual(plain.shareItem(for: link) as? URL, link, "no transform — the link as is")

        let session = StoriesSession(sdk: FakeSDK(), code: "b")
        session.shareUrlTransform = { $0.replacingOccurrences(of: "https://", with: "rees46://") }
        let viewer = session.makeViewer(stories: [story], startIndex: 0)
        XCTAssertEqual((viewer.shareItem(for: link) as? URL)?.absoluteString, "rees46://demo.test/?r46_stories=b&r46_story=40&r46_slide=37")

        viewer.shareUrlTransform = { _ in "" }
        XCTAssertEqual(viewer.shareItem(for: link) as? String, "", "what is no address goes as text")
    }

    // MARK: - Button

    func testTheShareButtonSitsLeftOfTheCrossAndIsHiddenByDefault() throws {
        let navigation = PersonalizationStoryNavigation()
        navigation.frame = CGRect(x: 0, y: 0, width: 300, height: PersonalizationStoryNavigation.height)
        navigation.layoutIfNeeded()
        let share = try XCTUnwrap(navigation.shareAnchor as? UIButton)
        XCTAssertFalse(navigation.isShareVisible)
        XCTAssertTrue(share.isHidden)
        XCTAssertEqual(share.accessibilityLabel, "Share")
        XCTAssertEqual(share.frame, CGRect(x: 300 - 32 - 8 - 32, y: navigation.bounds.height - 32, width: 32, height: 32))
        XCTAssertEqual(share.alpha, 0.65, accuracy: 0.001)

        var taps = 0
        navigation.onShare = { taps += 1 }
        navigation.isShareVisible = true
        navigation.shareLabel = "Поделиться"
        share.sendActions(for: .touchUpInside)
        XCTAssertEqual(taps, 1)
        XCTAssertEqual(share.accessibilityLabel, "Поделиться")
        XCTAssertEqual(PersonalizationStoriesTexts().shareLabel, "Share")
    }

    func testTheButtonShowsOnSlidesWithALinkAndPausesTheSlide() throws {
        let linked = PersonalizationStorySlide(id: "37", kind: .content, shareUrl: "https://demo.test/?r46_slide=37")
        let bare = PersonalizationStorySlide(id: "38", kind: .content)
        let story = PersonalizationStory(id: "40", name: "S", slides: [linked, bare])
        let viewer = PersonalizationStoriesViewController(stories: [story])
        var shared: [String] = []
        viewer.onShare = { story, slide in shared.append("\(story.id)/\(slide.id)") }
        viewer.loadViewIfNeeded()
        let page = try XCTUnwrap(viewer.pager.viewControllers?.first as? PersonalizationStoryPageViewController)
        page.loadViewIfNeeded()
        viewer.settle(on: page)
        XCTAssertTrue(page.navigation.isShareVisible)
        XCTAssertTrue(reachesNoSlideGesture(page.navigation.shareAnchor, on: page), "a tap on Share neither pages nor holds")

        viewer.shareTapped(on: page)
        XCTAssertEqual(shared, ["40/37"], "the event goes out at once")
        XCTAssertTrue(viewer.state.pauses.contains(.share))
        viewer.setPaused(.share, false)
        XCTAssertFalse(viewer.state.pauses.contains(.share))

        page.show(1)
        XCTAssertFalse(page.navigation.isShareVisible, "no link — no button")
    }

    private final class Touch: UITouch {
        private let target: UIView?
        init(on view: UIView?) {
            target = view
            super.init()
        }
        override var view: UIView? { target }
    }

    private func reachesNoSlideGesture(_ view: UIView, on page: PersonalizationStoryPageViewController) -> Bool {
        let gestures = (page.view.gestureRecognizers ?? []).filter { $0.delegate === page }
        return !gestures.isEmpty && gestures.allSatisfy { !page.gestureRecognizer($0, shouldReceive: Touch(on: view)) }
    }
}

// MARK: - Slides of the v3 feed: what happens is the web's

extension PersonalizationStoriesShareTests {

    private func slide(_ json: [String: Any], v3: Bool = true) throws -> PersonalizationStorySlide {
        try XCTUnwrap(PersonalizationStorySlide(json: json, v3: v3))
    }

    /// Media is decided by `type`, as `switch(slide.type)` of the web; the old feed keeps its rule.
    func testTheMediaOfAV3SlideIsItsType() throws {
        let content: [String: Any] = ["id": 1, "type": "", "background": "https://cdn.test/1.jpg"]
        XCTAssertNil(try slide(content).media, "a slide of no media type has no media")
        XCTAssertEqual(try slide(content, v3: false).media, .image("https://cdn.test/1.jpg"), "the old feed: any background")
        XCTAssertEqual(try slide(["id": 2, "type": "image", "background": "https://cdn.test/2.jpg"]).media, .image("https://cdn.test/2.jpg"))
        XCTAssertEqual(try slide(["id": 3, "type": "video", "background": "https://cdn.test/3.mp4"]).media, .video("https://cdn.test/3.mp4"))
        XCTAssertNil(try slide(["id": 4, "type": "image", "background": NSNull()]).media)
    }

    /// `background_color` paints a slide without media; the kit's card colour only without it.
    func testABackgroundColourPaintsAV3SlideWithoutMedia() throws {
        let red = UIColor(red: 1, green: 0, blue: 0, alpha: 1)
        XCTAssertEqual(try slide(["id": 1, "type": "", "background_color": "#FF0000"]).fillColor, red)
        XCTAssertEqual(try slide(["id": 1, "type": "", "background_color": "#FF0000"], v3: false).fillColor, PersonalizationColor.backgroundCard,
                       "the old feed keeps the kit's card")
        XCTAssertEqual(try slide(["id": 1, "type": ""]).fillColor, PersonalizationColor.backgroundCard)
        XCTAssertEqual(try slide(["id": 1, "type": "image", "background": "https://cdn.test/1.jpg", "background_color": "#FF0000"]).fillColor, red,
                       "around the media too")
        let view = PersonalizationStorySlideView(slide: try slide(["id": 1, "type": "", "background_color": "#FF0000"]),
                                                 texts: .init(), isMuted: true, imageLoader: { _, _ in })
        XCTAssertEqual(view.backgroundColor, red)
        XCTAssertEqual(try slide(["id": 1, "type": "", "background_color": "#1E3A8A"]).interfaceStyle, .dark, "the kit's texts stay readable")
        XCTAssertEqual(try slide(["id": 1, "type": "", "background_color": "#FDE68A"]).interfaceStyle, .light)
        XCTAssertEqual(try slide(["id": 1, "type": "", "background_color": "#1E3A8A"], v3: false).interfaceStyle, .unspecified)
    }

    /// One rule of the text block: the kit's body size, `bold` then `text_bold`, `italic` then
    /// `text_italic` (true, 1, "true"), opacity as the web's `calculateOpacity` — a number is a
    /// percent — and `monospace` or `monospaced`.
    func testTextBlocksOfV3FollowOneRule() throws {
        func block(_ json: [String: Any], v3: Bool = true) throws -> PersonalizationStorySlide.TextBlock {
            try XCTUnwrap(PersonalizationStorySlide.TextBlock(json: json.merging(["text_input": "Привет"]) { own, _ in own }, v3: v3))
        }
        XCTAssertEqual(try block([:]).style, .init(size: 16, lineHeight: 24), "the kit's Base/Default")
        XCTAssertEqual(try block([:], v3: false).style, .small, "the old feed keeps Small")
        XCTAssertEqual(try block(["font_size": 30]).style, .medium)
        XCTAssertEqual(try block(["font_size": 20, "text_line_spacing": 1.5]).style, .init(size: 20, lineHeight: 30))
        XCTAssertTrue(try block(["bold": true, "text_bold": false]).bold, "bold wins")
        XCTAssertTrue(try block(["text_bold": true]).bold, "the legacy key is read too")
        XCTAssertFalse(try block(["bold": false, "text_bold": true]).bold)
        XCTAssertTrue(try block(["text_italic": true]).italic)
        XCTAssertFalse(try block(["italic": false, "text_italic": true]).italic, "italic wins")
        XCTAssertTrue(try block(["bold": 1]).bold)
        XCTAssertTrue(try block(["bold": "true"]).bold)
        XCTAssertFalse(try block(["bold": "1"]).bold, "only true, 1 and \"true\"")
        XCTAssertTrue(try block(["bold": NSNull(), "text_bold": "true"]).bold, "null is no bold: the legacy key")
        XCTAssertEqual(try block(["font_type": "monospace"]).fontFamily, .monospaced)
        XCTAssertEqual(try block(["font_type": "monospaced"]).fontFamily, .monospaced)
        XCTAssertEqual(try block(["font_type": "serif"]).fontFamily, .serif)
        XCTAssertEqual(try block(["font_type": "sans-serif"]).fontFamily, .sansSerif)
        func alpha(_ opacity: Any?) throws -> CGFloat? {
            var json: [String: Any] = ["text_background_color": "#000000"]
            json["text_background_color_opacity"] = opacity
            return try block(json).fill?.cgColor.alpha
        }
        for (opacity, expected) in [("50%", 0.5), (50, 0.5), ("50", 0.5), ("0.5", 0.005), (0.5, 0.005), ("0", 0), ("100%", 1), ("35.5%", 0.355)] as [(Any, CGFloat)] {
            XCTAssertEqual(try alpha(opacity) ?? -1, expected, accuracy: 0.0001, "\(opacity)")
        }
        for opacity in [nil, "", 0, "abc", 150, -5, true] as [Any?] {
            XCTAssertEqual(try alpha(opacity) ?? -1, 1, accuracy: 0.0001, "\(String(describing: opacity)): no opacity — opaque")
        }
        XCTAssertEqual(try block(["text_background_color": "#000000", "text_background_color_opacity": "0.5"], v3: false).fill?.cgColor.alpha ?? -1,
                       0.5, accuracy: 0.0001, "the old feed keeps its fraction")
    }

    /// A button without a link sends `click` and opens nothing, as the web; no product fallback.
    func testAV3ButtonWithoutALinkOpensNothing() throws {
        let json: [String: Any] = ["id": "39_0", "type": "", "elements": [
            ["type": "product", "item": ["id": "1", "name": "Pool", "price": 10, "url": "https://shop.test/pool"]],
            ["type": "button", "title": "Купить"]
        ]]
        let v3 = try slide(json)
        XCTAssertNil(v3.link(of: v3.buttons[0]))
        XCTAssertNil(v3.buttons[0].element?.productId, "the slide's product is not put into the button")
        XCTAssertEqual(try slide(json, v3: false).buttons[0].element?.productId, "1", "the old feed puts it")
        let old = try slide(json, v3: false)
        XCTAssertEqual(old.link(of: old.buttons[0]), "https://shop.test/pool", "the old feed opens the product")

        let sent = expectation(description: "click")
        let requests = capture { request in
            sent.fulfill()
            return (Data("{}".utf8), 200)
        }
        let session = StoriesSession(sdk: FakeSDK(shopId: "shop"), code: "block", v3Domain: "app.test")
        var opened: [String] = []
        session.openURL = { opened.append($0.absoluteString) }
        let story = PersonalizationStory(id: "39", name: "P", slides: [v3])
        session.buttonTapped(story, v3, v3.buttons[0], in: nil)
        wait(for: [sent], timeout: 5)
        XCTAssertEqual(requests().map { body($0)["event"] as? String }, ["click"])
        XCTAssertEqual(opened, [])
    }

    /// `click` is for a button, a header and a carousel product: copying a promo code sends none.
    func testCopyingAPromoCodeSendsNoClickToV3() {
        let requests = capture { _ in (Data("{}".utf8), 200) }
        let session = StoriesSession(sdk: FakeSDK(shopId: "shop"), code: "block", v3Domain: "app.test")
        let slide = PersonalizationStorySlide(id: "1", kind: .content, textBlocks: [.init(text: "Code", promoCode: "TEXT10")])
        session.promoCopied(PersonalizationStory(id: "1", name: "S", slides: [slide]), slide, "TEXT10")
        let settled = expectation(description: "queue")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
        XCTAssertTrue(requests().isEmpty)

        let sdk = FakeSDK(shopId: "shop")
        StoriesSession(sdk: sdk, code: "block").promoCopied(PersonalizationStory(id: "1", name: "S", slides: [slide]), slide, "TEXT10")
        XCTAssertEqual(sdk.trackedEvents.count, 1, "the old feed still counts it as a click")
    }

    /// Back on the first slide of the first story closes a v3 viewer, as the web (`prev` with
    /// `i <= 0`), and the story is not counted as watched; the old feed restarts the slide, with no
    /// repeat `view`.
    func testBackOnTheFirstSlideClosesAV3ViewerAsTheWeb() throws {
        func run(v3: Bool) throws -> (shown: [String], closed: Bool, left: [String]) {
            var slide = PersonalizationStorySlide(id: "1", kind: .content)
            slide.isV3 = v3
            let viewer = PersonalizationStoriesViewController(stories: [PersonalizationStory(id: "s", name: "S", slides: [slide])])
            var shown: [String] = []
            var left: [String] = []
            var closed = false
            viewer.onSlideView = { _, slide in shown.append(slide.id) }
            viewer.onStoryLeftForward = { story, _ in left.append(story.id) }
            viewer.onClose = { closed = true }
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
            window.rootViewController = viewer
            window.isHidden = false
            defer { window.isHidden = true }
            let page = try XCTUnwrap(viewer.pager.viewControllers?.first as? PersonalizationStoryPageViewController)
            viewer.settle(on: page)
            viewer.apply(viewer.state.previous())
            return (shown, closed, left)
        }
        let v3 = try run(v3: true)
        XCTAssertTrue(v3.closed)
        XCTAssertEqual(v3.shown, ["1"])
        XCTAssertEqual(v3.left, [], "closing backwards does not watch the story")
        let old = try run(v3: false)
        XCTAssertFalse(old.closed, "the old feed restarts the slide")
        XCTAssertEqual(old.shown, ["1"], "the old feed: no view on a restart")
        XCTAssertEqual(PersonalizationStoriesViewerState(slideCounts: [2, 1], story: 1, closesFromStart: true).previous(),
                       .showStory(0, forward: false), "a later story goes back to the one before")
    }

    /// A v3 slide with no media type and no `product` element is skipped, as the web's `next()`: it
    /// stays in its story with its progress segment, and the viewer passes it. The old feed shows
    /// every slide.
    func testAV3SlideWithoutMediaOrProductIsKeptAndPassed() throws {
        let json: [String: Any] = ["id": 1, "start_position": 2, "slides": [
            ["id": 10, "type": "", "elements": [["type": "text_block", "text_input": "Hi"]]],
            ["id": 11, "type": "image", "background": "https://cdn.test/11.jpg"],
            ["id": 12, "type": "", "background_color": "#FF0000"],
            ["id": 13, "type": "", "elements": [["type": "product", "item": ["id": "1", "name": "Pool"]]]],
            ["id": 14, "type": "video", "background": "https://cdn.test/14.mp4"]
        ]]
        let v3 = try XCTUnwrap(PersonalizationStory(json: json, v3: true))
        XCTAssertEqual(v3.slides.map(\.id), ["10", "11", "12", "13", "14"], "the segments stay")
        XCTAssertEqual(v3.slides.map(\.isSkipped), [true, false, true, false, false])
        XCTAssertEqual(v3.startPosition, 2)
        let viewer = PersonalizationStoriesViewController(stories: [v3])
        XCTAssertEqual(viewer.startSlideIndex(of: v3), 3, "start_position on a skipped slide: the next shown one")
        let old = try XCTUnwrap(PersonalizationStory(json: json))
        XCTAssertEqual(old.slides.map(\.isSkipped), [false, false, false, false, false])
        XCTAssertEqual(PersonalizationStoriesViewController(stories: [old]).startSlideIndex(of: old), 2)

        let empty: [String: Any] = ["stories": [["id": 2, "slides": [["id": 20, "type": ""]]]]]
        XCTAssertEqual(PersonalizationStory.list(json: empty, v3: true).map(\.id), ["2"], "a story of skipped slides stays in the bar")

        // Forward passes a skipped slide, backward steps over it.
        var state = PersonalizationStoriesViewerState(slideCounts: [5, 2], skipped: [[0, 2], []], closesFromStart: true)
        state.enter(story: 0, slide: 1, mediaReady: true)
        XCTAssertEqual(state.next(), .showSlide(3))
        state.enter(slide: 3, mediaReady: true)
        XCTAssertEqual(state.previous(), .showSlide(1))
        state.enter(slide: 1, mediaReady: true)
        XCTAssertEqual(state.previous(), .closeFromStart, "slide 0 is skipped: back from the first shown slide")
        var tail = PersonalizationStoriesViewerState(slideCounts: [3, 1], skipped: [[2], []])
        tail.enter(story: 0, slide: 1, mediaReady: true)
        XCTAssertEqual(tail.next(), .showStory(1, forward: true), "a skipped last slide ends the story")
    }

    /// A story with nothing to show from its start — all its slides skipped, or only skipped ones
    /// after `start_position` — is passed and watched, as the web; the last one closes the viewer,
    /// which is never shown empty.
    func testAStoryWithNothingToShowIsPassedAndWatched() throws {
        func story(_ id: String, skipped: [Bool], start: Int = 0) -> PersonalizationStory {
            let slides = skipped.enumerated().map { index, skip -> PersonalizationStorySlide in
                var slide = PersonalizationStorySlide(id: "\(id)\(index)", kind: skip ? .content : .image, background: "https://cdn.test/\(id).jpg")
                slide.isV3 = true
                slide.isSkipped = skip
                return slide
            }
            return PersonalizationStory(id: id, name: id, startPosition: start, slides: slides)
        }
        let stories = [story("a", skipped: [true, true]), story("b", skipped: [false, true], start: 1), story("c", skipped: [false])]
        let viewer = PersonalizationStoriesViewController(stories: stories)
        var left: [String] = []
        viewer.onStoryLeftForward = { story, throughEnd in left.append(story.id + (throughEnd ? "!" : "")) }
        XCTAssertTrue(viewer.prepareStart())
        XCTAssertEqual(viewer.currentIndex, 2, "a and b (from its start) have nothing to show")
        XCTAssertEqual(left, ["a!", "b!"], "both passed and watched")

        let nothing = PersonalizationStoriesViewController(stories: [story("x", skipped: [true]), story("y", skipped: [true, true])])
        XCTAssertFalse(nothing.prepareStart(), "nothing to show: no viewer at all")

        // Forward from a story passes an empty one; the last one empty closes the viewer.
        let chain = PersonalizationStoriesViewController(stories: [story("p", skipped: [false]), story("q", skipped: [true]), story("r", skipped: [false])])
        var passed: [String] = []
        chain.onStoryLeftForward = { story, _ in passed.append(story.id) }
        XCTAssertEqual(chain.passStories(from: 1), 2)
        XCTAssertEqual(passed, ["q"])
        XCTAssertEqual(chain.previousStory(from: 1), 0, "backward steps over it without marks")
        XCTAssertEqual(passed, ["q"])
        XCTAssertEqual(chain.nextStory(after: 0), 2, "a swipe goes past it too")
        XCTAssertNil(PersonalizationStoriesViewController(stories: [story("s", skipped: [false]), story("t", skipped: [true])]).nextStory(after: 0))
    }

    /// A v3 story opens at the feed's `start_position`, whatever slides this device saw.
    func testAV3StoryOpensAtTheFeedsStartPosition() {
        let slides = (0..<3).map { PersonalizationStorySlide(id: "\($0)", kind: .content) }
        let story = PersonalizationStory(id: "40", name: "S", startPosition: 2, slides: slides)
        let session = StoriesSession(sdk: FakeSDK(shopId: "shop"), code: "block", v3Domain: "app.test")
        let viewer = session.makeViewer(stories: [story], startIndex: 0)
        XCTAssertEqual(viewer.startSlideIndex(of: story), 2)
        XCTAssertEqual(viewer.muteChoice.key, PersonalizationStoryAudio.rememberedKey, "the mute choice is kept per shop, as the web keeps it per site")

        session.progress.shown(slides[1], of: story)
        XCTAssertEqual(viewer.startSlideIndex(of: story), 1, "where it was left, like the web's feed in memory")
        session.progress.leftForward(story, throughEnd: true)
        XCTAssertEqual(viewer.startSlideIndex(of: story), 0, "watched to the end — from the start")
        XCTAssertTrue(StoriesSession(sdk: FakeSDK(), code: "block").makeViewer(stories: [story], startIndex: 0).muteChoice
                      === PersonalizationStoryAudio.shared.processChoice, "the old feed shares the choice of the run")
    }

    /// A story opened by a link starts on the link's slide the first time only; then, as any story,
    /// where it was left in this viewing.
    func testALinkSetsOnlyTheFirstOpenOfItsStory() throws {
        let slides = (0..<3).map { PersonalizationStorySlide(id: "\($0)", kind: .content) }
        let story = PersonalizationStory(id: "40", name: "S", startPosition: 0, slides: slides)
        let other = PersonalizationStory(id: "41", name: "T", startPosition: 1, slides: slides)
        let link = try XCTUnwrap(StoriesShareLink(url: URL(string: "https://demo.test/?r46_stories=b&r46_story=40&r46_slide=2")!))
        let session = StoriesSession(sdk: FakeSDK(shopId: "shop"), code: "b", v3Domain: "app.test")
        let viewer = session.makeViewer(stories: [story, other], startIndex: 0, link: link)
        XCTAssertEqual(viewer.startSlideIndex(of: story), 2, "the first open: the link's slide")
        XCTAssertEqual(viewer.startSlideIndex(of: other), 1)

        session.progress.shown(slides[2], of: story)
        session.progress.shown(slides[1], of: story)
        XCTAssertEqual(viewer.startSlideIndex(of: story), 1, "back to it: where it was left")
        session.progress.leftForward(story, throughEnd: true)
        XCTAssertEqual(viewer.startSlideIndex(of: story), 0, "watched to the end — from the start, not the link's slide")
    }

    /// The ring follows the feed's `viewed`; a story left forward is viewed for the life of the feed.
    func testTheRingOfAV3StoryFollowsTheFeedAndLeavingForward() {
        let slides = (0..<2).map { PersonalizationStorySlide(id: "\($0)", kind: .content) }
        let fresh = PersonalizationStory(id: "1", name: "A", slides: slides)
        let viewedByFeed = PersonalizationStory(id: "2", name: "B", viewed: true, slides: slides)
        let progress = StoriesFeedProgress()
        progress.shown(slides[0], of: fresh)
        XCTAssertEqual(progress.barItem(fresh).state, .default, "a shown slide does not light the ring")
        XCTAssertEqual(progress.barItem(fresh).seen, [])
        XCTAssertEqual(progress.barItem(viewedByFeed).state, .viewed)
        progress.leftForward(fresh, throughEnd: false)
        XCTAssertEqual(progress.barItem(fresh).state, .viewed)
        XCTAssertEqual(progress.startSlide(fresh), 0, "a swipe keeps the slide it was left on")
    }

    /// The viewer reports leaving forward: the last slide ended into the next story, or the close
    /// after the last story.
    func testTheViewerReportsLeavingAStoryForward() throws {
        let stories = ["a", "b"].map { PersonalizationStory(id: $0, name: $0, slides: [PersonalizationStorySlide(id: "\($0)1", kind: .content)]) }
        let viewer = PersonalizationStoriesViewController(stories: stories)
        var left: [String] = []
        viewer.onStoryLeftForward = { story, throughEnd in left.append(story.id + (throughEnd ? "!" : "")) }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = viewer
        window.isHidden = false
        defer { window.isHidden = true }
        let page = try XCTUnwrap(viewer.pager.viewControllers?.first as? PersonalizationStoryPageViewController)
        viewer.settle(on: page)
        viewer.apply(viewer.state.previous())
        XCTAssertEqual(left, [], "back is not forward")
        viewer.apply(viewer.state.next())
        XCTAssertEqual(left, ["a!"])
    }

    /// A v3 viewer has its own mute choice, kept by the sound button in its shop's storage; muted by
    /// default. The old feed's choice of the run is not touched, and volume up does not save.
    func testTheMuteChoiceOfV3IsItsOwnAndRememberedPerShop() {
        let audio = PersonalizationStoryAudio.shared
        audio.resetForTesting()
        let names = ["audio-a-\(UUID().uuidString)", "audio-b-\(UUID().uuidString)"]
        let shops = names.map { UserDefaults(suiteName: $0) ?? .standard }
        let key = PersonalizationStoryAudio.rememberedKey
        defer {
            audio.resetForTesting()
            names.forEach { UserDefaults.standard.removePersistentDomain(forName: $0) }
        }
        let first = PersonalizationStoryMuteChoice(defaults: shops[0], key: key)
        XCTAssertTrue(first.isMuted, "muted by default")
        audio.begin(choice: first)
        audio.setMuted(false, choice: first)
        XCTAssertFalse(audio.isPlaybackMuted)
        XCTAssertTrue(audio.processChoice.isMuted, "the old feed's choice of the run is untouched")
        audio.end(choice: first)
        XCTAssertEqual(shops[0].object(forKey: key) as? Bool, false)
        XCTAssertTrue(audio.isMuted, "no viewer open: the run's choice again")

        audio.setMuted(true)
        XCTAssertEqual(shops[0].object(forKey: key) as? Bool, false, "an old-feed viewer does not write")
        XCTAssertFalse(PersonalizationStoryMuteChoice(defaults: shops[0], key: key).isMuted, "the next v3 viewer of the shop starts as the user chose")
        XCTAssertTrue(PersonalizationStoryMuteChoice(defaults: shops[1], key: key).isMuted, "another shop has its own choice")

        let volume = PersonalizationStoryMuteChoice(defaults: shops[1], key: key)
        audio.begin(choice: volume)
        audio.volumeChanged(from: 0.3, to: 0.5, route: [])
        XCTAssertFalse(volume.isMuted, "volume up turns the sound on for this viewing")
        audio.end(choice: volume)
        XCTAssertNil(shops[1].object(forKey: key), "and saves nothing")
    }

    /// The key is scoped to the shop where several shops share an app group's suite, as the other
    /// keys of a shop.
    func testTheMuteKeyIsScopedInASharedPartition() {
        let shop = "mute-\(UUID().uuidString)"
        StoragePartition.remember(storageKey: "group.mute.test", forShop: shop)
        defer { StoragePartition.remember(storageKey: nil, forShop: shop) }
        let choice = StoriesSession.muteChoice(FakeSDK(shopId: shop))
        XCTAssertEqual(choice.key, "personalization_sdk.stories_muted.\(StoragePartition.sanitize(shop))")
        XCTAssertEqual(StoriesSession.muteChoice(FakeSDK(shopId: "own-\(UUID().uuidString)")).key, "personalization_sdk.stories_muted",
                       "a partition of the shop's own needs no scope")
    }

    /// The sound button of a v3 video hides only when the video's tracks are known and none is
    /// audio; while that is unclear it shows. A hidden button keeps no room at the bottom: the
    /// buttons come down to 16 above the safe area, and go back up when it shows again.
    func testAHiddenSoundButtonOfAV3VideoKeepsNoRoom() throws {
        XCTAssertEqual(PersonalizationStorySlideView.audioTrack([]), .unknown, "no tracks yet")
        XCTAssertEqual(PersonalizationStorySlideView.audioTrack([.video, nil]), .unknown, "a track not read yet")
        XCTAssertEqual(PersonalizationStorySlideView.audioTrack([.video]), .absent)
        XCTAssertEqual(PersonalizationStorySlideView.audioTrack([.video, .audio]), .present)

        func layout(v3: Bool) throws -> (view: PersonalizationStorySlideView, buttons: UIView) {
            var slide = PersonalizationStorySlide(id: "1", kind: .video, background: "https://video.example/a.mp4", buttons: [.init(title: "Buy")])
            slide.isV3 = v3
            let view = PersonalizationStorySlideView(slide: slide, texts: .init(), isMuted: true, imageLoader: { _, _ in })
            view.safeInsets = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
            view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
            view.layoutIfNeeded()
            return (view, try XCTUnwrap(view.subviews.first { $0 is UIStackView }))
        }
        let (view, buttons) = try layout(v3: true)
        defer { view.stop() }
        let sound = try XCTUnwrap(view.soundButton)
        XCTAssertFalse(sound.isHidden, "unclear yet: shown")
        XCTAssertEqual(buttons.frame.maxY, 874 - 34 - 64, accuracy: 0.5, "over the row")
        view.setSoundAvailability(.unknown)
        XCTAssertFalse(sound.isHidden)

        view.setSoundAvailability(.absent)
        view.layoutIfNeeded()
        XCTAssertTrue(sound.isHidden)
        XCTAssertFalse(view.hasBottomRow)
        XCTAssertEqual(buttons.frame.maxY, 874 - 34 - 16, accuracy: 0.5, "no room kept for the hidden button")

        view.setSoundAvailability(.present)
        view.layoutIfNeeded()
        XCTAssertFalse(sound.isHidden)
        XCTAssertEqual(buttons.frame.maxY, 874 - 34 - 64, accuracy: 0.5)

        let old = try layout(v3: false).view
        defer { old.stop() }
        old.setSoundAvailability(.absent)
        XCTAssertFalse(old.soundButton?.isHidden ?? true, "the old feed keeps its button")
    }

    /// `header`: icon, title and subtitle; a tap sends `click` and opens the link, as the web.
    func testTheHeaderOfAV3Slide() throws {
        let json: [String: Any] = ["id": 1, "type": "", "elements": [
            ["type": "header", "icon": "https://cdn.test/i.png", "title": "Магазин", "subtitle": "Новинки", "link": "https://shop.test/new"]
        ]]
        let v3 = try slide(json)
        XCTAssertEqual(v3.header, .init(iconUrl: "https://cdn.test/i.png", title: "Магазин", subtitle: "Новинки", link: "https://shop.test/new"))
        XCTAssertNil(try slide(json, v3: false).header, "the old feed does not draw it")
        XCTAssertNil(try slide(["id": 1, "elements": [["type": "header", "link": "https://shop.test/"]]]).header, "nothing to draw")

        let view = PersonalizationStorySlideView(slide: v3, texts: .init(), isMuted: true, imageLoader: { _, _ in })
        var tapped: PersonalizationStorySlide.Header?
        view.onHeader = { tapped = $0 }
        let header = try XCTUnwrap(view.headerView)
        XCTAssertEqual(header.titleLabel.text, "Магазин")
        XCTAssertEqual(header.subtitleLabel.text, "Новинки")
        header.sendActions(for: .touchUpInside)
        XCTAssertEqual(tapped?.link, "https://shop.test/new")

        let sent = expectation(description: "click")
        let requests = capture { _ in
            sent.fulfill()
            return (Data("{}".utf8), 200)
        }
        let session = StoriesSession(sdk: FakeSDK(shopId: "shop"), code: "block", v3Domain: "app.test")
        var opened: [String] = []
        session.openURL = { opened.append($0.absoluteString) }
        session.headerTapped(PersonalizationStory(id: "5", name: "S", slides: [v3]), v3, try XCTUnwrap(v3.header), in: nil)
        wait(for: [sent], timeout: 5)
        XCTAssertEqual(requests().map { body($0)["event"] as? String }, ["click"])
        XCTAssertEqual(opened, ["https://shop.test/new"])
    }
}
