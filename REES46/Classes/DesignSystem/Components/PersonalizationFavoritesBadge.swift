import UIKit

/// Метка «в избранном»: звезда в круге цвета Semantic/Warning, 24x24.
///
/// Источник: Figma Mobile SDK UI Kit, секция Badge, символ Favorites (391:17117).
@_spi(PersonalizationUI) public final class PersonalizationFavoritesBadge: UIView {

    /// Звезда 16 плюс поле 4 с каждой стороны.
    public static let side: CGFloat = 24

    private let star = UIImageView()

    public init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = PersonalizationColor.semanticWarning
        layer.cornerRadius = Self.side / 2

        star.image = PersonalizationIcons.starFill
        star.tintColor = PersonalizationColor.textLightPrimary
        star.contentMode = .scaleAspectFit
        star.translatesAutoresizingMaskIntoConstraints = false
        addSubview(star)

        let inset = PersonalizationSpacing.sm  // 4
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.side),
            heightAnchor.constraint(equalToConstant: Self.side),
            star.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            star.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
            star.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            star.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset)
        ])
    }
}
