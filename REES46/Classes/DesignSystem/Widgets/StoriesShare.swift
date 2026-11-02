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
/// Протокол SDK не расширяется: запросы идут своим `URLSession` с `shopId` и `deviceId` SDK,
/// в его очереди сессии, как и старые. Без `did` сервер отвечает 400, поэтому запрос ждёт
/// конца инициализации SDK; `sid` не нужен.
struct StoriesApiV3 {

    enum Event: String {
        case view, click, share
        case sharedOpen = "shared_open"
    }

    /// Хост без схемы, как `apiDomain` SDK, например `app.rees46.ru`.
    let domain: String

    /// Сколько ждать `did`, пока SDK инициализируется.
    static var deviceIdTimeout: TimeInterval = 15

    /// Отправка запроса; подменяется в тестах.
    static var transport: (URLRequest, @escaping (Data?, URLResponse?, Error?) -> Void) -> Void = { request, completion in
        URLSession.shared.dataTask(with: request, completionHandler: completion).resume()
    }

    // MARK: - Адреса и тело события

    func feedURL(code: String, shopId: String, did: String) -> URL? {
        url(code: code, suffix: "", query: Self.identity(shopId: shopId, did: did))
    }

    func storyURL(_ link: StoriesShareLink, shopId: String, did: String) -> URL? {
        var query = Self.identity(shopId: shopId, did: did)
        if let slide = link.slideId { query.append(URLQueryItem(name: "slide_id", value: slide)) }
        return url(code: link.code, suffix: "/story/\(link.storyId)", query: query)
    }

    func eventsURL(code: String) -> URL? {
        url(code: code, suffix: "/events", query: [])
    }

    /// Тело события: id кампании — числом, как в ленте; id слайда — всегда строкой (`39_0`).
    static func eventBody(shopId: String, did: String, event: Event, storyId: String, slideId: String) -> [String: Any] {
        [
            "shop_id": shopId,
            "did": did,
            "event": event.rawValue,
            "story_id": Int(storyId).map { $0 as Any } ?? storyId,
            "slide_id": slideId
        ]
    }

    private static func identity(shopId: String, did: String) -> [URLQueryItem] {
        [URLQueryItem(name: "shop_id", value: shopId), URLQueryItem(name: "did", value: did)]
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

    /// Ответ GET: `{"status":"success","payload":{…}}` → `payload`. HTTP-ошибка, `status` не
    /// `success` (неизвестная кампания или блок — 404 JSON) и не JSON (404 HTML) — ошибка.
    static func payload(data: Data?, response: URLResponse?, error: Error?) -> Result<[String: Any], SdkError> {
        if let error { return .failure(.custom(error: "Stories v3: \(error.localizedDescription)")) }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { return .failure(.custom(error: "Stories v3: HTTP \(status)")) }
        guard let data, let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .failure(.decodeError)
        }
        guard StoriesJSON.string(json["status"]) == "success", let payload = StoriesJSON.object(json["payload"]) else {
            return .failure(.custom(error: "Stories v3: \(StoriesJSON.string(json["message"]) ?? "unexpected response")"))
        }
        return .success(payload)
    }

    /// Кампания по ссылке: без массива `stories` в `payload` — ошибка, как у веба.
    static func story(payload: [String: Any]) -> Result<[PersonalizationStory], SdkError> {
        guard payload["stories"] is [Any] else { return .failure(.custom(error: "Stories v3: no stories in the response")) }
        return .success(PersonalizationStory.list(json: payload))
    }

    // MARK: - Запросы

    /// Лента блока: `payload` разбирается тем же разбором, что старая лента. Ответ — на главной очереди.
    func feed(sdk: PersonalizationSDK, code: String, completion: @escaping (Result<[PersonalizationStory], SdkError>) -> Void) {
        get(sdk: sdk, url: { feedURL(code: code, shopId: sdk.shopId, did: $0) }) { result in
            let stories = result.map { PersonalizationStory.list(json: $0) }
            MainThread.run { completion(stories) }
        }
    }

    /// Одна кампания по ссылке; `start_position` её сторис — слайд ссылки. Ответ — на главной очереди.
    func story(sdk: PersonalizationSDK, link: StoriesShareLink, completion: @escaping (Result<[PersonalizationStory], SdkError>) -> Void) {
        get(sdk: sdk, url: { storyURL(link, shopId: sdk.shopId, did: $0) }) { result in
            let stories = result.flatMap { Self.story(payload: $0) }
            MainThread.run { completion(stories) }
        }
    }

    /// Событие `POST …/events`. Ответ не ждём: событие — не повод мешать просмотру.
    func track(sdk: PersonalizationSDK, code: String, event: Event, storyId: String, slideId: String) {
        sdk.sessionQueue.addOperation {
            guard let did = Self.awaitDeviceId(sdk), let address = eventsURL(code: code) else { return }
            var request = URLRequest(url: address, timeoutInterval: PersonalizationStories.loadTimeout)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = Self.eventBody(shopId: sdk.shopId, did: did, event: event, storyId: storyId, slideId: slideId)
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            Self.transport(request) { _, response, error in
                #if DEBUG
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if error != nil || !(200..<300).contains(status) {
                    print("Stories v3: \(event.rawValue) event failed (\(error.map { "\($0)" } ?? "HTTP \(status)"))")
                }
                #endif
            }
        }
    }

    private func get(sdk: PersonalizationSDK, url: @escaping (String) -> URL?, completion: @escaping (Result<[String: Any], SdkError>) -> Void) {
        sdk.sessionQueue.addOperation {
            guard let did = Self.awaitDeviceId(sdk) else {
                return completion(.failure(.custom(error: "Stories v3: no did, the SDK is not initialized")))
            }
            guard let address = url(did) else {
                return completion(.failure(.custom(error: "Stories v3: bad address for the host \(domain)")))
            }
            var request = URLRequest(url: address, timeoutInterval: PersonalizationStories.loadTimeout)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
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
