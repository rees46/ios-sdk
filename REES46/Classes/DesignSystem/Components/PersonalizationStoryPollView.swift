import UIKit

/// Карточка опроса на слайде сторис V2: вопрос и варианты с буквами, варианты с кнопкой, поле
/// с кнопкой или шкала-дорожка; после ответа — итоги с долями и числом голосов, благодарность,
/// «ответить заново».
///
/// Логика — `StoryPollController`, здесь только вид и касания. Карточка матовая: размытие
/// слайда под ней со светлой подложкой; светлая и в тёмной теме. Весь текст — по левому краю.
///
/// Касание, начатое на карточке, слайду не достаётся: распознаватель нажатия карточки
/// срабатывает сразу, и жесты слайда, листание сторис и свайп закрытия ждут его провала.
/// Поле не даёт слайду сжаться: при клавиатуре карточка поднимается сама, чтобы поле и
/// кнопка были над ней (+16), и опускается обратно.
final class PersonalizationStoryPollView: UIView {

    /// Значения карточки — в одном месте, чтобы дизайнер поменял разом. Совпавшие со
    /// значением токена кита — из токенов.
    enum Style {
        /// Цвет выбора и успеха опроса.
        static let accent = rgb(0x22C55E)
        static let error = rgb(0xDC2626)
        static var text: UIColor { PersonalizationColor.textPrimary }
        static var textSecondary: UIColor { PersonalizationColor.textSecondary }
        static var hint: UIColor { PersonalizationColor.textHint }
        /// Светлая подложка поверх размытия и тонкая светлая граница.
        static let tint = UIColor(white: 1, alpha: 0.8)
        static let cardBorder = UIColor(white: 1, alpha: 0.5)
        /// Подложка вариантов, дорожки шкалы и неактивной кнопки.
        static let track = UIColor(white: 0, alpha: 0.06)
        /// Полоса доли в итогах; у своего ответа — акцент.
        static let bar = UIColor(white: 0, alpha: 0.08)
        static let barMine = accent.withAlphaComponent(0.25)
        /// Заливка выбранного варианта до отправки; мой ответ в итогах — с обычной подложкой.
        static let selectedFill = accent.withAlphaComponent(0.2)
        /// Квадрат буквы и поле ввода.
        static let plate = UIColor(white: 1, alpha: 0.85)

        /// От краёв слайда.
        static let margin = PersonalizationSpacing.lg  // 12
        static let padding = PersonalizationSpacing.xl2  // 20
        static var cardRadius: CGFloat { PersonalizationRadius.xl6 }  // 24
        static let cardBorderWidth: CGFloat = 1
        static let maxWidth: CGFloat = 420
        static let dotSize: CGFloat = 6
        static let dotGap = PersonalizationSpacing.md  // 8
        /// Шапка итогов → вопрос.
        static let headerGap = PersonalizationSpacing.lg  // 12
        /// Вопрос → содержимое, содержимое → подвал или кнопка, дорожка → текст полосы.
        static let blockGap = PersonalizationSpacing.xl  // 16
        static let optionHeight: CGFloat = 56
        static var optionRadius: CGFloat { PersonalizationRadius.xl5 }  // 20
        static let optionPadding = PersonalizationSpacing.lg  // 12
        static let optionGap = PersonalizationSpacing.md  // 8
        static let letterSize: CGFloat = 32
        static var letterRadius: CGFloat { PersonalizationRadius.lg }  // 8
        static let letterGap = PersonalizationSpacing.lg  // 12
        static let selectedBorder: CGFloat = 1.5
        static let trackHeight: CGFloat = 52
        static let trackPadding = PersonalizationSpacing.sm  // 4
        static let inputHeight: CGFloat = 52
        /// Выше поле не растёт, дальше текст прокручивается.
        static let inputMaxHeight: CGFloat = 120
        static var inputRadius: CGFloat { PersonalizationRadius.xl4 }  // 16
        static let inputPadding = PersonalizationSpacing.xl  // 16
        /// Поле → кнопка, итоги → «ответить заново», содержимое → ошибка.
        static let fieldGap = PersonalizationSpacing.lg  // 12
        static let counterGap = PersonalizationSpacing.sm  // 4
        static let buttonHeight: CGFloat = 52
        static var buttonRadius: CGFloat { PersonalizationRadius.xl4 }  // 16
        static let doneSize: CGFloat = 32
        static let answeredAlpha: CGFloat = 0.55
        static let sendingAlpha: CGFloat = 0.85
        static let keyboardGap = PersonalizationSpacing.xl  // 16
        static let fillDuration: TimeInterval = 0.6

