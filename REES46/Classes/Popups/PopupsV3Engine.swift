import Foundation

// Движок попапов v3 одного инстанса SDK: список, экраны, триггеры, частота, очередь, промокод.
// Логика — как у веба (`v3/src/popups-v3/controller.ts`), но вместо страниц — экраны приложения:
// хост зовёт `screenOpened(name)`, а маркетолог пишет эти имена в `target_screens`.
//
// Триггеры:
//   app_start       — при загрузке списка и на каждом открытом экране (частота решает, показывать ли);
//                     экран не из `target_screens` — ждём подходящего;
//   screen_open     — на `screenOpened(name)`, имя из списка или список пуст;
//   time_on_screen  — через `trigger_value` секунд на том же экране; смена экрана отменяет,
//                     уход в фон сбрасывает, при возврате отсчёт заново;
//   track_event     — на событии SDK `trackEvent` с именем `trigger_event`, если экран подходит
//                     (событийный триггер экрана не ждёт);
//   manual          — только `show(id:)`: без экранов и частоты, частота не пишется.
//
// Все методы — на главном потоке.

protocol PopupsV3Timer {
    func cancel()
}

/// Часы и таймеры движка; в тестах — виртуальное время.
protocol PopupsV3Clock: AnyObject {
    var now: Date { get }
    func schedule(after delay: TimeInterval, _ block: @escaping () -> Void) -> PopupsV3Timer
}

final class PopupsV3SystemClock: PopupsV3Clock {
    private struct Work: PopupsV3Timer {
        let item: DispatchWorkItem
        func cancel() { item.cancel() }
    }

    var now: Date { Date() }

    func schedule(after delay: TimeInterval, _ block: @escaping () -> Void) -> PopupsV3Timer {
        let item = DispatchWorkItem(block: block)
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay), execute: item)
        return Work(item: item)
    }
}

/// Что показать: попап, его дизайн, витринные переменные и обратная связь с движком.
struct PopupV3Presentation {
    let popup: PopupV3
    let design: PopupV3Design
    let runtime: [String: String]
    /// Событие попапа (`click`, `close`, `submit`, `subscribe` с каналом).
    let onEvent: (String, String?) -> Void
    /// Попап закрыт (уже без события): слот свободен.
    let onClose: () -> Void
}

/// Окна попапов: слоты (одна модалка на процесс, баннер сверху и снизу) и показ.
protocol PopupsV3Presenting: AnyObject {
    func isOpen(_ id: Int) -> Bool
    func canOpen(_ popup: PopupV3) -> (ok: Bool, reason: String?)
    /// Показ; `completion(false)` — показывать негде (нет сцены).
    func present(_ presentation: PopupV3Presentation, completion: @escaping (Bool) -> Void)
}

final class PopupsV3Engine {

    /// Пауза перед перезапросом списка после смены контекста.
    static let invalidateDelay: TimeInterval = 2

    var enabled = false {
        didSet { maybeStart() }
    }
    var ignoreInitFlag = false {
        didSet { maybeStart() }
    }
    var testMode = false
    var debug = false {
        didSet { PopupsV3Log.verbose = debug }
    }
    /// Показывать ли попапы самим (`enableAutoPopupPresentation` SDK); ручной показ — всегда.
    var autoPresentation: () -> Bool = { true }

    private let backend: PopupsV3Backend
    private let presenter: PopupsV3Presenting
    private let clock: PopupsV3Clock
    private let frequency: PopupsV3Frequency
    private let sid: () -> String

    /// Флаг `popups_v3` из `/init`; `nil` — инициализация ещё не закончилась.
    private(set) var initFlag: Bool?
    private(set) var started = false
    /// Попапы с триггером (без ручных) в порядке списка.
    private(set) var popups: [PopupV3] = []
    private var armed = Set<Int>()
    private(set) var currentScreen: String?
    private var screenOpenedAt: Date?
    private(set) var isForeground = true
    private var timers: [Int: PopupsV3Timer] = [:]
    private(set) var queue: [Int] = []
    private var showing = Set<Int>()
    private var listCache = PopupsV3ListCache()
    private var loading = false
    private var invalidateTimer: PopupsV3Timer?
    /// Последние данные смены контекста в этом сеансе: повтор тех же данных список не сбрасывает.
    private var signatures: [String: String] = [:]

    init(backend: PopupsV3Backend, presenter: PopupsV3Presenting, clock: PopupsV3Clock, frequency: PopupsV3Frequency, sid: @escaping () -> String) {
        self.backend = backend
        self.presenter = presenter
        self.clock = clock
        self.frequency = frequency
        self.sid = sid
    }

    // MARK: - Старт и список

