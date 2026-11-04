import UIKit

// Элементы карточки опроса (`PersonalizationStoryPollView`): вариант с буквой, кнопка отправки,
// ячейка шкалы, галочка, ссылка «ответить заново» и многострочное поле. Значения — `Style`
// карточки; в ките многострочного поля нет, оно своё.

private typealias Style = PersonalizationStoryPollView.Style

/// Вариант ответа: квадрат с буквой (A, B, C…) и текст. В форме — кнопка (один выбор) или
/// переключатель (несколько), в итогах — строка с долей: полоса растёт от начала строки,
/// процент у конца. Выбранный — с рамкой акцента и галочкой вместо буквы; до отправки вся строка
/// залита акцентом, мой ответ в итогах — обычная подложка и полоса акцента.
final class PollOptionRow: UIControl {

    let id: Int
    /// Доля в процентах; `nil` — результатов нет, полоски и процента тоже.
    let percent: Int?
    let title = UILabel()
    let letterLabel = UILabel()
    let percentLabel = UILabel()
    private let badge = UIView()
    private let check = PollCheckView()
    private let fill = UIView()
    private let interactive: Bool
    /// Видимая доля полоски: 0, пока не выросла.
    private(set) var shownFraction: CGFloat = 0
    private var didAnimate = false

    init(option: PersonalizationStoryPoll.Option, index: Int, percent: Int?, interactive: Bool) {
        self.id = option.id
        self.percent = percent
        self.interactive = interactive
        super.init(frame: .zero)
        layer.cornerRadius = Style.optionRadius
        layer.borderColor = Style.accent.cgColor
        clipsToBounds = true
        fill.isUserInteractionEnabled = false
        addSubview(fill)

        badge.isUserInteractionEnabled = false
        badge.layer.cornerRadius = Style.letterRadius
        letterLabel.text = Self.letter(index)
        letterLabel.font = Style.letterFont
        letterLabel.textColor = Style.textSecondary
        letterLabel.textAlignment = .center
        letterLabel.adjustsFontSizeToFitWidth = true
        letterLabel.minimumScaleFactor = 0.6
        for view in [letterLabel, check] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            badge.addSubview(view)
        }

        title.text = option.label
        title.font = Style.optionFont
        title.textColor = Style.text
        title.textAlignment = .natural
        title.numberOfLines = 2
        title.lineBreakMode = .byTruncatingTail
        percentLabel.text = percent.map { "\($0)%" }
        percentLabel.font = Style.percentFont
        percentLabel.textColor = Style.text
        percentLabel.isHidden = percent == nil
        percentLabel.setContentHuggingPriority(.required, for: .horizontal)
        percentLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        for view in [badge, title, percentLabel] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        check.color = Style.contrastingText(on: Style.accent)
        let padding = Style.optionPadding
        // Обычно 56; две строки текста — выше (сжатие текста 750 сильнее).
        let rest = heightAnchor.constraint(equalToConstant: Style.optionHeight)
        rest.priority = UILayoutPriority(749)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: Style.optionHeight),
            rest,
            badge.widthAnchor.constraint(equalToConstant: Style.letterSize),
            badge.heightAnchor.constraint(equalToConstant: Style.letterSize),
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor),
            letterLabel.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            letterLabel.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            letterLabel.widthAnchor.constraint(lessThanOrEqualTo: badge.widthAnchor, constant: -PersonalizationSpacing.sm),
            check.topAnchor.constraint(equalTo: badge.topAnchor),
            check.bottomAnchor.constraint(equalTo: badge.bottomAnchor),
            check.leadingAnchor.constraint(equalTo: badge.leadingAnchor),
            check.trailingAnchor.constraint(equalTo: badge.trailingAnchor),
            title.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: Style.letterGap),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            title.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: padding),
            title.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -padding),
            percentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            percentLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            percent == nil
                ? title.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -padding)
                : title.trailingAnchor.constraint(lessThanOrEqualTo: percentLabel.leadingAnchor, constant: -PersonalizationSpacing.md)
        ])
        isUserInteractionEnabled = interactive
        isAccessibilityElement = true
        accessibilityLabel = option.label + (percent.map { ", \($0)%" } ?? "")
        applyState()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Буква варианта: A…Z, дальше AA, AB…
    static func letter(_ index: Int) -> String {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        var value = max(0, index), result = ""
        repeat {
            result = String(letters[value % 26]) + result
            value = value / 26 - 1
        } while value >= 0
        return result
    }

    override var isSelected: Bool {
        didSet { applyState() }
    }

    override var isEnabled: Bool {
        didSet { applyState() }
    }

    /// Вместо буквы галочка — вариант выбран.
    var isCheckVisible: Bool { !check.isHidden }

    private func applyState() {
        backgroundColor = isSelected && interactive ? Style.selectedFill : Style.track
        layer.borderWidth = isSelected ? Style.selectedBorder : 0
        fill.backgroundColor = isSelected ? Style.barMine : Style.bar
        badge.backgroundColor = isSelected ? Style.accent : Style.plate
        letterLabel.isHidden = isSelected
        check.isHidden = !isSelected
        var traits: UIAccessibilityTraits = interactive ? .button : .staticText
        if isSelected { traits.insert(.selected) }
        if interactive, !isEnabled { traits.insert(.notEnabled) }
        accessibilityTraits = traits
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutFill()
        guard let percent, !didAnimate, bounds.width > 0, window != nil else { return }
        didAnimate = true
        let target = CGFloat(percent) / 100
        guard !UIAccessibility.isReduceMotionEnabled else {
            shownFraction = target
            return layoutFill()
        }
        DispatchQueue.main.async {
            UIView.animate(withDuration: Style.fillDuration, delay: 0, options: .curveEaseOut) {
                self.shownFraction = target
                self.layoutFill()
            }
        }
    }

    /// Полоска — от начала строки: слева, в RTL справа; скругление обрезает её по строке.
    private func layoutFill() {
        let width = bounds.width * shownFraction
        let rightToLeft = effectiveUserInterfaceLayoutDirection == .rightToLeft
        fill.frame = CGRect(x: rightToLeft ? bounds.width - width : 0, y: 0, width: width, height: bounds.height)
    }
}

