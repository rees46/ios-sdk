import XCTest
@_spi(PersonalizationUI) @testable import REES46

/// Popups v3, the engine: the 18 scenarios of the shared `scenarios.json` (triggers, screens,
/// background, frequency, cooldown, test mode, the modal slot, promo codes, context changes) on
/// virtual time, a fake network and a fake window presenter.
final class PopupsV3EngineTests: XCTestCase {

    // MARK: - Fakes

    final class Clock: PopupsV3Clock {
        private final class Item: PopupsV3Timer {
            let at: Date
            let order: Int
            let block: () -> Void
            var cancelled = false
            init(at: Date, order: Int, block: @escaping () -> Void) { self.at = at; self.order = order; self.block = block }
            func cancel() { cancelled = true }
        }

        let start = Date(timeIntervalSince1970: 1_800_000_000)
        private(set) var now: Date
        private var items: [Item] = []
        private var counter = 0

        init() { now = start }

        func schedule(after delay: TimeInterval, _ block: @escaping () -> Void) -> PopupsV3Timer {
            counter += 1
            let item = Item(at: now.addingTimeInterval(max(0, delay)), order: counter, block: block)
            items.append(item)
            return item
        }

        /// Seconds since the start; due timers fire in time order.
        func advance(to seconds: TimeInterval) {
            let target = start.addingTimeInterval(seconds)
            while let next = items.filter({ !$0.cancelled && $0.at <= target }).min(by: { ($0.at, $0.order) < ($1.at, $1.order) }) {
                items.removeAll { $0 === next }
                now = next.at
                next.block()
            }
            now = target
        }
    }

    final class Backend: PopupsV3Backend {
        var list: PopupsV3ListResult = .list(PopupsV3List(ttl: 300, popups: []))
        var popupsById: [Int: PopupV3] = [:]
        var promoCodes: [String: String] = [:]
        private(set) var listRequests = 0
        private(set) var promoRequests: [String] = []
        private(set) var events: [(id: Int, event: String, channel: String?)] = []

        func fetchList(testMode: Bool, debug: Bool, completion: @escaping (PopupsV3ListResult) -> Void) {
            listRequests += 1
            completion(list)
        }

        func fetchPopup(id: Int, testMode: Bool, completion: @escaping (PopupV3?) -> Void) {
            completion(popupsById[id])
        }

        func sendEvent(popupId: Int, event: String, channel: String?) {
            events.append((popupId, event, channel))
        }

        func fetchPromoCode(listId: String, completion: @escaping (String?) -> Void) {
            promoRequests.append(listId)
            completion(promoCodes[listId])
        }

        func shown(_ id: Int) -> Int { events.filter { $0.id == id && $0.event == "show" }.count }
    }

    final class Presenter: PopupsV3Presenting {
        private(set) var open: [Int: PopupV3Presentation] = [:]
        private(set) var shown: [Int] = []

        func isOpen(_ id: Int) -> Bool { open[id] != nil }

        func canOpen(_ popup: PopupV3) -> (ok: Bool, reason: String?) {
            if open[popup.id] != nil { return (false, "already open") }
            let others = open.values.map(\.popup)
            if popup.isModal, others.contains(where: \.isModal) { return (false, "another modal is open") }
            if !popup.isModal, others.contains(where: { !$0.isModal && $0.placement == popup.placement }) { return (false, "banner") }
            return (true, nil)
        }

        func present(_ presentation: PopupV3Presentation, completion: @escaping (Bool) -> Void) {
            open[presentation.popup.id] = presentation
            shown.append(presentation.popup.id)
            completion(true)
        }

        /// The user closed the popup: `close` event, the slot is free.
        func close(_ id: Int) {
            guard let presentation = open.removeValue(forKey: id) else { return }
            presentation.onEvent("close", nil)
            presentation.onClose()
        }
    }

    private var clock: Clock!
    private var backend: Backend!
    private var presenter: Presenter!
    private var defaults: UserDefaults!
    private var suite = ""
    private var sid = "SID-1"
    private var testMode = false
    /// Engines of a test stay alive to its end: popups hold them weakly.
    private var engines: [PopupsV3Engine] = []

    override func setUp() {
        super.setUp()
        clock = Clock()
        backend = Backend()
        presenter = Presenter()
        suite = "popups-v3-engine-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        sid = "SID-1"
        testMode = false
        engines = []
    }

