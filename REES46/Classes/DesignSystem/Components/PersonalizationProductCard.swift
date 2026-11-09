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
public final class PersonalizationProductCard: UIView {

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

    /// Ряд рейтинга. `false` — не рисовать даже при заданной оценке: в API рейтинга нет,
    /// и виджеты с данными SDK его выключают.
    public var showRating = true {
        didSet { applyRating() }
    }

    public var onAction: (() -> Void)?

    /// Нажатие на карточку целиком (не на кнопку) — открыть товар.
    public var onTap: (() -> Void)?

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

    private var ratingValue: String?
    private var root: UIStackView?
    private var badgeConstraints: [NSLayoutConstraint] = []
    private var listImageWidth: NSLayoutConstraint?
    private var listPriceLine: UIStackView?
    private var listBottom: UIStackView?
    private var listPriceBlockWidth: NSLayoutConstraint?
    /// Перенесены ли бейдж и кнопка у list-карточки по последней ширине; `nil` — ещё не решено.
    private var listWrap: (badge: Bool, button: Bool)?
    private var columnPriceRow: UIStackView?
    private var columnPriceSpacer: UIView?
    /// Стоит ли старая цена у колонок своей строкой над ценой; `nil` — ещё не решено.
    private var columnPriceWrap: Bool?

