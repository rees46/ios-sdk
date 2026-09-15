import UIKit

/// Заголовок блока.
///
/// Источник: Figma Mobile SDK UI Kit, секция Title (167:3802).
/// Все четыре заголовка на странице — один и тот же ряд «слева иконка, заголовок,
/// справа управление», отличается только содержимое по краям:
/// Recommender block (157:5176) — кнопка «Show all», Category (167:3812) — группа кнопок,
/// Filters (204:8340) — кнопка-крестик, Search results (167:3807) — кнопка «назад» и группа.
/// Поэтому края здесь — произвольные вью, а не фиксированные варианты.
@_spi(PersonalizationUI) public final class PersonalizationTitle: UIView {

    public var text: String? {
        didSet { applyText() }
    }

    /// Вью слева от заголовка. `nil` — убрать.
    public var leading: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let leading { stack.insertArrangedSubview(leading, at: 0) }
        }
    }

    /// Вью справа от заголовка. `nil` — убрать.
    public var trailing: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let trailing { stack.addArrangedSubview(trailing) }
        }
    }

    private let stack = UIStackView()
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
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = PersonalizationSpacing.sm  // 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        label.numberOfLines = 0
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(label)

        applyText()
    }

    private func applyText() {
        guard let text else {
            label.attributedText = nil
            return
        }
        var attributes = PersonalizationTypography.xl2Emphasized.attributes
        attributes[.foregroundColor] = PersonalizationColor.textPrimary
        label.attributedText = NSAttributedString(string: text, attributes: attributes)
    }
}