    override func tearDown() {
        engines = []
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    // MARK: - Helpers

    /// A popup of `list-response.json` with fields replaced.
    private func popup(_ id: Int, _ overrides: [String: Any] = [:]) -> PopupV3 {
        let payload = PopupsV3Fixtures.json("list-response")["payload"] as? [String: Any] ?? [:]
        var json = (payload["popups"] as? [[String: Any]] ?? []).first { ($0["id"] as? Int) == id } ?? [:]
        overrides.forEach { json[$0.key] = $0.value }
        guard let popup = PopupV3(json: json) else {
            XCTFail("popup \(id) does not parse")
            return PopupV3(json: ["id": id, "layout": "modal", "trigger_type": "manual"])!
        }
        return popup
    }

    private func serve(_ popups: [PopupV3]) {
        backend.list = .list(PopupsV3List(ttl: 300, popups: popups))
    }

    /// `init` + the host turned the engine on: the list loads at once.
    @discardableResult
    private func start(flag: Bool = true) -> PopupsV3Engine {
        let engine = makeEngine()
        engine.testMode = testMode
        engine.enabled = true
        engine.initFinished(flag: flag)
        return engine
    }

    private func makeEngine() -> PopupsV3Engine {
        let clock = self.clock!
        let frequency = PopupsV3Frequency(defaults: defaults, now: { clock.now }, sid: { [unowned self] in self.sid }, testMode: { [unowned self] in self.testMode })
        let engine = PopupsV3Engine(backend: backend, presenter: presenter, clock: clock, frequency: frequency, sid: { [unowned self] in self.sid })
        engines.append(engine)
        return engine
    }

    // MARK: - Switching on

    func testNothingIsRequestedUntilTheHostEnablesTheEngine() {
        serve([popup(512)])
        let engine = makeEngine()
        engine.initFinished(flag: true)
        engine.screenOpened("home")
        XCTAssertEqual(backend.listRequests, 0)
        engine.enabled = true
        XCTAssertEqual(backend.listRequests, 1)
        XCTAssertEqual(presenter.shown, [512])
    }

    func testTheInitFlagIsRequiredUnlessTheHostIgnoresIt() {
        serve([popup(512)])
        let engine = makeEngine()
        engine.enabled = true
        XCTAssertEqual(backend.listRequests, 0, "init has not finished yet")
        engine.initFinished(flag: false)
        XCTAssertEqual(backend.listRequests, 0, "no popups_v3 in /init")
        engine.ignoreInitFlag = true
        XCTAssertEqual(backend.listRequests, 1)
        XCTAssertEqual(presenter.shown, [512])
    }

    func testAutomaticPresentationOffKeepsTriggeredPopupsButNotManualOnes() {
        serve([popup(512)])
        backend.popupsById[516] = popup(516)
        let engine = makeEngine()
        engine.autoPresentation = { false }
        engine.enabled = true
        engine.initFinished(flag: true)
        XCTAssertEqual(presenter.shown, [])
        engine.show(id: 516)
        XCTAssertEqual(presenter.shown, [516])
    }

    // MARK: - scenarios.json

    func testScenariosFixtureHasEighteen() {
        let scenarios = PopupsV3Fixtures.json("scenarios")["scenarios"] as? [[String: Any]] ?? []
        XCTAssertEqual(scenarios.count, 18)
    }

    /// 1. app_start без экранов — show at list loaded.
    func testAppStartWithoutScreens() {
        serve([popup(512)])
        start()
        XCTAssertEqual(presenter.shown, [512])
        XCTAssertEqual(backend.shown(512), 1)
    }

    /// 2. app_start ждёт подходящий экран — show at screen(product).
    func testAppStartWaitsForATargetScreen() {
        serve([popup(512, ["target_screens": ["product"]])])
        let engine = start()
        XCTAssertEqual(presenter.shown, [])
        engine.screenOpened("home")
        XCTAssertEqual(presenter.shown, [])
        engine.screenOpened("product")
        XCTAssertEqual(presenter.shown, [512])
    }

    /// 3. screen_open по списку экранов — show at screen(product).
    func testScreenOpenByTheList() {
        serve([popup(513)])
        let engine = start()
        engine.screenOpened("home")
        XCTAssertEqual(presenter.shown, [])
        engine.screenOpened("product")
        XCTAssertEqual(presenter.shown, [513])
    }

    /// 4. screen_open с пустым списком — show at screen(home).
    func testScreenOpenWithAnEmptyList() {
        serve([popup(513, ["target_screens": []])])
        let engine = start()
        engine.screenOpened("home")
        XCTAssertEqual(presenter.shown, [513])
    }

    /// 5. time_on_screen ушёл раньше — no show.
    func testTimeOnScreenLeftEarly() {
        serve([popup(514)])
        let engine = start()
        engine.screenOpened("home")
        clock.advance(to: 9)
        engine.screenOpened("category")
        clock.advance(to: 20)
        XCTAssertEqual(presenter.shown, [])
    }

    /// 6. time_on_screen досидел — show at t=10.
    func testTimeOnScreenStayed() {
        serve([popup(514)])
        let engine = start()
        engine.screenOpened("home")
        clock.advance(to: 9.9)
        XCTAssertEqual(presenter.shown, [])
        clock.advance(to: 10)
        XCTAssertEqual(presenter.shown, [514])
    }

    /// 7. time_on_screen и фон — the timer restarts after the background: show at t=40.
    func testTimeOnScreenAndBackground() {
        serve([popup(514)])
        let engine = start()
        engine.screenOpened("home")
        clock.advance(to: 5)
        engine.enteredBackground()
        clock.advance(to: 30)
        engine.enteredForeground()
        clock.advance(to: 39)
        XCTAssertEqual(presenter.shown, [])
        clock.advance(to: 40)
        XCTAssertEqual(presenter.shown, [514])
    }

    /// 8. track_event — show at trackEvent(promo_view).
    func testTrackEvent() {
        serve([popup(515)])
        let engine = start()
        engine.trackEvent("other")
        XCTAssertEqual(presenter.shown, [])
        engine.trackEvent("promo_view")
        XCTAssertEqual(presenter.shown, [515])
    }

    /// 9. track_event не на том экране — no show, the event trigger does not wait for the screen.
    func testTrackEventOnAnotherScreen() {
        serve([popup(515, ["target_screens": ["cart"]])])
        let engine = start()
        engine.screenOpened("home")
        engine.trackEvent("promo_view")
        engine.screenOpened("cart")
        XCTAssertEqual(presenter.shown, [])
    }

    /// 10. manual — GET /popups/516 → show; frequency is not written.
    func testManual() {
        serve([popup(512, ["target_screens": ["nowhere"]]), popup(516)])
        backend.popupsById[516] = popup(516)
        let engine = start()
        engine.screenOpened("home")
        XCTAssertEqual(presenter.shown, [], "a manual popup has no trigger")
        engine.show(id: 516)
        XCTAssertEqual(presenter.shown, [516])
        XCTAssertEqual(backend.shown(516), 1)
        XCTAssertNil(defaults.object(forKey: "pv3_516_last"))
        XCTAssertNil(defaults.object(forKey: "pv3_516_sid"))
    }

    /// 11. once_session — show, no show in the same session, show in a new one.
    func testOnceSession() {
        serve([popup(512)])
        start()
        XCTAssertEqual(presenter.shown, [512])
        presenter.close(512)
        start()
        XCTAssertEqual(presenter.shown, [512], "the same sid")
        sid = "SID-2"
        start()
        XCTAssertEqual(presenter.shown, [512, 512], "a new sid")
        XCTAssertEqual(defaults.string(forKey: "pv3_512_sid"), "SID-2")
    }

    /// 12. once_day и пауза 60 минут — show, no, no, show.
    func testOnceDayAndCooldown() {
        serve([popup(513)])
        let engine = start()
        engine.screenOpened("product")
        XCTAssertEqual(presenter.shown, [513])
        presenter.close(513)
        clock.advance(to: 30 * 60)
        engine.screenOpened("product")
        XCTAssertEqual(presenter.shown.count, 1, "cooldown 60 min")
        clock.advance(to: 23 * 3600)
        engine.screenOpened("product")
        XCTAssertEqual(presenter.shown.count, 1, "once_day")
        clock.advance(to: 24 * 3600)
        engine.screenOpened("product")
        XCTAssertEqual(presenter.shown, [513, 513])
    }

    /// 13. every_page — once per screen: show, no show, show.
    func testEveryPageOncePerScreen() {
        serve([popup(512, ["frequency": "every_page"])])
        let engine = makeEngine()
        engine.screenOpened("home")
        engine.enabled = true
        engine.initFinished(flag: true)
        XCTAssertEqual(presenter.shown, [512])
        presenter.close(512)
        let frequency = PopupsV3Frequency(defaults: defaults, now: { Date() }, sid: { "SID-1" }, testMode: { false })
        frequency.record(popup(512, ["frequency": "every_page"]))
        XCTAssertFalse(frequency.canShow(popup(512, ["frequency": "every_page"])).ok, "already shown on this screen")
        engine.screenOpened("product")
        XCTAssertEqual(presenter.shown, [512, 512])
    }

    /// 14. testmode не пишет частоту — show, show.
    func testTestModeDoesNotWriteFrequency() {
        testMode = true
        serve([popup(512, ["frequency": "once_life"])])
        start()
        presenter.close(512)
        start()
        XCTAssertEqual(presenter.shown, [512, 512])
        XCTAssertNil(defaults.object(forKey: "pv3_512_last"))
    }

    /// 15. одна модалка — 513 shown, 613 queued and shown after 513 closes.
    func testOneModalAtATime() {
        serve([popup(513), popup(513, ["id": 613])])
        let engine = start()
        engine.screenOpened("product")
        XCTAssertEqual(presenter.shown, [513])
        XCTAssertEqual(engine.queue, [613])
        presenter.close(513)
        XCTAssertEqual(presenter.shown, [513, 613])
    }

    /// 16. баннер не ждёт модалку — the modal 512 and the banner 514 together.
    func testBannerDoesNotWaitForTheModal() {
        serve([popup(512), popup(514, ["trigger_type": "app_start", "target_screens": []])])
        start()
        XCTAssertEqual(Set(presenter.shown), [512, 514])
        XCTAssertTrue(presenter.isOpen(512) && presenter.isOpen(514))
    }

    /// 17. нет промокода — no show and no show event.
    func testNoPromoCodeNoShow() {
        let promo = PopupsV3Fixtures.json("element-promo-code")["design"] as? [String: Any] ?? [:]
        serve([popup(519, ["design": promo])])
        start()
        XCTAssertEqual(backend.promoRequests, ["7"])
        XCTAssertEqual(presenter.shown, [])
        XCTAssertEqual(backend.shown(519), 0)
    }

    func testPromoCodeBecomesAShowcaseVariable() {
        let promo = PopupsV3Fixtures.json("element-promo-code")["design"] as? [String: Any] ?? [:]
        serve([popup(519, ["design": promo])])
        backend.promoCodes["7"] = "ABC123"
        start()
        XCTAssertEqual(presenter.shown, [519])
        XCTAssertEqual(presenter.open[519]?.runtime, ["promo_code": "ABC123"])
    }

    /// 18. смена контекста — the list again ~2 s later; the same data in the session does not reset it.
    func testContextChange() {
        serve([])
        let engine = start()
        XCTAssertEqual(backend.listRequests, 1)
        engine.contextChanged("profile", signature: "anna@example.com")
        clock.advance(to: 1.9)
        XCTAssertEqual(backend.listRequests, 1)
        clock.advance(to: 2)
        XCTAssertEqual(backend.listRequests, 2)
        engine.contextChanged("profile", signature: "anna@example.com")
        clock.advance(to: 10)
        XCTAssertEqual(backend.listRequests, 2, "the same profile set again")
        engine.contextChanged("profile", signature: "bob@example.com")
        engine.purchased()
        clock.advance(to: 20)
        XCTAssertEqual(backend.listRequests, 3, "debounced into one request")
    }

    // MARK: - List cache

    func testClientErrorsAreCachedAsAnEmptyListForTheDefaultTTL() {
        backend.list = .clientError(404)
        let engine = start()
        engine.enteredBackground()
        clock.advance(to: 100)
        engine.enteredForeground()
        XCTAssertEqual(backend.listRequests, 1)
        engine.enteredBackground()
        clock.advance(to: 301)
        engine.enteredForeground()
        XCTAssertEqual(backend.listRequests, 2)
    }

    func testNetworkFailuresAreNotCached() {
        backend.list = .failure
        let engine = start()
        engine.enteredBackground()
        clock.advance(to: 1)
        engine.enteredForeground()
        XCTAssertEqual(backend.listRequests, 2)
    }

    func testANewListDisarmsRemovedPopups() {
        serve([popup(514)])
        let engine = start()
        engine.screenOpened("home")
        serve([])
        engine.contextChanged("segment", signature: "add 1")
        clock.advance(to: 20)
        XCTAssertEqual(presenter.shown, [], "the time trigger of the removed popup is gone")
        XCTAssertTrue(engine.popups.isEmpty)
    }

    func testAScreenOpenedBeforeTheListCounts() {
        serve([popup(513)])
        let engine = makeEngine()
        engine.screenOpened("product")
        engine.enabled = true
        engine.initFinished(flag: true)
        XCTAssertEqual(presenter.shown, [513])
    }

    func testCloseSendsTheCloseEvent() {
        serve([popup(512)])
        start()
        presenter.close(512)
        XCTAssertEqual(backend.events.map(\.event), ["show", "close"])
    }
}