    public init(type: CardType = .carousel) {
        super.init(frame: .zero)
        self.type = type
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    /// - Parameter value: уже отформатированная оценка: в макете «4,7» с запятой;
    ///   `nil` — товар без оценки, ряд рейтинга прячется.
    public func setRating(value: String?, reviews: Int) {
        ratingValue = value
        if let value { rating.set(value: value, reviews: reviews) }
        applyRating()
    }

    private func applyRating() {
        rating.isHidden = !showRating || ratingValue == nil
    }

    /// Тексты карточки из данных товара. Обработчики и картинку раскладка ставит сама.
    func show(_ product: PersonalizationProduct) {
        brand = product.brand
        name = product.name
        price = product.price
        oldPrice = product.oldPrice
        discount = product.discount
        actionText = product.actionText
        setRating(value: product.ratingValue, reviews: product.reviews)
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
        let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        tap.delegate = self
        addGestureRecognizer(tap)

        rebuild()
    }

    @objc private func actionTapped() {
        onAction?()
    }

    @objc private func cardTapped() {
        onTap?()
    }

    private func rebuild() {
        // Каталог меряет плитку и переключает ту же карточку в список, поэтому части уходят из
        // старых стеков аккуратно. Сначала они показываются, и стеки снимают с них ограничения
        // скрытия: иначе спрятанная в плитке старая цена уезжала в список шириной ноль. Потом
        // части снимаются по одной и только затем уходит корень: унесённые из уже отцепленного
        // корня, они давали карточке, которую до этого мерили, нулевую высоту.
        let parts: [UIView] = [imageContainer, brandLabel, nameLabel, rating, priceLabel, priceBadge, oldPriceLabel, button]
        let hidden = parts.map(\.isHidden)
        parts.forEach { $0.isHidden = false }
        root?.updateConstraintsIfNeeded()
        root?.layoutIfNeeded()
        for (view, wasHidden) in zip(parts, hidden) {
            view.removeFromSuperview()
            view.isHidden = wasHidden
        }
        root?.removeFromSuperview()
        listImageWidth?.isActive = false
        listImageWidth = nil
        listPriceBlockWidth?.isActive = false
        listPriceBlockWidth = nil
        listPriceLine = nil
        listBottom = nil
        listWrap = nil
        columnPriceRow = nil
        columnPriceSpacer = nil
        columnPriceWrap = nil
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
    ///
    /// Колонка из двух групп: верх (картинка, название, рейтинг) и низ (цена, кнопка)
    /// с распоркой между ними. Ячейки списка одной высоты (по самой высокой карточке),
    /// лишнее уходит в распорку — цена с кнопкой у соседей остаются на одной линии,
    /// даже когда название ушло на две строки. В макете такой случай не нарисован:
    /// там названия в одну строку. Сама по себе колонка остаётся по содержимому.
    private func buildColumn() -> UIStackView {
        let inset = type == .grid ? PersonalizationSpacing.sm : PersonalizationSpacing.md
        NSLayoutConstraint.deactivate(badgeConstraints)
        badgeConstraints = [
            imageBadge.topAnchor.constraint(equalTo: imageContainer.topAnchor, constant: inset),
            imageBadge.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor, constant: -inset)
        ]
        NSLayoutConstraint.activate(badgeConstraints)

        let priceSpacer = PersonalizationFlexibleSpace()
        let priceRow = UIStackView(arrangedSubviews: [priceLabel, oldPriceLabel, priceSpacer])
        columnPriceRow = priceRow
        columnPriceSpacer = priceSpacer
        priceRow.axis = .horizontal
        priceRow.alignment = .lastBaseline
        priceRow.spacing = PersonalizationSpacing.md  // 8

        let top = UIStackView(arrangedSubviews: [imageContainer, nameBlock(spacing: PersonalizationSpacing.xs), rating])
        top.axis = .vertical
        top.alignment = .fill
        top.spacing = PersonalizationSpacing.md  // 8

        let bottom = UIStackView(arrangedSubviews: [priceRow, button])
        bottom.axis = .vertical
        bottom.alignment = .fill
        bottom.spacing = PersonalizationSpacing.md  // 8

        // Шаг между группами задаёт распорка, у самой колонки spacing нет.
        let column = UIStackView(arrangedSubviews: [top, PersonalizationFlexibleSpace(axis: .vertical, minimum: PersonalizationSpacing.md), bottom])
        column.axis = .vertical
        column.alignment = .fill

        if type == .carousel {
            column.widthAnchor.constraint(equalToConstant: Self.carouselWidth).isActive = true
        }
        return column
    }

    /// List: картинка шириной 120 слева, справа колонка — название с рейтингом сверху,
    /// цена с кнопкой снизу (в узкой колонке кнопка под ценой). Высоту строки задаёт картинка
    /// по своей пропорции.
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
        bottom.distribution = .fill
        bottom.spacing = PersonalizationSpacing.md  // 8
        // Цена и бейдж не сжимаются, свободное место достаётся блоку цены, кнопка держит
        // свою ширину. Не влезают в строку — бейдж и кнопка переносятся (applyListWrap);
        // подпись кнопки укорачивается, только если кнопка шире всей колонки.
        for view in [priceLabel, priceBadge] {
            view.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        priceBlock.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .horizontal)
        listPriceLine = priceLine
        listBottom = bottom
        listPriceBlockWidth = priceBlock.widthAnchor.constraint(equalTo: bottom.widthAnchor)

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

    public override func layoutSubviews() {
        applyWrap(forWidth: bounds.width)
        super.layoutSubviews()
    }

    /// Списки меряют карточку по ширине ячейки: перенос решается до замера.
    public override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        if horizontalFittingPriority == .required { applyWrap(forWidth: targetSize.width) }
        return super.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: horizontalFittingPriority,
            verticalFittingPriority: verticalFittingPriority
        )
    }

    /// Переносы в ценах решаются по ширине карточки: в layoutSubviews и до замера списком.
    private func applyWrap(forWidth width: CGFloat) {
        guard width > 0 else { return }
        if type == .list { applyListWrap(forWidth: width) } else { applyColumnPriceWrap(forWidth: width) }
    }

    /// Длинные цены («799 990 ₽» и «1 574 990 ₽») в колонку плитки рядом не влезают: старая
    /// цена встаёт строкой над ценой, и цена с кнопкой остаются на линии соседей (низ карточек
    /// в списке выровнен распоркой). Иначе старая цена укорачивалась многоточием.
    private func applyColumnPriceWrap(forWidth width: CGFloat) {
        guard let priceRow = columnPriceRow, let spacer = columnPriceSpacer else { return }
        let column = type == .carousel ? Self.carouselWidth : width
        let old = fittingWidth(oldPriceLabel)
        let wraps = old > 0 && fittingWidth(priceLabel) + PersonalizationSpacing.md + old > column
        if columnPriceWrap == wraps { return }
        columnPriceWrap = wraps
        priceRow.axis = wraps ? .vertical : .horizontal
        priceRow.alignment = wraps ? .leading : .lastBaseline
        priceRow.spacing = wraps ? 0 : PersonalizationSpacing.md
        priceRow.insertArrangedSubview(oldPriceLabel, at: wraps ? 0 : 1)
        spacer.isHidden = wraps
    }

    /// В узкой колонке list-карточки (экран 360 pt, крупный шрифт) цена, бейдж и кнопка в строку
    /// не влезают: бейдж встаёт под цену, а кнопка — под блок цены к правому краю. Иначе
    /// укорачивалась подпись кнопки. Решение — по естественным ширинам, как у ряда с переносом
    /// на Android.
    private func applyListWrap(forWidth width: CGFloat) {
        guard let priceLine = listPriceLine, let bottom = listBottom else { return }
        let column = width - Self.listImageSide - PersonalizationSpacing.lg
        let gap = PersonalizationSpacing.md
        let price = fittingWidth(priceLabel)
        let badge = fittingWidth(priceBadge)
        let wrapsBadge = badge > 0 && price + gap + badge > column
        let line = wrapsBadge ? max(price, badge) : price + (badge > 0 ? gap + badge : 0)
        let block = max(line, fittingWidth(oldPriceLabel))
        let action = fittingWidth(button)
        let wrapsButton = action > 0 && block + gap + action > column
        if let current = listWrap, current.badge == wrapsBadge, current.button == wrapsButton { return }
        listWrap = (wrapsBadge, wrapsButton)

        priceLine.axis = wrapsBadge ? .vertical : .horizontal
        priceLine.alignment = wrapsBadge ? .leading : .center
        priceLine.spacing = wrapsBadge ? PersonalizationSpacing.sm : PersonalizationSpacing.md
        // Под ценой кнопка прижата вправо, а блок цены во всю ширину держит текст слева.
        bottom.axis = wrapsButton ? .vertical : .horizontal
        bottom.alignment = wrapsButton ? .trailing : .center
        listPriceBlockWidth?.isActive = wrapsButton
    }

    private func fittingWidth(_ view: UIView) -> CGFloat {
        if view.isHidden { return 0 }
        // Подпись — по своему тексту, без ограничений стека вокруг неё.
        if let label = view as? UILabel { return label.intrinsicContentSize.width }
        return view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
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
        // Другие тексты — другие ширины: перенос у list-карточки решается заново.
        setNeedsLayout()
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

extension PersonalizationProductCard: UIGestureRecognizerDelegate {
    /// Касание кнопки — её: нажатие на карточку тогда не начинается. Кнопка лежит в стеках
    /// глубже прямого потомка, и иначе тап карточки забирал её касание — товар открывался
    /// вместо «В корзину».
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var current = touch.view
        while let view = current, view !== self {
            if view is UIControl { return false }
            current = view.superview
        }
        return true
    }
}
