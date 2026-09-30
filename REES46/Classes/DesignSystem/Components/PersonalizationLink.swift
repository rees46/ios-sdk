import UIKit

/// Текстовая ссылка: «Cancel» у поля поиска, «Clear» у недавних запросов.
///
/// В секции Components такого символа нет — стиль снят с экранов Instant Search
/// (страница InstantSearchField, 151:3976 и 310:9829): кегль base 16/24,
/// начертание 600, цвет Text/Link, без подложки и отступов. Нажатого состояния
/// в макете нет, поэтому ссылка только слегка гаснет под пальцем.
@_spi(PersonalizationUI) public final class PersonalizationLink: UIControl {

    public var text: String? {
        didSet { applyText() }
    }

    private let label = UILabel()

    public init(text: String? = nil) {
        super.init(frame: .zero)
        self.text = text
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    public override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? Self.pressedAlpha : 1 }
    }

    private func setup() {
        label.numberOfLines = 1
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        // Размер контрола задаёт label, поэтому приоритеты нужны именно ему: иначе стек,
        // где ссылка стоит рядом с полем, растянет ссылку, а не поле.
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        applyText()
    }

    private func applyText() {
        var attributes = PersonalizationTypography.baseEmphasized.attributes
        attributes[.foregroundColor] = PersonalizationColor.textLink
        label.attributedText = text.map { NSAttributedString(string: $0, attributes: attributes) }
    }

    private static let pressedAlpha: CGFloat = 0.6
}
