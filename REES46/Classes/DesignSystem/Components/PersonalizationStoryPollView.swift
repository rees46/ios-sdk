import UIKit

/// Карточка опроса на слайде сторис V2: вопрос и варианты, чипы с кнопкой, поле с кнопкой или
/// шкала; после ответа — выбранное с долями, благодарность, «ответить заново».
///
/// Логика — `StoryPollController`, здесь только вид и касания. Вид — значения JS SDK
/// (`styles.ts`) один в один, макета нет: карточка светлая и в тёмной теме, как в вебе.
///
/// Касание, начатое на карточке, слайду не достаётся: распознаватель нажатия карточки
/// срабатывает сразу, и жесты слайда, листание сторис и свайп закрытия ждут его провала.
/// Поле не даёт слайду сжаться: при клавиатуре карточка поднимается сама, чтобы поле и
/// кнопка были над ней (+16), и опускается обратно.
final class PersonalizationStoryPollView: UIView {

    /// Значения карточки — в одном месте, чтобы дизайнер поменял разом. Совпавшие со
    /// значением токена кита — из токенов.
    enum Style {
        static let card = rgb(0xFFFFFF)
        static let text = rgb(0x0B1410)
        static let border = rgb(0xE1E8E4)
        static let field = rgb(0xF4F7F5)
        static let bar = rgb(0xD9F99D)
        static let accent = rgb(0x22C55E)
        static let barSelected = rgb(0x86EFAC)
        static let chipSelected = rgb(0x0F3D2A)
        static let chipSelectedText = rgb(0xD9F99D)
        static let submitText = rgb(0x06210F)
        static let muted = rgb(0x8A9A90)
        static let doneText = rgb(0x5B6B62)
        static let link = rgb(0x0F3D2A)
        static let error = rgb(0xDC2626)

        static var cardRadius: CGFloat { PersonalizationRadius.xl5 }  // 20
        static let padding: CGFloat = 14
        static let gap: CGFloat = 10
        static let margin = PersonalizationSpacing.xl  // 16
        static let maxWidth: CGFloat = 420
        static var controlRadius: CGFloat { PersonalizationRadius.xl2 }  // 12
        static let borderWidth: CGFloat = 1.5
        static let optionInsets = UIEdgeInsets(top: 10, left: PersonalizationSpacing.lg, bottom: 10, right: PersonalizationSpacing.lg)
        static let optionGap = PersonalizationSpacing.md  // 8
        static let chipGap: CGFloat = 6
        static let chipInsets = UIEdgeInsets(top: 7, left: 11, bottom: 7, right: 11)
        static var chipRadius: CGFloat { PersonalizationRadius.rounded }
        static let submitPadding: CGFloat = 11
        static let inputHeight: CGFloat = 72
        static let inputPadding: CGFloat = 10
        /// Счётчик прижат к полю: 10 − 6.
        static let counterGap = PersonalizationSpacing.sm  // 4
        static let scaleGap: CGFloat = 3
        static var scaleRadius: CGFloat { PersonalizationRadius.md }  // 6
        static let scalePadding = PersonalizationSpacing.md  // 8
        static let ringWidth: CGFloat = 2
        static let ringOffset: CGFloat = 1
        static let doneSize: CGFloat = 38
        static let doneGap: CGFloat = 6
        static let answeredAlpha: CGFloat = 0.55
        static let sendingAlpha: CGFloat = 0.85
        static let keyboardGap = PersonalizationSpacing.xl  // 16
        static let fillDuration: TimeInterval = 0.6

        static let shadowOpacity: Float = 0.35
        static let shadowRadius: CGFloat = 15
        static let shadowOffset = CGSize(width: 0, height: 12)
        static let shadowSpread: CGFloat = -10

