import XCTest
import ImageIO
@_spi(PersonalizationUI) @testable import REES46

/// Animated GIF on Stories V2 slides (rules G1–G8): detection by signature, frame delays with the
/// browser clamp, the slide length max(duration, one loop), the lazy player that holds its frame
/// while paused, and the viewer that pauses and rewinds the GIF together with the slide clock.
final class PersonalizationStoriesV2GifTests: XCTestCase {

    private typealias Gif = PersonalizationStoryGif
    private typealias Player = PersonalizationStoryGifPlayer
    private typealias State = PersonalizationStoriesViewerState

    /// The fixture shared by all four SDKs: 2x2, 3 frames, delays 10 cs / 0 cs / 50 cs.
    static let fixture = Data(base64Encoded:
        "R0lGODlhAgACAIEAAP8AAAD/AAAA/////yH/C05FVFNDQVBFMi4wAwEAAAAh+QQACgAAACwAAAAAAgACAAACAoRRACH5BAAAAAAALAAAAAACAAIAAAICjFMAIfkEADIAAAAsAAAAAAIAAgAAAgKUVQA7"
    )!

    /// A 2x2 PNG: an ordinary still image.
    static let png: Data = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { context in
        UIColor.red.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    }

    // MARK: - Parser

    func testTheSignatureMarksAGif() {
        XCTAssertTrue(Gif.isGif(Self.fixture))
        XCTAssertTrue(Gif.isGif(Data("GIF87a".utf8)), "the older version counts too")
        XCTAssertFalse(Gif.isGif(Self.png))
        XCTAssertFalse(Gif.isGif(Data("GIF8".utf8)), "too short for a signature")
        XCTAssertFalse(Gif.isGif(Data("GIF90a......".utf8)))
    }

    func testTheSharedFixtureHasThreeFramesAndA700MillisecondLoop() throws {
        let gif = try XCTUnwrap(Gif(data: Self.fixture))
        XCTAssertEqual(gif.frameCount, 3)
        XCTAssertEqual(gif.delays.map { Int(($0 * 1000).rounded()) }, [100, 100, 500], "a 0 cs frame counts as 100 ms")
        XCTAssertEqual(gif.loopDuration, 0.7, accuracy: 0.0001)
        XCTAssertEqual(gif.pixelSize, CGSize(width: 2, height: 2))
        XCTAssertEqual(gif.data, Self.fixture, "the raw bytes are kept, not decoded frames")
    }

    func testDelaysUnderTwentyMillisecondsCountAsOneHundred() {
        XCTAssertEqual(Gif.frameDelay(0), 0.1)
        XCTAssertEqual(Gif.frameDelay(0.01), 0.1)
        XCTAssertEqual(Gif.frameDelay(nil), 0.1, "a frame without a delay")
        XCTAssertEqual(Gif.frameDelay(0.02), 0.02)
        XCTAssertEqual(Gif.frameDelay(Double(Float(0.02))), 0.02, "2 cs read as a Float is still 20 ms")
        XCTAssertEqual(Gif.frameDelay(0.25), 0.25)
    }

    func testAPngIsAStillImageAndABrokenGifFailsLikeABrokenPhoto() {
        XCTAssertNil(Gif(data: Self.png))
        guard case .image? = PersonalizationStoryImages.decode(Self.png) else { return XCTFail("a PNG is a still image") }
        guard case .gif(let gif)? = PersonalizationStoryImages.decode(Self.fixture) else { return XCTFail("the fixture is a GIF") }
        XCTAssertEqual(gif.frameCount, 3)
        XCTAssertNil(PersonalizationStoryImages.decode(Data("GIF89a not really a gif".utf8)), "an unreadable GIF → Retry")
    }

    func testBigGifsAreDownsampledToTheSlideAreaButNeverUpscaled() throws {
        let tall = try XCTUnwrap(Gif(data: Self.makeGif(width: 400, height: 800, frames: 2)))
        XCTAssertEqual(tall.maxPixelSize(fitting: CGSize(width: 100, height: 100), scale: 2), 200)
        XCTAssertEqual(tall.maxPixelSize(fitting: CGSize(width: 402, height: 874), scale: 3), 800, "smaller than the screen: as is")

        let player = Player(gif: tall, maxPixelSize: 200, clock: .manual, decodesSynchronously: true)
        var shown: [UIImage] = []
        player.onFrame = { shown.append($0) }
        player.prepare()
        XCTAssertEqual(shown.first?.cgImage?.width, 100)
        XCTAssertEqual(shown.first?.cgImage?.height, 200)
    }

