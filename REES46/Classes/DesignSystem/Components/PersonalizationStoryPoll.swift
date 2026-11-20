import UIKit

/// Опрос на слайде сторис — элемент `poll` ленты API v3 (`PersonalizationStories.apiV3Domain`):
/// мини-опрос (один вариант, несколько вариантов, свой текст) или шкала NPS / CSAT / CES.
///
/// Поведение и вид — как у JS SDK (`createPoll`): один вариант и шкала уходят по нажатию,
/// несколько вариантов и текст — кнопкой. Рисует его просмотрщик, если у него есть транспорт
/// опросов (`PersonalizationStoriesViewController.pollTransport`); без транспорта опроса нет.
@_spi(PersonalizationV3) public struct PersonalizationStoryPoll {

    /// Шкала оценки.
    public enum Scale: String, CaseIterable {
        case nps, csat, ces

        /// Оценки по умолчанию: NPS 0–10, CSAT 1–5, CES 1–7.
        public var defaultRange: ClosedRange<Int> {
            switch self {
            case .nps: return 0...10
            case .csat: return 1...5
            case .ces: return 1...7
            }
        }
    }

    public enum Kind: Equatable {
        case singleChoice
        case multipleChoice
        case text
        case scale(Scale)
    }

    public struct Option: Equatable {
        public let id: Int
        public let label: String

        public init(id: Int, label: String) {
            self.id = id
            self.label = label
        }
    }

    /// Полоса шкалы: оценка в `from...to` — после неё вопрос `question` (ответ уходит
    /// комментарием), потом текст `success`.
    public struct Band: Equatable {
        public let from: Double
        public let to: Double
        /// Вопрос после оценки; пустой или из пробелов — вопроса нет.
        public let question: String?
        public let success: String?

        public init(from: Double, to: Double, question: String? = nil, success: String?) {
            self.from = from
            self.to = to
            self.question = question
            self.success = success
        }
    }

    /// Ответ клиента: варианты, текст или оценка с комментарием. Оценка — число как пришло, и
    /// дробное (в вебе любое число — ответ); ячейка шкалы выделяется, только если оценка с ней
    /// совпала.
    public struct Answer: Equatable {
        public let optionIds: [Int]?
        public let text: String?
        public let rate: Double?
        /// Ответ на вопрос полосы шкалы.
        public let comment: String?

        public init(optionIds: [Int]? = nil, text: String? = nil, rate: Double? = nil, comment: String? = nil) {
            self.optionIds = optionIds
            self.text = text
            self.rate = rate
            self.comment = comment
        }
    }

    /// Доли ответов по вариантам — у мини-опроса с `show_results`.
    public struct Results: Equatable {
        public struct Option: Equatable {
            public let id: Int
            public let percent: Double

            public init(id: Int, percent: Double) {
                self.id = id
                self.percent = percent
            }
        }

        public let total: Int
        public let options: [Option]

        public init(total: Int, options: [Option]) {
            self.total = total
            self.options = options
        }

        /// Процент варианта целым от 0 до 100; нет в результатах — 0.
        public func percent(of id: Int) -> Int {
            let value = options.first { $0.id == id }?.percent ?? 0
            return Int(min(max(value, 0), 100).rounded())
        }
    }

    /// Ответ транспорта на отправку: `answer` и `results` из `payload`, если сервер их прислал.
    public struct Reply: Equatable {
        public let answer: Answer?
        public let results: Results?

        public init(answer: Answer? = nil, results: Results? = nil) {
            self.answer = answer
            self.results = results
        }
    }

    /// Строки элемента (`labels` из ленты): важнее текстов хоста.
    public struct Labels: Equatable {
        public let reanswer: String?
        public let error: String?
        public let submit: String?

        public init(reanswer: String? = nil, error: String? = nil, submit: String? = nil) {
            self.reanswer = reanswer
            self.error = error
            self.submit = submit
        }
    }