        static var questionFont: UIFont { font(15, .bold) }
        static var optionFont: UIFont { font(13, .semibold) }
        static var chipFont: UIFont { font(PersonalizationTypography.xsEmphasized.size, .semibold) }  // 12
        static var submitFont: UIFont { font(13, .bold) }
        static var inputFont: UIFont { font(13, .medium) }
        static var counterFont: UIFont { tabular(font(10.5, .regular)) }
        static var percentFont: UIFont { tabular(font(13, .semibold)) }
        static var scaleFont: UIFont { tabular(font(11.5, .bold)) }
        static var doneIconFont: UIFont { font(18, .heavy) }
        static var doneTextFont: UIFont { font(11.5, .regular) }
        static var thanksFont: UIFont { font(13, .semibold) }
        static var linkFont: UIFont { font(PersonalizationTypography.xsEmphasized.size, .semibold) }  // 12
        static var errorFont: UIFont { font(PersonalizationTypography.xsDefault.size, .regular) }  // 12

        /// Шрифт кита — как у текстов V2 (`PersonalizationTheme.current.font`).
        static func font(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
            PersonalizationTheme.current.font(size, weight)
        }

        /// Цифры одной ширины: проценты и оценки не пляшут.
        static func tabular(_ font: UIFont) -> UIFont {
            let setting: [UIFontDescriptor.FeatureKey: Int]
            if #available(iOS 15.0, *) {
                setting = [.type: kNumberSpacingType, .selector: kMonospacedNumbersSelector]
            } else {
                setting = [.featureIdentifier: kNumberSpacingType, .typeIdentifier: kMonospacedNumbersSelector]
            }
            return UIFont(descriptor: font.fontDescriptor.addingAttributes([.featureSettings: [setting]]), size: font.pointSize)
        }

