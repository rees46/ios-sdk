import XCTest
@_spi(PersonalizationUI) @testable import REES46

/// The Stories V2 viewer logic without UI: tap zones by thirds (mirrored in RTL), slide and story
/// navigation, pause reasons, the products sheet, media readiness with Retry, and the clock.
final class PersonalizationStoriesV2StateTests: XCTestCase {

    private typealias State = PersonalizationStoriesViewerState

    // MARK: - Tap zones

    func testThirdsGoBackDoNothingAndGoForward() {
        XCTAssertEqual(State.zone(x: 10, width: 300, rightToLeft: false), .previous)
        XCTAssertEqual(State.zone(x: 150, width: 300, rightToLeft: false), .center)
        XCTAssertEqual(State.zone(x: 290, width: 300, rightToLeft: false), .next)
    }

    func testRightToLeftMirrorsTheEdgesNotTheCentre() {
        XCTAssertEqual(State.zone(x: 10, width: 300, rightToLeft: true), .next)
        XCTAssertEqual(State.zone(x: 150, width: 300, rightToLeft: true), .center)
        XCTAssertEqual(State.zone(x: 290, width: 300, rightToLeft: true), .previous)
    }

    func testACentreTapDoesNothing() {
        var state = State(slideCounts: [3], slide: 1)
        XCTAssertEqual(state.tap(x: 150, width: 300, rightToLeft: false), .none)
    }

    // MARK: - Navigation

    func testNextWalksSlidesThenStoriesThenCloses() {
        var state = State(slideCounts: [2, 1])
        XCTAssertEqual(state.next(), .showSlide(1))
        state.enter(slide: 1, mediaReady: true)
        XCTAssertEqual(state.next(), .showStory(1, forward: true))
        state.enter(story: 1, slide: 0, mediaReady: true)
        XCTAssertEqual(state.next(), .close, "past the last slide of the last story")
    }

    func testPreviousOnTheFirstSlideOfTheFirstStoryRestartsIt() {
        var state = State(slideCounts: [3, 2], story: 1, slide: 1)
        XCTAssertEqual(state.previous(), .showSlide(0))
        state.enter(slide: 0, mediaReady: true)
        XCTAssertEqual(state.previous(), .showStory(0, forward: false))
        state.enter(story: 0, slide: 0, mediaReady: true)
        XCTAssertEqual(state.previous(), .restartSlide)
    }

    func testNothingNavigatesOnceClosing() {
        var state = State(slideCounts: [3], slide: 1)
        XCTAssertTrue(state.close())
        XCTAssertFalse(state.close(), "closes once")
        XCTAssertEqual(state.tap(x: 290, width: 300, rightToLeft: false), .none)
        XCTAssertEqual(state.next(), .none)
        XCTAssertEqual(state.tick(20, duration: 5, isVideo: false), .none)
        XCTAssertFalse(state.canSwipe)
    }

    // MARK: - Products sheet

    func testAnOpenSheetPausesBlocksSwipesAndATapOnlyClosesIt() {
        var state = State(slideCounts: [3])
        state.setSheetOpen(true)
        XCTAssertFalse(state.isRunning)
        XCTAssertFalse(state.canSwipe)
        XCTAssertEqual(state.tap(x: 290, width: 300, rightToLeft: false), .closeSheet)
        XCTAssertEqual(state.slide, 0, "the tap did not navigate")
        XCTAssertTrue(state.isRunning)
        XCTAssertTrue(state.canSwipe)
    }

    func testChangingSlideResetsTheSheet() {
        var state = State(slideCounts: [3])
        state.setSheetOpen(true)
        state.enter(slide: 1, mediaReady: true)
        XCTAssertFalse(state.isSheetOpen)
        XCTAssertTrue(state.isRunning)
    }

    // MARK: - Pauses and the clock

    func testEveryReasonHoldsTheClockUntilAllAreGone() {
        var state = State(slideCounts: [2])
        state.setPaused(.hold, true)
        state.setPaused(.background, true)
        XCTAssertEqual(state.tick(20, duration: 5, isVideo: false), .none)
        state.setPaused(.hold, false)
        XCTAssertFalse(state.isRunning, "still in the background")
        state.setPaused(.background, false)
        XCTAssertEqual(state.tick(2, duration: 5, isVideo: false), .none)
        XCTAssertEqual(state.progress(duration: 5), 0.4, accuracy: 0.001)
        XCTAssertEqual(state.tick(3, duration: 5, isVideo: false), .showSlide(1))
    }

    func testAHoldOrDragLeavesTheSlideWhereItWas() {
        var state = State(slideCounts: [2])
        _ = state.tick(1, duration: 5, isVideo: false)
        state.setPaused(.drag, true)
        state.setPaused(.hold, true)
        state.setPaused(.hold, false)
        state.setPaused(.drag, false)
        XCTAssertEqual(state.slide, 0)
        XCTAssertEqual(state.elapsed, 1, accuracy: 0.001, "release resumes, never navigates")
    }

    func testAVideoWithAKnownLengthDrivesItsOwnClock() {
        var state = State(slideCounts: [2])
        XCTAssertEqual(state.tick(30, duration: nil, isVideo: true), .none)
        XCTAssertEqual(state.elapsed, 0)
    }

    // MARK: - Media readiness

