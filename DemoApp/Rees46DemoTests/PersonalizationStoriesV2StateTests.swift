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
}