        static func rgb(_ value: UInt32) -> UIColor {
            UIColor(
                red: CGFloat(value >> 16 & 0xFF) / 255,
                green: CGFloat(value >> 8 & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        }
    }

    let controller: StoryPollController
    /// Курсор вошёл в поле или вышел: пока он там, слайд не листается, а тап мимо карточки
    /// только прячет клавиатуру.
    var onEditingChange: ((Bool) -> Void)?
    /// Палец лёг на карточку.
    var onPress: (() -> Void)?

    let scroll = UIScrollView()
    let stack = UIStackView()
    let press = UILongPressGestureRecognizer()
    private(set) var optionRows: [PollOptionRow] = []
    private(set) var chips: [PollChip] = []
    private(set) var cells: [PollScaleCell] = []
    private(set) var submitButton: PollSubmitButton?
    private(set) var input: PollTextView?
    private(set) var counter: UILabel?
    private(set) var reanswerLink: PollLink?
    private(set) var errorLabel: UILabel?
    private(set) var thanksLabel: UILabel?
    private(set) var doneTextLabel: UILabel?
    /// Насколько карточка поднята над клавиатурой.
    private(set) var keyboardLift: CGFloat = 0
    private var keyboardTop: CGFloat?
    private var keyboardObservers: [NSObjectProtocol] = []

    init(controller: StoryPollController) {
        self.controller = controller
        super.init(frame: .zero)
        setup()
        controller.onChange = { [weak self] change in
            switch change {
            case .rebuild: self?.rebuild()
            case .update: self?.update()
            }
        }
        rebuild()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        keyboardObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// Курсор в поле карточки.
    var isEditing: Bool {
        input?.isFirstResponder ?? false
    }

    /// Убрать клавиатуру карточки; `true` — она была.
    @discardableResult
    func dismissKeyboard() -> Bool {
        guard isEditing else { return false }
        input?.resignFirstResponder()
        return true
    }
}

// MARK: - Карточка, касания, клавиатура

extension PersonalizationStoryPollView: UIGestureRecognizerDelegate {

    fileprivate func setup() {
        if #available(iOS 13.0, *) { overrideUserInterfaceStyle = .light }
        backgroundColor = Style.card
        layer.cornerRadius = Style.cardRadius
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = Style.shadowOpacity
        layer.shadowRadius = Style.shadowRadius
        layer.shadowOffset = Style.shadowOffset
        semanticContentAttribute = .unspecified

        // Не влезает между шапкой и кнопками — прокручивается внутри, а не обрезается.
        scroll.clipsToBounds = true
        scroll.layer.cornerRadius = Style.cardRadius
        scroll.alwaysBounceVertical = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Style.gap
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        let content = scroll.contentLayoutGuide
        // Высота по содержимому сильнее положения по `y_offset` (600, см. слайд), но слабее
        // сжатия текстов (750): не влезает ниже — карточка сдвигается, не влезает совсем —
        // прокручивается, а тексты не сжимаются.
        let fit = heightAnchor.constraint(equalTo: stack.heightAnchor, constant: 2 * Style.padding)
        fit.priority = UILayoutPriority(700)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: Style.padding),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Style.padding),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Style.padding),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Style.padding),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -2 * Style.padding),
            fit
        ])

        press.minimumPressDuration = 0
        press.allowableMovement = .greatestFiniteMagnitude
        press.cancelsTouchesInView = false
        press.delaysTouchesEnded = false
        press.delegate = self
        press.addTarget(self, action: #selector(pressed(_:)))
        addGestureRecognizer(press)

        let center = NotificationCenter.default
        keyboardObservers = [
            center.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] in
                self?.keyboardChanged($0, hiding: false)
            },
            center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] in
                self?.keyboardChanged($0, hiding: true)
            }
        ]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Тень CSS `0 12px 30px -10px`: размытие 30 — радиус 15, отрицательный разлёт — путь меньше карточки.
        let spread = -Style.shadowSpread
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds.insetBy(dx: spread, dy: spread),
            cornerRadius: max(0, Style.cardRadius - spread)
        ).cgPath
    }

    /// На экране — карточка снова живая; ушла (сменили слайд, закрыли просмотр) — ни
    /// перерисовки, ни удержания, клавиатура и подъём сброшены.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            controller.attach()
        } else {
            controller.detach()
            keyboardTop = nil
            keyboardLift = 0
            transform = .identity
        }
    }

    @objc private func pressed(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            controller.isPressed = true
            onPress?()
        case .ended, .cancelled, .failed:
            controller.isPressed = false
        default:
            break
        }
    }

    /// Жесты внутри карточки (поле, прокрутка) идут вместе с нажатием.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        other.view?.isDescendant(of: self) ?? false
    }

    /// Жесты снаружи — тап и удержание слайда, листание сторис, свайп закрытия — ждут провала
    /// нажатия карточки, а оно срабатывает сразу: касание с карточки до них не доходит.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === press, let view = other.view, !view.isDescendant(of: self) else { return false }
        return other is UIPanGestureRecognizer || other is UITapGestureRecognizer || other is UILongPressGestureRecognizer
    }

    // MARK: Клавиатура

    private func keyboardChanged(_ note: Notification, hiding: Bool) {
        let info = note.userInfo ?? [:]
        if hiding {
            keyboardTop = nil
        } else if let window, let end = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            let frame = window.convert(end, from: window.screen.coordinateSpace)
            keyboardTop = frame.minY < window.bounds.maxY ? frame.minY : nil
        }
        let duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
        let curve = (info[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 7
        updateLift(duration: duration, options: UIView.AnimationOptions(rawValue: curve << 16))
    }

    /// Поле и кнопка — над клавиатурой с зазором 16; без фокуса или клавиатуры — на месте.
    func updateLift(duration: TimeInterval = 0.25, options: UIView.AnimationOptions = .curveEaseInOut) {
        var lift: CGFloat = 0
        if isEditing, let keyboardTop, let window {
            let target: UIView = submitButton ?? input ?? self
            scroll.scrollRectToVisible(target.convert(target.bounds, to: scroll), animated: false)
            let bottom = target.convert(target.bounds, to: window).maxY + keyboardLift
            lift = max(0, bottom + Style.keyboardGap - keyboardTop)
        }
        guard lift != keyboardLift else { return }
        keyboardLift = lift
        UIView.animate(withDuration: duration, delay: 0, options: [options, .beginFromCurrentState]) {
            self.transform = lift == 0 ? .identity : CGAffineTransform(translationX: 0, y: -lift)
        }
    }
}

