import Foundation

/// Логика карточки опроса без UI — как `createPoll` JS SDK: форма и отвеченное состояние,
/// отправка через транспорт, ошибка с повтором, переответ, вопрос полосы шкалы и удержание слайда.
///
/// Ответ при показе — по `StoryPollStore`: отправленный за этот запуск, иначе из ленты, иначе
/// сохранённый на устройстве. Отправленный пишется туда же — и в память, и на устройство.
///
/// Шкала: после оценки, если у её полосы есть вопрос, а комментария ещё нет, — вопрос, поле
/// (до 5000 символов) и кнопка; комментарий уходит вторым отзывом с той же оценкой. Без вопроса
/// — сразу текст полосы. Ушли со слайда без комментария — на следующем показе вопрос снова.
///
/// Слайд держится (`onHold(true)`), пока карточку трогают, в её поле курсор или ответ
/// отправляется: `hold = pressed || focused || sending`. Карточка ушла с экрана
/// (`detach`) — ни перерисовки, ни удержания: ответ, пришедший после, попадает только в
/// `StoryPollStore` и в само состояние, которое вернувшаяся карточка покажет (`attach`).
final class StoryPollController {

    enum Mode: Equatable {
        case form, answered
    }

    /// Что перерисовать: всё (сменился вид) или только выделение, доступность и ошибку.
    enum Change {
        case rebuild, update
    }

    let poll: PersonalizationStoryPoll
    let storyId: String
    let slideId: String
    let shopId: String
    let texts: StoryPollTexts
    /// Где лежат ответы опроса: память запуска и запись устройства под `did` показа.
    let place: StoryPollStore.Place
    private let transport: PersonalizationStoryPollTransport
    private let store: StoryPollStore
    private let defaults: UserDefaults?

    private(set) var answer: PersonalizationStoryPoll.Answer?
    private(set) var results: PersonalizationStoryPoll.Results?
    private(set) var mode: Mode
    private(set) var isSending = false
    private(set) var showsError = false
    /// Выделенные варианты формы: нажатый вариант одного выбора или включённые чипы.
    private(set) var selected: Set<Int> = []
    /// Нажатая ячейка шкалы в форме (или прежняя оценка при переответе).
    private(set) var pressedRate: Double?
    /// Текст поля, уже обрезанный до `maxLength`.
    private(set) var text = ""
    /// Комментарий к вопросу полосы шкалы, уже обрезанный до 5000.
    private(set) var comment = ""
    /// Форма открыта ссылкой «ответить заново»: поле текста получает фокус.
    private(set) var isReanswering = false

    /// Палец на карточке.
    var isPressed = false {
        didSet { syncHold() }
    }
    /// Курсор в поле карточки.
    var isFocused = false {
        didSet { syncHold() }
    }
    private(set) var isAttached = true
    private var reportedHold = false
    private var pending: Change?

    var onHold: ((Bool) -> Void)?
    var onChange: ((Change) -> Void)?

    /// - Parameters:
    ///   - did: устройство показа; пустой — ответ на устройстве не читается и не пишется.
    ///   - defaults: хранилище магазина для записи устройства; `nil` — только память запуска.
    init(
        poll: PersonalizationStoryPoll,
        storyId: String,
        slideId: String,
        shopId: String,
        did: String = "",
        texts: StoryPollTexts,
        transport: PersonalizationStoryPollTransport,
        store: StoryPollStore = .shared,
        defaults: UserDefaults? = nil
    ) {
        self.poll = poll
        self.storyId = storyId
        self.slideId = slideId
        self.shopId = shopId
        self.texts = texts
        self.transport = transport
        self.store = store
        self.defaults = defaults
        place = StoryPollStore.Place(shopId: shopId, did: did, poll: poll, storyId: storyId, slideId: slideId)
        if let sent = store.sentEntry(place) {
            // Отправленный за этот запуск ответ — всегда отвеченный вид, даже без вариантов и текста.
            answer = sent.answer
            results = sent.results
            mode = .answered
        } else {
            // Ответ ленты важнее сохранённого: сохранённый — для тех, кого лента не знает.
            let saved = poll.answer == nil ? store.savedEntry(place, in: defaults) : nil
            answer = saved?.answer ?? poll.answer
            results = saved == nil ? poll.results : saved?.results
            mode = PersonalizationStoryPoll.hasAnswer(answer) ? .answered : .form
        }
        resetForm()
    }

    var hold: Bool {
        isPressed || isFocused || isSending
    }

    // MARK: - Форма

