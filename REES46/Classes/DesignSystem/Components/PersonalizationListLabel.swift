import UIKit

/// Подпись-разделитель списка.
///
/// Источник: Figma Mobile SDK UI Kit, секция List (241:10565), символ Label (243:10967).
/// Единственное место в макете, где шрифт берётся из Font Family/Body, а не Heading.
/// Inter в SDK не поставляется, так что на отрисовку это пока не влияет.
///
/// Текст переводится в верхний регистр самим компонентом — так задано в макете.
@_spi(PersonalizationUI) public final class PersonalizationListLabel: UIView {

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

    private func setup() {
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        applyText()
    }

    private func applyText() {
        guard let text else {
            label.attributedText = nil
            return
        }
        var attributes = PersonalizationTypography.smDefault.attributes
        attributes[.foregroundColor] = PersonalizationColor.textHint
        label.attributedText = NSAttributedString(
            string: text.uppercased(),
            attributes: attributes
        )
    }
}