    public let kind: Kind
    /// Код опроса (мини-опрос) или кампании (шкала); пустой — в ленте его нет.
    public let code: String
    public let question: String?
    /// Подсказка в поле текстового опроса.
    public let placeholder: String?
    /// Предел длины текста; `nil` — без предела и без счётчика.
    public let maxLength: Int?
    /// Подпись кнопки отправки; `nil` — текст хоста.
    public let submitLabel: String?
    /// Благодарность под отвеченным мини-опросом.
    public let thanksText: String?
    public let showResults: Bool
    public let options: [Option]
    /// Канал оценки шкалы; `nil` — `stories`.
    public let channel: String?
    public let rateMin: Int?
    public let rateMax: Int?
    public let bands: [Band]
    /// Верх карточки в процентах высоты слайда, как у текстовых блоков; `nil` — под шапкой.
    public let yOffset: CGFloat?
    /// В отвеченном опросе есть ссылка «ответить заново».
    public let allowReanswer: Bool
    /// Ответ из ленты; ответ этого запуска важнее (см. `StoryPollStore`).
    public let answer: Answer?
    public let results: Results?
    public let labels: Labels

    public init(
        kind: Kind,
        code: String,
        question: String? = nil,
        placeholder: String? = nil,
        maxLength: Int? = nil,
        submitLabel: String? = nil,
        thanksText: String? = nil,
        showResults: Bool = false,
        options: [Option] = [],
        channel: String? = nil,
        rateMin: Int? = nil,
        rateMax: Int? = nil,
        bands: [Band] = [],
        yOffset: CGFloat? = nil,
        allowReanswer: Bool = false,
        answer: Answer? = nil,
        results: Results? = nil,
        labels: Labels = Labels()
    ) {
        self.kind = kind
        self.code = code
        self.question = question
        self.placeholder = placeholder
        self.maxLength = maxLength.flatMap { $0 > 0 ? $0 : nil }
        self.submitLabel = submitLabel
        self.thanksText = thanksText
        self.showResults = showResults
        self.options = options
        self.channel = channel
        self.rateMin = rateMin
        self.rateMax = rateMax
        self.bands = bands
        self.yOffset = yOffset
        self.allowReanswer = allowReanswer
        self.answer = answer
        self.results = results
        self.labels = labels
    }
}

// MARK: - Правила опроса

extension PersonalizationStoryPoll {

    /// `poll_type` ленты: `mini_poll`, `nps`, `csat` или `ces`.
    public var pollType: String {
        if case .scale(let scale) = kind { return scale.rawValue }
        return "mini_poll"
    }

    public var scale: Scale? {
        if case .scale(let scale) = kind { return scale }
        return nil
    }

    /// Отвечен: есть варианты, непустой текст или любая числовая оценка.
    public static func hasAnswer(_ answer: Answer?) -> Bool {
        guard let answer else { return false }
        return !(answer.optionIds ?? []).isEmpty || !(answer.text ?? "").isEmpty || answer.rate != nil
    }

    /// Оценки шкалы `rateMin...rateMax`, без них — по умолчанию; не больше 21 значения,
    /// `min > max` — пусто.
    public static func scaleRange(_ scale: Scale, min: Int?, max: Int?) -> [Int] {
        let low = min ?? scale.defaultRange.lowerBound
        let high = max ?? scale.defaultRange.upperBound
        guard low <= high else { return [] }
        return Array(low...Swift.min(high, low + 20))
    }

    /// Оценки этой шкалы; у мини-опроса — пусто.
    public var scaleValues: [Int] {
        scale.map { Self.scaleRange($0, min: rateMin, max: rateMax) } ?? []
    }

    /// Тон ячейки шкалы — от плохой оценки к хорошей, как цвета ячеек в вебе (красный →
    /// оранжевый и жёлтый → зелёный); цвета — семантические кита.
    public enum Tone: Equatable {
        case negative, neutral, positive
    }

    /// Тон ячейки, как `scaleColor` веба: NPS 0–10 — 0–2 красные, 3–8 оранжевые и жёлтые,
    /// 9–10 зелёные; прочие шкалы — по третям диапазона.
    public static func scaleTone(_ scale: Scale, value: Int, min: Int, max: Int) -> Tone {
        if scale == .nps, min == 0, max == 10 {
            if value <= 2 { return .negative }
            return value <= 8 ? .neutral : .positive
        }
        let position = max > min ? Double(value - min) / Double(max - min) : 1
        return position < 0.34 ? .negative : (position < 0.68 ? .neutral : .positive)
    }

    /// Тон ячейки этой шкалы.
    func tone(of value: Int) -> Tone {
        let values = scaleValues
        guard let scale, let low = values.first, let high = values.last else { return .neutral }
        return Self.scaleTone(scale, value: value, min: low, max: high)
    }

