import XCTest
import AVFoundation
@_spi(PersonalizationUI) @testable import REES46

/// Stories V2 media: the disk cache names files by a stable key, keeps the newest files within its
/// limit and never trims a file in use; the video loader reads the total length off a ranged response
/// and tells the player the container type.
final class PersonalizationStoriesV2MediaTests: XCTestCase {

    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("stories-cache-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    func testKeysAreStableHexDigests() {
        let key = PersonalizationStoryMediaCache.key(for: "https://cdn.example/a.mp4")
        XCTAssertEqual(key.count, 64)
        XCTAssertEqual(key, PersonalizationStoryMediaCache.key(for: "https://cdn.example/a.mp4"))
        XCTAssertNotEqual(key, PersonalizationStoryMediaCache.key(for: "https://cdn.example/b.mp4"))
    }

    func testTheFileKeepsTheContainerExtension() {
        let cache = PersonalizationStoryMediaCache(directory: directory)
        XCTAssertEqual(cache.fileURL(for: "https://cdn.example/a.mp4?x=1").pathExtension, "mp4")
        XCTAssertEqual(cache.fileURL(for: "https://cdn.example/image").pathExtension, "bin")
        XCTAssertEqual(cache.partURL(for: "https://cdn.example/a.mp4").pathExtension, "part")
    }

