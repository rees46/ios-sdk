import Foundation

// «Поделиться» и ссылки сторис V2 — API v3 (`apiV3Domain` виджета, `show` и `handleLink`;
// по умолчанию — глобальный `PersonalizationStories.apiV3Domain`).
//
// Лента v3 присылает готовую ссылку каждого слайда (`share_url`) и кампании (у товарных
// кампаний своих ссылок у слайдов нет). Ссылка ведёт на сайт магазина:
//
//   https://shop.com/?r46_stories=<код блока>&r46_story=<id кампании>&r46_slide=<id слайда>
//
// Приложение открывает её через `PersonalizationStories.handleLink`, открытие трекается
// событием `shared_open`. Без `apiV3Domain` ничего этого нет: лента и трекинг — старого API.

/// Ссылка «Поделиться» на кампанию сторис. Разбор — как `parseShareLink` веба.
struct StoriesShareLink: Equatable {

    static let blockParameter = "r46_stories"
    static let storyParameter = "r46_story"
    static let slideParameter = "r46_slide"

    /// Код блока.
    let code: String
    /// Id кампании: от 1 до 10 цифр.
    let storyId: String
    /// Id слайда: число или виртуальный слайд товарной кампании `{story}_{index}`.
    /// Неверный — `nil`, кампания всё равно открывается.
    let slideId: String?

    init(code: String, storyId: String, slideId: String? = nil) {
        self.code = code
        self.storyId = storyId
        self.slideId = slideId
    }

    /// Ссылка сторис из адреса; любой другой адрес — `nil`. Прочие параметры не мешают.
    init?(url: URL) {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        guard let code = value(Self.blockParameter), !code.isEmpty,
              let story = value(Self.storyParameter), Self.isNumber(story, maxDigits: 10) else { return nil }
        self.init(code: code, storyId: story, slideId: value(Self.slideParameter).flatMap { Self.isSlideId($0) ? $0 : nil })
    }

    /// `^\d{1,maxDigits}$`: только цифры ASCII.
    static func isNumber(_ text: String, maxDigits: Int) -> Bool {
        (1...maxDigits).contains(text.count) && text.unicodeScalars.allSatisfy { ("0"..."9").contains($0) }
    }

    /// `^\d{1,10}(_\d{1,4})?$`.
    static func isSlideId(_ text: String) -> Bool {
        let parts = text.split(separator: "_", omittingEmptySubsequences: false).map(String.init)
        switch parts.count {
        case 1: return isNumber(parts[0], maxDigits: 10)
        case 2: return isNumber(parts[0], maxDigits: 10) && isNumber(parts[1], maxDigits: 4)
        default: return false
        }
    }
}

/// Сторис API v3 на хосте `apiV3Domain`: лента, кампания по ссылке и события.
///
/// Протокол SDK не расширяется: запросы идут своим `URLSession` в очереди сессии SDK, как и
/// старые. Каждый несёт личность, как в вебе (`Identity`): `shop_id`, `did`, `sid`, `segment`,
/// `stream` и `testmode=true` в тестовом режиме — у GET в адресе, у POST в теле. Без `did`
/// сервер отвечает 400, поэтому запрос ждёт конца инициализации SDK.
struct StoriesApiV3 {

    /// Кто спрашивает — поля каждого запроса v3, как `identity()` и `ajax` веба: магазин, `did`,
    /// сеанс (`sid`, без него — пустая строка), A/B-группа устройства (`segment`, неизвестна —
    /// пустая строка), поток SDK (`stream`) и тестовый режим — флаг попапов v3
    /// (`sdk.popups.testMode`, тот же, что шлёт `testmode=true` с `/init`).
    struct Identity: Equatable {
        let shopId: String
        let did: String
        let sid: String
        let segment: String
        let stream: String
        let testMode: Bool

        /// Личность запроса сейчас. Зовётся в очереди сессии SDK: сеанс берётся тот, с которым
        /// уходят запросы SDK, кончившийся — сначала продлевается (`sessionIdForRequest`).
        static func current(sdk: PersonalizationSDK, did: String) -> Identity {
            Identity(
                shopId: sdk.shopId,
                did: did,
                sid: sdk.sessionIdForRequest(),
                segment: sdk.segment,
                stream: sdk.requestStream,
                testMode: sdk.popups.testMode
            )
        }

        /// Параметры GET: `shop_id`, `did`, `sid`, `segment`, `stream`, `testmode=true` — только
        /// в тестовом режиме.
        var query: [URLQueryItem] {
            var items = [
                URLQueryItem(name: "shop_id", value: shopId),
                URLQueryItem(name: "did", value: did),
                URLQueryItem(name: "sid", value: sid),
                URLQueryItem(name: "segment", value: segment),
                URLQueryItem(name: "stream", value: stream)
            ]
            if testMode { items.append(URLQueryItem(name: "testmode", value: "true")) }
            return items
        }

