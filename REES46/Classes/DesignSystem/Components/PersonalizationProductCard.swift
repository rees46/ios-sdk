import UIKit

/// Карточка товара.
///
/// Источник: Figma Mobile SDK UI Kit, секция Card, фрейм Product (126:2263):
/// Carousel — колонка 220, Grid — колонка 161 с картинкой во всю ширину, List — строка
/// с картинкой шириной 120 и ценой с кнопкой внизу справа. Пропорция картинки —
/// `imageAspect`: на странице ProductCard (88:69) карточка нарисована с 4:3, 1:1 и 3:4,
/// и её высота идёт за картинкой.
/// У трёх типов разная типографика названия, цены и старой цены, поэтому она задана
/// на типе. Старая цена карусели — 16/24 по страницам ProductCard и Product Carousel;
/// мастер-компонент Product там же даёт 14/20 — расхождение в макете, взяты страницы.
///
/// Собрана из готовых блоков: `PersonalizationProductImage`, `PersonalizationRating`,
/// `PersonalizationBadge` (скидка, вид danger), `PersonalizationButton`.
/// Изображение хост грузит сам в `image.imageView`.
@_spi(PersonalizationUI) public final class PersonalizationProductCard: UIView {

    public enum CardType {
        case carousel, grid, list

        var nameStyle: PersonalizationTextStyle {
            switch self {
            case .carousel, .grid: return PersonalizationTypography.baseDefault
            case .list: return PersonalizationTypography.smDefault
            }
        }

        var priceStyle: PersonalizationTextStyle {
            switch self {
            case .carousel: return PersonalizationTypography.xlEmphasized
            case .grid: return PersonalizationTypography.lgEmphasized
            case .list: return PersonalizationTypography.baseEmphasized
            }
        }

        var oldPriceStyle: PersonalizationTextStyle {
            switch self {
            case .carousel: return PersonalizationTypography.baseDefault
            case .grid, .list: return PersonalizationTypography.smDefault
            }
        }
    }

    public var type: CardType = .carousel {
        didSet { rebuild() }
    }

    public var brand: String? {
        didSet { applyTexts() }
    }

    public var name: String? {
        didSet { applyTexts() }
    }

    public var price: String? {
        didSet { applyTexts() }
    }

    /// Старая цена, зачёркнутая. `nil` — не показывать.
    public var oldPrice: String? {
        didSet { applyTexts() }
    }

    /// Скидка, например «-15%». `nil` — без бейджа.
    public var discount: String? {
        didSet { applyTexts() }
    }

    /// Подпись кнопки. `nil` — без кнопки.
    public var actionText: String? {
        didSet { applyTexts() }
    }

    public var onAction: (() -> Void)?

    /// Изображение: хост грузит картинку в `image.imageView`.
    public let image = PersonalizationProductImage()

    /// Пропорция картинки; высота карточки идёт за ней.
    public var imageAspect: PersonalizationProductImage.Aspect {
        get { image.aspect }
        set { image.aspect = newValue }
    }

    private let imageContainer = UIView()
    private let imageBadge = PersonalizationBadge(size: .sm, view: .danger)
    private let brandLabel = UILabel()
    private let nameLabel = UILabel()
    private let rating = PersonalizationRating()
    private let priceLabel = UILabel()
    private let priceBadge = PersonalizationBadge(size: .sm, view: .danger)
    private let oldPriceLabel = UILabel()
    private let button = PersonalizationButton(size: .md, view: .primary)

    private var root: UIStackView?
    private var badgeConstraints: [NSLayoutConstraint] = []
    private var listImageWidth: NSLayoutConstraint?

    public init(type: CardType = .carousel) {
        super.init(frame: .zero)
        self.type = type
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    /// - Parameter value: уже отформатированная оценка: в макете «4,7» с запятой.
    public func setRating(value: String, reviews: Int) {
        rating.set(value: value, reviews: reviews)
    }

    private func setup() {
        image.translatesAutoresizingMaskIntoConstraints = false
        imageBadge.translatesAutoresizingMaskIntoConstraints = false
        imageContainer.addSubview(image)
        imageContainer.addSubview(imageBadge)
        NSLayoutConstraint.activate([
            image.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            image.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            image.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            image.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor)
        ])

        brandLabel.numberOfLines = 1
        nameLabel.numberOfLines = 2
        oldPriceLabel.numberOfLines = 1
        button.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        rebuild()
    }

    @objc private func actionTapped() {
        onAction?()
    }

    private func rebuild() {
        root?.removeFromSuperview()
        listImageWidth?.isActive = false
        listImageWidth = nil
        let stack = type == .list ? buildList() : buildColumn()
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        root = stack
        applyTexts()
    }