    /// Можно отправить кнопкой: несколько вариантов — хоть один выбран, текст или комментарий
    /// к вопросу полосы — не пустые.
    var canSubmit: Bool {
        if asksComment { return !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard mode == .form else { return false }
        switch poll.kind {
        case .multipleChoice: return !selected.isEmpty
        case .text: return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default: return false
        }
    }

    /// Вопрос полосы оценки, на который ждут комментарий: шкала отвечена, у полосы оценки есть
    /// вопрос, а комментария в ответе нет, как в вебе; иначе `nil`.
    var commentQuestion: String? {
        guard mode == .answered, poll.scale != nil, let rate = answer?.rate,
              (answer?.comment ?? "").isEmpty else { return nil }
        return poll.bandQuestion(rate: rate)
    }

    /// Отвеченная шкала ждёт комментарий к вопросу полосы.
    var asksComment: Bool {
        commentQuestion != nil
    }

    /// Один вариант: выделяется сразу и уходит; ошибка возвращает прежнее выделение.
    func tapOption(_ id: Int) {
        guard mode == .form, !isSending, poll.kind == .singleChoice else { return }
        let previous = previousIds
        selected = [id]
        send(miniPoll: ["option_ids": [id]], sent: .init(optionIds: [id])) { [weak self] in self?.selected = previous }
    }

    /// Чип нескольких вариантов: включить или выключить, без отправки.
    func toggleChip(_ id: Int) {
        guard mode == .form, !isSending, poll.kind == .multipleChoice else { return }
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        emit(.update)
    }

    /// Текст поля: обрезается до `maxLength` (по UTF-16, как в вебе, не разрывая суррогатную
    /// пару). У отвеченной шкалы с вопросом полосы поле — комментарий, до 5000.
    @discardableResult
    func setText(_ value: String) -> String {
        if asksComment {
            comment = Self.limit(value, to: PersonalizationStoryPoll.commentMaxLength)
            emit(.update)
            return comment
        }
        guard mode == .form, poll.kind == .text else { return text }
        text = Self.limit(value, to: poll.maxLength)
        emit(.update)
        return text
    }

    /// Текст поля сейчас: текст опроса или комментарий к вопросу полосы.
    var fieldText: String {
        asksComment ? comment : text
    }

    /// Кнопка отправки: выбранные варианты в порядке вариантов, текст без пробелов по краям или
    /// комментарий — с той же оценкой.
    func submit() {
        guard !isSending, canSubmit else { return }
        if asksComment, let rate = answer?.rate {
            return sendReview(rate: rate, comment: comment.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard mode == .form else { return }
        switch poll.kind {
        case .multipleChoice:
            let ids = poll.options.map(\.id).filter { selected.contains($0) }
            send(miniPoll: ["option_ids": ids], sent: .init(optionIds: ids), revert: nil)
        case .text:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            send(miniPoll: ["text": trimmed], sent: .init(text: trimmed), revert: nil)
        default:
            break
        }
    }

    /// Ячейка шкалы: выделяется сразу и уходит без комментария (и при переответе — вопрос
    /// полосы появится снова); ошибка возвращает прежнюю оценку.
    func tapRate(_ rate: Int) {
        guard mode == .form, !isSending, poll.scale != nil else { return }
        let previous = answer?.rate
        pressedRate = Double(rate)
        sendReview(rate: Double(rate), comment: nil, revert: { [weak self] in self?.pressedRate = previous })
    }

    /// Отзыв шкалы: оценка числом, как пришла в ячейке; комментарий — только непустой. Успех —
    /// ответ `{rate}` или `{rate, comment}`, без итогов, как в вебе.
    private func sendReview(rate: Double, comment: String?, revert: (() -> Void)? = nil) {
        guard let scale = poll.scale else { return }
        var body: [String: Any] = ["channel": Self.nonEmpty(poll.channel) ?? "stories"]
        body["rate"] = rate == rate.rounded() && abs(rate) < 1e15 ? Int(rate) as Any : rate
        body[scale == .nps ? "category" : "campaign"] = poll.code
        if let comment, !comment.isEmpty { body["comment"] = comment }
        body.merge(Self.source(storyId: storyId, slideId: slideId)) { _, source in source }
        let sent = PersonalizationStoryPoll.Answer(rate: rate, comment: Self.nonEmpty(comment))
        send(sent: sent, keepsServerAnswer: false, revert: revert) { transport, completion in
            transport.review(kind: scale, body: body, completion: completion)
        }
    }

    /// «Ответить заново»: снова форма, прежний ответ подсвечен (у текста поле пустое и в фокусе).
    func reanswer() {
        guard mode == .answered, poll.allowReanswer, !isSending else { return }
        mode = .form
        showsError = false
        isReanswering = true
        resetForm()
        emit(.rebuild)
    }

    private var previousIds: Set<Int> {
        Set(answer?.optionIds ?? [])
    }

    private func resetForm() {
        let ids = Set(poll.options.map(\.id))
        selected = previousIds.intersection(ids)
        pressedRate = answer?.rate
        text = ""
        comment = ""
    }

    // MARK: - Отправка

    /// Источник ответа для отчётов опросов, как `sourceParams` веба: сторис и слайд, строками
    /// (у виртуальных слайдов товарных кампаний id вида `12_0`). Без id сторис источника нет,
    /// пустой id слайда не уходит.
    static func source(storyId: String, slideId: String) -> [String: Any] {
        guard !storyId.isEmpty else { return [:] }
        var source: [String: Any] = ["source_type": "stories", "source_id": storyId]
        if !slideId.isEmpty { source["source_item_id"] = slideId }
        return source
    }

    private func send(miniPoll fields: [String: Any], sent: PersonalizationStoryPoll.Answer, revert: (() -> Void)?) {
        let body = fields.merging(Self.source(storyId: storyId, slideId: slideId)) { _, source in source }
        let code = poll.code
        send(sent: sent, keepsServerAnswer: true, revert: revert) { transport, completion in
            transport.answerMiniPoll(code: code, body: body, completion: completion)
        }
    }

    /// Одна отправка за раз. Ответ пишется в хранилище, даже если карточки уже нет.
    /// `keepsServerAnswer` — ответ сервера (`answer` и `results` из `payload`) важнее отправленного,
    /// как у мини-опроса в вебе; у шкалы — отправленный.
    private func send(
        sent: PersonalizationStoryPoll.Answer,
        keepsServerAnswer: Bool,
        revert: (() -> Void)?,
        request: (PersonalizationStoryPollTransport, @escaping (Result<PersonalizationStoryPoll.Reply, Error>) -> Void) -> Void
    ) {
        guard !isSending else { return }
        isSending = true
        showsError = false
        syncHold()
        emit(.update)
        let store = self.store, place = self.place, defaults = self.defaults
        var finished = false
        request(transport) { [weak self] result in
            MainThread.run {
                guard !finished else { return }
                finished = true
                switch result {
                case .success(let reply):
                    // Ответ сервера — любой объект `answer`, даже `{id}`; отправленный — только без него.
                    let entry = keepsServerAnswer
                        ? StoryPollStore.Entry(answer: reply.answer ?? sent, results: reply.results)
                        : StoryPollStore.Entry(answer: sent, results: nil)
                    store.save(entry, place: place, in: defaults)
                    self?.succeeded(entry)
                case .failure:
                    self?.failed(revert: revert)
                }
            }
        }
    }

    private func succeeded(_ entry: StoryPollStore.Entry) {
        isSending = false
        answer = entry.answer
        results = entry.results
        mode = .answered
        resetForm()
        syncHold()
        emit(.rebuild)
    }

    private func failed(revert: (() -> Void)?) {
        isSending = false
        showsError = true
        revert?()
        syncHold()
        emit(.update)
    }

    // MARK: - Экран

    /// Карточка снова на экране: что пришло, пока её не было (свой ответ или ответ другой
    /// карточки того же опроса), и текущее удержание.
    func attach() {
        isAttached = true
        if !isSending, let saved = store.sentEntry(place),
           saved != StoryPollStore.Entry(answer: answer, results: results) {
            answer = saved.answer
            results = saved.results
            mode = .answered
            resetForm()
            pending = .rebuild
        }
        reportedHold = hold
        onHold?(hold)
        let change = pending
        pending = nil
        change.map { onChange?($0) }
    }

    /// Карточка ушла с экрана: удержание снимает сам просмотрщик при смене слайда.
    func detach() {
        isAttached = false
        reportedHold = false
        isPressed = false
        isFocused = false
    }

    /// Поле текста просит фокус один раз — после «ответить заново» (поле пустое).
    func takeFocusRequest() -> Bool {
        defer { isReanswering = false }
        return isReanswering && mode == .form && poll.kind == .text
    }

    private func syncHold() {
        let hold = self.hold
        guard isAttached, hold != reportedHold else { return }
        reportedHold = hold
        onHold?(hold)
    }

    /// Без карточки на экране перерисовка ждёт `attach`.
    private func emit(_ change: Change) {
        guard isAttached else {
            if pending != .rebuild { pending = change }
            return
        }
        onChange?(change)
    }

    // MARK: - Помощники

    /// Не длиннее `limit` единиц UTF-16 (так считает веб); режется по кодовым точкам, пара
    /// суррогатов не рвётся, а составной символ (эмодзи с оттенком кожи) — может, как в вебе.
    static func limit(_ value: String, to limit: Int?) -> String {
        guard let limit, value.utf16.count > limit else { return value }
        var result = String.UnicodeScalarView()
        var count = 0
        for scalar in value.unicodeScalars {
            let length = scalar.value > 0xFFFF ? 2 : 1
            guard count + length <= limit else { break }
            result.append(scalar)
            count += length
        }
        return String(result)
    }

    static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