// MARK: - Содержимое

extension PersonalizationStoryPollView {

    private var poll: PersonalizationStoryPoll { controller.poll }

    /// Вид целиком: форма или отвеченное, по виду опроса.
    func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        optionRows = []
        chips = []
        cells = []
        submitButton = nil
        input = nil
        counter = nil
        reanswerLink = nil
        thanksLabel = nil
        doneTextLabel = nil
        let answered = controller.mode == .answered

        if let question = poll.question {
            stack.addArrangedSubview(Self.label(question, font: Style.questionFont, color: Style.text, alignment: .center))
        }
        switch (poll.kind, answered) {
        case (.singleChoice, false):
            buildOptions(interactive: true)
        case (.multipleChoice, false):
            buildChips()
            buildSubmit()
        case (.text, false):
            buildInput()
            buildSubmit()
        case (.scale, false):
            buildScale(interactive: true)
        case (.text, true):
            buildDone()
        case (.scale, true):
            buildScale(interactive: false)
            addThanks(poll.bandText(rate: controller.answer?.rate))
        case (_, true):
            buildOptions(interactive: false)
            addThanks(poll.thanksText)
        }
        if answered, poll.allowReanswer {
            let link = PollLink(title: controller.texts.reanswer)
            link.addTarget(self, action: #selector(reanswerTapped), for: .touchUpInside)
            let row = UIStackView(arrangedSubviews: [link])
            row.axis = .vertical
            row.alignment = .center
            stack.addArrangedSubview(row)
            reanswerLink = link
        }
        let error = Self.label(controller.texts.error, font: Style.errorFont, color: Style.error, alignment: .center)
        error.isHidden = true
        stack.addArrangedSubview(error)
        errorLabel = error
        update()
        if controller.takeFocusRequest() { input?.becomeFirstResponder() }
    }

    /// Выделение, доступность, счётчик и ошибка — без пересборки.
    func update() {
        let sending = controller.isSending
        alpha = sending ? Style.sendingAlpha : 1
        let form = controller.mode == .form
        let chosen = form ? controller.selected : Set(controller.answer?.optionIds ?? [])
        optionRows.forEach {
            $0.isSelected = chosen.contains($0.id)
            $0.isEnabled = form && !sending
        }
        chips.forEach {
            $0.isSelected = controller.selected.contains($0.id)
            $0.isEnabled = !sending
        }
        let rate = form ? controller.pressedRate : controller.answer?.rate
        cells.forEach {
            let chosen = Double($0.value) == rate
            $0.isSelected = chosen
            $0.isEnabled = form && !sending
            $0.alpha = form || chosen ? 1 : Style.answeredAlpha
        }
        submitButton?.isEnabled = controller.canSubmit && !sending
        input?.isEditable = !sending
        if let limit = poll.maxLength { counter?.text = "\(controller.text.utf16.count)/\(limit)" }
        reanswerLink?.isEnabled = !sending
        if let errorLabel {
            let show = controller.showsError
            if show, errorLabel.isHidden { UIAccessibility.post(notification: .announcement, argument: controller.texts.error) }
            errorLabel.isHidden = !show
        }
    }

    // MARK: Виды