    /// Carousel и Grid: картинка, название, рейтинг, цена, кнопка — колонкой с шагом 8.
    private func buildColumn() -> UIStackView {
        let inset = type == .grid ? PersonalizationSpacing.sm : PersonalizationSpacing.md
        NSLayoutConstraint.deactivate(badgeConstraints)
        badgeConstraints = [
            imageBadge.topAnchor.constraint(equalTo: imageContainer.topAnchor, constant: inset),
            imageBadge.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor, constant: -inset)
        ]
        NSLayoutConstraint.activate(badgeConstraints)

        let priceRow = UIStackView(arrangedSubviews: [priceLabel, oldPriceLabel, PersonalizationFlexibleSpace()])
        priceRow.axis = .horizontal
        priceRow.alignment = .lastBaseline
        priceRow.spacing = PersonalizationSpacing.md  // 8

        let column = UIStackView(arrangedSubviews: [imageContainer, nameBlock(spacing: PersonalizationSpacing.xs), rating, priceRow, button])
        column.axis = .vertical
        column.alignment = .fill
        column.spacing = PersonalizationSpacing.md  // 8

        if type == .carousel {
            column.widthAnchor.constraint(equalToConstant: Self.carouselWidth).isActive = true
        }
        return column
    }

    /// List: картинка шириной 120 слева, справа колонка — название с рейтингом сверху,
    /// цена с кнопкой снизу. Высоту строки задаёт картинка по своей пропорции.
    private func buildList() -> UIStackView {
        NSLayoutConstraint.deactivate(badgeConstraints)
        badgeConstraints = []
        listImageWidth = imageContainer.widthAnchor.constraint(equalToConstant: Self.listImageSide)
        listImageWidth?.isActive = true

        let top = UIStackView(arrangedSubviews: [nameBlock(spacing: PersonalizationSpacing.xs), rating])
        top.axis = .vertical
        top.alignment = .leading
        top.spacing = PersonalizationSpacing.sm  // 4

        let priceLine = UIStackView(arrangedSubviews: [priceLabel, priceBadge])
        priceLine.axis = .horizontal
        priceLine.alignment = .center
        priceLine.spacing = PersonalizationSpacing.md  // 8

        let priceBlock = UIStackView(arrangedSubviews: [priceLine, oldPriceLabel])
        priceBlock.axis = .vertical
        priceBlock.alignment = .leading

        let bottom = UIStackView(arrangedSubviews: [priceBlock, button])
        bottom.axis = .horizontal
        bottom.alignment = .center
        bottom.distribution = .equalSpacing

        let column = UIStackView(arrangedSubviews: [top, bottom])
        column.axis = .vertical
        column.alignment = .fill
        column.distribution = .equalSpacing

        // Высота строки — большее из картинки и текста: колонка тянется до картинки
        // (цена с кнопкой уходят вниз), а низкая картинка её не сжимает.
        let row = UIStackView(arrangedSubviews: [imageContainer, column])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = PersonalizationSpacing.lg  // 12
        column.heightAnchor.constraint(greaterThanOrEqualTo: imageContainer.heightAnchor).isActive = true
        return row
    }

    private func nameBlock(spacing: CGFloat) -> UIStackView {
        let block = UIStackView(arrangedSubviews: [brandLabel, nameLabel])
        block.axis = .vertical
        block.alignment = .fill
        block.spacing = spacing
        return block
    }

    private func applyTexts() {
        brandLabel.isHidden = (brand ?? "").isEmpty
        brandLabel.attributedText = attributed(brand, PersonalizationTypography.xsDefault, PersonalizationColor.textSecondary)
        nameLabel.attributedText = attributed(name, type.nameStyle, PersonalizationColor.textPrimary)
        priceLabel.attributedText = attributed(price, type.priceStyle, PersonalizationColor.textPrimary)

        oldPriceLabel.isHidden = (oldPrice ?? "").isEmpty
        var strike = type.oldPriceStyle.attributes
        strike[.foregroundColor] = PersonalizationColor.textHint
        strike[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        oldPriceLabel.attributedText = oldPrice.map { NSAttributedString(string: $0, attributes: strike) }

        // У колонок скидка лежит на картинке, у списка — рядом с ценой.
        let hasDiscount = !(discount ?? "").isEmpty
        imageBadge.text = discount
        priceBadge.text = discount
        imageBadge.isHidden = !hasDiscount || type == .list
        priceBadge.isHidden = !hasDiscount || type != .list

        button.text = actionText
        button.isHidden = (actionText ?? "").isEmpty
    }

    private func attributed(_ text: String?, _ style: PersonalizationTextStyle, _ color: UIColor) -> NSAttributedString? {
        guard let text else { return nil }
        var attributes = style.attributes
        attributes[.foregroundColor] = color
        return NSAttributedString(string: text, attributes: attributes)
    }

    private static let carouselWidth: CGFloat = 220
    private static let listImageSide: CGFloat = 120
}
