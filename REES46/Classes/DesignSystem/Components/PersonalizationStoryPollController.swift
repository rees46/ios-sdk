import Foundation

/// Логика карточки опроса без UI — как `createPoll` JS SDK: форма и отвеченное состояние,
/// отправка через транспорт, ошибка с повтором, переответ и удержание слайда.
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
    private let transport: PersonalizationStoryPollTransport
    private let store: StoryPollStore

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

    init(
        poll: PersonalizationStoryPoll,
        storyId: String,
        slideId: String,
        shopId: String,
        texts: StoryPollTexts,
        transport: PersonalizationStoryPollTransport,
        store: StoryPollStore = .shared
    ) {
        self.poll = poll
        self.storyId = storyId
        self.slideId = slideId
        self.shopId = shopId
        self.texts = texts
        self.transport = transport
        self.store = store
        let saved = store.entry(shopId: shopId, poll: poll)
        answer = saved?.answer ?? poll.answer
        results = saved == nil ? poll.results : saved?.results
        // Отправленный за этот запуск ответ — всегда отвеченный вид, даже без вариантов и текста.
        mode = saved != nil || PersonalizationStoryPoll.hasAnswer(answer) ? .answered : .form
        resetForm()
    }

    var hold: Bool {
        isPressed || isFocused || isSending
    }

    // MARK: - Форма

    /// Можно отправить кнопкой: несколько вариантов — хоть один выбран, текст — не пустой.
    var canSubmit: Bool {
        switch poll.kind {
        case .multipleChoice: return !selected.isEmpty
        case .text: return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default: return false
        }
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

    /// Текст поля: обрезается до `maxLength` (по UTF-16, как в вебе, не разрывая суррогатную пару).
    @discardableResult
    func setText(_ value: String) -> String {
        guard mode == .form, poll.kind == .text else { return text }
        text = Self.limit(value, to: poll.maxLength)
        emit(.update)
        return text
    }

    /// Кнопка отправки: выбранные варианты в порядке вариантов или текст без пробелов по краям.
    func submit() {
        guard mode == .form, !isSending, canSubmit else { return }
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

    /// Ячейка шкалы: выделяется сразу и уходит; ошибка возвращает прежнюю оценку.
    func tapRate(_ rate: Int) {
        guard mode == .form, !isSending, let scale = poll.scale else { return }
        let previous = answer?.rate
        pressedRate = Double(rate)
        var body: [String: Any] = ["channel": Self.nonEmpty(poll.channel) ?? "stories", "rate": rate]
        body[scale == .nps ? "category" : "campaign"] = poll.code
        send(sent: .init(rate: Double(rate)), revert: { [weak self] in self?.pressedRate = previous }) { transport, completion in
            transport.review(kind: scale, body: body) { completion($0.map { _ in .init() }) }
        }
    }

    /// «Ответить заново»: снова форма, прежний ответ подсвечен (у текста поле пустое).
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
    }

    // MARK: - Отправка

    private func send(miniPoll fields: [String: Any], sent: PersonalizationStoryPoll.Answer, revert: (() -> Void)?) {
        var body = fields
        body["story_id"] = Int(storyId).map { $0 as Any } ?? storyId
        body["slide_id"] = slideId
        let code = poll.code
        send(sent: sent, revert: revert) { transport, completion in
            transport.answerMiniPoll(code: code, body: body, completion: completion)
        }
    }

    /// Одна отправка за раз. Ответ пишется в хранилище, даже если карточки уже нет.
    private func send(
        sent: PersonalizationStoryPoll.Answer,
        revert: (() -> Void)?,
        request: (PersonalizationStoryPollTransport, @escaping (Result<PersonalizationStoryPoll.Reply, Error>) -> Void) -> Void
    ) {
        guard !isSending else { return }
        isSending = true
        showsError = false
        syncHold()
        emit(.update)
        let store = self.store, shopId = self.shopId, poll = self.poll
        var finished = false
        request(transport) { [weak self] result in
            MainThread.run {
                guard !finished else { return }
                finished = true
                switch result {
                case .success(let reply):
                    // Ответ сервера — любой объект `answer`, даже `{id}`; отправленный — только без него.
                    let entry = StoryPollStore.Entry(answer: reply.answer ?? sent, results: reply.results)
                    store.save(entry, shopId: shopId, poll: poll)
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
        if !isSending, let saved = store.entry(shopId: shopId, poll: poll),
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

    /// Поле текста просит фокус один раз — после «ответить заново».
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