        /// Поля тела POST; `segment` — у сторис, у ответов опросов его нет, как в вебе.
        func fields(segment withSegment: Bool) -> [String: Any] {
            var body: [String: Any] = ["shop_id": shopId, "did": did, "sid": sid, "stream": stream]
            if withSegment { body["segment"] = segment }
            if testMode { body["testmode"] = true }
            return body
        }
    }

    enum Event: String {
        case view, click, share
        case sharedOpen = "shared_open"
    }

    /// Хост без схемы, как `apiDomain` SDK, например `app.rees46.ru`.
    let domain: String

    /// Сколько ждать `did`, пока SDK инициализируется.
    static var deviceIdTimeout: TimeInterval = 15

    /// Отправка запроса — сессией SDK без cookies (`SdkURLSession`); подменяется в тестах.
    static var transport: (URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> Void = { request, completion in
        SdkURLSession.shared.dataTask(with: request, completionHandler: completion).resume()
    }

    // MARK: - Адреса и тело события

    func feedURL(code: String, identity: Identity) -> URL? {
        url(code: code, suffix: "", query: identity.query)
    }

    func storyURL(_ link: StoriesShareLink, identity: Identity) -> URL? {
        var query = identity.query
        if let slide = link.slideId { query.append(URLQueryItem(name: "slide_id", value: slide)) }
        return url(code: link.code, suffix: "/story/\(link.storyId)", query: query)
    }

    func eventsURL(code: String) -> URL? {
        url(code: code, suffix: "/events", query: [])
    }

    /// Тело события: личность и событие; id кампании — числом, если он числовой, как в ленте,
    /// иначе строкой; id слайда — всегда строкой (`39_0`).
    static func eventBody(identity: Identity, event: Event, storyId: String, slideId: String) -> [String: Any] {
        identity.fields(segment: true).merging([
            "event": event.rawValue,
            "story_id": Int(storyId).map { $0 as Any } ?? storyId,
            "slide_id": slideId
        ]) { _, own in own }
    }

    private func url(code: String, suffix: String, query: [URLQueryItem]) -> URL? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove("/")
        guard let block = code.addingPercentEncoding(withAllowedCharacters: allowed),
              var components = URLComponents(string: "https://\(domain)/api/v3/storefront/stories/\(block)\(suffix)") else { return nil }
        if !query.isEmpty { components.queryItems = query }
        return components.url
    }

    // MARK: - Ответ

    /// Ответ API v3 целиком — общий для GET ленты, событий и опросов. Ошибка: нет сети или
    /// таймаут, HTTP не 2xx (400, 402, 404, 429, 5xx — с `message` сервера, если он есть), не
    /// JSON-объект, `status` `fail` или `error`.
    static func response(data: Data?, response: URLResponse?, error: Error?) -> Result<[String: Any], SdkError> {
        if let error = error as? SdkError { return .failure(error) }
        if let error { return .failure(.custom(error: "Stories v3: \(error.localizedDescription)")) }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
        let message = json.flatMap { StoriesJSON.string($0["message"]) }
        guard (200..<300).contains(status) else {
            return .failure(.custom(error: "Stories v3: HTTP \(status)" + (message.map { ": \($0)" } ?? "")))
        }
        guard let json else { return .failure(.decodeError) }
        if let state = StoriesJSON.string(json["status"]), state == "fail" || state == "error" {
            return .failure(.custom(error: "Stories v3: \(message ?? state)"))
        }
        return .success(json)
    }

    /// Ответ GET: `{"status":"success","payload":{…}}` → `payload`. HTTP-ошибка, `status` не
    /// `success` (неизвестная кампания или блок — 404 JSON) и не JSON (404 HTML) — ошибка.
    static func payload(data: Data?, response: URLResponse?, error: Error?) -> Result<[String: Any], SdkError> {
        Self.response(data: data, response: response, error: error).flatMap { json in
            guard StoriesJSON.string(json["status"]) == "success", let payload = StoriesJSON.object(json["payload"]) else {
                return .failure(.custom(error: "Stories v3: \(StoriesJSON.string(json["message"]) ?? "unexpected response")"))
            }
            return .success(payload)
        }
    }

    /// Кампания по ссылке: без массива `stories` в `payload` — ошибка, как у веба.
    static func story(payload: [String: Any]) -> Result<[PersonalizationStory], SdkError> {
        guard payload["stories"] is [Any] else { return .failure(.custom(error: "Stories v3: no stories in the response")) }
        return .success(PersonalizationStory.list(json: payload, v3: true))
    }

