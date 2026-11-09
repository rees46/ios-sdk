import UIKit

/// Пустое состояние дизайн-системы.
///
/// Источник: Figma Mobile SDK UI Kit, секция Empty State (319:7736).
/// Горизонтальные отступы 16, вертикальные 92, текст по центру ступенью
/// XL/Default цветом Text/Secondary.
///
/// Текст не зашит: в макете стоит «No results for your request.», но строку
/// подставляет потребитель — локализация остаётся на его стороне.
///
/// Под текстом может стоять кнопка (`actionText`) — так собрана ошибка загрузки
/// с «Retry». В макете ошибки нет: кнопка кита, вид secondary, шаг 16 от текста.
public final class PersonalizationEmptyState: UIView {

    public var message: String? {
        didSet { applyText() }
    }

    /// Подпись кнопки под текстом. `nil` — без кнопки.
    public var actionText: String? {
        didSet { applyAction() }
    }

    public var onAction: (() -> Void)?

    private let label = UILabel()
    private let button = PersonalizationButton(size: .md, view: .secondary)

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
        button.iconStart = PersonalizationIcons.arrowRotateCw
        button.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        // Текст во всю ширину, кнопка под ним по центру; скрытая кнопка места не держит.
        let content = UIStackView(arrangedSubviews: [label, button])
        content.axis = .vertical
        content.alignment = .center
        content.spacing = PersonalizationSpacing.xl  // 16
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            label.widthAnchor.constraint(equalTo: content.widthAnchor),
            // В макете текст отцентрован во фрейме, 92 — не позиция, а минимальное поле.
            content.centerYAnchor.constraint(equalTo: centerYAnchor),
            content.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 92),
            content.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -92)
        ])

        applyText()
        applyAction()
    }

    @objc private func actionTapped() {
        onAction?()
    }

    private func applyAction() {
        button.text = actionText
        button.isHidden = (actionText ?? "").isEmpty
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
