import XCTest
import UIKit
@_spi(PersonalizationV3) @testable import REES46

/// Transport with manual control of every request, like the web tests' `transport()`.
final class FakePollTransport: PersonalizationStoryPollTransport {

    struct Call {
        let method: String
        let code: String?
        let kind: PersonalizationStoryPoll.Scale?
        let body: [String: Any]
    }

    private(set) var calls: [Call] = []
    private var pending: [(Result<PersonalizationStoryPoll.Reply, Error>) -> Void] = []

    func answerMiniPoll(code: String, body: [String: Any], completion: @escaping (Result<PersonalizationStoryPoll.Reply, Error>) -> Void) {
        calls.append(Call(method: "answerMiniPoll", code: code, kind: nil, body: body))
        pending.append(completion)
    }

    func review(kind: PersonalizationStoryPoll.Scale, body: [String: Any], completion: @escaping (Result<PersonalizationStoryPoll.Reply, Error>) -> Void) {
        calls.append(Call(method: "review", code: nil, kind: kind, body: body))
        pending.append(completion)
    }

    func resolve(_ index: Int, _ reply: PersonalizationStoryPoll.Reply = .init()) {
        pending[index](.success(reply))
    }

    func reject(_ index: Int) {
        pending[index](.failure(URLError(.notConnectedToInternet)))
    }

    /// The body as sorted JSON, for exact comparisons.
    func json(_ index: Int) -> String {
        let data = try? JSONSerialization.data(withJSONObject: calls[index].body, options: .sortedKeys)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
}

/// Polls on Stories V2 slides, the card (the web SDK's `create-poll.test.ts`): single choice and
/// scales go on tap, multiple choice and text by the button; one send at a time, an error is
/// shown under the content and lets the client retry (single choice and scales go back to the
/// previous pick), answered polls show the answer, results and thanks, `allow_reanswer` brings
/// the form back. The slide is held while the card is touched, focused or sending.
final class PersonalizationStoriesPollsTests: XCTestCase {

    typealias Poll = PersonalizationStoryPoll

    override func setUp() {
        super.setUp()
        StoryPollStore.shared.removeAll()
    }

    override func tearDown() {
        StoryPollStore.shared.removeAll()
        super.tearDown()
    }

    private func miniPoll(
        _ kind: Poll.Kind,
        yOffset: CGFloat? = 40,
        allowReanswer: Bool = false,
        submitLabel: String? = "Отправить",
        maxLength: Int? = nil,
        answer: Poll.Answer? = nil,
        results: Poll.Results? = nil,
        labels: Poll.Labels = .init()
    ) -> Poll {
        Poll(
            kind: kind,
            code: "gift_recipient",
            question: "Кому выбираете подарок?",
            placeholder: kind == .text ? "Название или автор" : nil,
            maxLength: maxLength ?? (kind == .text ? 10 : nil),
            submitLabel: submitLabel,
            thanksText: "Спасибо!",
            showResults: true,
            options: [.init(id: 1, label: "Себе"), .init(id: 2, label: "Маме"), .init(id: 3, label: "Папе")],
            yOffset: yOffset,
            allowReanswer: allowReanswer,
            answer: answer,
            results: results,
            labels: labels
        )
    }

    private func scalePoll(
        _ scale: Poll.Scale,
        channel: String? = "stories",
        bands: [Poll.Band]? = nil,
        allowReanswer: Bool = false,
        answer: Poll.Answer? = nil
    ) -> Poll {
        Poll(
            kind: .scale(scale),
            code: "delivery",
            question: "Как вам доставка?",
            channel: channel,
            rateMin: scale == .nps ? 0 : 1,
            rateMax: scale == .nps ? 10 : (scale == .csat ? 5 : 7),
            bands: bands ?? [
                .init(from: 0, to: 6, success: "Спасибо, мы станем лучше"),
                .init(from: 7, to: 8, success: "Спасибо!"),
                .init(from: 9, to: 10, success: "Спасибо, рады стараться!")
            ],
            yOffset: 50,
            allowReanswer: allowReanswer,
            answer: answer
        )
    }

    /// Slide hold events of a mounted card.
    private final class Events {
        var holds: [Bool] = []
    }

    private func mount(
        _ poll: Poll,
        texts: PersonalizationStoriesTexts = .init(),
        language: StoryPollTexts.Language = .en,
        storyId: String = "5",
        slideId: String = "101",
        did: String = "",
        defaults: UserDefaults? = nil
    ) -> (card: PersonalizationStoryPollView, transport: FakePollTransport, events: Events) {
        let transport = FakePollTransport()
        let events = Events()
        let controller = StoryPollController(
            poll: poll,
            storyId: storyId,
            slideId: slideId,
            shopId: "shop",
            did: did,
            texts: StoryPollTexts(host: texts, labels: poll.labels, language: language),
            transport: transport,
            defaults: defaults
        )
        controller.onHold = { events.holds.append($0) }
        return (PersonalizationStoryPollView(controller: controller), transport, events)
    }

    /// The card in a key window, so its field can take the focus; skipped where this host gives
    /// no first responder.
    private func hosted(_ card: PersonalizationStoryPollView) throws -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        let host = UIViewController()
        window.rootViewController = host
        window.isHidden = false
        window.makeKey()
        let probe = UITextView()
        host.view.addSubview(probe)
        let focusable = probe.becomeFirstResponder()
        probe.resignFirstResponder()
        probe.removeFromSuperview()
        guard focusable else {
            window.isHidden = true
            throw XCTSkip("no first responder in this host")
        }
        card.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(card)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: host.view.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: host.view.trailingAnchor, constant: -16),
            card.topAnchor.constraint(equalTo: host.view.topAnchor, constant: 100)
        ])
        host.view.layoutIfNeeded()
        return window
    }

    private func question(_ card: PersonalizationStoryPollView) -> String? {
        card.questionLabel?.text
    }

    private func selectedRows(_ card: PersonalizationStoryPollView) -> [Int] {
        card.optionRows.filter(\.isSelected).map(\.id)
    }

    private func pressedCells(_ card: PersonalizationStoryPollView) -> [Int] {
        card.cells.filter(\.isSelected).map(\.value)
    }
}

// MARK: - Single choice

extension PersonalizationStoriesPollsTests {

