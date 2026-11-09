import Foundation

// Клиент попапов v3. Хост ЛК (`appHost`, например `app.rees46.ru`):
//
//   GET  /api/v3/storefront/popups?shop_id&did&sid&channel=mobile[&testmode=true][&debug=1]
//   GET  /api/v3/storefront/popups/:id?shop_id&did&sid[&testmode=true]
//   POST /api/v3/storefront/popups/:id/events   {shop_id, did, sid, event[, channel]}
//
// Промокод — на API-хосте SDK: `GET /promo_codes/fetch?shop_id&did&sid&id=<список>` → `{code}`.
// Запросы идут тем же транспортом и в той же очереди сессии SDK, что сторис и опросы API v3
// (`StoriesApiV3`): тесты подменяют `StoriesApiV3.transport`.

/// Исход запроса списка.
enum PopupsV3ListResult {
    case list(PopupsV3List)
    /// 4xx или неожиданный ответ: список считается пустым на `ttl` по умолчанию.
    case clientError(Int)
    /// Нет сети, таймаут, 5xx: не кешируется, повтор при следующем поводе.
    case failure
}

/// Что движку нужно от сети; в тестах — подмена.
protocol PopupsV3Backend: AnyObject {
    func fetchList(testMode: Bool, debug: Bool, completion: @escaping (PopupsV3ListResult) -> Void)
    func fetchPopup(id: Int, testMode: Bool, completion: @escaping (PopupV3?) -> Void)
    func sendEvent(popupId: Int, event: String, channel: String?)
    func fetchPromoCode(listId: String, completion: @escaping (String?) -> Void)
}

final class PopupsV3API: PopupsV3Backend {

    /// Сколько ждать промокод.
    static var promoTimeout: TimeInterval = 10
    /// Сколько помнить выданный промокод списка.
    static let promoTTL: TimeInterval = 2 * 60 * 60
    /// Пауза событий после 429.
    static let rateLimitPause: TimeInterval = 60

    private weak var sdkObject: AnyObject?
    private let appHost: () -> String
    private let apiHost: String
    private let now: () -> Date

    /// Трогаются только на главном потоке.
    private var promoCodes: [String: (code: String, expires: Date)] = [:]
    private var eventsPausedUntil: Date?

    init(sdk: PersonalizationSDK & AnyObject, appHost: @escaping () -> String, apiHost: String, now: @escaping () -> Date = Date.init) {
        self.sdkObject = sdk
        self.appHost = appHost
        self.apiHost = apiHost
        self.now = now
    }

    private var sdk: PersonalizationSDK? { sdkObject as? PersonalizationSDK }

    // MARK: - Адреса

    static func listURL(host: String, shopId: String, did: String, sid: String, testMode: Bool, debug: Bool) -> URL? {
        var query = identity(shopId: shopId, did: did, sid: sid)
        query.append(URLQueryItem(name: "channel", value: "mobile"))
        if testMode { query.append(URLQueryItem(name: "testmode", value: "true")) }
        if debug { query.append(URLQueryItem(name: "debug", value: "1")) }
        return url(host: host, path: "/api/v3/storefront/popups", query: query)
    }

    static func popupURL(host: String, id: Int, shopId: String, did: String, sid: String, testMode: Bool) -> URL? {
        var query = identity(shopId: shopId, did: did, sid: sid)
        if testMode { query.append(URLQueryItem(name: "testmode", value: "true")) }
        return url(host: host, path: "/api/v3/storefront/popups/\(id)", query: query)
    }

    static func eventsURL(host: String, id: Int) -> URL? {
        url(host: host, path: "/api/v3/storefront/popups/\(id)/events", query: [])
    }

    static func eventBody(shopId: String, did: String, sid: String, event: String, channel: String?) -> [String: Any] {
        var body: [String: Any] = ["shop_id": shopId, "did": did, "sid": sid, "event": event]
        if let channel { body["channel"] = channel }
        return body
    }

    static func promoURL(apiHost: String, shopId: String, did: String, sid: String, listId: String) -> URL? {
        var query = identity(shopId: shopId, did: did, sid: sid)
        query.append(URLQueryItem(name: "id", value: listId))
        return url(host: apiHost, path: "/promo_codes/fetch", query: query)
    }

    private static func identity(shopId: String, did: String, sid: String) -> [URLQueryItem] {
        [URLQueryItem(name: "shop_id", value: shopId), URLQueryItem(name: "did", value: did), URLQueryItem(name: "sid", value: sid)]
    }

    /// Хост без схемы (`app.rees46.ru`) или с ней (`https://app.rees46.ru/`).
    static func url(host: String, path: String, query: [URLQueryItem]) -> URL? {
        var base = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.hasPrefix("https://") { base.removeFirst(8) } else if base.hasPrefix("http://") { base.removeFirst(7) }
        while base.hasSuffix("/") { base.removeLast() }
        guard !base.isEmpty, var components = URLComponents(string: "https://\(base)\(path)") else { return nil }
        if !query.isEmpty { components.queryItems = query }
        return components.url
    }

    // MARK: - Разбор ответов

    static func listResult(status: Int, json: [String: Any]?, error: Error?) -> PopupsV3ListResult {
        if error != nil || status == 0 || status >= 500 { return .failure }
        guard (200..<300).contains(status) else { return .clientError(status) }
        guard let json, json["status"] as? String == "success", let payload = json["payload"] as? [String: Any] else {
            return .clientError(status)
        }
        return .list(PopupsV3List(payload: payload))
    }

