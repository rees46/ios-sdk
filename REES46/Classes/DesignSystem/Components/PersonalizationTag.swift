import UIKit

/// Тег дизайн-системы.
///
/// Источник: Figma Mobile SDK UI Kit, секция Tag (243:10993).
/// В макете только размер MD, поэтому размера в API нет.
public final class PersonalizationTag: UIView {

    public enum View {
        case primary, secondary
    }

    public var text: String? {
        didSet { applyText() }
    }

    public var view: View = .primary {
        didSet { applyStyle() }
    }

    /// Задан — тег показывает крестик и зовёт колбэк по нажатию на него.
    public var onRemove: (() -> Void)? {
        didSet { applyStyle() }
    }

    private let label = UILabel()
    private let removeButton = UIButton(type: .system)
    private let stack = UIStackView()
    private var stackInsets: [NSLayoutConstraint] = []

    public init(text: String? = nil, view: View = .primary, onRemove: (() -> Void)? = nil) {
        super.init(frame: .zero)
        self.text = text
        self.view = view
        self.onRemove = onRemove
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        clipsToBounds = true
        layer.cornerRadius = PersonalizationRadius.buttonSm  // 8

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = PersonalizationSpacing.sm  // 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        stack.addArrangedSubview(label)
        stack.addArrangedSubview(removeButton)

        removeButton.setImage(PersonalizationIcons.cross, for: .normal)
        removeButton.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            removeButton.widthAnchor.constraint(equalToConstant: 16),
            removeButton.heightAnchor.constraint(equalToConstant: 16)
        ])

        applyStyle()
        applyText()
    }

    @objc private func removeTapped() {
        onRemove?()
    }

    private func applyStyle() {
        let removable = onRemove != nil
        removeButton.isHidden = !removable
        backgroundColor = view == .primary
            ? PersonalizationColor.buttonPrimary
            : PersonalizationColor.buttonSecondary
        removeButton.tintColor = view == .primary
            ? PersonalizationColor.textLightPrimary
            : PersonalizationColor.textPrimary

        // Справа отступ меньше, когда есть крестик: 8/4 против 8/8.
        NSLayoutConstraint.deactivate(stackInsets)
        stackInsets = [
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: removable ? -4 : -8)
        ]
        NSLayoutConstraint.activate(stackInsets)

        applyText()
    }

    private func applyText() {
        guard let text else {
            label.attributedText = nil
            return
        }
        var attributes = PersonalizationTypography.xsDefault.attributes
        attributes[.foregroundColor] = view == .primary
            ? PersonalizationColor.textLightPrimary
            : PersonalizationColor.textPrimary
        label.attributedText = NSAttributedString(string: text, attributes: attributes)
    }
}
