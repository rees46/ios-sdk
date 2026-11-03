import Foundation

/// Частота показов и пауза между ними — как `frequency.ts` веба. Хранится на устройстве, в
/// хранилище магазина: время (мс) и сеанс последнего показа, ключи `pv3_<id>_last` и
/// `pv3_<id>_sid`. `every_page` и «уже показан на этом экране» — в памяти, до следующего экрана.
final class PopupsV3Frequency {

    static let minute: TimeInterval = 60
    static let day: TimeInterval = 24 * 60 * 60
    static let periods: [PopupV3.Frequency: TimeInterval] = [.onceDay: day, .onceWeek: 7 * day, .onceMonth: 30 * day]

    private let defaults: UserDefaults
    private let now: () -> Date
    private let sid: () -> String
    private let testMode: () -> Bool
    private var shownOnScreen = Set<Int>()

    init(defaults: UserDefaults, now: @escaping () -> Date, sid: @escaping () -> String, testMode: @escaping () -> Bool) {
        self.defaults = defaults
        self.now = now
        self.sid = sid
        self.testMode = testMode
    }

    /// Новый экран — новая «страница» частоты.
    func newScreen() {
        shownOnScreen.removeAll()
    }

    func lastShow(_ id: Int) -> Date? {
        guard let millis = defaults.object(forKey: "pv3_\(id)_last") as? Double, millis.isFinite else { return nil }
        return Date(timeIntervalSince1970: millis / 1000)
    }

    /// Можно ли показать; нет — причина для лога.
    func canShow(_ popup: PopupV3) -> (ok: Bool, reason: String?) {
        if shownOnScreen.contains(popup.id) { return (false, "already shown on this screen") }
        let current = now()
        let last = lastShow(popup.id)
        if popup.cooldownMinutes > 0, let last, current.timeIntervalSince(last) < popup.cooldownMinutes * Self.minute {
            return (false, "cooldown \(Self.format(popup.cooldownMinutes)) min")
        }
        switch popup.frequency {
        case .everyPage:
            return (true, nil)
        case .onceLife:
            return last == nil ? (true, nil) : (false, "once_life: already shown")
        case .onceDay, .onceWeek, .onceMonth:
            guard let last, let period = Self.periods[popup.frequency] else { return (true, nil) }
            return current.timeIntervalSince(last) >= period ? (true, nil) : (false, "\(popup.frequency.rawValue): shown recently")
        case .onceSession:
            let shownSid = defaults.string(forKey: "pv3_\(popup.id)_sid")
            return shownSid != nil && shownSid == sid() ? (false, "once_session: already shown in this session") : (true, nil)
        }
    }

    /// Показ состоялся. В тестовом режиме в хранилище ничего не пишется.
    func record(_ popup: PopupV3) {
        shownOnScreen.insert(popup.id)
        guard !testMode() else { return }
        defaults.set(now().timeIntervalSince1970 * 1000, forKey: "pv3_\(popup.id)_last")
        let session = sid()
        if !session.isEmpty { defaults.set(session, forKey: "pv3_\(popup.id)_sid") }
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

/// Кеш списка в памяти: на `ttl` ответа, для того же сеанса и тестового режима.
struct PopupsV3ListCache {
    private(set) var popups: [PopupV3] = []
    private var expires: Date?
    private var sid = ""
    private var testMode = false

    func valid(now: Date, sid: String, testMode: Bool) -> [PopupV3]? {
        guard let expires, expires > now, self.sid == sid, self.testMode == testMode else { return nil }
        return popups
    }

    mutating func store(_ popups: [PopupV3], ttl: TimeInterval, now: Date, sid: String, testMode: Bool) {
        self.popups = popups
        self.expires = now.addingTimeInterval(ttl)
        self.sid = sid
        self.testMode = testMode
    }

    mutating func clear() {
        expires = nil
    }
}