    static func popupResult(status: Int, json: [String: Any]?) -> PopupV3? {
        guard (200..<300).contains(status), json?["status"] as? String == "success",
              let popup = (json?["payload"] as? [String: Any])?["popup"] as? [String: Any] else { return nil }
        return PopupV3(json: popup)
    }

    static func promoResult(status: Int, json: [String: Any]?) -> String? {
        guard (200..<300).contains(status), let code = PopupV3Value.string(json?["code"])?.trimmingCharacters(in: .whitespacesAndNewlines),
              !code.isEmpty else { return nil }
        // Значение витринной переменной безопасно для разметки, как у веба.
        let cleaned = code.filter { !"<>\"'&".contains($0) }
        return cleaned.isEmpty ? nil : cleaned
    }

    // MARK: - Запросы

    func fetchList(testMode: Bool, debug: Bool, completion: @escaping (PopupsV3ListResult) -> Void) {
        let host = appHost()
        get(url: { sdk, did in Self.listURL(host: host, shopId: sdk.shopId, did: did, sid: sdk.userSeance, testMode: testMode, debug: debug) },
            timeout: 15) { status, json, error in
            let result = Self.listResult(status: status, json: json, error: error)
            if case .clientError(let code) = result {
                PopupsV3Log.log("list request failed with HTTP \(code): \(PopupV3Value.string(json?["message"]) ?? "unexpected response")")
            } else if case .failure = result {
                PopupsV3Log.log("list request failed: \(error.map { "\($0)" } ?? "HTTP \(status)")")
            }
            completion(result)
        }
    }

    func fetchPopup(id: Int, testMode: Bool, completion: @escaping (PopupV3?) -> Void) {
        let host = appHost()
        get(url: { sdk, did in Self.popupURL(host: host, id: id, shopId: sdk.shopId, did: did, sid: sdk.userSeance, testMode: testMode) },
            timeout: 15) { status, json, error in
            let popup = Self.popupResult(status: status, json: json)
            if popup == nil {
                PopupsV3Log.log("popup \(id) request failed: \(error.map { "\($0)" } ?? "HTTP \(status) \(PopupV3Value.string(json?["message"]) ?? "")")")
            }
            completion(popup)
        }
    }

    func fetchPromoCode(listId: String, completion: @escaping (String?) -> Void) {
        if let cached = promoCodes[listId], cached.expires > now() { return completion(cached.code) }
        let apiHost = self.apiHost
        get(url: { sdk, did in Self.promoURL(apiHost: apiHost, shopId: sdk.shopId, did: did, sid: sdk.userSeance, listId: listId) },
            timeout: Self.promoTimeout) { [weak self] status, json, error in
            let code = Self.promoResult(status: status, json: json)
            if let code, let self {
                self.promoCodes[listId] = (code, self.now().addingTimeInterval(Self.promoTTL))
            } else if code == nil {
                PopupsV3Log.log("no promo code from the list \(listId): \(error.map { "\($0)" } ?? "HTTP \(status) \(PopupV3Value.string(json?["message"]) ?? "")")")
            }
            completion(code)
        }
    }

    /// Событие «выстрелил и забыл»: один повтор при сети или 5xx, 4xx не повторяется, после 429 —
    /// минута тишины.
    func sendEvent(popupId: Int, event: String, channel: String?) {
        if let paused = eventsPausedUntil, paused > now() {
            PopupsV3Log.log("popup \(popupId) event \(event) dropped: too many requests")
            return
        }
        send(popupId: popupId, event: event, channel: channel, attempt: 1)
    }

    private func send(popupId: Int, event: String, channel: String?, attempt: Int) {
        guard let sdk, let url = Self.eventsURL(host: appHost(), id: popupId) else { return }
        let sid = sdk.userSeance
        let body = { (did: String) in Self.eventBody(shopId: sdk.shopId, did: did, sid: sid, event: event, channel: channel) }
        StoriesApiV3(domain: appHost()).post(sdk: sdk, url: url, body: body) { [weak self] _, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            MainThread.run {
                guard let self else { return }
                if (200..<300).contains(status) {
                    PopupsV3Log.log("popup \(popupId) event \(event)\(channel.map { " (\($0))" } ?? "") sent")
                } else if status == 429 {
                    self.eventsPausedUntil = self.now().addingTimeInterval(Self.rateLimitPause)
                    PopupsV3Log.log("popup \(popupId) event \(event): HTTP 429, events paused")
                } else if (error != nil || status == 0 || status >= 500) && attempt == 1 {
                    self.send(popupId: popupId, event: event, channel: channel, attempt: 2)
                } else {
                    PopupsV3Log.log("popup \(popupId) event \(event) failed: \(error.map { "\($0)" } ?? "HTTP \(status)")")
                }
            }
        }
    }

    /// GET в очереди сессии SDK, когда есть `did`; ответ — на главной очереди.
    private func get(
        url: @escaping (PersonalizationSDK, String) -> URL?,
        timeout: TimeInterval,
        completion: @escaping (Int, [String: Any]?, Error?) -> Void
    ) {
        guard let sdk else { return MainThread.run { completion(0, nil, nil) } }
        sdk.sessionQueue.addOperation {
            guard let did = StoriesApiV3.awaitDeviceId(sdk), let address = url(sdk, did) else {
                return MainThread.run { completion(0, nil, SdkError.custom(error: "Popups v3: no did or bad host")) }
            }
            var request = URLRequest(url: address, timeoutInterval: timeout)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpShouldHandleCookies = false
            StoriesApiV3.transport(request) { data, response, error in
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
                MainThread.run { completion(status, json, error) }
            }
        }
    }
}
