import UIKit

/// Чекбокс с подписью.
///
/// Источник: Figma Mobile SDK UI Kit, фрейм Checkbox with Label (205:10151).
/// Зазор 8, подпись 16/20 обычного начертания; в disabled подпись уходит
/// в Text/Hint.
public final class PersonalizationCheckboxWithLabel: UIControl {

    public var text: String? {
        didSet { applyText() }
    }

    public var checkState: PersonalizationCheckbox.State {
        get { checkbox.checkState }
        set { checkbox.checkState = newValue }
    }

    public override var isEnabled: Bool {
        didSet {
            checkbox.isEnabled = isEnabled
            applyText()
        }
    }

    private let checkbox = PersonalizationCheckbox()
    private let label = UILabel()

    public init(text: String? = nil, state: PersonalizationCheckbox.State = .unchecked) {
        super.init(frame: .zero)
        self.text = text
        checkbox.checkState = state
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let stack = UIStackView(arrangedSubviews: [checkbox, label])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = PersonalizationSpacing.md  // 8
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        addTarget(self, action: #selector(toggle), for: .touchUpInside)
        applyText()
    }

    @objc private func toggle() {
        guard isEnabled else { return }
        checkbox.checkState = checkbox.checkState == .checked ? .unchecked : .checked
        sendActions(for: .valueChanged)
    }

    private func applyText() {
        guard let text else {
            label.attributedText = nil
            return
        }
        // Подпись 16/20 — кегль Base, но интерлиньяж SM, как в макете.
        let style = PersonalizationTextStyle(size: 16, lineHeight: 20, tracking: 0, weight: .regular)
        var attributes = style.attributes
        attributes[.foregroundColor] = isEnabled
            ? PersonalizationColor.textPrimary
            : PersonalizationColor.textHint
        label.attributedText = NSAttributedString(string: text, attributes: attributes)
    }
}
