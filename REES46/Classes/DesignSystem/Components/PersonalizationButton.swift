import UIKit

/// Кнопка дизайн-системы.
///
/// Источник: Figma Mobile SDK UI Kit, секция Button (90:862), фрейм 90:869.
/// Матрица: 3 размера x 3 вида x 3 состояния x 4 конфигурации контента.
///
/// Состояние Focus из макета — это нажатие, оно приходит из `isHighlighted`.
/// Disabled — обычный `isEnabled` у `UIControl`.
@_spi(PersonalizationUI) public final class PersonalizationButton: UIControl {

    public enum Size {
        case lg, md, sm

        var textStyle: PersonalizationTextStyle {
            switch self {
            case .lg: return PersonalizationTypography.xlEmphasized
            case .md: return PersonalizationTypography.baseEmphasized
            // SM берёт кегль со ступени sm, а интерлиньяж со ступени base:
            // в макете 14/24, тогда как ступень sm — это 14/20.
            case .sm:
                return PersonalizationTextStyle(
                    size: PersonalizationTypography.smEmphasized.size,
                    lineHeight: PersonalizationTypography.baseEmphasized.lineHeight,
                    tracking: PersonalizationTypography.smEmphasized.tracking,
                    weight: PersonalizationTypography.smEmphasized.weight
                )
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .lg: return PersonalizationRadius.buttonLg  // 12
            case .md: return PersonalizationRadius.buttonMd  // 10
            case .sm: return PersonalizationRadius.buttonSm  // 8
            }
        }

        var paddingVertical: CGFloat {
            switch self {
            case .lg, .md: return PersonalizationSpacing.md  // 8
            case .sm: return PersonalizationSpacing.sm       // 4
            }
        }

        /// Горизонтальный отступ кнопки-иконки: у LG он 12 при вертикальном 8,
        /// у остальных равен вертикальному.
        var paddingIconOnly: CGFloat {
            switch self {
            case .lg: return PersonalizationSpacing.lg  // 12
            case .md: return PersonalizationSpacing.md  // 8
            case .sm: return PersonalizationSpacing.sm  // 4
            }
        }

        /// Горизонтальный отступ со стороны без иконки.
        var paddingWide: CGFloat {
            switch self {
            case .lg: return PersonalizationSpacing.xl3 // 24
            case .md: return PersonalizationSpacing.xl  // 16
            case .sm: return PersonalizationSpacing.lg  // 12
            }
        }

        /// Горизонтальный отступ со стороны с иконкой.
        var paddingNarrow: CGFloat {
            switch self {
            case .lg: return PersonalizationSpacing.xl  // 16
            case .md: return PersonalizationSpacing.lg  // 12
            case .sm: return PersonalizationSpacing.md  // 8
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .lg: return 32
            case .md: return 24
            case .sm: return 20
            }
        }
    }

    public enum View {
        case primary, secondary, ghost
    }

    public var text: String? {
        didSet { applyContent() }
    }

    public var size: Size = .lg {
        didSet { applyContent() }
    }

    public var view: View = .primary {
        didSet { applyStyle() }
    }

    /// Кнопка стоит поверх тёмного (картинки-фона). В макете такие контролы берут
    /// инвертированную палитру: заливка Secondary белая 5%, подпись и иконка светлые.
    /// На `.primary` не влияет — она и так светлая по тексту.
    public var onDark: Bool = false {
        didSet { applyStyle() }
    }

    /// Иконка перед текстом. Без текста кнопка становится кнопкой-иконкой.
    public var iconStart: UIImage? {
        didSet { applyContent() }
    }

    /// Иконка после текста.
    public var iconEnd: UIImage? {
        didSet { applyContent() }
    }

    public override var isHighlighted: Bool {
        didSet { applyStyle() }
    }

    public override var isEnabled: Bool {
        didSet { applyStyle() }
    }

    private let stack = UIStackView()
    private let label = UILabel()
    private let iconStartView = UIImageView()
    private let iconEndView = UIImageView()
    private var stackInsets: [NSLayoutConstraint] = []
    private var iconConstraints: [NSLayoutConstraint] = []