/// Галочка по центру своего квадрата: у выбранного варианта и отвеченного текста.
final class PollCheckView: UIView {

    private let shape = CAShapeLayer()

    /// Цвет галочки — по контрасту с заливкой под ней.
    var color: UIColor = .white {
        didSet { shape.strokeColor = color.cgColor }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        shape.fillColor = nil
        shape.strokeColor = UIColor.white.cgColor
        shape.lineWidth = 2
        shape.lineCap = .round
        shape.lineJoin = .round
        layer.addSublayer(shape)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Галочка 14 × 10 в квадрате 32 — доли стороны.
        let side = min(bounds.width, bounds.height)
        let origin = CGPoint(x: bounds.midX - side / 2, y: bounds.midY - side / 2)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: origin.x + x * side, y: origin.y + y * side) }
        let path = UIBezierPath()
        path.move(to: point(0.29, 0.5))
        path.addLine(to: point(0.43, 0.64))
        path.addLine(to: point(0.71, 0.36))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.frame = bounds
        shape.path = path.cgPath
        CATransaction.commit()
    }
}

/// Кнопка отправки во всю ширину, высота 52: активная — заливка акцента, текст белый или
/// тёмный по контрасту с ней; неактивная — серая подложка.
final class PollSubmitButton: UIControl {

    let title = UILabel()

    init(title text: String) {
        super.init(frame: .zero)
        layer.cornerRadius = Style.buttonRadius
        title.text = text
        title.font = Style.buttonFont
        title.textAlignment = .center
        title.numberOfLines = 0
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)
        let inset = Style.optionPadding
        // Обычно 52; длинная подпись в две строки — выше (сжатие текста 750 сильнее).
        let rest = heightAnchor.constraint(equalToConstant: Style.buttonHeight)
        rest.priority = UILayoutPriority(749)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: Style.buttonHeight),
            rest,
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            title.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: PersonalizationSpacing.md),
            title.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -PersonalizationSpacing.md),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset)
        ])
        isAccessibilityElement = true
        accessibilityLabel = text
        applyState()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isEnabled: Bool {
        didSet { applyState() }
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.8 : 1 }
    }

    private func applyState() {
        backgroundColor = isEnabled ? Style.accent : Style.track
        title.textColor = isEnabled ? Style.contrastingText(on: Style.accent) : Style.textSecondary
        accessibilityTraits = isEnabled ? .button : [.button, .notEnabled]
    }
}

/// Цифра на дорожке шкалы; выбранная — в капсуле на всю высоту дорожки, цвета своей полосы,
/// цифра белая или тёмная — что контрастнее.
final class PollScaleCell: UIControl {