    /// `/init` закончился: флаг `popups_v3` из ответа.
    func initFinished(flag: Bool) {
        PopupsV3Log.log("init: popups_v3 \(flag)")
        initFlag = flag
        maybeStart()
    }

    /// Работает, если хост включил движок и `/init` прислал флаг (или хост велел его не ждать).
    var isActive: Bool {
        enabled && initFlag != nil && (ignoreInitFlag || initFlag == true)
    }

    private func maybeStart() {
        guard !started, enabled, let flag = initFlag else { return }
        guard flag || ignoreInitFlag else {
            PopupsV3Log.log("the init response has no popups_v3 flag, popups are off")
            return
        }
        started = true
        PopupsV3Log.log("started\(testMode ? " in test mode" : "")")
        load(force: false)
    }

    private func load(force: Bool) {
        let now = clock.now
        if !force, let cached = listCache.valid(now: now, sid: sid(), testMode: testMode) {
            return apply(cached)
        }
        guard !loading else { return }
        loading = true
        backend.fetchList(testMode: testMode, debug: debug) { [weak self] result in
            guard let self else { return }
            self.loading = false
            switch result {
            case .list(let list):
                self.listCache.store(list.popups, ttl: list.ttl, now: self.clock.now, sid: self.sid(), testMode: self.testMode)
                for item in list.excluded {
                    PopupsV3Log.log("popup \(item.id) excluded by the server: \(item.reason)")
                }
                self.apply(list.popups)
            case .clientError:
                self.listCache.store([], ttl: PopupsV3List.defaultTTL, now: self.clock.now, sid: self.sid(), testMode: self.testMode)
                self.apply([])
            case .failure:
                break
            }
        }
    }

    /// Свежий список: исчезнувшие попапы снимаются, новые встают на триггеры. Открытый попап остаётся.
    private func apply(_ list: [PopupV3]) {
        let next = list.filter { $0.trigger != .manual }
        let ids = Set(next.map(\.id))
        for id in armed where !ids.contains(id) {
            timers.removeValue(forKey: id)?.cancel()
            armed.remove(id)
        }
        queue.removeAll { !ids.contains($0) }
        popups = next
        PopupsV3Log.log("\(next.count) popup(s) armed, \(list.count - next.count) manual")
        for popup in next where !armed.contains(popup.id) {
            armed.insert(popup.id)
            arm(popup)
        }
    }

    private func arm(_ popup: PopupV3) {
        switch popup.trigger {
        case .appStart:
            fire(popup)
        case .screenOpen:
            // Экран уже открыт, когда пришёл список, — он и считается открытым.
            if currentScreen != nil { fire(popup) }
        case .timeOnScreen:
            if currentScreen != nil, isForeground {
                let elapsed = screenOpenedAt.map { clock.now.timeIntervalSince($0) } ?? 0
                startTimer(popup, delay: popup.triggerValue - elapsed)
            }
        case .trackEvent, .manual:
            break
        }
    }

    // MARK: - Экраны, события, фон

    func screenOpened(_ name: String) {
        currentScreen = name
        screenOpenedAt = clock.now
        frequency.newScreen()
        cancelTimers()
        guard started else { return }
        PopupsV3Log.log("screen \(name)")
        for popup in popups {
            switch popup.trigger {
            case .appStart, .screenOpen:
                fire(popup)
            case .timeOnScreen:
                if popup.matches(screen: name), isForeground { startTimer(popup, delay: popup.triggerValue) }
            case .trackEvent, .manual:
                break
            }
        }
    }

    func trackEvent(_ name: String) {
        guard started else { return }
        for popup in popups where popup.trigger == .trackEvent && popup.triggerEvent == name {
            fire(popup)
        }
    }

    func enteredBackground() {
        isForeground = false
        cancelTimers()
    }

    func enteredForeground() {
        guard !isForeground else { return }
        isForeground = true
        guard started else { return }
        if listCache.valid(now: clock.now, sid: sid(), testMode: testMode) == nil { load(force: false) }
        guard let screen = currentScreen else { return }
        for popup in popups where popup.trigger == .timeOnScreen && popup.matches(screen: screen) {
            startTimer(popup, delay: popup.triggerValue)
        }
    }

    /// Профиль, подписка или сегмент изменились: список заново через 2 с. Те же данные в этом
    /// сеансе повторно список не сбрасывают.
    func contextChanged(_ kind: String, signature: String) {
        guard signatures[kind] != signature else { return }
        signatures[kind] = signature
        invalidate()
    }

    /// Покупка: список заново всегда.
    func purchased() {
        invalidate()
    }