    public init(
        text: String? = nil,
        size: Size = .lg,
        view: View = .primary,
        iconStart: UIImage? = nil,
        iconEnd: UIImage? = nil
    ) {
        super.init(frame: .zero)
        self.text = text
        self.size = size
        self.view = view
        self.iconStart = iconStart
        self.iconEnd = iconEnd
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        clipsToBounds = true

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = PersonalizationSpacing.md  // 8
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        iconStartView.contentMode = .scaleAspectFit
        iconEndView.contentMode = .scaleAspectFit
        label.textAlignment = .center
        // В тесном ряду (цена + бейдж + кнопка в списочной карточке) уступает подпись
        // кнопки — с многоточием, а не наезжая на соседей.
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 749), for: .horizontal)

        stack.addArrangedSubview(iconStartView)
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(iconEndView)

        applyContent()
    }

    private func applyContent() {
        let hasText = !(text ?? "").isEmpty
        label.isHidden = !hasText
        iconStartView.isHidden = iconStart == nil
        iconEndView.isHidden = iconEnd == nil
        iconStartView.image = iconStart
        iconEndView.image = iconEnd

        layer.cornerRadius = size.cornerRadius

        NSLayoutConstraint.deactivate(iconConstraints)
        iconConstraints = [
            iconStartView.widthAnchor.constraint(equalToConstant: size.iconSize),
            iconStartView.heightAnchor.constraint(equalToConstant: size.iconSize),
            iconEndView.widthAnchor.constraint(equalToConstant: size.iconSize),
            iconEndView.heightAnchor.constraint(equalToConstant: size.iconSize)
        ]
        NSLayoutConstraint.activate(iconConstraints)

        let leading: CGFloat
        let trailing: CGFloat
        let vertical: CGFloat
        if hasText {
            leading = iconStart == nil ? size.paddingWide : size.paddingNarrow
            trailing = iconEnd == nil ? size.paddingWide : size.paddingNarrow
            vertical = size.paddingVertical
        } else {
            // Кнопка-иконка: по вертикали как у текстовой, по горизонтали своё — 12/8/4.
            leading = size.paddingIconOnly
            trailing = size.paddingIconOnly
            vertical = size.paddingVertical
        }

        NSLayoutConstraint.deactivate(stackInsets)
        // Содержимое центрируется как группа: растянутая хостом кнопка держит иконку
        // рядом с текстом посередине, а не прижимает её к краю. Своя ширина кнопки —
        // по содержимому плюс поля: это ограничение с приоритетом ниже обязательного,
        // чтобы стек с .fill мог растянуть кнопку, а стек с .equalSpacing — нет.
        let hug = stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leading)
        hug.priority = .defaultHigh
        stackInsets = [
            stack.topAnchor.constraint(equalTo: topAnchor, constant: vertical),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -vertical),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor, constant: (leading - trailing) / 2),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: leading),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -trailing),
            hug
        ]
        NSLayoutConstraint.activate(stackInsets)

        applyStyle()
    }

    private func applyStyle() {
        backgroundColor = backgroundColorForState()
        let foreground = foregroundColorForState()
        iconStartView.tintColor = foreground
        iconEndView.tintColor = foreground

        guard let text, !text.isEmpty else {
            label.attributedText = nil
            return
        }
        var attributes = size.textStyle.attributes
        attributes[.foregroundColor] = foreground
        // Стиль абзаца из типографики перекрывает textAlignment лейбла, поэтому
        // центрирование задаётся в нём — иначе растянутая кнопка прижмёт текст к иконке.
        let paragraph = (size.textStyle.paragraphStyle.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        attributes[.paragraphStyle] = paragraph
        label.attributedText = NSAttributedString(string: text, attributes: attributes)
    }

    private func backgroundColorForState() -> UIColor {
        if !isEnabled {
            switch view {
            case .primary: return PersonalizationColor.buttonPrimaryDisabled
            case .secondary: return PersonalizationColor.buttonSecondaryDisabled
            case .ghost: return PersonalizationColor.backgroundTransparent
            }
        }
        if isHighlighted {
            switch view {
            case .primary: return PersonalizationColor.buttonPrimaryFocus
            // Ghost в нажатии красится тем же, что и Secondary.
            case .secondary, .ghost: return PersonalizationColor.buttonSecondaryFocus
            }
        }
        switch view {
        // Кнопка привязана к Brand/Primary, а не к Button/Primary — так в макете.
        case .primary: return PersonalizationColor.brandPrimary
        case .secondary:
            return onDark ? PersonalizationColor.buttonSecondaryOnDark
                          : PersonalizationColor.buttonSecondary
        case .ghost: return PersonalizationColor.backgroundTransparent
        }
    }

    private func foregroundColorForState() -> UIColor {
        if view == .primary || onDark {
            return isEnabled ? PersonalizationColor.textLightPrimary
                             : PersonalizationColor.textLightHint
        }
        return isEnabled ? PersonalizationColor.textPrimary : PersonalizationColor.textHint
    }
}