    private func buildOptions(interactive: Bool) {
        let list = UIStackView()
        list.axis = .vertical
        list.spacing = Style.optionGap
        let results = interactive ? nil : controller.results
        for option in poll.options {
            let row = PollOptionRow(option: option, percent: results?.percent(of: option.id), interactive: interactive)
            if interactive { row.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside) }
            list.addArrangedSubview(row)
            optionRows.append(row)
        }
        stack.addArrangedSubview(list)
    }

    private func buildChips() {
        let flow = PollChipsView(gap: Style.chipGap)
        chips = poll.options.map { option in
            let chip = PollChip(option: option)
            chip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            return chip
        }
        flow.items = chips
        stack.addArrangedSubview(flow)
    }

    private func buildSubmit() {
        let button = PollSubmitButton(title: poll.submitLabel ?? controller.texts.submit)
        button.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        stack.addArrangedSubview(button)
        submitButton = button
    }

    private func buildInput() {
        let field = PollTextView()
        field.placeholder = poll.placeholder
        field.text = controller.text
        field.delegate = self
        stack.addArrangedSubview(field)
        input = field
        guard poll.maxLength != nil else { return }
        // Счётчик — у конца строки: справа, в RTL слева.
        let rightToLeft = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
        let label = Self.label("", font: Style.counterFont, color: Style.muted, alignment: rightToLeft ? .left : .right)
        stack.setCustomSpacing(Style.counterGap, after: field)
        stack.addArrangedSubview(label)
        counter = label
    }

    private func buildScale(interactive: Bool) {
        let values = poll.scaleValues
        guard let scale = poll.scale, let low = values.first, let high = values.last else { return }
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = Style.scaleGap
        for value in values {
            let cell = PollScaleCell(value: value, color: PersonalizationStoryColors.parse(
                PersonalizationStoryPoll.scaleColor(scale, value: value, min: low, max: high)
            ) ?? Style.field)
            if interactive { cell.addTarget(self, action: #selector(cellTapped(_:)), for: .touchUpInside) }
            row.addArrangedSubview(cell)
            cells.append(cell)
        }
        stack.addArrangedSubview(row)
    }

    private func buildDone() {
        let icon = Self.label("✓", font: Style.doneIconFont, color: Style.link, alignment: .center)
        icon.backgroundColor = Style.bar
        icon.layer.cornerRadius = Style.doneSize / 2
        icon.clipsToBounds = true
        icon.isAccessibilityElement = false
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: Style.doneSize),
            icon.heightAnchor.constraint(equalToConstant: Style.doneSize)
        ])
        let done = UIStackView(arrangedSubviews: [icon])
        done.axis = .vertical
        done.alignment = .center
        done.spacing = Style.doneGap
        if let thanks = poll.thanksText {
            let label = Self.label(thanks, font: Style.thanksFont, color: Style.text, alignment: .center)
            done.addArrangedSubview(label)
            thanksLabel = label
        }
        if let text = controller.answer?.text, !text.isEmpty {
            let label = Self.label(text, font: Style.doneTextFont, color: Style.doneText, alignment: .center)
            done.addArrangedSubview(label)
            doneTextLabel = label
        }
        stack.addArrangedSubview(done)
    }

    private func addThanks(_ text: String?) {
        guard let text, !text.isEmpty else { return }
        let label = Self.label(text, font: Style.thanksFont, color: Style.text, alignment: .center)
        stack.addArrangedSubview(label)
        thanksLabel = label
    }

    static func label(_ text: String, font: UIFont, color: UIColor, alignment: NSTextAlignment) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.textAlignment = alignment
        label.numberOfLines = 0
        return label
    }

    // MARK: Нажатия

    @objc private func optionTapped(_ sender: PollOptionRow) { controller.tapOption(sender.id) }
    @objc private func chipTapped(_ sender: PollChip) { controller.toggleChip(sender.id) }
    @objc private func cellTapped(_ sender: PollScaleCell) { controller.tapRate(sender.value) }
    @objc private func reanswerTapped() { controller.reanswer() }

    @objc private func submitTapped() {
        // Сначала отправка — она держит слайд, потом поле отдаёт фокус и клавиатура уходит:
        // удержание не прерывается ни на миг, как в вебе.
        controller.submit()
        input?.resignFirstResponder()
    }
}

extension PersonalizationStoryPollView: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        // Пока набирается иероглиф (marked text), строку не режем.
        let value = controller.setText(textView.text ?? "")
        if textView.markedTextRange == nil, value != textView.text { textView.text = value }
        (textView as? PollTextView)?.updatePlaceholder()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        controller.isFocused = true
        onEditingChange?(true)
        updateLift()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        controller.isFocused = false
        onEditingChange?(false)
        updateLift()
    }
}
