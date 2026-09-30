import UIKit

/// Счётчик «показано N из M».
///
/// Источник: Figma Mobile SDK UI Kit, секция Navigation (90:660), символ Count (301:6810).
/// Слова — параметры, а не константы: локализация остаётся за интегратором.
/// В макете это «Showed 6 from 569».
@_spi(PersonalizationUI) public final class PersonalizationCount: UIView {

    private let stack = UIStackView()
    private let prefixLabel = UILabel()
    private let shownLabel = UILabel()
    private let separatorLabel = UILabel()
    private let totalLabel = UILabel()

    public init() {
        super.init(frame: .zero)
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

        let vertical = PersonalizationSpacing.sm  // 4
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: vertical),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -vertical),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        ])

        [prefixLabel, shownLabel, separatorLabel, totalLabel].forEach(stack.addArrangedSubview)
    }

    /// - Parameters:
    ///   - prefix: слово перед первым числом («Показано»).
    ///   - separator: слово между числами («из»).
    public func set(prefix: String, shown: Int, separator: String, total: Int) {
        prefixLabel.attributedText = attributed(prefix, emphasized: false)
        shownLabel.attributedText = attributed("\(shown)", emphasized: true)
        separatorLabel.attributedText = attributed(separator, emphasized: false)
        totalLabel.attributedText = attributed("\(total)", emphasized: true)
    }

    private func attributed(_ string: String, emphasized: Bool) -> NSAttributedString {
        var attributes = emphasized
            ? PersonalizationTypography.baseEmphasized.attributes
            : PersonalizationTypography.baseDefault.attributes
        attributes[.foregroundColor] = emphasized
            ? PersonalizationColor.textPrimary
            : PersonalizationColor.textSecondary
        return NSAttributedString(string: string, attributes: attributes)
    }
}