    // MARK: - Slide length

    func testAGifSlideLastsTheLongerOfDurationAndOneLoop() {
        XCTAssertEqual(State.timerDuration(5, gifLoop: 8), 8, "a long loop is not cut")
        XCTAssertEqual(State.timerDuration(10, gifLoop: 0.7), 10, "a short loop repeats until the slide ends")
        XCTAssertEqual(State.timerDuration(5, gifLoop: nil), 5, "unknown loop: the server duration")
        XCTAssertEqual(State.timerDuration(5, gifLoop: 0), 5)
    }

    func testTheClockOfAGifSlideRunsForTheWholeLoop() {
        var state = State(slideCounts: [2])
        state.enter(slide: 0, mediaReady: true)
        let duration = State.timerDuration(5, gifLoop: 8)
        for _ in 0..<31 {
            XCTAssertEqual(state.tick(0.25, duration: duration, isVideo: false), .none)
        }
        XCTAssertEqual(state.progress(duration: duration), 7.75 / 8, accuracy: 0.001)
        XCTAssertEqual(state.tick(0.25, duration: duration, isVideo: false), .showSlide(1), "after 8 s, not 5 s")
    }

    // MARK: - Timeline

    func testTheTimelineLoopsWithEveryFrameOnItsOwnDelay() {
        var timeline = PersonalizationStoryGifTimeline(delays: [0.1, 0.1, 0.5])
        var changes: [Int] = []
        for _ in 0..<145 {
            if timeline.advance(0.01, nextReady: true) { changes.append(timeline.frame) }
        }
        XCTAssertEqual(changes, [1, 2, 0, 1, 2, 0], "two loops of 700 ms")
    }

    func testTheTimelineWaitsForAFrameThatIsNotDecodedYet() {
        var timeline = PersonalizationStoryGifTimeline(delays: [0.1, 0.1, 0.5])
        XCTAssertFalse(timeline.advance(0.3, nextReady: false))
        XCTAssertEqual(timeline.frame, 0, "the next frame is not ready: the current one stays")
        XCTAssertEqual(timeline.shown, 0.1, accuracy: 0.0001, "the wait is not owed afterwards")
        XCTAssertTrue(timeline.advance(0.01, nextReady: true))
        XCTAssertEqual(timeline.frame, 1)
        XCTAssertEqual(timeline.shown, 0.01, accuracy: 0.0001)
    }

    // MARK: - Player (manual clock, synchronous decoding)

    private func fixturePlayer() throws -> Player {
        Player(gif: try XCTUnwrap(Gif(data: Self.fixture)), maxPixelSize: 100, clock: .manual, decodesSynchronously: true)
    }

    func testThePlayerPutsTheFirstFrameOnScreenThenReportsReady() throws {
        let player = try fixturePlayer()
        var events: [String] = []
        player.onFrame = { _ in events.append("frame") }
        player.onReady = { events.append("ready") }
        player.prepare()
        XCTAssertEqual(events, ["frame", "ready"], "the slide clock starts once the first frame is on screen")
        XCTAssertFalse(player.isPlaying, "it waits for the slide to play")
        XCTAssertEqual(player.decodedFrameCount, 1, "nothing ahead before it plays")
        player.advance(by: 1)
        XCTAssertEqual(player.currentFrame, 0)
    }

    func testPauseHoldsTheFrameResumeGoesOnAndRestartStartsOver() throws {
        let player = try fixturePlayer()
        var shown = 0
        player.onFrame = { _ in shown += 1 }
        player.prepare()
        player.resume()
        player.advance(by: 0.1)
        XCTAssertEqual(player.currentFrame, 1)
        player.advance(by: 0.05)

        player.pause()
        let shownBeforePause = shown
        player.advance(by: 5)
        XCTAssertEqual(player.currentFrame, 1, "pause holds the frame")
        XCTAssertEqual(shown, shownBeforePause, "and puts nothing new on screen")

        player.resume()
        player.advance(by: 0.05)
        XCTAssertEqual(player.currentFrame, 2, "resume goes on from the frame: 50 ms of it were left")
        player.advance(by: 0.5)
        XCTAssertEqual(player.currentFrame, 0, "loops")
        player.advance(by: 0.1)
        XCTAssertEqual(player.currentFrame, 1)

        player.restart()
        XCTAssertEqual(player.currentFrame, 0, "restart: the first frame")
        XCTAssertTrue(player.isPlaying, "and keeps playing")
        player.advance(by: 0.1)
        XCTAssertEqual(player.currentFrame, 1)
    }