    func testSingleChoiceSendsOnTapAndShowsThanksAndResults() {
        let (card, transport, _) = mount(miniPoll(.singleChoice))
        XCTAssertEqual(question(card), "Кому выбираете подарок?")
        XCTAssertEqual(card.optionRows.count, 3)
        XCTAssertNil(card.submitButton, "single choice has no button")

        card.optionRows[1].sendActions(for: .touchUpInside)
        XCTAssertEqual(transport.calls.count, 1)
        XCTAssertEqual(transport.calls[0].method, "answerMiniPoll")
        XCTAssertEqual(transport.calls[0].code, "gift_recipient")
        XCTAssertEqual(transport.json(0), #"{"option_ids":[2],"source_id":"5","source_item_id":"101","source_type":"stories"}"#, "the source of the answer: the story and the slide, strings")
        XCTAssertTrue(card.optionRows.allSatisfy { !$0.isEnabled }, "controls are disabled while sending")
        XCTAssertEqual(card.alpha, 0.85, accuracy: 0.001)
        XCTAssertEqual(selectedRows(card), [2], "the option is highlighted at once")

        transport.resolve(0, .init(answer: .init(optionIds: [2]), results: .init(total: 121, options: [.init(id: 1, percent: 40), .init(id: 2, percent: 60)])))
        XCTAssertEqual(card.controller.mode, .answered)
        XCTAssertEqual(card.alpha, 1)
        XCTAssertEqual(card.thanksLabel?.text, "Спасибо!")
        XCTAssertEqual(card.optionRows.count, 3)
        XCTAssertEqual(selectedRows(card), [2])
        XCTAssertEqual(card.optionRows.map { $0.percentLabel.text }, ["40%", "60%", "0%"])
        XCTAssertEqual(card.optionRows[1].percent, 60)
        XCTAssertTrue(card.optionRows.allSatisfy { !$0.isUserInteractionEnabled }, "nothing to tap in the answer")
        XCTAssertNil(card.reanswerLink)
    }

    func testNoSecondSendWhileTheRequestIsPending() {
        let (card, transport, _) = mount(miniPoll(.singleChoice))
        card.optionRows[0].sendActions(for: .touchUpInside)
        card.optionRows[0].isEnabled = true
        card.optionRows[0].sendActions(for: .touchUpInside)
        card.optionRows[2].sendActions(for: .touchUpInside)
        XCTAssertEqual(transport.calls.count, 1)
    }

    func testAnErrorIsShownAndTheClientCanRetry() {
        let (card, transport, _) = mount(miniPoll(.singleChoice), texts: .init(pollErrorText: "Ошибка"))
        card.optionRows[0].sendActions(for: .touchUpInside)
        transport.reject(0)

        XCTAssertEqual(card.errorLabel?.text, "Ошибка")
        XCTAssertFalse(card.errorLabel?.isHidden ?? true)
        XCTAssertTrue(card.optionRows.allSatisfy(\.isEnabled))
        XCTAssertEqual(selectedRows(card), [], "the pick goes back to none")
        XCTAssertEqual(card.alpha, 1)

        card.optionRows[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(transport.calls.count, 2, "no automatic retry, the client taps again")
        XCTAssertTrue(card.errorLabel?.isHidden ?? false)
        transport.resolve(1, .init(answer: .init(optionIds: [1])))
        XCTAssertEqual(card.controller.mode, .answered)
        XCTAssertTrue(card.optionRows.allSatisfy { $0.percentLabel.isHidden }, "no percent without results")
    }

    func testTheSentAnswerWhenTheServerReturnsNone() {
        let (card, transport, _) = mount(miniPoll(.singleChoice))
        card.optionRows[2].sendActions(for: .touchUpInside)
        transport.resolve(0)
        XCTAssertEqual(selectedRows(card), [3])
        XCTAssertEqual(card.controller.answer, .init(optionIds: [3]))
    }

    /// The web does not check the code: the card is there, the server says no, the client retries.
    func testAPollWithoutACodeIsDrawnAndItsErrorShown() {
        let poll = Poll(kind: .singleChoice, code: "", question: "Q", options: [.init(id: 1, label: "A"), .init(id: 2, label: "B")])
        let (card, transport, _) = mount(poll)
        XCTAssertEqual(card.optionRows.count, 2)
        card.optionRows[1].sendActions(for: .touchUpInside)
        XCTAssertEqual(transport.calls.first?.code, "", "the request goes")
        transport.reject(0)
        XCTAssertEqual(card.errorLabel?.text, "Failed to send the answer. Please try again")
        XCTAssertFalse(card.errorLabel?.isHidden ?? true)
        card.optionRows[1].sendActions(for: .touchUpInside)
        XCTAssertEqual(transport.calls.count, 2, "and may be retried")
        transport.resolve(1)
        XCTAssertNotNil(StoryPollStore.shared.sentEntry(card.controller.place), "stored under the empty code")

        let scale = mount(Poll(kind: .scale(.nps), code: ""))
        scale.card.cells[3].sendActions(for: .touchUpInside)
        XCTAssertEqual(scale.transport.json(0), #"{"category":"","channel":"stories","rate":3,"source_id":"5","source_item_id":"101","source_type":"stories"}"#)
    }

    /// Any object of `payload.answer` is the answer, even `{id}` alone; the card is answered anyway.
    func testAnAnswerWithoutOptionsIsStillAnswered() {
        let (card, transport, _) = mount(miniPoll(.singleChoice))
        card.optionRows[1].sendActions(for: .touchUpInside)
        transport.resolve(0, .init(answer: .init()))
        XCTAssertEqual(card.controller.mode, .answered)
        XCTAssertEqual(card.controller.answer, .init(), "not the sent one")
        XCTAssertEqual(selectedRows(card), [], "nothing to highlight")
        XCTAssertEqual(card.thanksLabel?.text, "Спасибо!")
        XCTAssertEqual(mount(miniPoll(.singleChoice)).card.controller.mode, .answered, "and so it comes back from the store")
    }

    func testAProductSlideSendsItsIdAsAString() {
        let (card, transport, _) = mount(miniPoll(.singleChoice), slideId: "39_0")
        card.optionRows[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(transport.json(0), #"{"option_ids":[1],"source_id":"5","source_item_id":"39_0","source_type":"stories"}"#)
    }
}

// MARK: - Multiple choice

extension PersonalizationStoriesPollsTests {

    func testMultipleChoiceSendsTheSelectedOptionsByTheButton() throws {
        let (card, transport, _) = mount(miniPoll(.multipleChoice))
        XCTAssertEqual(card.optionRows.map(\.letterLabel.text), ["A", "B", "C"], "rows with letters, like single choice")
        let submit = try XCTUnwrap(card.submitButton)
        XCTAssertEqual(submit.title.text, "Отправить")
        XCTAssertFalse(submit.isEnabled)

        card.optionRows[2].sendActions(for: .touchUpInside)
        card.optionRows[0].sendActions(for: .touchUpInside)
        XCTAssertTrue(card.optionRows[0].isSelected)
        XCTAssertTrue(card.optionRows[0].isCheckVisible, "a check instead of the letter")
        XCTAssertTrue(card.optionRows[0].accessibilityTraits.contains(.selected))
        XCTAssertTrue(submit.isEnabled)
        XCTAssertTrue(transport.calls.isEmpty, "the options do not send")

        card.optionRows[2].sendActions(for: .touchUpInside)
        card.optionRows[2].sendActions(for: .touchUpInside)
        submit.sendActions(for: .touchUpInside)
        XCTAssertEqual(transport.json(0), #"{"option_ids":[1,3],"source_id":"5","source_item_id":"101","source_type":"stories"}"#, "the order of the options")

        transport.resolve(0, .init(answer: .init(optionIds: [1, 3]), results: .init(total: 2, options: [.init(id: 1, percent: 50), .init(id: 3, percent: 50)])))
        XCTAssertEqual(selectedRows(card), [1, 3])
        XCTAssertTrue(card.optionRows.allSatisfy { !$0.isUserInteractionEnabled }, "nothing to tap in the answer")
        XCTAssertNil(card.submitButton)
        XCTAssertEqual(card.optionRows.map(\.letterLabel.text), ["A", "B", "C"], "the same rows before and after, like the web")
        XCTAssertEqual(card.optionRows.map { $0.percentLabel.text }, ["50%", "0%", "50%"])
    }

    func testTheButtonStaysOffAfterEveryOptionIsOffAgain() {
        let (card, _, _) = mount(miniPoll(.multipleChoice))
        card.optionRows[0].sendActions(for: .touchUpInside)
        card.optionRows[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(card.submitButton?.isEnabled, false)
    }

    func testTextsOfSpacesAreShown() {
        let poll = Poll(kind: .multipleChoice, code: "x", question: " ", submitLabel: "  ", options: [.init(id: 1, label: "A")])
        let card = mount(poll, texts: .init(pollSubmitText: "Готово")).card
        XCTAssertEqual(question(card), " ")
        XCTAssertEqual(card.submitButton?.title.text, "  ", "submit_label of spaces wins, like the web")
    }

    func testTheDefaultSubmitLabel() {
        XCTAssertEqual(mount(miniPoll(.multipleChoice, submitLabel: nil)).card.submitButton?.title.text, "Send")
        XCTAssertEqual(mount(miniPoll(.multipleChoice, submitLabel: nil), texts: .init(pollSubmitText: "Готово")).card.submitButton?.title.text,
                       "Готово", "the host's text")
        XCTAssertEqual(mount(miniPoll(.multipleChoice, submitLabel: nil, labels: .init(submit: "Ок")), texts: .init(pollSubmitText: "Готово"))
                        .card.submitButton?.title.text, "Ок", "labels of the element win")
    }
}

// MARK: - Text

extension PersonalizationStoriesPollsTests {

    func testTextCountsCharactersAndSendsItTrimmed() throws {
        let (card, transport, _) = mount(miniPoll(.text))
        let input = try XCTUnwrap(card.input)
        let submit = try XCTUnwrap(card.submitButton)
        XCTAssertEqual(input.placeholder, "Название или автор")
        XCTAssertTrue(input.isPlaceholderVisible)
        XCTAssertEqual(card.counter?.text, "0/10")
        XCTAssertFalse(submit.isEnabled)

        input.text = "   "
        card.textViewDidChange(input)
        XCTAssertFalse(submit.isEnabled, "blanks are no answer")

        input.text = " Мастер и Маргарита "
        card.textViewDidChange(input)
        XCTAssertEqual(input.text, " Мастер и ", "max_length cuts the input")
        XCTAssertEqual(card.counter?.text, "10/10")
        XCTAssertFalse(input.isPlaceholderVisible)
        XCTAssertTrue(submit.isEnabled)

        submit.sendActions(for: .touchUpInside)
        XCTAssertEqual(transport.json(0), #"{"source_id":"5","source_item_id":"101","source_type":"stories","text":"Мастер и"}"#)
        XCTAssertFalse(input.isEditable)

        transport.resolve(0, .init(answer: .init(text: "Мастер и")))
        XCTAssertEqual(card.thanksLabel?.text, "Спасибо!")
        XCTAssertEqual(card.doneTextLabel?.text, "Мастер и")
        XCTAssertNil(card.input)
    }

    func testNoCounterWithoutMaxLength() {
        let poll = Poll(kind: .text, code: "t", options: [])
        XCTAssertNil(mount(poll).card.counter)
        XCTAssertNotNil(mount(poll).card.input)
    }

    func testTheLimitCountsUtf16AndDoesNotCutACharacter() {
        XCTAssertEqual(StoryPollController.limit("ab👍c", to: 3), "ab", "the emoji is two UTF-16 units: it does not fit whole")
        XCTAssertEqual(StoryPollController.limit("ab👍c", to: 4), "ab👍")
        XCTAssertEqual(StoryPollController.limit("abc", to: nil), "abc")
        XCTAssertEqual(StoryPollController.limit("ab👍🏽", to: 4), "ab👍", "by code points, like the web: the modifier falls off")
        XCTAssertEqual(StoryPollController.limit("ab👍🏽", to: 5), "ab👍", "a surrogate pair is never cut")
        XCTAssertEqual(StoryPollController.limit("ab👍🏽", to: 6), "ab👍🏽")
    }
}

// MARK: - Scales

extension PersonalizationStoriesPollsTests {

    func testNpsZeroToTenSendsTheRateOnTap() {
        let (card, transport, _) = mount(scalePoll(.nps))
        XCTAssertEqual(card.cells.map { $0.title.text }, (0...10).map(String.init))
        XCTAssertEqual(card.cells.map(\.fillColor), (0...10).map {
            Style.color(of: PersonalizationStoryPoll.scaleTone(.nps, value: $0, min: 0, max: 10))
        }, "every rate in the tone of its value, red to green, like the web's cells")
        XCTAssertFalse(card.cells.contains(where: \.isCapsuleVisible), "tinted digits on the track until a pick")

        card.cells[9].sendActions(for: .touchUpInside)
        XCTAssertEqual(transport.calls[0].method, "review")
        XCTAssertEqual(transport.calls[0].kind, .nps)
        XCTAssertEqual(transport.json(0), #"{"category":"delivery","channel":"stories","rate":9,"source_id":"5","source_item_id":"101","source_type":"stories"}"#)
        XCTAssertEqual(pressedCells(card), [9])
        transport.resolve(0, .init(answer: .init(rate: 3)))

        XCTAssertEqual(card.thanksLabel?.text, "Спасибо, рады стараться!", "the band of the sent rate")
        XCTAssertEqual(pressedCells(card), [9], "a review answer is the sent rate")
        XCTAssertTrue(card.cells[9].isCapsuleVisible)
        XCTAssertEqual(card.cells.filter(\.isCapsuleVisible).count, 1)
        XCTAssertEqual(card.cells[0].alpha, 0.55, accuracy: 0.001, "the rest are muted")
        XCTAssertEqual(card.cells[9].alpha, 1)
    }

    func testCsatAndCesUseTheCampaignAndTheDefaultChannel() {
        let csat = mount(scalePoll(.csat, bands: [.init(from: 1, to: 3, success: "Жаль"), .init(from: 4, to: 5, success: "Ура")]))
        XCTAssertEqual(csat.card.cells.count, 5)
        csat.card.cells[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(csat.transport.calls[0].kind, .csat)
        XCTAssertEqual(csat.transport.json(0), #"{"campaign":"delivery","channel":"stories","rate":1,"source_id":"5","source_item_id":"101","source_type":"stories"}"#)
        csat.transport.resolve(0)
        XCTAssertEqual(csat.card.thanksLabel?.text, "Жаль")

        let ces = mount(scalePoll(.ces, channel: nil))
        XCTAssertEqual(ces.card.cells.map(\.value), Array(1...7))
        ces.card.cells[6].sendActions(for: .touchUpInside)
        XCTAssertEqual(ces.transport.json(0), #"{"campaign":"delivery","channel":"stories","rate":7,"source_id":"5","source_item_id":"101","source_type":"stories"}"#, "no channel — stories")
        let blank = mount(scalePoll(.nps, channel: " "))
        blank.card.cells[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(blank.transport.json(0), #"{"category":"delivery","channel":" ","rate":0,"source_id":"5","source_item_id":"101","source_type":"stories"}"#, "a channel of spaces goes as is")
        let empty = mount(scalePoll(.nps, channel: ""))
        empty.card.cells[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(empty.transport.json(0), #"{"category":"delivery","channel":"stories","rate":0,"source_id":"5","source_item_id":"101","source_type":"stories"}"#, "an empty channel — stories too")
    }

    func testTheAnsweredScaleOfTheFeed() {
        let (card, transport, _) = mount(scalePoll(.nps, answer: .init(rate: 3)))
        XCTAssertEqual(card.controller.mode, .answered)
        XCTAssertTrue(card.cells.allSatisfy { !$0.isEnabled })
        XCTAssertEqual(pressedCells(card), [3])
        XCTAssertEqual(card.thanksLabel?.text, "Спасибо, мы станем лучше")
        card.cells[5].sendActions(for: .touchUpInside)
        XCTAssertTrue(transport.calls.isEmpty)
    }

    func testAFractionalRateOfTheFeedIsAnswered() {
        let (card, _, _) = mount(scalePoll(.nps, answer: .init(rate: 3.5)))
        XCTAssertEqual(card.controller.mode, .answered)
        XCTAssertEqual(pressedCells(card), [], "no cell is 3.5")
        XCTAssertTrue(card.cells.allSatisfy { $0.alpha < 1 })
        XCTAssertEqual(card.thanksLabel?.text, "Спасибо, мы станем лучше", "the band of 0...6")
    }

    func testTheScaleRestoresThePreviousRateAfterAFailedReanswer() throws {
        let (card, transport, _) = mount(scalePoll(.nps, allowReanswer: true, answer: .init(rate: 3)))
        try XCTUnwrap(card.reanswerLink).sendActions(for: .touchUpInside)
        XCTAssertTrue(card.cells.allSatisfy(\.isEnabled))
        XCTAssertEqual(pressedCells(card), [3], "the previous rate stays highlighted")
        card.cells[8].sendActions(for: .touchUpInside)
        XCTAssertEqual(pressedCells(card), [8])
        transport.reject(0)
        XCTAssertEqual(pressedCells(card), [3], "the previous rate is back after an error")
    }
}

// MARK: - Answer from the feed and re-answer

extension PersonalizationStoriesPollsTests {

    private var answered: (answer: Poll.Answer, results: Poll.Results) {
        (.init(optionIds: [2]), .init(total: 120, options: [.init(id: 1, percent: 40), .init(id: 2, percent: 60)]))
    }

    func testTheAnsweredStateWithoutReanswer() {
        let (card, _, _) = mount(miniPoll(.singleChoice, answer: answered.answer, results: answered.results))
        XCTAssertEqual(card.controller.mode, .answered)
        XCTAssertTrue(card.optionRows.allSatisfy { !$0.isUserInteractionEnabled }, "nothing to tap")
        XCTAssertEqual(selectedRows(card), [2])
        XCTAssertEqual(card.optionRows[0].percentLabel.text, "40%")
        XCTAssertEqual(card.thanksLabel?.text, "Спасибо!")
        XCTAssertNil(card.reanswerLink)
    }

    func testAnswerAgainResetsTheFormWithThePreviousAnswerHighlighted() throws {
        let (card, transport, _) = mount(miniPoll(.singleChoice, allowReanswer: true, answer: answered.answer, results: answered.results),
                                         texts: .init(pollReanswerText: "Ответить ещё раз"))
        let link = try XCTUnwrap(card.reanswerLink)
        XCTAssertEqual(link.title.text, "Ответить ещё раз")

        link.sendActions(for: .touchUpInside)
        XCTAssertEqual(card.controller.mode, .form)
        XCTAssertNil(card.reanswerLink)
        XCTAssertEqual(card.optionRows.count, 3)
        XCTAssertEqual(selectedRows(card), [2], "the previous answer is highlighted")

        card.optionRows[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(selectedRows(card), [1], "only the new option is highlighted")
        XCTAssertEqual(transport.calls.count, 1)
        transport.resolve(0, .init(answer: .init(optionIds: [1])))
        XCTAssertNotNil(card.reanswerLink, "the link is back")
    }

    func testAFailedReanswerRestoresThePreviousSingleChoice() throws {
        let (card, transport, _) = mount(miniPoll(.singleChoice, allowReanswer: true, answer: answered.answer, results: answered.results))
        try XCTUnwrap(card.reanswerLink).sendActions(for: .touchUpInside)
        card.optionRows[2].sendActions(for: .touchUpInside)
        transport.reject(0)
        XCTAssertEqual(selectedRows(card), [2])
    }

    func testMultipleChoicePreselectsThePreviousAnswerOnReanswer() throws {
        let (card, transport, _) = mount(miniPoll(.multipleChoice, allowReanswer: true, answer: .init(optionIds: [1, 3])))
        try XCTUnwrap(card.reanswerLink).sendActions(for: .touchUpInside)
        XCTAssertEqual(card.optionRows.map(\.isSelected), [true, false, true])
        XCTAssertEqual(card.submitButton?.isEnabled, true)
        card.optionRows[0].sendActions(for: .touchUpInside)
        card.submitButton?.sendActions(for: .touchUpInside)
        XCTAssertEqual(transport.json(0), #"{"option_ids":[3],"source_id":"5","source_item_id":"101","source_type":"stories"}"#)
    }

    func testTextReanswerStartsEmpty() throws {
        let (card, _, _) = mount(miniPoll(.text, allowReanswer: true, answer: .init(text: "Букварь")))
        XCTAssertEqual(card.doneTextLabel?.text, "Букварь")
        try XCTUnwrap(card.reanswerLink).sendActions(for: .touchUpInside)
        XCTAssertEqual(card.input?.text, "")
        XCTAssertEqual(card.counter?.text, "0/10")
    }

    func testTheFieldTakesTheFocusAfterAnswerAgain() throws {
        let (card, _, events) = mount(miniPoll(.text, allowReanswer: true, answer: .init(text: "Букварь")))
        let window = try hosted(card)
        defer {
            card.dismissKeyboard()
            window.isHidden = true
        }
        events.holds = []
        try XCTUnwrap(card.reanswerLink).sendActions(for: .touchUpInside)
        XCTAssertTrue(card.isEditing, "the field takes the focus and the keyboard opens, like the web")
        XCTAssertEqual(events.holds, [true], "the focus holds the slide")
    }

    func testASuccessfulAnswerReplacesTheResultsOfTheFeed() throws {
        let (card, transport, _) = mount(miniPoll(.singleChoice, allowReanswer: true, answer: answered.answer, results: answered.results))
        XCTAssertEqual(card.optionRows[0].percentLabel.text, "40%")
        try XCTUnwrap(card.reanswerLink).sendActions(for: .touchUpInside)
        card.optionRows[0].sendActions(for: .touchUpInside)
        transport.resolve(0, .init(answer: .init(optionIds: [1])))
        XCTAssertNil(card.controller.results, "no results in the reply — none")
        XCTAssertTrue(card.optionRows.allSatisfy { $0.percentLabel.isHidden })
        XCTAssertEqual(StoryPollStore.shared.sentEntry(card.controller.place), .init(answer: .init(optionIds: [1]), results: nil))
    }

    /// Labels of the element, then the host's texts, then the SDK's own in the device's language.
    func testTextsLabelsThenTheHostThenBuiltInsOfTheLanguage() {
        let host = PersonalizationStoriesTexts(pollReanswerText: "Ещё", pollSubmitText: "Ок", pollErrorText: "Сбой")
        let english = StoryPollTexts(host: .init(), labels: .init(), language: .en)
        XCTAssertEqual([english.reanswer, english.submit, english.error], ["Answer again", "Send", "Failed to send the answer. Please try again"])
        let russian = StoryPollTexts(host: .init(), labels: .init(), language: .ru)
        XCTAssertEqual([russian.reanswer, russian.submit, russian.error], ["Ответить заново", "Отправить", "Не удалось отправить ответ. Попробуйте еще раз"],
                       "no English fallback in a Russian interface")
        XCTAssertEqual(PersonalizationStoriesTexts().pollSubmitText, "", "the host's texts are empty by default: the SDK's own go")
        let fromHost = StoryPollTexts(host: host, labels: .init(reanswer: "", error: nil, submit: nil), language: .ru)
        XCTAssertEqual([fromHost.reanswer, fromHost.submit, fromHost.error], ["Ещё", "Ок", "Сбой"], "empty labels do not count")
        let fromLabels = StoryPollTexts(host: host, labels: .init(reanswer: "Заново", error: "Не ушло", submit: "Отправить"))
        XCTAssertEqual([fromLabels.reanswer, fromLabels.submit, fromLabels.error], ["Заново", "Отправить", "Не ушло"])
        let spaces = StoryPollTexts(host: .init(pollReanswerText: " ", pollSubmitText: " ", pollErrorText: " "), labels: .init())
        XCTAssertEqual([spaces.reanswer, spaces.submit, spaces.error], [" ", " ", " "], "a host text of spaces wins")

        let (card, _, _) = mount(miniPoll(.singleChoice, allowReanswer: true, answer: answered.answer, labels: .init(reanswer: "Ещё раз")),
                                 texts: .init(pollReanswerText: "Answer again"))
        XCTAssertEqual(card.reanswerLink?.title.text, "Ещё раз")
        XCTAssertEqual(mount(miniPoll(.singleChoice, allowReanswer: true, answer: answered.answer)).card.reanswerLink?.title.text, "Answer again")
        XCTAssertEqual(mount(miniPoll(.singleChoice, allowReanswer: true, answer: answered.answer), language: .ru).card.reanswerLink?.title.text,
                       "Ответить заново")
    }
}

// MARK: - The look

extension PersonalizationStoriesPollsTests {

    typealias Style = PersonalizationStoryPollView.Style

    func testTheCardIsFrostedWithALightBorder() {
        let card = mount(miniPoll(.singleChoice)).card
        XCTAssertTrue(card.backdrop.effect is UIBlurEffect, "the slide under the card is blurred")
        XCTAssertEqual(card.backdrop.contentView.backgroundColor, Style.tint, "with a light plate")
        XCTAssertEqual(card.layer.cornerRadius, 24)
        XCTAssertEqual(card.layer.borderWidth, 1)
        XCTAssertEqual(card.questionLabel?.font.pointSize, 18)
        XCTAssertEqual(card.questionLabel?.textAlignment, .natural, "every text from the left edge")
    }

    func testOptionsCarryLettersAndThePickIsChecked() {
        let (card, transport, _) = mount(miniPoll(.singleChoice))
        XCTAssertEqual(card.optionRows.map(\.letterLabel.text), ["A", "B", "C"])
        XCTAssertFalse(card.optionRows.contains(where: \.isCheckVisible))
        XCTAssertEqual(card.optionRows[0].backgroundColor, Style.track)
        XCTAssertEqual(card.optionRows[0].layer.borderWidth, 0)

        card.optionRows[1].sendActions(for: .touchUpInside)
        XCTAssertTrue(card.optionRows[1].isCheckVisible, "the pick is checked at once")
        XCTAssertEqual(card.optionRows[1].backgroundColor, Style.selectedFill, "the pick before the send is filled")
        XCTAssertEqual(card.optionRows[1].layer.borderWidth, 1.5)
        transport.resolve(0, .init(answer: .init(optionIds: [2]), results: .init(total: 3, options: [.init(id: 2, percent: 100)])))
        XCTAssertEqual(card.optionRows.map(\.isCheckVisible), [false, true, false], "my answer in the results")
        XCTAssertEqual(card.optionRows[1].backgroundColor, Style.track, "my answer: the usual plate, the accent border and bar")
        XCTAssertEqual(card.optionRows[1].layer.borderWidth, 1.5)

        XCTAssertEqual(PollOptionRow.letter(0), "A")
        XCTAssertEqual(PollOptionRow.letter(25), "Z")
        XCTAssertEqual(PollOptionRow.letter(26), "AA")
        XCTAssertEqual(PollOptionRow.letter(27), "AB")
    }

    /// After the answer, as the web: the rows with the answer and the percents when results came,
    /// then `thanks_text` — no header, no default thanks, no count of votes.
    func testAnAnsweredChoiceShowsWhatTheWebShows() {
        let results = Poll.Results(total: 1248, options: [.init(id: 1, percent: 52), .init(id: 2, percent: 31), .init(id: 3, percent: 17)])
        let card = mount(miniPoll(.singleChoice, answer: .init(optionIds: [2]), results: results), language: .ru).card
        XCTAssertEqual(card.optionRows.map { $0.percentLabel.text }, ["52%", "31%", "17%"])
        XCTAssertEqual(selectedRows(card), [2])
        XCTAssertEqual(card.thanksLabel?.text, "Спасибо!", "the poll's thanks_text")

        let plain = Poll(kind: .multipleChoice, code: "c", question: "Q", options: [.init(id: 1, label: "A"), .init(id: 2, label: "B")],
                         answer: .init(optionIds: [1]))
        let bare = mount(plain).card
        XCTAssertNil(bare.thanksLabel, "no thanks_text — nothing")
        XCTAssertTrue(bare.optionRows.allSatisfy { $0.percentLabel.isHidden }, "no results — no percents")
    }

    /// The tone of a rate, like the web's colours of the cells: red, then orange and yellow, then green.
    func testTheScaleCellsGoFromRedToGreenInTheKitsColours() throws {
        let (card, _, _) = mount(scalePoll(.nps))
        XCTAssertEqual(card.cells.map(\.fillColor), [0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 2].map {
            [PersonalizationColor.semanticDanger, PersonalizationColor.semanticWarning, Style.accent][$0]
        })
        XCTAssertEqual(card.cells[0].capsuleColor, PersonalizationColor.semanticDanger.withAlphaComponent(PollScaleCell.tintAlpha))
        card.cells[9].sendActions(for: .touchUpInside)
        XCTAssertTrue(card.cells[9].isCapsuleVisible)
        XCTAssertEqual(card.cells[9].capsuleColor, Style.accent, "the pick is filled")
        XCTAssertEqual(card.cells[9].title.textColor, PersonalizationColor.textDarkPrimary, "dark digit on the green")
        XCTAssertEqual(card.cells[0].title.textColor, Style.text)

        XCTAssertEqual((1...5).map { PersonalizationStoryPoll.scaleTone(.csat, value: $0, min: 1, max: 5) },
                       [.negative, .negative, .neutral, .positive, .positive], "by thirds")
        XCTAssertEqual((1...7).map { PersonalizationStoryPoll.scaleTone(.ces, value: $0, min: 1, max: 7) },
                       [.negative, .negative, .negative, .neutral, .neutral, .positive, .positive])
        XCTAssertEqual(PersonalizationStoryPoll.scaleTone(.csat, value: 3, min: 3, max: 3), .positive, "one value")

        XCTAssertEqual(Style.contrastingText(on: .black), .white)
        XCTAssertEqual(Style.contrastingText(on: Style.rgb(0x1E3A8A)), .white)
        XCTAssertEqual(Style.contrastingText(on: Style.rgb(0xFDE68A)), PersonalizationColor.textDarkPrimary)
        let button = try XCTUnwrap(mount(miniPoll(.multipleChoice)).card.submitButton)
        button.isEnabled = true
        XCTAssertEqual(button.title.textColor, Style.contrastingText(on: Style.accent), "one rule for the button, the check and the digit")
    }

    func testTheFieldGrowsWithTheText() throws {
        let card = mount(Poll(kind: .text, code: "t", question: "Q", options: [])).card
        let input = try XCTUnwrap(card.input)
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 378, height: 800))
        card.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(card)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            card.topAnchor.constraint(equalTo: host.topAnchor)
        ])
        host.layoutIfNeeded()
        XCTAssertEqual(input.frame.height, 52, accuracy: 0.5)
        XCTAssertEqual(card.submitButton?.frame.height ?? 0, 52, accuracy: 0.5)
        XCTAssertEqual((card.submitButton?.frame.minY ?? 0) - input.frame.maxY, 12, accuracy: 0.5, "the button 12 under the field")

        input.text = String(repeating: "Очень длинный ответ ", count: 3)
        card.textViewDidChange(input)
        XCTAssertGreaterThan(input.frame.height, 52, "a second line — taller")
        XCTAssertEqual(card.frame.height, card.stack.frame.height + 40, accuracy: 0.5, "and the card with it")
        input.text = String(repeating: "Очень длинный ответ ", count: 30)
        card.textViewDidChange(input)
        XCTAssertEqual(input.frame.height, 120, accuracy: 0.5, "then it scrolls")
    }
}

// MARK: - Holding the slide, touches

extension PersonalizationStoriesPollsTests {

    func testTheSlideIsHeldWhileTheCardIsTouched() {
        let (card, _, events) = mount(miniPoll(.multipleChoice))
        card.controller.isPressed = true
        XCTAssertEqual(events.holds, [true])
        card.controller.isPressed = false
        XCTAssertEqual(events.holds, [true, false])
    }

    func testTheSlideIsHeldWhileTheFieldIsFocused() throws {
        let (card, _, events) = mount(miniPoll(.text))
        let input = try XCTUnwrap(card.input)
        card.textViewDidBeginEditing(input)
        XCTAssertEqual(events.holds, [true])
        card.controller.isPressed = true
        card.controller.isPressed = false
        XCTAssertEqual(events.holds, [true], "still focused")
        card.textViewDidEndEditing(input)
        XCTAssertEqual(events.holds, [true, false])
    }

    func testTheSlideIsHeldWhileSendingAndGoesOnAfter() {
        let (card, transport, events) = mount(scalePoll(.nps))
        card.cells[10].sendActions(for: .touchUpInside)
        XCTAssertEqual(events.holds, [true])
        transport.resolve(0)
        XCTAssertEqual(events.holds, [true, false])
    }

    func testAFailedSendReleasesTheSlideToo() throws {
        let (card, transport, events) = mount(miniPoll(.text))
        let input = try XCTUnwrap(card.input)
        card.textViewDidBeginEditing(input)
        input.text = "Книга"
        card.textViewDidChange(input)
        card.submitButton?.sendActions(for: .touchUpInside)
        card.textViewDidEndEditing(input)
        XCTAssertEqual(events.holds, [true], "focus left, the answer is still on its way")
        transport.reject(0)
        XCTAssertEqual(events.holds, [true, false])
    }

    /// The web's "resumes the timer after the text is sent": the field gives the focus away, the
    /// send holds the slide, the answer lets it go.
    func testTheSlideGoesOnAfterTheTextIsSent() throws {
        let (card, transport, events) = mount(miniPoll(.text))
        let window = try hosted(card)
        defer { window.isHidden = true }
        events.holds = []
        let input = try XCTUnwrap(card.input)
        XCTAssertTrue(input.becomeFirstResponder())
        XCTAssertEqual(events.holds, [true])
        input.text = "Книга"
        card.textViewDidChange(input)
        try XCTUnwrap(card.submitButton).sendActions(for: .touchUpInside)
        XCTAssertFalse(card.isEditing)
        XCTAssertEqual(events.holds, [true], "the send holds the slide")
        transport.resolve(0, .init(answer: .init(text: "Книга")))
        XCTAssertNil(card.input)
        XCTAssertEqual(events.holds, [true, false])
    }

    func testARemovedCardDoesNotReleaseTheSlide() {
        let (card, _, events) = mount(miniPoll(.text))
        card.controller.isPressed = true
        card.controller.detach()
        card.controller.isPressed = false
        XCTAssertEqual(events.holds, [true], "the viewer takes the pause off with the slide change")
    }

    func testTheCardTakesItsTouchesAwayFromTheSlide() {
        let (card, _, _) = mount(miniPoll(.multipleChoice))
        XCTAssertEqual(card.press.minimumPressDuration, 0, "the press begins at once")
        XCTAssertFalse(card.press.cancelsTouchesInView, "chips and the button still get their taps")
        let slide = UIView()
        slide.addSubview(card)
        let outside: [UIGestureRecognizer] = [UIPanGestureRecognizer(), UITapGestureRecognizer(), UILongPressGestureRecognizer()]
        outside.forEach(slide.addGestureRecognizer)
        for gesture in outside {
            XCTAssertTrue(card.gestureRecognizer(card.press, shouldBeRequiredToFailBy: gesture), "\(type(of: gesture)) waits for the card")
        }
        let inner = UIPanGestureRecognizer()
        card.scroll.addGestureRecognizer(inner)
        XCTAssertFalse(card.gestureRecognizer(card.press, shouldBeRequiredToFailBy: inner), "the card's own scroll is not blocked")
        XCTAssertTrue(card.gestureRecognizer(card.press, shouldRecognizeSimultaneouslyWith: inner))
        XCTAssertFalse(card.gestureRecognizer(card.press, shouldRecognizeSimultaneouslyWith: outside[0]))
    }

    func testAnAnswerAfterTheCardLeftGoesOnlyToTheStore() {
        let (card, transport, events) = mount(miniPoll(.singleChoice))
        card.optionRows[1].sendActions(for: .touchUpInside)
        XCTAssertEqual(events.holds, [true])
        card.controller.detach()
        transport.resolve(0, .init(answer: .init(optionIds: [2])))
        XCTAssertEqual(events.holds, [true], "no hold change from a card that is gone")
        XCTAssertTrue(card.optionRows.allSatisfy(\.isUserInteractionEnabled), "no redraw either")
        XCTAssertEqual(StoryPollStore.shared.sentEntry(card.controller.place)?.answer, .init(optionIds: [2]))

        card.controller.attach()
        XCTAssertEqual(events.holds, [true, false], "back on screen: the current hold")
        XCTAssertEqual(card.controller.mode, .answered)
        XCTAssertFalse(card.optionRows.contains(where: \.isUserInteractionEnabled), "the answer is drawn on return")
    }

    func testTheAnswerOfThisRunWinsAndIsKeptWhenTheCardIsGone() {
        var transport: FakePollTransport?
        autoreleasepool {
            let mounted = mount(miniPoll(.singleChoice))
            mounted.card.optionRows[0].sendActions(for: .touchUpInside)
            transport = mounted.transport
        }
        transport?.resolve(0, .init(answer: .init(optionIds: [1]), results: .init(total: 1, options: [.init(id: 1, percent: 100)])))
        let place = StoryPollStore.Place(shopId: "shop", did: "", poll: miniPoll(.singleChoice), storyId: "5", slideId: "101")
        XCTAssertEqual(StoryPollStore.shared.sentEntry(place)?.answer, .init(optionIds: [1]), "the card is gone, the answer is kept")

        // What the web's cached feed element becomes after a send: it is not reloaded.
        let again = mount(miniPoll(.singleChoice, answer: .init(optionIds: [2])))
        XCTAssertEqual(again.card.controller.mode, .answered)
        XCTAssertEqual(selectedRows(again.card), [1])
        XCTAssertEqual(again.card.optionRows[0].percentLabel.text, "100%")

        XCTAssertEqual(mount(miniPoll(.singleChoice), slideId: "102").card.controller.mode, .form, "per slide, like the web's key")
        XCTAssertEqual(mount(miniPoll(.singleChoice), storyId: "6").card.controller.mode, .form, "per story")
        XCTAssertEqual(mount(miniPoll(.singleChoice), did: "other").card.controller.mode, .form, "per device")
        XCTAssertEqual(mount(scalePoll(.nps)).card.controller.mode, .form, "per type and code")
    }
}

// MARK: - Saved on the device

extension PersonalizationStoriesPollsTests {

    private func suite() -> UserDefaults {
        let name = "polls-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        return defaults
    }

    private var savedKey: String { "stories_poll_d1_mini_poll_gift_recipient_5_101" }

    /// After a send the answer is saved under `stories_poll_{did}_{type}_{code}_{story}_{slide}` with
    /// its results and the time, like the web's `writePollAnswer`.
    func testASentAnswerIsSavedOnTheDeviceUnderTheWebsKey() throws {
        let defaults = suite()
        let clock = Date(timeIntervalSince1970: 1_700_000_000)
        StoryPollStore.shared.now = { clock }
        defer { StoryPollStore.shared.now = Date.init }
        let (card, transport, _) = mount(miniPoll(.singleChoice), did: "d1", defaults: defaults)
        card.optionRows[1].sendActions(for: .touchUpInside)
        transport.resolve(0, .init(answer: .init(optionIds: [2]), results: .init(total: 3, options: [.init(id: 2, percent: 100)])))

        let raw = try XCTUnwrap(defaults.string(forKey: savedKey))
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        XCTAssertEqual(record["saved_at"] as? Double, 1_700_000_000_000)
        XCTAssertEqual((record["answer"] as? [String: Any])?["option_ids"] as? [Int], [2])
        XCTAssertEqual(((record["results"] as? [String: Any])?["options"] as? [[String: Any]])?.first?["percent"] as? Double, 100)
    }

    /// The feed's answer wins over the saved one; the saved one wins over nothing.
    func testTheFeedWinsOverTheSavedAnswerAndTheSavedOneOverNothing() throws {
        let defaults = suite()
        let now = Date().timeIntervalSince1970 * 1000
        defaults.set(#"{"answer":{"option_ids":[3]},"results":{"total":2,"options":[{"id":3,"percent":50}]},"saved_at":\#(now)}"#, forKey: savedKey)

        let saved = mount(miniPoll(.singleChoice), did: "d1", defaults: defaults).card
        XCTAssertEqual(saved.controller.mode, .answered, "the feed knows no answer of an anonymous user — the saved one")
        XCTAssertEqual(selectedRows(saved), [3])
        XCTAssertEqual(saved.controller.results?.percent(of: 3), 50)

        let feed = mount(miniPoll(.singleChoice, answer: .init(optionIds: [1]), results: answered.results), did: "d1", defaults: defaults).card
        XCTAssertEqual(selectedRows(feed), [1], "the feed's answer wins")
        XCTAssertEqual(feed.controller.results, answered.results)

        XCTAssertEqual(mount(miniPoll(.singleChoice), did: "", defaults: defaults).card.controller.mode, .form,
                       "without a did nothing is read: the answer of another user must not show")
    }

    func testAnExpiredOrUndatedRecordIsDroppedOnRead() {
        let defaults = suite()
        let now = Date().timeIntervalSince1970 * 1000
        let day = 24 * 60 * 60 * 1000.0
        defaults.set(#"{"answer":{"option_ids":[3]},"saved_at":\#(now - 91 * day)}"#, forKey: savedKey)
        XCTAssertEqual(mount(miniPoll(.singleChoice), did: "d1", defaults: defaults).card.controller.mode, .form, "older than 90 days")
        XCTAssertNil(defaults.string(forKey: savedKey), "and deleted")

        defaults.set(#"{"answer":{"option_ids":[3]}}"#, forKey: savedKey)
        XCTAssertEqual(mount(miniPoll(.singleChoice), did: "d1", defaults: defaults).card.controller.mode, .form, "no date")
        XCTAssertNil(defaults.string(forKey: savedKey))

        defaults.set(#"{"answer":{"option_ids":[3]},"saved_at":\#(now - 89 * day)}"#, forKey: savedKey)
        XCTAssertEqual(mount(miniPoll(.singleChoice), did: "d1", defaults: defaults).card.controller.mode, .answered, "89 days — still kept")
    }

    /// A record that cannot be read — not JSON, not an object, no `answer` object, not a string —
    /// is deleted on read too.
    func testAnUnparseableRecordIsDeletedOnRead() {
        let defaults = suite()
        let now = Date().timeIntervalSince1970 * 1000
        for broken in ["{not json", "[1,2]", #"{"answer":5,"saved_at":\#(now)}"#, #"{"saved_at":\#(now)}"#, 42] as [Any] {
            defaults.set(broken, forKey: savedKey)
            XCTAssertEqual(mount(miniPoll(.singleChoice), did: "d1", defaults: defaults).card.controller.mode, .form, "\(broken)")
            XCTAssertNil(defaults.object(forKey: savedKey), "\(broken) is deleted")
        }
    }

    func testNothingIsSavedWithoutADid() {
        let defaults = suite()
        let (card, transport, _) = mount(miniPoll(.singleChoice), did: "", defaults: defaults)
        card.optionRows[0].sendActions(for: .touchUpInside)
        transport.resolve(0)
        XCTAssertTrue(defaults.dictionaryRepresentation().keys.allSatisfy { !$0.hasPrefix("stories_poll") })
    }
}

// MARK: - The question of the band

extension PersonalizationStoriesPollsTests {

    private var followupBands: [Poll.Band] {
        [.init(from: 0, to: 6, question: " Что улучшить? ", success: "Спасибо, мы станем лучше"),
         .init(from: 7, to: 8, question: "  ", success: "Спасибо!"),
         .init(from: 9, to: 10, success: "Спасибо, рады стараться!")]
    }

    /// The rate of a band with a question: the question, a field for up to 5000 characters and a
    /// button; the comment goes with the same rate, then the band's success.
    func testTheQuestionOfTheBandAsksForACommentWithTheSameRate() throws {
        let (card, transport, _) = mount(scalePoll(.nps, bands: followupBands), language: .ru)
        card.cells[3].sendActions(for: .touchUpInside)
        transport.resolve(0)
        XCTAssertEqual(card.controller.commentQuestion, "Что улучшить?", "trimmed")
        XCTAssertEqual(card.followupLabel?.text, "Что улучшить?")
        let input = try XCTUnwrap(card.input)
        XCTAssertNil(input.placeholder, "no placeholder")
        XCTAssertEqual(card.counter?.text, "0/5000")
        let submit = try XCTUnwrap(card.submitButton)
        XCTAssertEqual(submit.title.text, "Отправить", "the button's own localized label")
        XCTAssertFalse(submit.isEnabled)
        XCTAssertNil(card.thanksLabel, "the success comes after the comment")

        input.text = "  Быстрее  "
        card.textViewDidChange(input)
        XCTAssertEqual(card.counter?.text, "11/5000")
        XCTAssertTrue(submit.isEnabled)
        submit.sendActions(for: .touchUpInside)
        XCTAssertEqual(transport.calls.count, 2)
        XCTAssertEqual(transport.json(1),
                       #"{"category":"delivery","channel":"stories","comment":"Быстрее","rate":3,"source_id":"5","source_item_id":"101","source_type":"stories"}"#)
        transport.resolve(1)
        XCTAssertEqual(card.controller.answer, .init(rate: 3, comment: "Быстрее"))
        XCTAssertNil(card.input)
        XCTAssertEqual(card.thanksLabel?.text, "Спасибо, мы станем лучше")
    }

    func testABandWithoutAQuestionShowsTheSuccessAtOnce() {
        let (card, transport, _) = mount(scalePoll(.nps, bands: followupBands))
        card.cells[7].sendActions(for: .touchUpInside)
        transport.resolve(0)
        XCTAssertNil(card.controller.commentQuestion, "a question of spaces is none")
        XCTAssertNil(card.input)
        XCTAssertEqual(card.thanksLabel?.text, "Спасибо!")
        XCTAssertEqual(transport.json(0), #"{"category":"delivery","channel":"stories","rate":7,"source_id":"5","source_item_id":"101","source_type":"stories"}"#)
    }

    func testTheCommentIsLimitedTo5000AndAFailedSendKeepsIt() throws {
        let (card, transport, _) = mount(scalePoll(.csat, bands: [.init(from: 1, to: 5, question: "Почему?", success: "Ок")], answer: .init(rate: 2)))
        let input = try XCTUnwrap(card.input, "a rate without a comment asks again")
        input.text = String(repeating: "я", count: 5005)
        card.textViewDidChange(input)
        XCTAssertEqual(input.text.count, 5000)
        XCTAssertEqual(card.counter?.text, "5000/5000")
        card.submitButton?.sendActions(for: .touchUpInside)
        XCTAssertEqual(transport.calls[0].body["rate"] as? Int, 2)
        XCTAssertEqual(transport.calls[0].body["campaign"] as? String, "delivery")
        transport.reject(0)
        XCTAssertFalse(card.errorLabel?.isHidden ?? true)
        XCTAssertEqual(card.controller.fieldText.count, 5000, "the comment stays for a retry")
        XCTAssertEqual(card.submitButton?.isEnabled, true)
    }

    /// Leaving without a comment is allowed: the next show asks again; a comment of the feed ends it.
    func testTheQuestionComesBackUntilThereIsAComment() {
        let bands = followupBands
        var transport: FakePollTransport?
        autoreleasepool {
            let mounted = mount(scalePoll(.nps, bands: bands))
            mounted.card.cells[2].sendActions(for: .touchUpInside)
            transport = mounted.transport
        }
        transport?.resolve(0)
        let again = mount(scalePoll(.nps, bands: bands)).card
        XCTAssertEqual(again.controller.answer, .init(rate: 2))
        XCTAssertNotNil(again.input, "the comment is missing — the question again")

        StoryPollStore.shared.removeAll()
        let commented = mount(scalePoll(.nps, bands: bands, answer: .init(rate: 2, comment: "Долго"))).card
        XCTAssertNil(commented.input)
        XCTAssertEqual(commented.thanksLabel?.text, "Спасибо, мы станем лучше")
    }

    /// Answering the scale again sends the new rate without a comment, and the question is back.
    func testAReanswerSendsTheRateWithoutTheCommentAndAsksAgain() throws {
        let (card, transport, _) = mount(scalePoll(.nps, bands: followupBands, allowReanswer: true, answer: .init(rate: 9, comment: "Всё отлично")))
        XCTAssertNil(card.input)
        try XCTUnwrap(card.reanswerLink).sendActions(for: .touchUpInside)
        card.cells[1].sendActions(for: .touchUpInside)
        XCTAssertNil(transport.calls[0].body["comment"])
        transport.resolve(0)
        XCTAssertEqual(card.controller.answer, .init(rate: 1))
        XCTAssertNotNil(card.input)
        XCTAssertNotNil(card.reanswerLink, "re-answer stays under the question")
    }

    func testTheSlideIsHeldWhileTheCommentIsTypedOrSent() throws {
        let (card, transport, events) = mount(scalePoll(.nps, bands: followupBands, answer: .init(rate: 1)))
        let window = try hosted(card)
        defer {
            card.dismissKeyboard()
            window.isHidden = true
        }
        events.holds = []
        let input = try XCTUnwrap(card.input)
        XCTAssertTrue(input.becomeFirstResponder())
        XCTAssertEqual(events.holds, [true])
        input.text = "Ок"
        card.textViewDidChange(input)
        card.submitButton?.sendActions(for: .touchUpInside)
        XCTAssertEqual(events.holds, [true], "the send takes over the hold of the focus")
        transport.resolve(0)
        XCTAssertEqual(events.holds, [true, false])
    }

    /// No story id — no source; an empty slide id is left out.
    func testTheSourceNeedsAStory() {
        XCTAssertTrue(StoryPollController.source(storyId: "", slideId: "1").isEmpty)
        XCTAssertEqual(StoryPollController.source(storyId: "5", slideId: "").count, 2)
        let (card, transport, _) = mount(miniPoll(.singleChoice), storyId: "", slideId: "")
        card.optionRows[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(transport.json(0), #"{"option_ids":[1]}"#)
    }
}

// MARK: - In the viewer

extension PersonalizationStoriesPollsTests {

    private func viewer(
        slides: [PersonalizationStorySlide],
        transport: PersonalizationStoryPollTransport?
    ) throws -> (PersonalizationStoriesViewController, PersonalizationStoryPageViewController, UIWindow) {
        let viewer = PersonalizationStoriesViewController(stories: [PersonalizationStory(id: "5", name: "S", slides: slides)])
        viewer.pollTransport = transport
        viewer.pollShopId = "shop"
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = viewer
        window.isHidden = false
        viewer.loadViewIfNeeded()
        let page = try XCTUnwrap(viewer.pager.viewControllers?.first as? PersonalizationStoryPageViewController)
        page.loadViewIfNeeded()
        viewer.settle(on: page)
        return (viewer, page, window)
    }

    func testThePollPauseComesOffWithTheSlideChangeAndALateAnswerTouchesNothing() throws {
        let transport = FakePollTransport()
        let slides = [
            PersonalizationStorySlide(id: "1", kind: .content, poll: miniPoll(.singleChoice)),
            PersonalizationStorySlide(id: "2", kind: .content)
        ]
        let (viewer, page, window) = try viewer(slides: slides, transport: transport)
        defer {
            viewer.close()
            window.isHidden = true
        }
        let card = try XCTUnwrap(page.slideView?.pollView)
        XCTAssertNotNil(card.window)

        card.controller.isPressed = true
        XCTAssertTrue(viewer.state.pauses.contains(.poll))
        card.controller.isPressed = false
        XCTAssertFalse(viewer.state.pauses.contains(.poll), "released — the slide goes on")

        card.optionRows[0].sendActions(for: .touchUpInside)
        XCTAssertTrue(viewer.state.pauses.contains(.poll), "held while sending")
        viewer.apply(.showSlide(1))
        XCTAssertFalse(viewer.state.pauses.contains(.poll), "a slide change takes the pause off")
        XCTAssertNil(card.window)

        transport.resolve(0)
        XCTAssertFalse(viewer.state.pauses.contains(.poll), "the late answer does not hold the next slide")
        XCTAssertNotNil(StoryPollStore.shared.sentEntry(.init(shopId: "shop", did: "", poll: miniPoll(.singleChoice), storyId: "5", slideId: "1")),
                        "it is stored")

        viewer.apply(.showSlide(0))
        let back = try XCTUnwrap(page.slideView?.pollView)
        XCTAssertEqual(back.controller.mode, .answered, "back on the slide — the answer is there")
    }

    func testReleasingTheCardKeepsOtherPauses() throws {
        let slides = [PersonalizationStorySlide(id: "1", kind: .content, poll: miniPoll(.singleChoice))]
        let (viewer, page, window) = try viewer(slides: slides, transport: FakePollTransport())
        defer {
            viewer.close()
            window.isHidden = true
        }
        let card = try XCTUnwrap(page.slideView?.pollView)
        viewer.setPaused(.host, true)
        card.controller.isPressed = true
        XCTAssertTrue(viewer.state.pauses.isSuperset(of: [.host, .poll]))
        card.controller.isPressed = false
        XCTAssertFalse(viewer.state.pauses.contains(.poll))
        XCTAssertTrue(viewer.state.pauses.contains(.host), "only the poll's own pause comes off")
        XCTAssertFalse(viewer.state.isRunning)
    }

    func testNoTransportNoPollAndTheSessionGivesTheV3Client() throws {
        let slides = [PersonalizationStorySlide(id: "1", kind: .content, poll: miniPoll(.singleChoice))]
        let (plain, page, window) = try viewer(slides: slides, transport: nil)
        defer {
            plain.close()
            window.isHidden = true
        }
        XCTAssertNil(page.slideView?.pollView, "without a transport the poll is not drawn")

        let story = PersonalizationStory(id: "5", name: "S", slides: slides)
        let v3 = StoriesSession(sdk: FakeSDK(shopId: "shop"), code: "b", v3Domain: "app.test").makeViewer(stories: [story], startIndex: 0)
        XCTAssertTrue(v3.pollTransport is StoriesPollsApi)
        XCTAssertEqual(v3.pollShopId, "shop")
        XCTAssertEqual(v3.pollDeviceId(), "fake-device-id", "answers are saved under the SDK's did")
        XCTAssertNil(StoriesSession(sdk: FakeSDK(), code: "b").makeViewer(stories: [story], startIndex: 0).pollTransport, "the old API has no polls")
        let old = StoriesSession(sdk: FakeSDK(), code: "b")
        old.pollTransport = FakePollTransport()
        XCTAssertNil(old.makeViewer(stories: [story], startIndex: 0).pollTransport, "not even with the host's own transport")

        let fake = FakePollTransport()
        let session = StoriesSession(sdk: FakeSDK(shopId: "shop"), code: "b", v3Domain: "app.test")
        session.pollTransport = fake
        XCTAssertTrue(session.makeViewer(stories: [story], startIndex: 0).pollTransport as? FakePollTransport === fake)
    }

    func testATapBesideTheCardOnlyHidesTheKeyboard() throws {
        let slides = [PersonalizationStorySlide(id: "1", kind: .content, poll: miniPoll(.text)), PersonalizationStorySlide(id: "2", kind: .content)]
        let (viewer, page, window) = try viewer(slides: slides, transport: FakePollTransport())
        defer {
            viewer.close()
            window.isHidden = true
        }
        let card = try XCTUnwrap(page.slideView?.pollView)
        window.makeKey()
        guard card.input?.becomeFirstResponder() == true else { throw XCTSkip("no first responder in this host") }
        XCTAssertTrue(viewer.isPollEditing)
        XCTAssertFalse(viewer.pagerScrollView?.isScrollEnabled ?? true, "no swipes between stories while typing")
        viewer.handleTap(at: 390, width: 402, from: page)
        XCTAssertEqual(page.slideIndex, 0, "the tap did not page")
        XCTAssertFalse(card.isEditing, "the keyboard is gone")
    }

    func testTheCardSitsOnItsOffsetAndStaysInsideTheSlide() throws {
        func layout(_ poll: PersonalizationStoryPoll, buttons: [PersonalizationStorySlide.Button] = [], width: CGFloat = 402)
            -> (slide: PersonalizationStorySlideView, card: PersonalizationStoryPollView) {
            let slide = PersonalizationStorySlideView(
                slide: PersonalizationStorySlide(id: "1", kind: .content, buttons: buttons, poll: poll),
                texts: .init(), isMuted: true, imageLoader: { _, _ in }
            )
            let card = mount(poll).card
            slide.attachPoll(card)
            slide.frame = CGRect(x: 0, y: 0, width: width, height: 874)
            slide.layoutIfNeeded()
            return (slide, card)
        }
        let middle = layout(miniPoll(.singleChoice, yOffset: 35)).card
        XCTAssertEqual(middle.frame.minY, 874 * 0.35, accuracy: 0.5, "y_offset is a share of the slide, like text blocks")
        XCTAssertEqual(middle.frame.minX, 12, "12 from the edges of the slide")
        XCTAssertEqual(middle.frame.width, 402 - 24)

        let low = layout(miniPoll(.singleChoice, yOffset: 90)).card
        XCTAssertEqual(low.frame.maxY, 874 - 16, accuracy: 0.5, "too low — it moves up, whole")
        XCTAssertEqual(low.frame.height, low.stack.frame.height + 40, accuracy: 0.5, "not squeezed")
        let scale = layout(Poll(kind: .scale(.csat), code: "c", question: "Как вам наш магазин?", yOffset: 90)).card
        scale.superview?.layoutIfNeeded()
        XCTAssertEqual(scale.frame.height, scale.stack.frame.height + 40, accuracy: 0.5, "a scale at the bottom keeps its question")
        XCTAssertGreaterThan(scale.stack.arrangedSubviews.first?.frame.height ?? 0, 10)

        let top = layout(miniPoll(.singleChoice, yOffset: 0)).card
        XCTAssertEqual(top.frame.minY, 0, accuracy: 0.5, "the top of the slide, under the header if so")
        XCTAssertEqual(layout(miniPoll(.singleChoice, yOffset: nil)).card.frame.minY, 0, accuracy: 0.5, "no y_offset — 0")
        XCTAssertEqual(layout(miniPoll(.singleChoice, yOffset: -20)).card.frame.minY, 0, accuracy: 0.5, "clamped to 0")
        XCTAssertEqual(layout(miniPoll(.singleChoice, yOffset: 150)).card.frame.maxY, 874 - 16, accuracy: 0.5, "clamped to 100, inside")

        let withButton = layout(miniPoll(.singleChoice, yOffset: 90), buttons: [.init(title: "Buy")])
        XCTAssertEqual(withButton.card.frame.maxY, 874 - 16, accuracy: 0.5, "16 above the bottom of the slide, as the web")

        // The share is of the whole slide; the safe area keeps the card above the home indicator.
        func inset(_ yOffset: CGFloat) -> PersonalizationStoryPollView {
            let poll = miniPoll(.singleChoice, yOffset: yOffset)
            let slide = PersonalizationStorySlideView(slide: PersonalizationStorySlide(id: "1", kind: .content, poll: poll),
                                                      texts: .init(), isMuted: true, imageLoader: { _, _ in })
            slide.safeInsets = UIEdgeInsets(top: 100, left: 0, bottom: 34, right: 0)
            let card = mount(poll).card
            slide.attachPoll(card)
            slide.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
            slide.layoutIfNeeded()
            return card
        }
        XCTAssertEqual(inset(35).frame.minY, 874 * 0.35, accuracy: 0.5, "of the whole height, not of the area")
        XCTAssertEqual(inset(5).frame.minY, 874 * 0.05, accuracy: 0.5, "5% stays under the header: it keeps its offset")
        XCTAssertEqual(inset(95).frame.maxY, 874 - 34 - 16, accuracy: 0.5, "16 above the safe bottom")

        let wide = layout(miniPoll(.singleChoice), width: 1000).card
        XCTAssertEqual(wide.frame.width, 420, "not wider than 420")
        XCTAssertEqual(wide.frame.midX, 500, accuracy: 0.5)
    }

    /// The text block keeps to the area between the header and the buttons; the card keeps its
    /// `y_offset` and only the bottom of the slide, as the web's `fittedTop`.
    func testATextBlockAndAPollWithOneOffset() throws {
        func layout(_ yOffset: CGFloat, buttons: [PersonalizationStorySlide.Button] = []) throws
            -> (block: CGRect, card: CGRect, buttons: CGRect?) {
            let poll = miniPoll(.singleChoice, yOffset: yOffset)
            let slide = PersonalizationStorySlideView(
                slide: PersonalizationStorySlide(id: "1", kind: .content, buttons: buttons,
                                                 textBlocks: [.init(text: "Sale", yOffset: yOffset)], poll: poll),
                texts: .init(), isMuted: true, imageLoader: { _, _ in }
            )
            slide.safeInsets = UIEdgeInsets(top: 100, left: 0, bottom: 34, right: 0)
            slide.attachPoll(mount(poll).card)
            slide.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
            slide.layoutIfNeeded()
            let block = try XCTUnwrap(slide.subviews.first { $0 is PersonalizationStoryTextBlock })
            let card = try XCTUnwrap(slide.pollView)
            return (block.frame, card.frame, slide.subviews.compactMap { $0 as? UIStackView }.first?.frame)
        }
        for offset: CGFloat in [35, 50, 60] {
            let both = try layout(offset)
            XCTAssertEqual(both.block.minY, both.card.minY, accuracy: 0.5, "y_offset \(offset)")
        }
        let high = try layout(5)
        XCTAssertEqual(high.block.minY, 116, accuracy: 0.5, "the block moves under the header")
        XCTAssertEqual(high.card.minY, 874 * 0.05, accuracy: 0.5, "the card keeps its offset")

        let withButton = try layout(95, buttons: [.init(title: "Buy")])
        let buttons = try XCTUnwrap(withButton.buttons)
        XCTAssertEqual(withButton.block.maxY, buttons.minY - 16, accuracy: 0.5, "the block above the buttons")
        XCTAssertEqual(withButton.card.maxY, 874 - 34 - 16, accuracy: 0.5, "the card 16 above the safe bottom")
    }
}

// MARK: - Keyboard

extension PersonalizationStoriesPollsTests {

    /// The simulator's hardware keyboard hides the on-screen one, so its notifications are posted here.
    func testTheCardRisesAboveTheKeyboardAndComesBack() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        let host = UIViewController()
        window.rootViewController = host
        window.isHidden = false
        window.makeKey()
        defer { window.isHidden = true }
        let card = mount(miniPoll(.text)).card
        card.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(card)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: host.view.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: host.view.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: host.view.bottomAnchor, constant: -60)
        ])
        host.view.layoutIfNeeded()
        let input = try XCTUnwrap(card.input)
        guard input.becomeFirstResponder() else { throw XCTSkip("no first responder in this host") }
        let resting = card.frame

        let keyboard = CGRect(x: 0, y: 874 - 336, width: 402, height: 336)
        NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil, userInfo: [
            UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: keyboard),
            UIResponder.keyboardAnimationDurationUserInfoKey: 0
        ])
        let submit = try XCTUnwrap(card.submitButton)
        XCTAssertEqual(submit.convert(submit.bounds, to: window).maxY, keyboard.minY - 16, accuracy: 0.5,
                       "the field and the button are 16 above the keyboard")
        XCTAssertGreaterThan(card.keyboardLift, 0)
        XCTAssertEqual(card.frame.height, resting.height, accuracy: 0.01, "the card moves, it is not squeezed")

        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil, userInfo: [
            UIResponder.keyboardAnimationDurationUserInfoKey: 0
        ])
        XCTAssertEqual(card.transform, .identity, "back in place")
        XCTAssertEqual(card.keyboardLift, 0)

        NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil, userInfo: [
            UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: keyboard),
            UIResponder.keyboardAnimationDurationUserInfoKey: 0
        ])
        XCTAssertGreaterThan(card.keyboardLift, 0)
        card.removeFromSuperview()
        XCTAssertEqual(card.transform, .identity, "a card that left the screen is not left lifted")
        input.resignFirstResponder()
    }
}
