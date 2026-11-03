import UIKit

// Опросы на слайдах сторис V2 — только лента API v3 (`apiV3Domain`). Разбор элемента `poll`
// терпимый: числа бывают строками, необязательные поля — `null`, битый элемент пропускается,
// слайд показывается без опроса. Тексты — как есть, без обрезки пробелов: строка из пробелов
// тоже текст, как в вебе. Ответы уходят на тот же хост, что и лента:
//
//   POST https://<host>/api/v3/polls/mini_polls/<code>/answers   {shop_id, did, sid, story_id, slide_id, option_ids | text}
//   POST https://<host>/api/v3/polls/<nps|csat|ces>/reviews      {shop_id, did, sid, channel, category | campaign, rate}

extension PersonalizationStoryPoll {

    /// Элемент `poll` слайда. Неизвестный `poll_type` или вид мини-опроса, нет объекта `poll` —
    /// `nil` и строка в debug-лог; `poll_type` и `kind` сравниваются как есть, без обрезки и с
    /// учётом регистра. Код не обязателен, как в вебе: без него — пустой, карточка рисуется, а
    /// ответ сервер отклонит, и карточка покажет ошибку.
    init?(json: [String: Any]) {
        let type = json["poll_type"] as? String ?? ""
        guard let body = StoriesJSON.object(json["poll"]) else {
            Self.skip("poll \(type) without a poll object")
            return nil
        }
        let code = Self.text(body["code"]) ?? ""
        let kind: Kind
        if let scale = Scale(rawValue: type) {
            kind = .scale(scale)
        } else if type == "mini_poll" {
            switch body["kind"] as? String {
            case "single_choice": kind = .singleChoice
            case "multiple_choice": kind = .multipleChoice
            case "text": kind = .text
            case let other:
                Self.skip("mini poll \(code) of an unknown kind \(other ?? "nil")")
                return nil
            }
        } else {
            Self.skip("poll \(code) of an unknown type \(type)")
            return nil
        }
        let labels = StoriesJSON.object(json["labels"])
        self.init(
            kind: kind,
            code: code,
            question: Self.text(body["question"]),
            placeholder: Self.text(body["placeholder"]),
            maxLength: StoriesJSON.number(body["max_length"]).flatMap { $0.isFinite && abs($0) < 1e15 ? Int($0) : nil },
            submitLabel: Self.text(body["submit_label"]),
            thanksText: Self.text(body["thanks_text"]),
            showResults: Self.flag(body["show_results"]),
            // Вариант без подписи остаётся — пустой, как в вебе; без целого id — пропускается.
            options: StoriesJSON.objects(body["options"]).compactMap { option in
                Self.int(option["id"]).map { Option(id: $0, label: Self.text(option["label"]) ?? "") }
            },
            channel: Self.text(body["channel"]),
            rateMin: Self.int(body["rate_min"]),
            rateMax: Self.int(body["rate_max"]),
            bands: StoriesJSON.objects(body["bands"]).compactMap { band in
                guard let from = StoriesJSON.number(band["from"]), let to = StoriesJSON.number(band["to"]) else { return nil }
                return Band(from: from, to: to, success: Self.text(band["success"]))
            },
            yOffset: StoriesJSON.number(json["y_offset"]).map { CGFloat($0) },
            allowReanswer: Self.flag(json["allow_reanswer"]),
            answer: Answer(json: json["answer"]),
            results: Results(json: json["results"]),
            labels: Labels(
                reanswer: Self.label(labels?["reanswer"]),
                error: Self.label(labels?["error"]),
                submit: Self.label(labels?["submit"])
            )
        )
    }

    /// Целое из числа или строки (`"120"`); дробное, нечисло и заведомо не id — `nil`.
    static func int(_ value: Any?) -> Int? {
        StoriesJSON.number(value).flatMap { $0.isFinite && $0 == $0.rounded() && abs($0) < 1e15 ? Int($0) : nil }
    }

    /// Текст как есть: строка длиной больше нуля (из пробелов — тоже) или запись числа; пустая
    /// строка, `null` и прочее — `nil`.
    static func text(_ value: Any?) -> String? {
        switch value {
        case let text as String: return text.isEmpty ? nil : text
        case let number as NSNumber where !(number === kCFBooleanTrue || number === kCFBooleanFalse): return number.stringValue
        default: return nil
        }
    }

    /// `allow_reanswer`, `show_results`: истина — только `true`, число `1` и строка `"true"`; прочее
    /// (`"1"`, `"TRUE"`, `2`, `null`) — ложь.
    static func flag(_ value: Any?) -> Bool {
        switch value {
        case let number as NSNumber: return number.doubleValue == 1
        case let text as String: return text == "true"
        default: return false
        }
    }

