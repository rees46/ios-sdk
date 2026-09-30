import UIKit

/// Пустое состояние дизайн-системы.
///
/// Источник: Figma Mobile SDK UI Kit, секция Empty State (319:7736).
/// Горизонтальные отступы 16, вертикальные 92, текст по центру ступенью
/// XL/Default цветом Text/Secondary.
///
/// Текст не зашит: в макете стоит «No results for your request.», но строку
/// подставляет потребитель — локализация остаётся на его стороне.
@_spi(PersonalizationUI) public final class PersonalizationEmptyState: UIView {

    public var message: String? {
        didSet { applyText() }
    }

    private let label = UILabel()

    public init(message: String? = nil) {
        super.init(frame: .zero)
        self.message = message
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            // В макете текст отцентрован во фрейме, 92 — не позиция, а минимальное поле.
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 92),
            label.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -92)
        ])

        applyText()
    }

    private func applyText() {
        guard let message else {
            label.attributedText = nil
            return
        }
        var attributes = PersonalizationTypography.xlDefault.attributes
        attributes[.foregroundColor] = PersonalizationColor.textSecondary
        // Выравнивание живёт в параграфе, поэтому его надо переопределить целиком.
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 32
        paragraph.maximumLineHeight = 32
        paragraph.alignment = .center
        attributes[.paragraphStyle] = paragraph
        label.attributedText = NSAttributedString(string: message, attributes: attributes)
    }
}