    func testTheClockWaitsForMediaThenShowsRetryAfterTenSeconds() {
        var state = State(slideCounts: [2])
        state.enter(slide: 0, mediaReady: false)
        XCTAssertEqual(state.tick(9, duration: 5, isVideo: false), .none)
        XCTAssertEqual(state.elapsed, 0, "the slide clock has not started")
        XCTAssertEqual(state.tick(1, duration: 5, isVideo: false), .mediaFailed)
        XCTAssertTrue(state.hasFailed)
        XCTAssertEqual(state.tick(60, duration: 5, isVideo: false), .none, "an image waits for Retry")

        state.retry()
        XCTAssertTrue(state.isLoading)
        state.mediaReady()
        XCTAssertTrue(state.isRunning)
    }

    func testAFailedVideoRetriesByItselfAfterFifteenSeconds() {
        var state = State(slideCounts: [1])
        state.enter(slide: 0, mediaReady: false)
        state.mediaFailed()
        XCTAssertEqual(state.tick(14, duration: nil, isVideo: true), .none)
        XCTAssertEqual(state.tick(1, duration: nil, isVideo: true), .retryMedia)
        XCTAssertTrue(state.isLoading)
    }

    func testWaitingForMediaStopsInTheBackgroundAndOnLeavingTheSlide() {
        var state = State(slideCounts: [2])
        state.enter(slide: 0, mediaReady: false)
        state.setPaused(.background, true)
        XCTAssertEqual(state.tick(30, duration: 5, isVideo: false), .none)
        XCTAssertEqual(state.waited, 0)
        state.setPaused(.background, false)
        state.mediaFailed()
        state.enter(slide: 1, mediaReady: true)
        XCTAssertFalse(state.hasFailed, "leaving the slide cancels Retry")
        XCTAssertTrue(state.isRunning)
    }

    // MARK: - Session: tracking ids, delegate and links

    private final class Delegate: StoriesCommunicationProtocol {
        var events: [String] = []
        var allow = true
        func receiveIosLink(text: String) { events.append("ios-link") }
        func receiveSelectedProductData(products: StoriesElement) { events.append("element:\(products.link ?? "")") }
        func receiveSelectedCarouselProductData(products: StoriesProduct) { events.append("carousel:\(products.url)") }
        func receiveSelectedPromocodeProductData(promoCodeSlide: StoriesPromoCodeElement) {
            events.append("promo:\(promoCodeSlide.promocode)")
        }
        func shouldOpenLinkBySdk(url: String) -> Bool { allow }
    }

    func testOnlyPositiveIntegerIdsAreTracked() {
        XCTAssertTrue(StoriesSession.isTrackable("37"))
        XCTAssertFalse(StoriesSession.isTrackable("39_0"), "dynamic product slides")
        XCTAssertFalse(StoriesSession.isTrackable("0"))
        XCTAssertFalse(StoriesSession.isTrackable("-4"))
        XCTAssertFalse(StoriesSession.isTrackable(""))
    }

    func testAButtonNotifiesTheDelegateAndTheSdkOpensItsLinkUnlessDeclined() {
        let delegate = Delegate()
        let session = StoriesSession(sdk: nil, code: "block")
        session.delegate = delegate
        var opened: [String] = []
        session.openURL = { opened.append($0.absoluteString) }
        let element = StoriesElement(json: ["type": "button", "link": "https://shop.example/a"])
        let button = PersonalizationStorySlide.Button(title: "Go", link: "https://shop.example/a", element: element)
        let slide = PersonalizationStorySlide(id: "1", kind: .content, buttons: [button])
        let story = PersonalizationStory(id: "1", name: "S", slides: [slide])

        session.buttonTapped(story, slide, button, in: nil)
        XCTAssertEqual(delegate.events, ["element:https://shop.example/a"])
        XCTAssertEqual(opened, ["https://shop.example/a"])

        delegate.allow = false
        session.buttonTapped(story, slide, button, in: nil)
        XCTAssertEqual(opened.count, 1, "the host routes it itself")
        XCTAssertFalse(delegate.events.contains("ios-link"), "receiveIosLink stays uncalled, as in V1")
    }

    func testACarouselProductGoesToTheCarouselCallbackAndOpensTheProduct() {
        let delegate = Delegate()
        let session = StoriesSession(sdk: nil, code: "block")
        session.delegate = delegate
        var opened: [String] = []
        session.openURL = { opened.append($0.absoluteString) }
        let item: [String: Any] = ["name": "Mouse", "price": 10, "url": "https://shop.example/m", "deeplink_ios": "app://m"]
        guard let offer = PersonalizationStorySlide.Offer(carousel: item, index: 0) else { return XCTFail("no offer") }
        let slide = PersonalizationStorySlide(id: "1", kind: .content)
        session.productTapped(PersonalizationStory(id: "1", name: "S", slides: [slide]), slide, offer, in: nil)
        XCTAssertEqual(delegate.events, ["carousel:https://shop.example/m"])
        XCTAssertEqual(opened, ["app://m"], "deeplink_ios first")
    }

    func testACopiedCodeReachesThePromoCallback() {
        let delegate = Delegate()
        let session = StoriesSession(sdk: nil, code: "block")
        session.delegate = delegate
        let slide = PersonalizationStorySlide(id: "1", kind: .image, background: "https://img.example/a.jpg",
                                              textBlocks: [.init(text: "Code", promoCode: "TEXT10")])
        session.promoCopied(PersonalizationStory(id: "1", name: "S", slides: [slide]), slide, "TEXT10")
        XCTAssertEqual(delegate.events, ["promo:TEXT10"], "a text block code is wrapped for the V1 callback")
    }
}