    func testTheCacheDropsTheOldestFilesOverItsLimit() throws {
        let cache = PersonalizationStoryMediaCache(directory: directory, limit: 250)
        let urls = (0..<3).map { "https://cdn.example/\($0).jpg" }
        for (index, url) in urls.enumerated() {
            try Data(count: 100).write(to: cache.fileURL(for: url))
            let date = Date(timeIntervalSinceNow: TimeInterval(index - 10))
            try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: cache.fileURL(for: url).path)
        }
        cache.trim()
        XCTAssertNil(cache.cachedFile(for: urls[0]), "the oldest goes")
        XCTAssertNotNil(cache.cachedFile(for: urls[1]))
        XCTAssertNotNil(cache.cachedFile(for: urls[2]))
    }

    func testAProtectedFileSurvivesTheTrim() throws {
        let cache = PersonalizationStoryMediaCache(directory: directory, limit: 150)
        let old = "https://cdn.example/playing.mp4"
        let fresh = "https://cdn.example/fresh.jpg"
        try Data(count: 100).write(to: cache.partURL(for: old))
        try FileManager.default.setAttributes([.modificationDate: Date.distantPast], ofItemAtPath: cache.partURL(for: old).path)
        try Data(count: 100).write(to: cache.fileURL(for: fresh))

        cache.protect(old)
        cache.trim()
        XCTAssertTrue(FileManager.default.fileExists(atPath: cache.partURL(for: old).path), "in use, though the oldest")
        XCTAssertNil(cache.cachedFile(for: fresh), "the next oldest goes instead")

        try Data(count: 100).write(to: cache.fileURL(for: fresh))
        cache.unprotect(old)
        cache.trim()
        XCTAssertFalse(FileManager.default.fileExists(atPath: cache.partURL(for: old).path))
    }

    func testTheTotalLengthComesFromTheContentRange() {
        XCTAssertEqual(PersonalizationStoryVideoDownload.total(fromContentRange: "bytes 100-999/5000"), 5000)
        XCTAssertNil(PersonalizationStoryVideoDownload.total(fromContentRange: "bytes 0-99/*"))
        XCTAssertNil(PersonalizationStoryVideoDownload.total(fromContentRange: nil))
    }

    func testTheContainerTypeFollowsTheMimeThenTheExtension() {
        let mp4 = URL(string: "https://cdn.example/a.mp4")!
        let mov = URL(string: "https://cdn.example/a.mov")!
        XCTAssertEqual(PersonalizationStoryVideoLoader.contentType(mime: "video/mp4", url: mov), "public.mpeg-4")
        XCTAssertEqual(PersonalizationStoryVideoLoader.contentType(mime: nil, url: mov), "com.apple.quicktime-movie")
        XCTAssertEqual(PersonalizationStoryVideoLoader.contentType(mime: "application/octet-stream", url: mp4), "public.mpeg-4")
    }

    func testACachedVideoPlaysStraightFromTheFile() throws {
        let cache = PersonalizationStoryMediaCache(directory: directory)
        let videos = PersonalizationStoryVideos(cache: cache)
        let url = "https://cdn.example/clip.mp4"
        try Data(count: 10).write(to: cache.fileURL(for: url))

        let cached = videos.asset(for: url)
        XCTAssertEqual(cached?.asset.url, cache.fileURL(for: url))
        XCTAssertNil(cached?.loader)

        let streamed = videos.asset(for: "https://cdn.example/other.mp4")
        XCTAssertEqual(streamed?.asset.url.scheme, PersonalizationStoryVideos.scheme, "read through the loader")
        XCTAssertNotNil(streamed?.loader)
        XCTAssertNil(videos.asset(for: "not a url"))
    }

    // MARK: - Sound

    func testMutedStoriesMixWithOtherAudioAndClosingRestoresTheSession() throws {
        let audio = PersonalizationStoryAudio.shared
        audio.resetForTesting()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.soloAmbient, mode: .default, options: [])

        audio.begin()
        XCTAssertTrue(audio.isMuted, "muted on the first open")
        XCTAssertEqual(session.category, .ambient, "does not interrupt other apps")

        audio.setMuted(false)
        XCTAssertEqual(session.category, .playback)

        audio.end()
        XCTAssertEqual(session.category, .soloAmbient, "the host's category is back")

        audio.begin()
        XCTAssertFalse(audio.isMuted, "the choice is kept for the process")
        XCTAssertEqual(session.category, .playback)
        audio.end()
        audio.resetForTesting()
    }

    // MARK: - Sound taken by the system

    private func routeChange(_ reason: AVAudioSession.RouteChangeReason) {
        NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance(),
                                        userInfo: [AVAudioSessionRouteChangeReasonKey: reason.rawValue])
    }

    private func interruption(_ type: AVAudioSession.InterruptionType, options: AVAudioSession.InterruptionOptions = []) {
        var info: [AnyHashable: Any] = [AVAudioSessionInterruptionTypeKey: type.rawValue]
        if type == .ended { info[AVAudioSessionInterruptionOptionKey] = options.rawValue }
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(), userInfo: info)
    }

    func testUnpluggedHeadphonesSilenceThisViewingButKeepTheChoice() {
        let audio = PersonalizationStoryAudio.shared
        audio.resetForTesting()
        audio.begin()
        audio.setMuted(false)
        XCTAssertFalse(audio.isPlaybackMuted)

        routeChange(.oldDeviceUnavailable)
        XCTAssertTrue(audio.isPlaybackMuted, "the video goes on without sound")
        XCTAssertFalse(audio.isMuted, "the kept choice stays unmuted")
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .ambient, "no longer holds other apps' audio")
        routeChange(.newDeviceAvailable)
        XCTAssertTrue(audio.isPlaybackMuted, "plugging back in does not turn the sound on")

        audio.end()
        audio.begin()
        XCTAssertFalse(audio.isPlaybackMuted, "the next open follows the kept choice")
        audio.end()
        audio.resetForTesting()
    }

    func testAnInterruptionGivesTheSoundBackOnlyWhenTheSystemSaysResume() {
        let audio = PersonalizationStoryAudio.shared
        audio.resetForTesting()
        audio.begin()
        audio.setMuted(false)

        interruption(.began)
        XCTAssertTrue(audio.isPlaybackMuted)
        XCTAssertFalse(audio.isMuted)
        interruption(.ended, options: .shouldResume)
        XCTAssertFalse(audio.isPlaybackMuted, "the system gave the sound back")

        interruption(.began)
        interruption(.ended)
        XCTAssertTrue(audio.isPlaybackMuted, "without shouldResume the sound stays off")
        audio.setMuted(false)
        XCTAssertFalse(audio.isPlaybackMuted, "the user turns it back on")
        audio.end()
        audio.resetForTesting()
    }

    func testAVideoStoppedByTheSystemGoesOnWithoutSound() {
        let audio = PersonalizationStoryAudio.shared
        audio.resetForTesting()
        audio.begin()
        var changes = 0
        let observer = NotificationCenter.default.addObserver(forName: PersonalizationStoryAudio.didChange, object: nil, queue: nil) { _ in
            changes += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        audio.playbackStoppedBySystem()
        XCTAssertFalse(audio.isSilenced, "already muted: nothing to take")
        XCTAssertEqual(changes, 1, "viewers still resync their players")

        audio.setMuted(false)
        audio.playbackStoppedBySystem()
        XCTAssertTrue(audio.isSilenced)
        XCTAssertFalse(audio.isMuted)
        XCTAssertEqual(changes, 3)
        audio.end()
        audio.resetForTesting()
    }

    func testOnlyVolumeUpOnTheSameOutputTurnsTheSoundOn() {
        let audio = PersonalizationStoryAudio.shared
        audio.resetForTesting()
        audio.begin()
        audio.volumeChanged(from: 0.3, to: 0.8, route: ["headphones-gone"])
        XCTAssertTrue(audio.isMuted, "a jump between outputs is not a key press")
        audio.volumeChanged(from: 0.8, to: 0.7, route: ["headphones-gone"])
        XCTAssertTrue(audio.isMuted, "volume down keeps it muted")
        audio.volumeChanged(from: 0.7, to: 0.8, route: ["headphones-gone"])
        XCTAssertFalse(audio.isMuted, "volume up unmutes")
        audio.end()
        audio.resetForTesting()
    }
}
