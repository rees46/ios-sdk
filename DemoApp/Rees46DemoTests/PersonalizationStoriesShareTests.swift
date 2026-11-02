import XCTest
import UIKit
@_spi(PersonalizationUI) @testable import REES46

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

    func testTheSlideLinkWinsAndTheCampaignLinkIsTheFallback() {
        let story = PersonalizationStory(id: "5", name: "S", slides: [], shareUrl: campaign)
        let own = PersonalizationStorySlide(id: "1", kind: .content, shareUrl: "https://shop.test/?r46_slide=1")
        XCTAssertEqual(story.shareUrl(of: own)?.absoluteString, "https://shop.test/?r46_slide=1")
        XCTAssertEqual(story.shareUrl(of: PersonalizationStorySlide(id: "5_0", kind: .content))?.absoluteString, campaign,
                       "product slides have no link of their own")
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
        let stories = PersonalizationStory.list(json: payload)
        XCTAssertEqual(stories.map(\.id), ["39", "40", "41"])

        let product = stories[0].slides[0]
        XCTAssertEqual(product.id, "39_0")
        XCTAssertNil(product.background, "JSON null is no background, not the string \"null\"")
        XCTAssertNil(product.preview)
        XCTAssertNil(product.media)
        XCTAssertNotNil(product.offer)
        XCTAssertNil(product.shareUrl)
        XCTAssertEqual(stories[0].shareUrl(of: product)?.absoluteString, "https://demo.test/?r46_stories=b&r46_story=39")

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

    func testRequestAddresses() {
        let api = StoriesApiV3(domain: "app.test")
        let base = "https://app.test/api/v3/storefront/stories"
        XCTAssertEqual(api.feedURL(code: "abc", shopId: "shop", did: "d1")?.absoluteString, "\(base)/abc?shop_id=shop&did=d1")
        XCTAssertEqual(api.storyURL(StoriesShareLink(code: "abc", storyId: "40", slideId: "37"), shopId: "shop", did: "d1")?.absoluteString,
                       "\(base)/abc/story/40?shop_id=shop&did=d1&slide_id=37")
        XCTAssertEqual(api.storyURL(StoriesShareLink(code: "abc", storyId: "40"), shopId: "shop", did: "d1")?.absoluteString,
                       "\(base)/abc/story/40?shop_id=shop&did=d1")
        XCTAssertEqual(api.eventsURL(code: "abc")?.absoluteString, "\(base)/abc/events")
        XCTAssertEqual(api.eventsURL(code: "a/b")?.absoluteString, "\(base)/a%2Fb/events", "the code is one path segment")
    }

    func testTheEventBodyHasANumericCampaignAndAStringSlide() throws {
        let body = StoriesApiV3.eventBody(shopId: "shop", did: "d1", event: .view, storyId: "40", slideId: "37")
        let json = try JSONSerialization.data(withJSONObject: body, options: .sortedKeys)
        XCTAssertEqual(String(data: json, encoding: .utf8), #"{"did":"d1","event":"view","shop_id":"shop","slide_id":"37","story_id":40}"#)

        let virtual = StoriesApiV3.eventBody(shopId: "shop", did: "d1", event: .sharedOpen, storyId: "39", slideId: "39_0")
        XCTAssertEqual(virtual["event"] as? String, "shared_open")
        XCTAssertEqual(virtual["story_id"] as? Int, 39)
        XCTAssertEqual(virtual["slide_id"] as? String, "39_0")
        XCTAssertEqual(StoriesApiV3.eventBody(shopId: "s", did: "d", event: .share, storyId: "x", slideId: "1")["story_id"] as? String, "x",
                       "a host's own non-numeric id goes as is")
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
                       "https://app.test/api/v3/storefront/stories/block?shop_id=shop&did=late-did")
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
                       "https://app.test/api/v3/storefront/stories/115bd0b67cf5989a1b60c841790b2af6/story/40?shop_id=shop&did=fake-device-id&slide_id=37")
        let viewer = try XCTUnwrap(host.shown.first as? PersonalizationStoriesViewController)
        XCTAssertNil(viewer.startSlide, "the server's start_position, not the first unseen slide")
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
        oldSDK.onGetRequest = { path in
            XCTAssertEqual(path, "stories/plain")
            oldApi.fulfill()
        }
        let v3SDK = FakeSDK(shopId: "shop")
        v3SDK.onGetRequest = { path in XCTFail("the v3 widget asked the old API for \(path)") }
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