    func testRewindStandsOnTheFirstFrameAndStopLetsEverythingGo() throws {
        let player = try fixturePlayer()
        var last: UIImage?
        player.onFrame = { last = $0 }
        player.prepare()
        let first = last
        player.resume()
        player.advance(by: 0.1)
        XCTAssertEqual(player.decodedFrameCount, 3, "the current frame, the ones ahead and the first")

        player.rewind()
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.currentFrame, 0)
        XCTAssertTrue(last === first, "the first frame is back on screen")
        XCTAssertEqual(player.decodedFrameCount, 1, "only the first frame stays")

        player.stop()
        XCTAssertEqual(player.decodedFrameCount, 0)
        XCTAssertFalse(player.isReady)
    }

    func testABigLongGifKeepsOnlyAFewFramesDecoded() throws {
        let gif = try XCTUnwrap(Gif(data: Self.makeGif(width: 1080, height: 1920, frames: 120, delay: 0.04)))
        XCTAssertEqual(gif.frameCount, 120)
        XCTAssertEqual(gif.loopDuration, 4.8, accuracy: 0.001)
        let player = Player(
            gif: gif, maxPixelSize: gif.maxPixelSize(fitting: CGSize(width: 402, height: 874), scale: 3),
            clock: .manual, decodesSynchronously: true
        )
        player.prepare()
        player.resume()
        var most = 0
        for _ in 0..<130 {
            player.advance(by: 0.04)
            most = max(most, player.decodedFrameCount)
        }
        XCTAssertEqual(player.currentFrame, 10, "one frame per step, around the loop")
        XCTAssertLessThanOrEqual(most, Player.lookahead + 2, "never more than the current frame, a few ahead and the first")
    }

    // MARK: - Slide and viewer

    /// Never shown, but a window: the views lay out the way they do on screen.
    private var host: UIWindow!

    override func setUp() {
        super.setUp()
        host = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    }

    override func tearDown() {
        host = nil
        super.tearDown()
    }

    func testAHostLoaderGifIsNeitherAnimatedNorMeasured() {
        let slide = PersonalizationStorySlide(id: "1", kind: .image, background: "https://shop.example/story.gif", duration: 5)
        let view = PersonalizationStorySlideView(slide: slide, texts: .init(), isMuted: true, imageLoader: { imageView, _ in
            imageView.image = UIImage(data: Self.fixture)
        })
        XCTAssertTrue(view.isMediaReady, "ready once the host's image is there")
        XCTAssertNil(view.gifPlayer)
        XCTAssertNil(view.gifLoopDuration)
        XCTAssertEqual(view.timerDuration, 5, "the server duration")
    }

    func testCoversAvatarsPostersAndProductPicturesShowTheFirstFrameOnly() throws {
        let url = try fixtureFile()
        let imageView = UIImageView()
        PersonalizationStoryImages.load(into: imageView, url: url, loader: nil)
        waitUntil { imageView.image != nil }
        XCTAssertNil(imageView.image?.images, "a still first frame, not an animated image")
        XCTAssertEqual(imageView.image?.size, CGSize(width: 2, height: 2))
        XCTAssertFalse(imageView.isAnimating)
    }

    func testTheViewerRunsAGifSlideForAWholeLoopAndPausesTheGifWithTheClock() throws {
        let url = try fixtureFile()
        let story = PersonalizationStory(id: "gif", name: "GIF", slides: [
            PersonalizationStorySlide(id: "1", kind: .image, background: url, duration: 0.5),
            PersonalizationStorySlide(id: "2", kind: .content)
        ])
        let viewer = settledViewer([story])
        guard let page = viewer.activePage, let slide = page.slideView else { return XCTFail("no slide") }
        XCTAssertTrue(viewer.state.isLoading, "the clock waits for the first frame")
        waitUntil { slide.isMediaReady }
        let player = try XCTUnwrap(slide.gifPlayer)
        XCTAssertNotNil(slide.mediaImage.image, "the first frame is on screen when the clock starts")
        XCTAssertFalse(viewer.state.isLoading)
        XCTAssertEqual(slide.timerDuration, 0.7, accuracy: 0.0001, "max(0.5 s, one 700 ms loop)")
        XCTAssertTrue(player.isPlaying, "plays with the slide clock")

        viewer.pause()
        XCTAssertFalse(player.isPlaying, "the host's pause() stops the GIF on its frame")
        viewer.resume()
        XCTAssertTrue(player.isPlaying)
        viewer.handleHold(true)
        XCTAssertFalse(player.isPlaying, "so does a hold")
        viewer.handleHold(false)
        viewer.setPaused(.background, true)
        XCTAssertFalse(player.isPlaying, "and the background")
        viewer.setPaused(.background, false)
        viewer.productsToggled(true, on: page)
        XCTAssertFalse(player.isPlaying, "and the products sheet")
        viewer.productsToggled(false, on: page)
        XCTAssertTrue(player.isPlaying)

        waitUntil { player.currentFrame != 0 }
        viewer.apply(.restartSlide)
        XCTAssertEqual(player.currentFrame, 0, "restart: from the first frame")
        XCTAssertTrue(slide.gifPlayer === player, "without reloading")
    }

    func testLeavingAGifStoryRewindsItAndComingBackStartsFromTheFirstFrame() throws {
        let url = try fixtureFile()
        let stories = [
            PersonalizationStory(id: "gif", name: "GIF", slides: [
                PersonalizationStorySlide(id: "1", kind: .image, background: url)
            ]),
            PersonalizationStory(id: "next", name: "Next", slides: [PersonalizationStorySlide(id: "2", kind: .content)])
        ]
        let viewer = settledViewer(stories)
        guard let gifPage = viewer.activePage, let slide = gifPage.slideView else { return XCTFail("no slide") }
        waitUntil { slide.isMediaReady }
        let player = try XCTUnwrap(slide.gifPlayer)
        waitUntil { player.currentFrame != 0 }

        let next = viewer.page(at: 1)
        next.loadViewIfNeeded()
        viewer.settle(on: next)
        XCTAssertFalse(player.isPlaying, "leaving the slide stops it")
        XCTAssertEqual(player.currentFrame, 0)
        XCTAssertEqual(player.decodedFrameCount, 1, "only the first frame stays decoded")

        viewer.settle(on: gifPage)
        XCTAssertTrue(gifPage.slideView === slide && slide.gifPlayer === player, "the same GIF, not reloaded")
        XCTAssertTrue(player.isPlaying, "plays again from the first frame")
        XCTAssertEqual(player.currentFrame, 0)
    }

    // MARK: - Helpers

    /// The fixture as a local file under a fresh name: the kit's loaders read `file://` like any URL,
    /// and no earlier test has it in memory yet.
    private func fixtureFile() throws -> String {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("story-\(UUID().uuidString).gif")
        try Self.fixture.write(to: file)
        addTeardownBlock { try? FileManager.default.removeItem(at: file) }
        return file.absoluteString
    }

    /// A viewer with its view loaded and its first page settled, as after `viewDidAppear`.
    private func settledViewer(_ stories: [PersonalizationStory]) -> PersonalizationStoriesViewController {
        let viewer = PersonalizationStoriesViewController(stories: stories)
        viewer.view.frame = host.bounds
        host.addSubview(viewer.view)
        if let page = viewer.pager.viewControllers?.first as? PersonalizationStoryPageViewController {
            viewer.settle(on: page)
        }
        return viewer
    }

    /// Spins the main run loop until `condition` holds: loads and decodes answer on the main queue.
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(condition(), "timed out", file: file, line: line)
    }

    /// A GIF of solid frames, every one `delay` long.
    static func makeGif(width: Int, height: Int, frames: Int, delay: Double = 0.1) -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "com.compuserve.gif" as CFString, frames, nil) else { return Data() }
        let properties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary
        let space = CGColorSpaceCreateDeviceRGB()
        for index in 0..<frames {
            autoreleasepool {
                guard let context = CGContext(
                    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
                ) else { return }
                let level = CGFloat(index % 16) / 15
                context.setFillColor(red: level, green: 0.2, blue: 1 - level, alpha: 1)
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                if let image = context.makeImage() { CGImageDestinationAddImage(destination, image, properties) }
            }
        }
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}