        /// Шапка итогов: прописные с разрядкой 0,08 em.
        static var headerFont: UIFont { font(PersonalizationTypography.xsEmphasized.size, .semibold) }  // 12
        static var headerTracking: CGFloat { 0.08 * PersonalizationTypography.xsEmphasized.size }
        static var questionFont: UIFont { font(PersonalizationTypography.lgEmphasized.size, .semibold) }  // 18
        static let questionLineHeight: CGFloat = 24
        static var optionFont: UIFont { font(PersonalizationTypography.baseDefault.size, .regular) }  // 16
        static var letterFont: UIFont { font(PersonalizationTypography.smEmphasized.size, .semibold) }  // 14
        static var percentFont: UIFont { tabular(font(PersonalizationTypography.baseEmphasized.size, .semibold)) }  // 16
        static var scaleFont: UIFont { tabular(font(PersonalizationTypography.baseEmphasized.size, .semibold)) }  // 16
        static var buttonFont: UIFont { font(PersonalizationTypography.baseEmphasized.size, .semibold) }  // 16
        static var inputFont: UIFont { font(PersonalizationTypography.baseDefault.size, .regular) }  // 16
        static var counterFont: UIFont { tabular(font(PersonalizationTypography.xsDefault.size, .regular)) }  // 12
        static var footerFont: UIFont { font(PersonalizationTypography.smDefault.size, .regular) }  // 14
        static var footerBoldFont: UIFont { font(PersonalizationTypography.smEmphasized.size, .semibold) }  // 14
        static var votesFont: UIFont { tabular(footerFont) }
        static var bandFont: UIFont { font(PersonalizationTypography.smDefault.size, .regular) }  // 14
        static var doneTitleFont: UIFont { font(PersonalizationTypography.baseEmphasized.size, .semibold) }  // 16
        static var doneTextFont: UIFont { font(PersonalizationTypography.smDefault.size, .regular) }  // 14
        static var linkFont: UIFont { font(PersonalizationTypography.smEmphasized.size, .semibold) }  // 14
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

        /// Текст и значки на заливке (подпись основной кнопки, галочка, выбранная цифра шкалы) —
        /// белые или тёмные, что контрастнее с заливкой (WCAG); одно правило для всех.
        static func contrastingText(on color: UIColor) -> UIColor {
            let dark = PersonalizationColor.textDarkPrimary
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return dark }
            func linear(_ value: CGFloat) -> CGFloat {
                value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
            return 1.05 / (luminance + 0.05) > (luminance + 0.05) / 0.05 ? .white : dark
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

    /// Размытие слайда под карточкой со светлой подложкой.
    let backdrop = UIVisualEffectView(effect: PersonalizationStoryPollView.material)
    let scroll = UIScrollView()
    let stack = UIStackView()
    let press = UILongPressGestureRecognizer()
    private(set) var optionRows: [PollOptionRow] = []
    private(set) var cells: [PollScaleCell] = []
    private(set) var submitButton: PollSubmitButton?
    private(set) var input: PollTextView?
    private(set) var counter: UILabel?
    private(set) var reanswerLink: PollLink?
    private(set) var errorLabel: UILabel?
    /// Шапка итогов опроса с выбором.
    private(set) var resultsLabel: UILabel?
    private(set) var questionLabel: UILabel?
    /// Благодарность: подвал итогов, текст полосы шкалы или строка отвеченного текста.
    private(set) var thanksLabel: UILabel?
    /// Число голосов в подвале итогов.
    private(set) var votesLabel: UILabel?
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

    /// Тонкий светлый материал; на iOS 12 — светлое размытие.
    private static var material: UIBlurEffect {
        if #available(iOS 13.0, *) { return UIBlurEffect(style: .systemThinMaterialLight) }
        return UIBlurEffect(style: .light)
    }
}

// MARK: - Карточка, касания, клавиатура

extension PersonalizationStoryPollView: UIGestureRecognizerDelegate {

