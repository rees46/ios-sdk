import UIKit

/// Строка-аккордеон списка.
///
/// Источник: Figma Mobile SDK UI Kit, секция List (241:10565), фрейм Accordion (241:10575).
/// Два варианта — Expanded=False и True, отличаются только направлением шеврона.
///
/// Состояние компонент держит сам: нажатие переключает `expanded` и только потом
/// зовёт `onToggle`. Отдельно выставлять `expanded` из колбэка не нужно —
/// в React Native и Flutter тот же компонент, наоборот, ничего не хранит
/// и ждёт перерисовки сверху.
@_spi(PersonalizationUI) public final class PersonalizationAccordion: UIControl {

    public var text: String? {
        didSet { applyText() }
    }

    /// Число в скобках после подписи. `nil` — не показывать.
    public var count: Int? {
        didSet { applyText() }
    }

    public var expanded: Bool = false {
        didSet { applyChevron() }
    }

    /// Зовётся после переключения, уже с новым значением `expanded`.
    public var onToggle: ((Bool) -> Void)?

    private let stack = UIStackView()
    private let label = UILabel()
    private let counter = UILabel()
    private let chevron = UIImageView()

    public init(text: String? = nil, count: Int? = nil, expanded: Bool = false) {
        super.init(frame: .zero)
        self.text = text
        self.count = count
        self.expanded = expanded
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
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        chevron.contentMode = .scaleAspectFit
        chevron.tintColor = PersonalizationColor.textPrimary
        chevron.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chevron.widthAnchor.constraint(equalToConstant: 24),
            chevron.heightAnchor.constraint(equalToConstant: 24)
        ])

        stack.addArrangedSubview(label)
        stack.addArrangedSubview(counter)
        stack.addArrangedSubview(chevron)

        addTarget(self, action: #selector(toggle), for: .touchUpInside)

        applyText()
        applyChevron()
    }

    @objc private func toggle() {
        expanded.toggle()
        onToggle?(expanded)
    }

    private func applyText() {
        if let text {
            var attributes = PersonalizationTypography.baseDefault.attributes
            attributes[.foregroundColor] = PersonalizationColor.textPrimary
            label.attributedText = NSAttributedString(string: text, attributes: attributes)
        } else {
            label.attributedText = nil
        }

        counter.isHidden = count == nil
        if let count {
            var attributes = PersonalizationTypography.baseDefault.attributes
            attributes[.foregroundColor] = PersonalizationColor.textSecondary
            counter.attributedText = NSAttributedString(string: "(\(count))", attributes: attributes)
        } else {
            counter.attributedText = nil
        }
    }

    private func applyChevron() {
        chevron.image = expanded ? PersonalizationIcons.angleUp : PersonalizationIcons.angleDown
    }
}
