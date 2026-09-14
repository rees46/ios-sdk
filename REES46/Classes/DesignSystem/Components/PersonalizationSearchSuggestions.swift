import UIKit

/// Панель подсказок поиска: теги-подсказки, категории, товары.
///
/// Источник: Figma Mobile SDK UI Kit, секция Card, фрейм Search (151:3880).
/// Экран там нарисован наброском — шапка вручную, а не из InputField, шрифт
/// SF Pro, — поэтому сюда взято только то, что читается однозначно: ряд тегов
/// с шагом 8, блоки категорий и товаров с шагом 12 внутри и между, разделитель
/// 1px, боковые поля 16. Разделитель в макете — чёрный 4%, ближайший токен
/// Line/Generic Subtle (5%).
///
/// Строки — `PersonalizationSuggestionRow`, теги — `PersonalizationTag`.
/// Картинки хост грузит через `imageLoader`.
public final class PersonalizationSearchSuggestions: UIView {

    public struct Suggestion {
        public let id: String
        public let title: String
        /// Цена у товара, родительская категория у категории.
        public let subtitle: String?
        public let imageUrl: String?

        public init(id: String, title: String, subtitle: String? = nil, imageUrl: String? = nil) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.imageUrl = imageUrl
        }
    }

    /// Подстрока запроса, выделяемая в подсказках полужирным.
    public var highlight: String? {
        didSet { rows.forEach { $0.highlight = highlight } }
    }

    /// Показывать ли картинки у строк: в макете есть оба варианта.
    public var showImages: Bool = false {
        didSet { rows.forEach { $0.showImage = showImages } }
    }

    public var imageLoader: ((UIImageView, Suggestion) -> Void)?
    public var onTagTap: ((String) -> Void)?
    public var onCategoryTap: ((Suggestion) -> Void)?
    public var onProductTap: ((Suggestion) -> Void)?

    private let stack = UIStackView()
    private let tagsScroll = UIScrollView()
    private let tagsRow = UIStackView()
    private let categories = UIStackView()
    private let separator = UIView()
    private let products = UIStackView()
    private var tags: [String] = []
    private var categoryItems: [Suggestion] = []
    private var productItems: [Suggestion] = []

    private var rows: [PersonalizationSuggestionRow] {
        (categories.arrangedSubviews + products.arrangedSubviews).compactMap { $0 as? PersonalizationSuggestionRow }
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
        let side = PersonalizationSpacing.xl  // 16
        let gap = PersonalizationSpacing.lg   // 12

        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = gap
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        tagsRow.axis = .horizontal
        tagsRow.spacing = PersonalizationSpacing.md  // 8
        tagsRow.translatesAutoresizingMaskIntoConstraints = false
        tagsScroll.showsHorizontalScrollIndicator = false
        tagsScroll.addSubview(tagsRow)
        NSLayoutConstraint.activate([
            tagsRow.topAnchor.constraint(equalTo: tagsScroll.contentLayoutGuide.topAnchor),
            tagsRow.bottomAnchor.constraint(equalTo: tagsScroll.contentLayoutGuide.bottomAnchor),
            tagsRow.leadingAnchor.constraint(equalTo: tagsScroll.contentLayoutGuide.leadingAnchor, constant: side),
            tagsRow.trailingAnchor.constraint(equalTo: tagsScroll.contentLayoutGuide.trailingAnchor, constant: -side),
            tagsRow.heightAnchor.constraint(equalTo: tagsScroll.frameLayoutGuide.heightAnchor)
        ])
        tagsScroll.isHidden = true

        for column in [categories, products] {
            column.axis = .vertical
            column.alignment = .fill
            column.spacing = gap
            column.isLayoutMarginsRelativeArrangement = true
            column.layoutMargins = UIEdgeInsets(top: 0, left: side, bottom: 0, right: side)
            column.isHidden = true
        }

        separator.backgroundColor = PersonalizationColor.lineGenericSubtle
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        separator.isHidden = true

        stack.addArrangedSubview(tagsScroll)
        stack.addArrangedSubview(categories)
        stack.addArrangedSubview(separator)
        stack.addArrangedSubview(products)
    }

    public func setTags(_ tags: [String]) {
        self.tags = tags
        tagsRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tagsScroll.isHidden = tags.isEmpty
        for (index, tag) in tags.enumerated() {
            let view = PersonalizationTag(text: tag, view: .primary)
            view.tag = index
            view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tagTapped(_:))))
            tagsRow.addArrangedSubview(view)
        }
    }

    public func setCategories(_ items: [Suggestion]) {
        categoryItems = items
        fill(categories, items, kind: .category, action: #selector(categoryTapped(_:)))
        applySeparator()
    }

    public func setProducts(_ items: [Suggestion]) {
        productItems = items
        fill(products, items, kind: .product, action: #selector(productTapped(_:)))
        applySeparator()
    }

    private func fill(_ column: UIStackView, _ items: [Suggestion], kind: PersonalizationSuggestionRow.Kind, action: Selector) {
        column.arrangedSubviews.forEach { $0.removeFromSuperview() }
        column.isHidden = items.isEmpty
        for (index, item) in items.enumerated() {
            let row = PersonalizationSuggestionRow(kind: kind)
            row.tag = index
            row.title = item.title
            row.subtitle = item.subtitle
            row.showImage = showImages
            row.highlight = highlight
            row.addTarget(self, action: action, for: .touchUpInside)
            if showImages { imageLoader?(row.imageView, item) }
            column.addArrangedSubview(row)
        }
    }

    /// Разделитель нужен только между двумя непустыми блоками.
    private func applySeparator() {
        separator.isHidden = categories.isHidden || products.isHidden
    }

    @objc private func tagTapped(_ recognizer: UITapGestureRecognizer) {
        guard let index = recognizer.view?.tag, tags.indices.contains(index) else { return }
        onTagTap?(tags[index])
    }

    @objc private func categoryTapped(_ sender: UIControl) {
        guard categoryItems.indices.contains(sender.tag) else { return }
        onCategoryTap?(categoryItems[sender.tag])
    }

    @objc private func productTapped(_ sender: UIControl) {
        guard productItems.indices.contains(sender.tag) else { return }
        onProductTap?(productItems[sender.tag])
    }
}