    /// Первая полоса, в которую попала оценка, как `findBand` веба; без оценки или мимо — `nil`.
    public func band(rate: Double?) -> Band? {
        guard let rate else { return nil }
        return bands.first { rate >= $0.from && rate <= $0.to }
    }

    /// Текст `success` полосы оценки; без оценки, мимо полос или у полосы нет текста — `nil`.
    public func bandText(rate: Double?) -> String? {
        guard let success = band(rate: rate)?.success, !success.isEmpty else { return nil }
        return success
    }

    /// Вопрос полосы оценки без пробелов по краям, как `bandQuestion` веба; пустой — `nil`.
    public func bandQuestion(rate: Double?) -> String? {
        guard let question = band(rate: rate)?.question?.trimmingCharacters(in: .whitespacesAndNewlines),
              !question.isEmpty else { return nil }
        return question
    }

    /// Предел длины комментария к вопросу полосы, как `COMMENT_MAX_LENGTH` веба.
    public static let commentMaxLength = 5000
}

/// Тексты карточки опроса: `labels` элемента, потом тексты хоста (`PersonalizationStoriesTexts`),
/// потом свои по первому языку устройства — русские или английские. Перекрывает только непустая
/// строка. Кнопка комментария после оценки — та же подпись отправки: в русском интерфейсе без
/// своих текстов она «Отправить», а не английская.
struct StoryPollTexts: Equatable {

    enum Language: Equatable {
        case ru, en

        /// По первому языку устройства.
        static var current: Language {
            (Locale.preferredLanguages.first ?? "").lowercased().hasPrefix("ru") ? .ru : .en
        }
    }

    var reanswer: String
    var error: String
    var submit: String
    let language: Language

    init(host: PersonalizationStoriesTexts, labels: PersonalizationStoryPoll.Labels, language: Language = .current) {
        func pick(_ own: String?, _ host: String, _ fallback: String) -> String {
            [own, host].lazy.compactMap { $0 }.first { !$0.isEmpty } ?? fallback
        }
        let ru = language == .ru
        reanswer = pick(labels.reanswer, host.pollReanswerText, ru ? "Ответить заново" : "Answer again")
        error = pick(labels.error, host.pollErrorText, ru ? "Не удалось отправить ответ. Попробуйте еще раз" : "Failed to send the answer. Please try again")
        submit = pick(labels.submit, host.pollSubmitText, ru ? "Отправить" : "Send")
        self.language = language
    }
}

// MARK: - Транспорт

/// Отправка ответов опросов. Виджет `PersonalizationStories` даёт просмотрщику клиент API v3
/// (`POST /api/v3/polls/...` на хосте ленты); тесты и офлайн-демо подменяют его своим.
///
/// `body` — поля опроса без личности запроса (`shop_id`, `did`, `sid`, `stream`, `testmode`): её
/// добавляет сам транспорт (`sid` — всегда, без сеанса пустой строкой).
/// - мини-опрос: `{option_ids: [Int]}` или `{text: String}`;
/// - шкала: `{channel, category (NPS) | campaign (CSAT, CES), rate}`, с комментарием к вопросу
///   полосы — та же оценка и `comment`;
/// - у обоих источник ответа, как в вебе: `source_type: "stories"`, `source_id` (id сторис) и
///   `source_item_id` (id слайда) — строками; без id сторис источника нет.
///
/// `completion` — один раз, на любой очереди: успех с `answer` / `results` из `payload` или ошибка.
@_spi(PersonalizationV3) public protocol PersonalizationStoryPollTransport {
    func answerMiniPoll(
        code: String,
        body: [String: Any],
        completion: @escaping (Result<PersonalizationStoryPoll.Reply, Error>) -> Void
    )
    func review(
        kind: PersonalizationStoryPoll.Scale,
        body: [String: Any],
        completion: @escaping (Result<PersonalizationStoryPoll.Reply, Error>) -> Void
    )
}

// MARK: - Сохранённые ответы