    /// Строка `labels`: только непустая строка, как в вебе; прочее — текст хоста.
    static func label(_ value: Any?) -> String? {
        guard let text = value as? String, !text.isEmpty else { return nil }
        return text
    }

    private static func skip(_ reason: String) {
        #if DEBUG
        print("Stories v3: \(reason) is skipped")
        #endif
    }
}

extension PersonalizationStoryPoll.Answer {

    /// `answer` ленты или ответа сервера; не объект — `nil`.
    init?(json: Any?) {
        guard let object = StoriesJSON.object(json) else { return nil }
        self.init(
            optionIds: (object["option_ids"] as? [Any])?.compactMap { PersonalizationStoryPoll.int($0) },
            // Текст — как есть: отвечен и ответ из одних пробелов, как в вебе. Оценка — любое
            // число, и дробное: отвечено, хоть ячейки под ним и нет.
            text: object["text"] as? String,
            rate: StoriesJSON.number(object["rate"]).flatMap { $0.isFinite ? $0 : nil }
        )
    }
}

extension PersonalizationStoryPoll.Results {

    /// `results` ленты или ответа сервера; не объект или `options` не массив — `nil`, и
    /// процентов нет: у варианта без строки в массиве — 0%, без массива — ничего.
    init?(json: Any?) {
        guard let object = StoriesJSON.object(json), let options = object["options"] as? [Any] else { return nil }
        self.init(
            total: PersonalizationStoryPoll.int(object["total"]) ?? 0,
            options: options.compactMap { StoriesJSON.object($0) }.compactMap { option in
                guard let id = PersonalizationStoryPoll.int(option["id"]) else { return nil }
                return Option(id: id, percent: StoriesJSON.number(option["percent"]) ?? 0)
            }
        )
    }
}

extension StoriesApiV3 {

    /// `https://<host>/api/v3/polls/<path>`.
    func pollsURL(_ path: String) -> URL? {
        URL(string: "https://\(domain)/api/v3/polls/\(path)")
    }

    /// Код опроса — один сегмент пути, как `encodeURIComponent`.
    static func pathSegment(_ value: String) -> String {
        let unreserved = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
        return value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
    }
}

/// Клиент опросов API v3 — транспорт опросов просмотрщика по умолчанию у виджета, `show` и
/// `handleLink`. Тот же хост, `did` и `URLSession`, что у ленты (`StoriesApiV3.post`); к телу
/// добавляются `shop_id`, `did` и `sid` сеанса SDK (без сеанса — пустая строка, как в вебе).
/// Ответ — на главной очереди; ошибка — в debug-лог с кодом и `message` сервера.
struct StoriesPollsApi: PersonalizationStoryPollTransport {

    let api: StoriesApiV3
    let sdk: PersonalizationSDK

    func answerMiniPoll(
        code: String,
        body: [String: Any],
        completion: @escaping (Result<PersonalizationStoryPoll.Reply, Error>) -> Void
    ) {
        let url = api.pollsURL("mini_polls/\(StoriesApiV3.pathSegment(code))/answers")
        post(url: url, body: body, what: "mini poll \(code)", completion: completion) { payload in
            PersonalizationStoryPoll.Reply(
                answer: PersonalizationStoryPoll.Answer(json: payload["answer"]),
                results: PersonalizationStoryPoll.Results(json: payload["results"])
            )
        }
    }

    func review(
        kind: PersonalizationStoryPoll.Scale,
        body: [String: Any],
        completion: @escaping (Result<PersonalizationStoryPoll.Reply, Error>) -> Void
    ) {
        post(url: api.pollsURL("\(kind.rawValue)/reviews"), body: body, what: "\(kind.rawValue) review", completion: completion) { _ in
            PersonalizationStoryPoll.Reply()
        }
    }

    /// `shop_id`, `did` и `sid` — все три всегда, пустые тоже.
    static func identity(shopId: String, did: String, sid: String) -> [String: Any] {
        ["shop_id": shopId, "did": did, "sid": sid]
    }

    private func post(
        url: URL?,
        body: [String: Any],
        what: String,
        completion: @escaping (Result<PersonalizationStoryPoll.Reply, Error>) -> Void,
        reply: @escaping ([String: Any]) -> PersonalizationStoryPoll.Reply
    ) {
        let sdk = self.sdk
        let fields = { (did: String) in
            Self.identity(shopId: sdk.shopId, did: did, sid: sdk.userSeance).merging(body) { _, own in own }
        }
        api.post(sdk: sdk, url: url, body: fields) { data, response, error in
            let result = StoriesApiV3.response(data: data, response: response, error: error)
                .map { reply(StoriesJSON.object($0["payload"]) ?? [:]) }
            #if DEBUG
            if case .failure(let failure) = result { print("Stories v3: \(what) failed: \(failure)") }
            #endif
            MainThread.run { completion(result.mapError { $0 }) }
        }
    }
}