    private func invalidate() {
        guard started else { return }
        invalidateTimer?.cancel()
        invalidateTimer = clock.schedule(after: Self.invalidateDelay) { [weak self] in
            guard let self else { return }
            self.invalidateTimer = nil
            PopupsV3Log.log("list invalidated")
            self.listCache.clear()
            self.load(force: true)
        }
    }

    private func startTimer(_ popup: PopupV3, delay: TimeInterval) {
        timers.removeValue(forKey: popup.id)?.cancel()
        timers[popup.id] = clock.schedule(after: max(0, delay)) { [weak self] in
            self?.timers.removeValue(forKey: popup.id)
            self?.fire(popup)
        }
    }

    private func cancelTimers() {
        timers.values.forEach { $0.cancel() }
        timers.removeAll()
    }

    // MARK: - Показ

    /// Ручной показ: попап по id с сервера, без экранов и частоты.
    func show(id: Int) {
        guard enabled else {
            PopupsV3Log.log("popup \(id) is not shown: popups are not enabled")
            return
        }
        backend.fetchPopup(id: id, testMode: testMode) { [weak self] popup in
            guard let popup else { return }
            self?.show(popup, manual: true)
        }
    }

    /// Триггер сработал: экран и частота.
    private func fire(_ popup: PopupV3) {
        guard popup.matches(screen: currentScreen) else {
            PopupsV3Log.log("popup \(popup.id) waits: screen \(currentScreen ?? "nil") is not in its target screens")
            return
        }
        let check = frequency.canShow(popup)
        guard check.ok else {
            PopupsV3Log.log("popup \(popup.id) skipped: \(check.reason ?? "")")
            return
        }
        show(popup, manual: false)
    }

    private func show(_ popup: PopupV3, manual: Bool) {
        let id = popup.id
        guard !showing.contains(id), !presenter.isOpen(id) else { return }
        if !manual {
            let check = frequency.canShow(popup)
            guard check.ok else {
                PopupsV3Log.log("popup \(id) skipped: \(check.reason ?? "")")
                return
            }
            guard autoPresentation() else {
                PopupsV3Log.log("popup \(id) skipped: automatic popup presentation is off")
                return
            }
        }
        let slot = presenter.canOpen(popup)
        guard slot.ok else {
            PopupsV3Log.log("popup \(id) postponed: \(slot.reason ?? "")")
            if !manual { enqueue(id) }
            return
        }
        let design = PopupV3Design(json: popup.design)
        guard !design.isEmpty else {
            PopupsV3Log.log("popup \(id) skipped: the design has nothing to draw")
            return
        }
        showing.insert(id)
        guard popup.needsPromoCode, let list = popup.promoCodeListId else {
            return present(popup, design: design, runtime: [:], manual: manual)
        }
        backend.fetchPromoCode(listId: list) { [weak self] code in
            guard let self else { return }
            guard let code else {
                self.showing.remove(id)
                PopupsV3Log.log("popup \(id) skipped: no promo code")
                return
            }
            self.present(popup, design: design, runtime: ["promo_code": code], manual: manual)
        }
    }

    private func present(_ popup: PopupV3, design: PopupV3Design, runtime: [String: String], manual: Bool) {
        let id = popup.id
        // Пока ждали промокод, могла открыться другая модалка.
        let slot = presenter.canOpen(popup)
        guard slot.ok else {
            showing.remove(id)
            PopupsV3Log.log("popup \(id) postponed: \(slot.reason ?? "")")
            if !manual { enqueue(id) }
            return
        }
        let presentation = PopupV3Presentation(
            popup: popup,
            design: design,
            runtime: runtime,
            onEvent: { [weak self] event, channel in self?.backend.sendEvent(popupId: id, event: event, channel: channel) },
            onClose: { [weak self] in
                PopupsV3Log.log("popup \(id) closed")
                self?.processQueue()
            }
        )
        presenter.present(presentation) { [weak self] shown in
            guard let self else { return }
            self.showing.remove(id)
            guard shown else {
                PopupsV3Log.log("popup \(id) is not shown: no window scene on screen")
                return
            }
            if !manual { self.frequency.record(popup) }
            self.backend.sendEvent(popupId: id, event: "show", channel: nil)
            PopupsV3Log.log("popup \(id) shown")
        }
    }

    private func enqueue(_ id: Int) {
        if !queue.contains(id) { queue.append(id) }
    }

    /// Слот освободился (закрыт попап, в том числе старый): очередь — по порядку, если частота
    /// ещё позволяет.
    func processQueue() {
        let pending = queue
        queue.removeAll()
        for id in pending {
            guard let popup = popups.first(where: { $0.id == id }) else { continue }
            show(popup, manual: false)
        }
    }
}