/// Ответы опросов, как `storage.ts` веба: отправленные за этот запуск и сохранённые на устройстве.
///
/// - Запись устройства — в хранилище магазина (раздел SDK, где и просмотренные слайды) под
///   ключом `stories_poll_{did}_{poll_type}_{code}_{id сторис}_{id слайда}`: JSON `{answer,
///   results, saved_at}` (`saved_at` — миллисекунды). Живёт 90 дней — столько ответ помнит лента;
///   просроченная или без даты удаляется при чтении. Без `did` ничего не читается и не пишется:
///   чужой ответ не показывается.
/// - Ответ этого запуска (в памяти) — то, чем в вебе становится закешированный элемент ленты
///   после отправки: лента не перегружается, и вернувшийся к слайду видит свой ответ.
///
/// Что показать: ответ этого запуска, иначе ответ ленты, иначе запись устройства, иначе ничего.
/// Только главная очередь.
final class StoryPollStore {

    struct Entry: Equatable {
        let answer: PersonalizationStoryPoll.Answer?
        let results: PersonalizationStoryPoll.Results?
    }

    /// Чей ответ и где: магазин, устройство, опрос и слайд.
    struct Place: Hashable {
        let shopId: String
        let did: String
        let pollType: String
        let code: String
        let storyId: String
        let slideId: String

        init(shopId: String, did: String, poll: PersonalizationStoryPoll, storyId: String, slideId: String) {
            self.shopId = shopId
            self.did = did
            self.pollType = poll.pollType
            self.code = poll.code
            self.storyId = storyId
            self.slideId = slideId
        }

        /// Ключ записи устройства; без `did` — `nil`.
        var key: String? {
            guard !did.isEmpty else { return nil }
            return ["stories_poll", did, pollType, code, storyId, slideId].joined(separator: "_")
        }
    }

    /// Сколько живёт запись устройства: столько ответ помнит лента (`STORIES_ANSWER_MEMORY_DAYS`).
    static let ttl: TimeInterval = 90 * 24 * 60 * 60

    static let shared = StoryPollStore()

    /// Часы записи устройства; подменяются в тестах.
    var now: () -> Date = Date.init

    private var sent: [Place: Entry] = [:]

    /// Ответ, отправленный за этот запуск.
    func sentEntry(_ place: Place) -> Entry? {
        sent[place]
    }

    /// Запись устройства: просроченная, без даты или битая удаляется, без `did` — `nil`.
    func savedEntry(_ place: Place, in defaults: UserDefaults?) -> Entry? {
        guard let key = place.key, let defaults, let raw = defaults.string(forKey: key) else { return nil }
        guard let record = (try? JSONSerialization.jsonObject(with: Data(raw.utf8))) as? [String: Any],
              let answer = PersonalizationStoryPoll.Answer(json: record["answer"]) else { return nil }
        guard let savedAt = StoriesJSON.number(record["saved_at"]),
              now().timeIntervalSince1970 * 1000 - savedAt <= Self.ttl * 1000 else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return Entry(answer: answer, results: PersonalizationStoryPoll.Results(json: record["results"]))
    }

    /// Ответ ушёл: в память запуска и, с `did`, на устройство.
    func save(_ entry: Entry, place: Place, in defaults: UserDefaults?) {
        sent[place] = entry
        guard let key = place.key, let defaults else { return }
        var record: [String: Any] = ["saved_at": (now().timeIntervalSince1970 * 1000).rounded()]
        record["answer"] = entry.answer?.json ?? [String: Any]()
        record["results"] = entry.results?.json ?? NSNull()
        guard let data = try? JSONSerialization.data(withJSONObject: record),
              let text = String(data: data, encoding: .utf8) else { return }
        defaults.set(text, forKey: key)
    }

    /// Забыть ответы этого запуска (записи устройства остаются).
    func removeAll() {
        sent = [:]
    }
}

extension PersonalizationStoryPoll.Answer {

    /// JSON ответа, как его шлёт лента: только заданные поля.
    var json: [String: Any] {
        var json: [String: Any] = [:]
        if let optionIds { json["option_ids"] = optionIds }
        if let text { json["text"] = text }
        if let rate { json["rate"] = rate }
        if let comment { json["comment"] = comment }
        return json
    }
}

extension PersonalizationStoryPoll.Results {

    /// JSON итогов, как их шлёт лента.
    var json: [String: Any] {
        ["total": total, "options": options.map { ["id": $0.id, "percent": $0.percent] as [String: Any] }]
    }
}
