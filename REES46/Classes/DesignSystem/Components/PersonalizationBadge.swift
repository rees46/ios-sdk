import UIKit

/// Бейдж дизайн-системы.
///
/// Источник: Figma Mobile SDK UI Kit, секция Badge (241:7434).
///
/// Внимание: типографика бейджа не совпадает со ступенями `PersonalizationTypography` —
/// кегль берётся с одной ступени, интерлиньяж с другой (20/24, 16/20, 14/16).
/// Поэтому стиль собирается здесь явно, а не переиспользуется.
public final class PersonalizationBadge: UIView {

    public enum Size {
        case sm, md, lg

        var insets: UIEdgeInsets {
            switch self {
            case .lg: return UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
            case .md: return UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
            case .sm: return UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .lg: return PersonalizationRadius.xl   // 10
            case .md: return PersonalizationRadius.lg   // 8
            case .sm: return PersonalizationRadius.md   // 6
            }
        }

        var font: (size: CGFloat, lineHeight: CGFloat) {
            switch self {
            case .lg: return (20, 24)
            case .md: return (16, 20)
            case .sm: return (14, 16)
            }
        }
    }

    public var text: String? {
        didSet { applyText() }
    }

    public var size: Size {
        didSet { applyStyle() }
    }

    private let label = UILabel()

    public init(text: String? = nil, size: Size = .lg) {
        self.size = size
        super.init(frame: .zero)
        self.text = text
        setup()
    }

    required init?(coder: NSCoder) {
        self.size = .lg
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = PersonalizationColor.semanticWarning
        clipsToBounds = true

        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 1
        addSubview(label)

        applyStyle()
        applyText()
    }

    private var insetConstraints: [NSLayoutConstraint] = []

    private func applyStyle() {
        layer.cornerRadius = size.cornerRadius

        NSLayoutConstraint.deactivate(insetConstraints)
        let i = size.insets
        insetConstraints = [
            label.topAnchor.constraint(equalTo: topAnchor, constant: i.top),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: i.left),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -i.right),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -i.bottom)
        ]
        NSLayoutConstraint.activate(insetConstraints)

        applyText()
    }

    private func applyText() {
        guard let text else {
            label.attributedText = nil
            return
        }
        let metrics = size.font
        let style = PersonalizationTextStyle(
            size: metrics.size,
            lineHeight: metrics.lineHeight,
            tracking: 0,
            weight: .semibold
        )
        var attributes = style.attributes
        attributes[.foregroundColor] = PersonalizationColor.textLightPrimary
        label.attributedText = NSAttributedString(string: text, attributes: attributes)
    }
}