    let value: Int
    let title = UILabel()
    /// Заливка капсулы выбранной цифры.
    let fillColor: UIColor
    private let capsule = UIView()

    init(value: Int, fill: UIColor) {
        self.value = value
        self.fillColor = fill
        super.init(frame: .zero)
        capsule.isUserInteractionEnabled = false
        capsule.backgroundColor = fill
        capsule.isHidden = true
        addSubview(capsule)
        title.text = String(value)
        title.font = Style.scaleFont
        title.textAlignment = .center
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.6
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)
        NSLayoutConstraint.activate([
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: PersonalizationSpacing.xs),
            title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -PersonalizationSpacing.xs)
        ])
        isAccessibilityElement = true
        accessibilityLabel = String(value)
        applyState()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isSelected: Bool {
        didSet { applyState() }
    }

    override var isEnabled: Bool {
        didSet { applyState() }
    }

    /// Капсула выбранной цифры видна.
    var isCapsuleVisible: Bool { !capsule.isHidden }

    private func applyState() {
        capsule.isHidden = !isSelected
        title.textColor = isSelected ? Style.contrastingText(on: fillColor) : Style.text
        var traits: UIAccessibilityTraits = .button
        if isSelected { traits.insert(.selected) }
        if !isEnabled { traits.insert(.notEnabled) }
        accessibilityTraits = traits
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        capsule.frame = bounds
        capsule.layer.cornerRadius = min(bounds.width, bounds.height) / 2
    }
}

/// Ссылка «ответить заново»: подчёркнутый текст по левому краю.
final class PollLink: UIControl {

    let title = UILabel()

    init(title text: String) {
        super.init(frame: .zero)
        title.attributedText = NSAttributedString(string: text, attributes: [
            .font: Style.linkFont,
            .foregroundColor: Style.text,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ])
        title.textAlignment = .natural
        title.numberOfLines = 0
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: PersonalizationSpacing.xs),
            title.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -PersonalizationSpacing.xs),
            title.leadingAnchor.constraint(equalTo: leadingAnchor),
            title.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        isAccessibilityElement = true
        accessibilityLabel = text
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }
}

/// Многострочное поле текстового опроса с подсказкой: высота от 52 растёт с текстом до 120,
/// дальше текст прокручивается.
final class PollTextView: UITextView {

    private let placeholderLabel = UILabel()
    /// Высота по тексту — собственный размер поля: стек карточки пересчитывается сам.
    private var fittingHeight = Style.inputHeight

    var placeholder: String? {
        didSet {
            placeholderLabel.text = placeholder
            accessibilityLabel = placeholder
            updatePlaceholder()
        }
    }

    override var text: String! {
        didSet {
            updatePlaceholder()
            updateHeight()
        }
    }

    init() {
        super.init(frame: .zero, textContainer: nil)
        font = Style.inputFont
        textColor = Style.text
        backgroundColor = Style.plate
        tintColor = Style.accent
        layer.cornerRadius = Style.inputRadius
        let inset = Style.inputPadding
        textContainerInset = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        textContainer.lineFragmentPadding = 0
        keyboardAppearance = .light
        placeholderLabel.font = Style.inputFont
        placeholderLabel.textColor = Style.hint
        placeholderLabel.numberOfLines = 0
        placeholderLabel.isAccessibilityElement = false
        addSubview(placeholderLabel)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    var isPlaceholderVisible: Bool { !placeholderLabel.isHidden }

    func updatePlaceholder() {
        placeholderLabel.isHidden = !(text ?? "").isEmpty
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: fittingHeight)
    }

    /// Высота по тексту в пределах 52...120; `true` — изменилась.
    @discardableResult
    func updateHeight() -> Bool {
        guard let font, bounds.width > 0 else { return false }
        let inset = textContainerInset
        let width = max(0, bounds.width - inset.left - inset.right)
        let lines = ((text ?? "") as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).height
        let fitting = max(lines, font.lineHeight) + inset.top + inset.bottom
        let value = min(max(Style.inputHeight, ceil(fitting)), Style.inputMaxHeight)
        guard value != fittingHeight else { return false }
        fittingHeight = value
        invalidateIntrinsicContentSize()
        return true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateHeight()
        let inset = Style.inputPadding
        let width = max(0, bounds.width - 2 * inset)
        let size = placeholderLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        placeholderLabel.frame = CGRect(x: inset, y: inset, width: width, height: min(size, max(0, bounds.height - 2 * inset)))
    }
}
