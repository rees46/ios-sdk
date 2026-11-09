import Foundation

/// Попап v3 из ответа `GET /api/v3/storefront/popups` (канал mobile): макет, триггер, частота и
/// дизайн. Разбор терпимый: числа строками, `null` в частоте, паузе и экранах — умолчания.
/// Неизвестный для mobile макет или триггер — `nil` и строка в лог.
struct PopupV3 {

    enum Layout: String {
        case banner, modal, fullscreen
    }

    enum Trigger: String {
        case appStart = "app_start"
        case screenOpen = "screen_open"
        case timeOnScreen = "time_on_screen"
        case trackEvent = "track_event"
        case manual
    }

    enum Frequency: String {
        case onceSession = "once_session"
        case onceLife = "once_life"
        case onceDay = "once_day"
        case onceWeek = "once_week"
        case onceMonth = "once_month"
        case everyPage = "every_page"
    }

    enum Placement: String {
        case top, bottom, center
    }

    let id: Int
    let layout: Layout
    let placement: Placement
    let trigger: Trigger
    /// Секунды у `time_on_screen`.
    let triggerValue: Double
    /// Имя события у `track_event`.
    let triggerEvent: String?
    let frequency: Frequency
    let cooldownMinutes: Double
    let promoCodeListId: String?
    /// Экраны показа; пусто — любой.
    let targetScreens: [String]
    let design: [String: Any]

    init?(json: [String: Any]) {
        guard let id = PopupV3Value.number(json["id"]).flatMap({ $0 == $0.rounded() ? Int(exactly: $0) : nil }) else {
            PopupsV3Log.log("popup without id skipped")
            return nil
        }
        guard let layout = (json["layout"] as? String).flatMap(Layout.init(rawValue:)) else {
            PopupsV3Log.log("popup \(id) skipped: layout \(json["layout"] ?? "nil") is not for mobile")
            return nil
        }
        guard let trigger = (json["trigger_type"] as? String).flatMap(Trigger.init(rawValue:)) else {
            PopupsV3Log.log("popup \(id) skipped: trigger \(json["trigger_type"] ?? "nil") is not for mobile")
            return nil
        }
        self.id = id
        self.layout = layout
        switch layout {
        case .banner: placement = (json["placement"] as? String) == "bottom" ? .bottom : .top
        case .modal, .fullscreen: placement = .center
        }
        self.trigger = trigger
        triggerValue = max(0, PopupV3Value.num(json["trigger_value"], 0))
        triggerEvent = PopupV3Value.string(json["trigger_event"])
        frequency = (json["frequency"] as? String).flatMap(Frequency.init(rawValue:)) ?? .onceSession
        cooldownMinutes = max(0, PopupV3Value.num(json["cooldown_minutes"], 0))
        promoCodeListId = PopupV3Value.string(json["promo_code_list_id"])
        targetScreens = (json["target_screens"] as? [Any] ?? []).compactMap { PopupV3Value.string($0) }
        design = json["design"] as? [String: Any] ?? [:]
    }

    /// Модалка и фуллскрин — одно окно на процесс; баннер — свой слот сверху или снизу.
    var isModal: Bool { layout != .banner }

    /// Экран подходит: список пуст или экран в нём.
    func matches(screen: String?) -> Bool {
        targetScreens.isEmpty || screen.map(targetScreens.contains) == true
    }

    /// Нужен персональный промокод до показа: задан список и в дизайне есть `{{promo_code}}` или
    /// элемент `promoCode` не со статическим кодом.
    var needsPromoCode: Bool {
        guard promoCodeListId != nil else { return false }
        if let data = try? JSONSerialization.data(withJSONObject: design),
           let text = String(data: data, encoding: .utf8),
           PopupV3Variables.contains("promo_code", in: text) {
            return true
        }
        let elements = (design["elements"] as? [Any] ?? []).compactMap { $0 as? [String: Any] }
        return elements.contains { raw in
            guard raw["type"] as? String == "promoCode" else { return false }
            let element = PopupV3Element(id: "", type: "promoCode", style: raw["style"] as? [String: Any] ?? [:])
            return element.string("promoSource") != "static"
        }
    }
}

/// Список попапов из ответа: `ttl` (строкой тоже, по умолчанию 300), попапы и `excluded`.
struct PopupsV3List {
    static let defaultTTL: TimeInterval = 300

    let ttl: TimeInterval
    let popups: [PopupV3]
    let excluded: [(id: String, reason: String)]

    init(payload: [String: Any]) {
        let ttl = PopupV3Value.num(payload["ttl"], Self.defaultTTL)
        self.ttl = ttl > 0 ? ttl : Self.defaultTTL
        popups = (payload["popups"] as? [Any] ?? []).compactMap { ($0 as? [String: Any]).flatMap(PopupV3.init(json:)) }
        excluded = (payload["excluded"] as? [Any] ?? []).compactMap { item in
            guard let object = item as? [String: Any], let id = PopupV3Value.string(object["id"]) else { return nil }
            return (id, PopupV3Value.string(object["reason"]) ?? "")
        }
    }

    init(ttl: TimeInterval, popups: [PopupV3]) {
        self.ttl = ttl
        self.popups = popups
        self.excluded = []
    }
}
