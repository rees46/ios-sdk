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

    /// Полоса шкалы: текст `success` — под отвеченной шкалой, если оценка в `from...to`.
    public struct Band: Equatable {
        public let from: Double
        public let to: Double
        public let success: String?

        public init(from: Double, to: Double, success: String?) {
            self.from = from
            self.to = to
            self.success = success
        }
    }

    /// Ответ клиента: варианты, текст или оценка. Оценка — число как пришло, и дробное (в вебе
    /// любое число — ответ); ячейка шкалы выделяется, только если оценка с ней совпала.
    public struct Answer: Equatable {
        public let optionIds: [Int]?
        public let text: String?
        public let rate: Double?

        public init(optionIds: [Int]? = nil, text: String? = nil, rate: Double? = nil) {
            self.optionIds = optionIds
            self.text = text
            self.rate = rate
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

    private static let npsColors = ["#FCA5A5", "#FCA5A5", "#FCA5A5", "#FDBA74", "#FDBA74", "#FDBA74", "#FCD34D"]

    /// Цвет ячейки: NPS 0–10 — критики красные и оранжевые, нейтральные жёлтые, промоутеры
    /// зелёные; прочие шкалы — по третям диапазона.
    public static func scaleColor(_ scale: Scale, value: Int, min: Int, max: Int) -> String {
        if scale == .nps, min == 0, max == 10 {
            if (0...6).contains(value) { return npsColors[value] }
            return value <= 8 ? "#FDE68A" : "#86EFAC"
        }
        let position = max > min ? Double(value - min) / Double(max - min) : 1
        return position < 0.34 ? "#FCA5A5" : (position < 0.68 ? "#FDE68A" : "#86EFAC")
    }

    /// Заливка выбранной оценки: попала в одну из полос `bands` — цвет шкалы для этой оценки
    /// (`scaleColor`: критики, нейтральные, довольные); без полос или мимо них — `nil`, карточка
    /// берёт акцент.
    func bandColor(of value: Int) -> String? {
        let values = scaleValues
        guard let scale, let low = values.first, let high = values.last,
              bands.contains(where: { Double(value) >= $0.from && Double(value) <= $0.to }) else { return nil }
        return Self.scaleColor(scale, value: value, min: low, max: high)
    }

    /// Текст `success` первой полосы, в которую попала оценка; без оценки, мимо полос или у
    /// полосы нет текста — `nil`.
    public func bandText(rate: Double?) -> String? {
        guard let rate else { return nil }
        guard let success = bands.first(where: { rate >= $0.from && rate <= $0.to })?.success, !success.isEmpty else { return nil }
        return success
    }
}

/// Тексты карточки опроса: умолчания < тексты хоста (`PersonalizationStoriesTexts`) < `labels`
/// элемента. Перекрывает только непустая строка.
///
/// Шапка и подвал итогов («Результаты», «Спасибо! Голос учтён», число голосов) — свои, по
/// первому языку устройства: русские или английские.
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
        let defaults = PersonalizationStoriesTexts()
        func pick(_ own: String?, _ host: String, _ fallback: String) -> String {
            [own, host].lazy.compactMap { $0 }.first { !$0.isEmpty } ?? fallback
        }
        reanswer = pick(labels.reanswer, host.pollReanswerText, defaults.pollReanswerText)
        error = pick(labels.error, host.pollErrorText, defaults.pollErrorText)
        submit = pick(labels.submit, host.pollSubmitText, defaults.pollSubmitText)
        self.language = language
    }

    /// Шапка итогов опроса с выбором (на карточке — прописными).
    var results: String {
        language == .ru ? "Результаты" : "Results"
    }

    /// Подвал итогов без своего `thanks_text`: «Спасибо!» и за ним «Голос учтён».
    var thanks: String {
        language == .ru ? "Спасибо!" : "Thank you!"
    }

    var voteCounted: String {
        language == .ru ? "Голос учтён" : "Vote counted"
    }

    /// Число голосов с разрядами и склонением: «1 голос», «3 голоса», «1 248 голосов»;
    /// «1 vote», «1,248 votes».
    func votes(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        // Разделитель свой, а не из локали: у русского — неразрывный пробел на любой системе.
        formatter.groupingSeparator = language == .ru ? "\u{00A0}" : ","
        let number = formatter.string(from: NSNumber(value: count)) ?? String(count)
        switch language {
        case .ru:
            let tens = count % 100, ones = count % 10
            let word = ones == 1 && tens != 11 ? "голос"
                : (2...4).contains(ones) && !(12...14).contains(tens) ? "голоса" : "голосов"
            return "\(number) \(word)"
        case .en:
            return "\(number) \(count == 1 ? "vote" : "votes")"
        }
    }
}

// MARK: - Транспорт

/// Отправка ответов опросов. Виджет `PersonalizationStories` даёт просмотрщику клиент API v3
/// (`POST /api/v3/polls/...` на хосте ленты); тесты и офлайн-демо подменяют его своим.
///
/// `body` — поля опроса без `shop_id`, `did` и `sid`: их добавляет сам транспорт (`sid` —
/// всегда, без сеанса пустой строкой).
/// - мини-опрос: `{option_ids: [Int]}` или `{text: String}`, плюс `story_id` (число) и
///   `slide_id` (всегда строка);
/// - шкала: `{channel, category (NPS) | campaign (CSAT, CES), rate}`.
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

// MARK: - Ответы этого запуска

/// Ответы опросов, отправленные за этот запуск: одни на все виджеты, `show` и ссылки, по
/// магазину, виду и коду опроса. Важнее ответа из ленты: лента не перегружается после ответа,
/// и вернувшийся к слайду должен увидеть свой ответ. На диск не пишутся. Только главная очередь.
final class StoryPollStore {

    struct Entry: Equatable {
        let answer: PersonalizationStoryPoll.Answer?
        let results: PersonalizationStoryPoll.Results?
    }

    private struct Key: Hashable {
        let shopId: String
        let type: String
        let code: String
    }

    static let shared = StoryPollStore()

    private var entries: [Key: Entry] = [:]

    func entry(shopId: String, poll: PersonalizationStoryPoll) -> Entry? {
        entries[Key(shopId: shopId, type: poll.pollType, code: poll.code)]
    }

    func save(_ entry: Entry, shopId: String, poll: PersonalizationStoryPoll) {
        entries[Key(shopId: shopId, type: poll.pollType, code: poll.code)] = entry
    }

    func removeAll() {
        entries = [:]
    }
}
