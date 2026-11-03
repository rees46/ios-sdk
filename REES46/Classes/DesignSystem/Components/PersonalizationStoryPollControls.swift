import UIKit

// Элементы карточки опроса (`PersonalizationStoryPollView`): вариант, чип, ряд чипов, кнопка
// отправки, ячейка шкалы, ссылка «ответить заново» и многострочное поле. Значения — `Style`
// карточки; в ките многострочного поля нет, оно своё.

private typealias Style = PersonalizationStoryPollView.Style

/// Вариант ответа: в форме одного выбора — кнопка, в отвеченном — строка с долей
/// (полоска растёт от нуля, процент у конца строки).
final class PollOptionRow: UIControl {

    let id: Int
    /// Доля в процентах; `nil` — результатов нет, полоски и процента тоже.
    let percent: Int?
    let title = UILabel()
    let percentLabel = UILabel()
    private let fill = UIView()
    private let interactive: Bool
    /// Видимая доля полоски: 0, пока не выросла.
    private(set) var shownFraction: CGFloat = 0
    private var didAnimate = false

    init(option: PersonalizationStoryPoll.Option, percent: Int?, interactive: Bool) {
        self.id = option.id
        self.percent = percent
        self.interactive = interactive
        super.init(frame: .zero)
        backgroundColor = Style.field
        layer.cornerRadius = Style.controlRadius
        layer.borderWidth = Style.borderWidth
        clipsToBounds = true
        fill.isUserInteractionEnabled = false
        addSubview(fill)
        title.text = option.label
        title.font = Style.optionFont
        title.textColor = Style.text
        title.numberOfLines = 0
        percentLabel.text = percent.map { "\($0)%" }
        percentLabel.font = Style.percentFont
        percentLabel.textColor = Style.text
        percentLabel.isHidden = percent == nil
        percentLabel.setContentHuggingPriority(.required, for: .horizontal)
        percentLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let insets = Style.optionInsets
        for label in [title, percentLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
        }
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: insets.top),
            title.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
            percentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right),
            percentLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            percent == nil
                ? title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right)
                : title.trailingAnchor.constraint(lessThanOrEqualTo: percentLabel.leadingAnchor, constant: -PersonalizationSpacing.md)
        ])
        isUserInteractionEnabled = interactive
        isAccessibilityElement = true
        accessibilityLabel = option.label + (percent.map { ", \($0)%" } ?? "")
        applyState()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isSelected: Bool {
        didSet { applyState() }
    }

    override var isEnabled: Bool {
        didSet { applyState() }
    }

    private func applyState() {
        layer.borderColor = (isSelected ? Style.accent : Style.border).cgColor
        fill.backgroundColor = isSelected ? Style.barSelected : Style.bar
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

    /// Полоска — от начала строки: слева, в RTL справа.
    private func layoutFill() {
        let width = bounds.width * shownFraction
        let rightToLeft = effectiveUserInterfaceLayoutDirection == .rightToLeft
        fill.frame = CGRect(x: rightToLeft ? bounds.width - width : 0, y: 0, width: width, height: bounds.height)
    }
}

/// Чип нескольких вариантов: переключатель.
final class PollChip: UIControl {

    let id: Int
    let title = UILabel()

    init(option: PersonalizationStoryPoll.Option) {
        self.id = option.id
        super.init(frame: .zero)
        layer.borderWidth = Style.borderWidth
        title.text = option.label
        title.font = Style.chipFont
        title.lineBreakMode = .byTruncatingTail
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)
        let insets = Style.chipInsets
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: insets.top),
            title.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
            title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right)
        ])
        isAccessibilityElement = true
        accessibilityLabel = option.label
        applyState()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isSelected: Bool {
        didSet { applyState() }
    }

    override var isEnabled: Bool {
        didSet { applyState() }
    }

    private func applyState() {
        backgroundColor = isSelected ? Style.chipSelected : Style.field
        layer.borderColor = (isSelected ? Style.chipSelected : Style.border).cgColor
        title.textColor = isSelected ? Style.chipSelectedText : Style.text
        var traits: UIAccessibilityTraits = .button
        if isSelected { traits.insert(.selected) }
        if !isEnabled { traits.insert(.notEnabled) }
        accessibilityTraits = traits
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(Style.chipRadius, bounds.height / 2)
    }
}

/// Чипы с переносом: ряды по центру, шаг `gap` по обеим осям; в RTL порядок справа налево.
final class PollChipsView: UIView {

    private let gap: CGFloat
    private var measuredHeight: CGFloat = 0

