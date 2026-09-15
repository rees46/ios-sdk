import UIKit

/// Рейтинг товара, короткая форма.
///
/// Источник: Figma Mobile SDK UI Kit, секция Rating (88:209), фрейм Product Short (237:4711).
/// Вариант Reviews меняет только данные и цвет звезды: без отзывов она серая.
///
/// Внимание: типографика 16/20 — кегль со ступени base, интерлиньяж со ступени sm.
/// Ступень base — это 16/24, поэтому размеры заданы явно.
///
/// Цвет заполненной звезды в макете не привязан к переменной, взят ближайший
/// существующий токен Semantic/Warning — его стоит подтвердить у дизайнера.
@_spi(PersonalizationUI) public final class PersonalizationRating: UIView {

    private let stack = UIStackView()
    private let star = UIImageView()
    private let valueLabel = UILabel()
    private let reviewsLabel = UILabel()

    private var textStyle: PersonalizationTextStyle {
        PersonalizationTextStyle(
            size: PersonalizationTypography.baseDefault.size,
            lineHeight: PersonalizationTypography.smDefault.lineHeight,
            tracking: PersonalizationTypography.baseDefault.tracking,
            weight: PersonalizationTypography.baseDefault.weight
        )
    }

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
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            // В макете у строки есть нижний отступ 4.
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -PersonalizationSpacing.sm),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            // Строка прижата к началу: если хост растянет компонент, числа не разъедутся.
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        ])

        star.image = PersonalizationIcons.starFill
        // Ассет чёрный, а тинт ставится в set(_:reviews:). Без этой строки
        // компонент до первого вызова показывал бы чёрную звезду.
        star.tintColor = PersonalizationColor.lineGeneric
        star.contentMode = .scaleAspectFit
        star.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            star.widthAnchor.constraint(equalToConstant: 20),
            star.heightAnchor.constraint(equalToConstant: 20)
        ])

        let numbers = UIStackView(arrangedSubviews: [valueLabel, reviewsLabel])
        numbers.axis = .horizontal
        numbers.alignment = .firstBaseline
        numbers.spacing = PersonalizationSpacing.xs  // 2

        stack.addArrangedSubview(star)
        stack.addArrangedSubview(numbers)
    }

    /// - Parameter value: уже отформатированная оценка: в макете «4,7» с запятой.
    public func set(value: String, reviews: Int) {
        var valueAttributes = textStyle.attributes
        valueAttributes[.font] = UIFont.systemFont(ofSize: textStyle.size, weight: .semibold)
        valueAttributes[.foregroundColor] = PersonalizationColor.textSecondary
        valueLabel.attributedText = NSAttributedString(string: value, attributes: valueAttributes)

        var reviewsAttributes = textStyle.attributes
        reviewsAttributes[.foregroundColor] = PersonalizationColor.textHint
        reviewsLabel.attributedText = NSAttributedString(
            string: "(\(reviews))",
            attributes: reviewsAttributes
        )

        star.tintColor = reviews > 0
            ? PersonalizationColor.semanticWarning
            : PersonalizationColor.lineGeneric
    }
}