    fileprivate func setup() {
        if #available(iOS 13.0, *) { overrideUserInterfaceStyle = .light }
        backgroundColor = .clear
        layer.cornerRadius = Style.cardRadius
        // Граница слоя рисуется поверх подслоёв — и поверх размытия.
        layer.borderWidth = Style.cardBorderWidth
        layer.borderColor = Style.cardBorder.cgColor
        semanticContentAttribute = .unspecified

        backdrop.isUserInteractionEnabled = false
        backdrop.clipsToBounds = true
        backdrop.layer.cornerRadius = Style.cardRadius
        backdrop.contentView.backgroundColor = Style.tint
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backdrop)

        // Не влезает между шапкой и кнопками — прокручивается внутри, а не обрезается.
        scroll.clipsToBounds = true
        scroll.layer.cornerRadius = Style.cardRadius
        scroll.alwaysBounceVertical = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        stack.axis = .vertical
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        let content = scroll.contentLayoutGuide
        // Высота по содержимому сильнее положения по `y_offset` (600, см. слайд), но слабее
        // сжатия текстов (750): не влезает ниже — карточка сдвигается, не влезает совсем —
        // прокручивается, а тексты не сжимаются.
        let fit = heightAnchor.constraint(equalTo: stack.heightAnchor, constant: 2 * Style.padding)
        fit.priority = UILayoutPriority(700)
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: trailingAnchor),
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

    /// Вид целиком: форма или отвеченное, по виду опроса. Сверху вниз: шапка итогов (опрос с
    /// выбором после ответа), вопрос, содержимое, подвал или благодарность, «ответить заново»,
    /// ошибка.
    func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        optionRows = []
        cells = []
        submitButton = nil
        input = nil
        counter = nil
        reanswerLink = nil
        resultsLabel = nil
        questionLabel = nil
        thanksLabel = nil
        votesLabel = nil
        doneTextLabel = nil
        let answered = controller.mode == .answered
        let choice = poll.kind == .singleChoice || poll.kind == .multipleChoice