    // MARK: - Запросы

    /// Лента блока: `payload` разбирается тем же разбором, что старая лента. Ответ — на главной очереди.
    func feed(sdk: PersonalizationSDK, code: String, completion: @escaping (Result<[PersonalizationStory], SdkError>) -> Void) {
        get(sdk: sdk, url: { feedURL(code: code, identity: $0) }) { result in
            let stories = result.map { PersonalizationStory.list(json: $0, v3: true) }
            MainThread.run { completion(stories) }
        }
    }

    /// Одна кампания по ссылке; `start_position` её сторис — слайд ссылки. Ответ — на главной очереди.
    func story(sdk: PersonalizationSDK, link: StoriesShareLink, completion: @escaping (Result<[PersonalizationStory], SdkError>) -> Void) {
        get(sdk: sdk, url: { storyURL(link, identity: $0) }) { result in
            let stories = result.flatMap { Self.story(payload: $0) }
            MainThread.run { completion(stories) }
        }
    }

    /// Событие `POST …/events`. Ответ не ждём: событие — не повод мешать просмотру.
    func track(sdk: PersonalizationSDK, code: String, event: Event, storyId: String, slideId: String) {
        // Built on the session queue: the session of the moment, renewed first when it ended.
        let body = { did in Self.eventBody(identity: .current(sdk: sdk, did: did), event: event, storyId: storyId, slideId: slideId) }
        let shopId = sdk.shopId
        post(sdk: sdk, url: eventsURL(code: code), body: body) { _, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if error != nil || !(200..<300).contains(status) {
                // The kind of the error or the HTTP code: an error's text repeats the URL and its query.
                let reason = error.map { SdkLogger.errorKind($0) } ?? "HTTP \(status)"
                SdkLogger.area(.storiesV3, .warning, "\(event.rawValue) event failed: \(reason)", shopId: shopId)
            }
        }
    }

    /// `POST` JSON на хост v3 в очереди сессии SDK, без cookies — общий для событий и опросов.
    /// Тело собирает `body` с `did`; `did` не дождались или адреса нет — ошибка без запроса.
    /// Ответ — как его отдал транспорт, на его очереди.
    func post(
        sdk: PersonalizationSDK,
        url: URL?,
        body: @escaping (String) -> [String: Any],
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) {
        sdk.sessionQueue.addOperation {
            guard let did = Self.awaitDeviceId(sdk) else {
                return completion(nil, nil, SdkError.custom(error: "Stories v3: no did, the SDK is not initialized"))
            }
            guard let url else {
                return completion(nil, nil, SdkError.custom(error: "Stories v3: bad address for the host \(domain)"))
            }
            var request = URLRequest(url: url, timeoutInterval: PersonalizationStories.loadTimeout)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpShouldHandleCookies = false
            request.httpBody = try? JSONSerialization.data(withJSONObject: body(did))
            Self.transport(request, completion)
        }
    }

    /// `GET` на хост v3 в очереди сессии SDK, без cookies: адрес собирает `url` из личности
    /// запроса (`Identity.current`).
    private func get(sdk: PersonalizationSDK, url: @escaping (Identity) -> URL?, completion: @escaping (Result<[String: Any], SdkError>) -> Void) {
        sdk.sessionQueue.addOperation {
            guard let did = Self.awaitDeviceId(sdk) else {
                return completion(.failure(.custom(error: "Stories v3: no did, the SDK is not initialized")))
            }
            guard let address = url(.current(sdk: sdk, did: did)) else {
                return completion(.failure(.custom(error: "Stories v3: bad address for the host \(domain)")))
            }
            var request = URLRequest(url: address, timeoutInterval: PersonalizationStories.loadTimeout)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpShouldHandleCookies = false
            Self.transport(request) { data, response, error in
                completion(Self.payload(data: data, response: response, error: error))
            }
        }
    }

    /// `did` SDK. До конца первой инициализации его нет — ждём в очереди сессии, не дольше
    /// `deviceIdTimeout`; не дождались — `nil`.
    static func awaitDeviceId(_ sdk: PersonalizationSDK) -> String? {
        let deadline = Date().addingTimeInterval(deviceIdTimeout)
        while sdk.deviceId.isEmpty {
            guard Date() < deadline else { return nil }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return sdk.deviceId
    }
}

extension PersonalizationSDK {

    /// Поток запросов SDK (`stream`): настроенный у SDK (`ios`, у мостов — свой); у чужих
    /// реализаций протокола — `ios`.
    var requestStream: String {
        (self as? SimplePersonalizationSDK)?.stream ?? "ios"
    }
}
