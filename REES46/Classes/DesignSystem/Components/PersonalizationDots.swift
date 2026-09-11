import UIKit

/// Точки-индикатор карусели.
///
/// Источник: Figma Mobile SDK UI Kit, секция Navigation (90:660),
/// символы Dots (90:669) и Dot (90:685).
/// В макете нарисовано пять точек, число вынесено в API.
public final class PersonalizationDots: UIView {

    public var count: Int = 0 {
        didSet {
            if selectedIndex >= count { selectedIndex = 0 }
            rebuild()
        }
    }

    public var selectedIndex: Int = 0 {
        didSet { applySelection() }
    }

    private let stack = UIStackView()
    private var dots: [UIView] = []

    public init(count: Int = 0, selectedIndex: Int = 0) {
        super.init(frame: .zero)
        self.count = count
        self.selectedIndex = selectedIndex
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = PersonalizationSpacing.lg  // 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let vertical = PersonalizationSpacing.md  // 8
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: vertical),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -vertical),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        ])

        rebuild()
    }

    private func rebuild() {
        dots.forEach { $0.removeFromSuperview() }
        dots = []
        for _ in 0..<max(0, count) {
            let dot = UIView()
            dot.layer.cornerRadius = Self.dotSize / 2
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: Self.dotSize),
                dot.heightAnchor.constraint(equalToConstant: Self.dotSize)
            ])
            stack.addArrangedSubview(dot)
            dots.append(dot)
        }
        applySelection()
    }

    private func applySelection() {
        for (index, dot) in dots.enumerated() {
            dot.backgroundColor = index == selectedIndex
                ? PersonalizationColor.brandPrimary
                : PersonalizationColor.lineGeneric
        }
    }

    private static let dotSize: CGFloat = 16
}