        if answered, choice { buildResultsHeader() }
        if let question = poll.question {
            let label = Self.label(question, font: Style.questionFont, color: Style.text, lineHeight: Style.questionLineHeight)
            add(label)
            questionLabel = label
        }
        switch (poll.kind, answered) {
        case (.singleChoice, false):
            buildOptions(interactive: true)
        case (.multipleChoice, false):
            buildOptions(interactive: true)
            buildSubmit(gap: Style.blockGap)
        case (.text, false):
            buildInput()
            buildSubmit(gap: Style.fieldGap)
        case (.scale, false):
            buildScale(interactive: true)
        case (.text, true):
            buildDone()
        case (.scale, true):
            buildScale(interactive: false)
            addBandText(poll.bandText(rate: controller.answer?.rate))
        case (_, true):
            buildOptions(interactive: false)
            buildFooter()
        }
        if answered, poll.allowReanswer {
            let link = PollLink(title: controller.texts.reanswer)
            link.addTarget(self, action: #selector(reanswerTapped), for: .touchUpInside)
            let row = UIStackView(arrangedSubviews: [link])
            row.axis = .vertical
            row.alignment = .leading
            add(row, gap: Style.fieldGap)
            reanswerLink = link
        }
        let error = Self.label(controller.texts.error, font: Style.errorFont, color: Style.error)
        error.isHidden = true
        add(error, gap: Style.fieldGap)
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

    /// Следующий блок карточки: `gap` — зазор от предыдущего. По умолчанию после шапки итогов
    /// 12, после остального 16.
    private func add(_ view: UIView, gap: CGFloat? = nil) {
        if let last = stack.arrangedSubviews.last {
            stack.setCustomSpacing(gap ?? (last === resultsLabel?.superview ? Style.headerGap : Style.blockGap), after: last)
        }
        stack.addArrangedSubview(view)
    }

    // MARK: Виды

    /// Точка акцента и «РЕЗУЛЬТАТЫ».
    private func buildResultsHeader() {
        let dot = UIView()
        dot.backgroundColor = Style.accent
        dot.layer.cornerRadius = Style.dotSize / 2
        dot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: Style.dotSize),
            dot.heightAnchor.constraint(equalToConstant: Style.dotSize)
        ])
        let title = controller.texts.results
        let label = UILabel()
        label.attributedText = NSAttributedString(string: title.uppercased(), attributes: [
            .font: Style.headerFont,
            .foregroundColor: Style.textSecondary,
            .kern: Style.headerTracking
        ])
        label.accessibilityLabel = title
        label.accessibilityTraits = .header
        let row = UIStackView(arrangedSubviews: [dot, label])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Style.dotGap
        add(row)
        resultsLabel = label
    }

    /// Варианты с буквами: в форме одного выбора нажатие отправляет, в форме нескольких —
    /// переключает; в итогах — доли.
    private func buildOptions(interactive: Bool) {
        let list = UIStackView()
        list.axis = .vertical
        list.spacing = Style.optionGap
        let results = interactive ? nil : controller.results
        let action = poll.kind == .multipleChoice ? #selector(optionToggled(_:)) : #selector(optionTapped(_:))
        for (index, option) in poll.options.enumerated() {
            let row = PollOptionRow(option: option, index: index, percent: results?.percent(of: option.id), interactive: interactive)
            if interactive { row.addTarget(self, action: action, for: .touchUpInside) }
            list.addArrangedSubview(row)
            optionRows.append(row)
        }
        add(list)
    }

    private func buildSubmit(gap: CGFloat) {
        let button = PollSubmitButton(title: poll.submitLabel ?? controller.texts.submit)
        button.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        add(button, gap: gap)
        submitButton = button
    }

    private func buildInput() {
        let field = PollTextView()
        field.placeholder = poll.placeholder
        field.text = controller.text
        field.delegate = self
        add(field)
        input = field
        guard poll.maxLength != nil else { return }
        // Счётчик — у конца строки: справа, в RTL слева.
        let rightToLeft = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
        let label = Self.label("", font: Style.counterFont, color: Style.textSecondary)
        label.textAlignment = rightToLeft ? .left : .right
        add(label, gap: Style.counterGap)
        counter = label
    }

    /// Дорожка шкалы: цифры поровну, выбранная — в капсуле цвета своей полосы.
    private func buildScale(interactive: Bool) {
        let values = poll.scaleValues
        guard !values.isEmpty else { return }
        let track = UIView()
        track.backgroundColor = Style.track
        track.layer.cornerRadius = Style.trackHeight / 2
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(row)
        let inset = Style.trackPadding
        NSLayoutConstraint.activate([
            track.heightAnchor.constraint(equalToConstant: Style.trackHeight),
            row.topAnchor.constraint(equalTo: track.topAnchor, constant: inset),
            row.bottomAnchor.constraint(equalTo: track.bottomAnchor, constant: -inset),
            row.leadingAnchor.constraint(equalTo: track.leadingAnchor, constant: inset),
            row.trailingAnchor.constraint(equalTo: track.trailingAnchor, constant: -inset)
        ])
        for value in values {
            let fill = PersonalizationStoryColors.parse(poll.bandColor(of: value)) ?? Style.accent
            let cell = PollScaleCell(value: value, fill: fill)
            if interactive { cell.addTarget(self, action: #selector(cellTapped(_:)), for: .touchUpInside) }
            row.addArrangedSubview(cell)
            cells.append(cell)
        }
        add(track)
    }

    /// Отвеченный текст: кружок с галочкой, благодарность и сам ответ.
    private func buildDone() {
        let icon = UIView()
        icon.backgroundColor = Style.accent
        icon.layer.cornerRadius = Style.doneSize / 2
        icon.isAccessibilityElement = false
        let check = PollCheckView()
        check.color = Style.contrastingText(on: Style.accent)
        check.translatesAutoresizingMaskIntoConstraints = false
        icon.addSubview(check)
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: Style.doneSize),
            icon.heightAnchor.constraint(equalToConstant: Style.doneSize),
            check.topAnchor.constraint(equalTo: icon.topAnchor),
            check.bottomAnchor.constraint(equalTo: icon.bottomAnchor),
            check.leadingAnchor.constraint(equalTo: icon.leadingAnchor),
            check.trailingAnchor.constraint(equalTo: icon.trailingAnchor)
        ])
        let texts = UIStackView()
        texts.axis = .vertical
        texts.spacing = PersonalizationSpacing.xs
        if let thanks = poll.thanksText {
            let label = Self.label(thanks, font: Style.doneTitleFont, color: Style.text)
            texts.addArrangedSubview(label)
            thanksLabel = label
        }
        if let text = controller.answer?.text, !text.isEmpty {
            let label = Self.label(text, font: Style.doneTextFont, color: Style.textSecondary)
            texts.addArrangedSubview(label)
            doneTextLabel = label
        }
        let done = UIStackView(arrangedSubviews: [icon, texts])
        done.axis = .horizontal
        done.alignment = .center
        done.spacing = Style.letterGap
        add(done)
    }

    /// Текст полосы под отвеченной шкалой.
    private func addBandText(_ text: String?) {
        guard let text, !text.isEmpty else { return }
        let label = Self.label(text, font: Style.bandFont, color: Style.text)
        add(label)
        thanksLabel = label
    }

    /// Подвал итогов: слева своя благодарность опроса или «Спасибо! Голос учтён», справа число
    /// голосов (`results.total`; нет или 0 — справа пусто).
    private func buildFooter() {
        let thanks = UILabel()
        thanks.numberOfLines = 0
        thanks.textAlignment = .natural
        if let own = poll.thanksText {
            thanks.attributedText = NSAttributedString(string: own, attributes: [.font: Style.footerBoldFont, .foregroundColor: Style.text])
        } else {
            let text = NSMutableAttributedString(string: controller.texts.thanks, attributes: [
                .font: Style.footerBoldFont, .foregroundColor: Style.text
            ])
            text.append(NSAttributedString(string: " " + controller.texts.voteCounted, attributes: [
                .font: Style.footerFont, .foregroundColor: Style.textSecondary
            ]))
            thanks.attributedText = text
        }
        let row = UIStackView(arrangedSubviews: [thanks])
        row.axis = .horizontal
        row.alignment = .firstBaseline
        row.spacing = Style.optionPadding
        thanksLabel = thanks
        if let total = controller.results?.total, total > 0 {
            let votes = Self.label(controller.texts.votes(total), font: Style.votesFont, color: Style.textSecondary)
            votes.numberOfLines = 1
            votes.setContentHuggingPriority(.required, for: .horizontal)
            votes.setContentCompressionResistancePriority(.required, for: .horizontal)
            row.addArrangedSubview(votes)
            votesLabel = votes
        }
        add(row)
    }

    /// Текст карточки — по левому краю (в RTL — по правому); `lineHeight` — свой межстрочный.
    static func label(_ text: String, font: UIFont, color: UIColor, lineHeight: CGFloat? = nil) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .natural
        if let lineHeight {
            let paragraph = NSMutableParagraphStyle()
            paragraph.minimumLineHeight = lineHeight
            paragraph.maximumLineHeight = lineHeight
            label.attributedText = NSAttributedString(string: text, attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph,
                // Текст по центру строки, как у типографики кита.
                .baselineOffset: (lineHeight - font.lineHeight) / 4
            ])
        } else {
            label.text = text
            label.font = font
            label.textColor = color
        }
        return label
    }

    // MARK: Нажатия

    @objc private func optionTapped(_ sender: PollOptionRow) { controller.tapOption(sender.id) }
    @objc private func optionToggled(_ sender: PollOptionRow) { controller.toggleChip(sender.id) }
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
        guard let field = textView as? PollTextView else { return }
        field.updatePlaceholder()
        field.updateHeight()
        guard abs(field.bounds.height - field.intrinsicContentSize.height) > 0.5 else { return }
        // Поле выросло или сжалось: карточка пересчитывается сразу, кнопка остаётся над клавиатурой.
        [field.superview, stack, scroll, self].forEach { $0?.setNeedsLayout() }
        if let superview {
            superview.setNeedsLayout()
            superview.layoutIfNeeded()
        } else {
            layoutIfNeeded()
        }
        if isEditing { updateLift(duration: 0) }
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