    var items: [UIView] = [] {
        didSet {
            oldValue.forEach { $0.removeFromSuperview() }
            items.forEach(addSubview)
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    init(gap: CGFloat) {
        self.gap = gap
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var intrinsicContentSize: CGSize {
        // До раскладки ширины нет: прикидка по ширине экрана, после раскладки — точная.
        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width - 2 * (Style.margin + Style.padding)
        return CGSize(width: UIView.noIntrinsicMetric, height: arrange(width: width, apply: false))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = arrange(width: bounds.width, apply: true)
        if height != measuredHeight {
            measuredHeight = height
            invalidateIntrinsicContentSize()
        }
    }

    /// Раскладывает чипы рядами и возвращает высоту.
    @discardableResult
    func arrange(width: CGFloat, apply: Bool) -> CGFloat {
        var lines: [[(view: UIView, size: CGSize)]] = [[]]
        var lineWidth: CGFloat = 0
        for view in items {
            var size = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            size.width = min(size.width, width)
            if !lines[lines.count - 1].isEmpty, lineWidth + gap + size.width > width {
                lines.append([])
                lineWidth = 0
            }
            lineWidth += (lines[lines.count - 1].isEmpty ? 0 : gap) + size.width
            lines[lines.count - 1].append((view, size))
        }
        let rightToLeft = effectiveUserInterfaceLayoutDirection == .rightToLeft
        var y: CGFloat = 0
        for (index, line) in lines.enumerated() where !line.isEmpty {
            let total = line.reduce(0) { $0 + $1.size.width } + gap * CGFloat(line.count - 1)
            let height = line.map(\.size.height).max() ?? 0
            var x = max(0, (width - total) / 2)
            for item in rightToLeft ? line.reversed() : line {
                if apply {
                    item.view.frame = CGRect(x: x, y: y + (height - item.size.height) / 2, width: item.size.width, height: item.size.height)
                }
                x += item.size.width + gap
            }
            y += height + (index < lines.count - 1 ? gap : 0)
        }
        return y
    }
}

/// Кнопка отправки во всю ширину; выключенная — серая.
final class PollSubmitButton: UIControl {

    let title = UILabel()

    init(title text: String) {
        super.init(frame: .zero)
        layer.cornerRadius = Style.controlRadius
        title.text = text
        title.font = Style.submitFont
        title.textAlignment = .center
        title.numberOfLines = 0
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)
        let inset = Style.submitPadding
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            title.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
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
        backgroundColor = isEnabled ? Style.accent : Style.border
        title.textColor = isEnabled ? Style.submitText : Style.muted
        accessibilityTraits = isEnabled ? .button : [.button, .notEnabled]
    }
}

/// Ячейка шкалы: цвет по оценке, у выбранной — обводка с зазором 1.
final class PollScaleCell: UIControl {

    let value: Int
    let title = UILabel()
    private let ring = CALayer()

    init(value: Int, color: UIColor) {
        self.value = value
        super.init(frame: .zero)
        backgroundColor = color
        layer.cornerRadius = Style.scaleRadius
        title.text = String(value)
        title.font = Style.scaleFont
        title.textColor = Style.text
        title.textAlignment = .center
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.6
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: Style.scalePadding),
            title.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Style.scalePadding),
            title.leadingAnchor.constraint(equalTo: leadingAnchor),
            title.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        ring.borderColor = Style.text.cgColor
        ring.borderWidth = Style.ringWidth
        ring.isHidden = true
        layer.addSublayer(ring)
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

    /// Обводка выбранной ячейки видна.
    var isRingVisible: Bool { !ring.isHidden }

    private func applyState() {
        ring.isHidden = !isSelected
        var traits: UIAccessibilityTraits = .button
        if isSelected { traits.insert(.selected) }
        if !isEnabled { traits.insert(.notEnabled) }
        accessibilityTraits = traits
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let outset = Style.ringOffset + Style.ringWidth
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ring.frame = bounds.insetBy(dx: -outset, dy: -outset)
        ring.cornerRadius = Style.scaleRadius + outset
        CATransaction.commit()
    }
}

/// Ссылка «ответить заново»: подчёркнутый текст по центру.
final class PollLink: UIControl {

    let title = UILabel()

    init(title text: String) {
        super.init(frame: .zero)
        title.attributedText = NSAttributedString(string: text, attributes: [
            .font: Style.linkFont,
            .foregroundColor: Style.link,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ])
        title.textAlignment = .center
        title.numberOfLines = 0
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: PersonalizationSpacing.xs),
            title.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -PersonalizationSpacing.xs),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: PersonalizationSpacing.sm),
            title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -PersonalizationSpacing.sm)
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

/// Многострочное поле текстового опроса с подсказкой; высота 72, длинный текст прокручивается.
final class PollTextView: UITextView {

    private let placeholderLabel = UILabel()

    var placeholder: String? {
        didSet {
            placeholderLabel.text = placeholder
            accessibilityLabel = placeholder
            updatePlaceholder()
        }
    }

    override var text: String! {
        didSet { updatePlaceholder() }
    }

    init() {
        super.init(frame: .zero, textContainer: nil)
        font = Style.inputFont
        textColor = Style.text
        backgroundColor = Style.field
        tintColor = Style.accent
        layer.cornerRadius = Style.controlRadius
        layer.borderWidth = Style.borderWidth
        layer.borderColor = Style.border.cgColor
        let inset = Style.inputPadding
        textContainerInset = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        textContainer.lineFragmentPadding = 0
        keyboardAppearance = .light
        placeholderLabel.font = Style.inputFont
        placeholderLabel.textColor = Style.muted
        placeholderLabel.numberOfLines = 0
        placeholderLabel.isAccessibilityElement = false
        addSubview(placeholderLabel)
        heightAnchor.constraint(equalToConstant: Style.inputHeight).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    var isPlaceholderVisible: Bool { !placeholderLabel.isHidden }

    func updatePlaceholder() {
        placeholderLabel.isHidden = !(text ?? "").isEmpty
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = Style.inputPadding
        let width = max(0, bounds.width - 2 * inset)
        let height = placeholderLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        placeholderLabel.frame = CGRect(x: inset, y: inset, width: width, height: min(height, max(0, bounds.height - 2 * inset)))
    }
}
