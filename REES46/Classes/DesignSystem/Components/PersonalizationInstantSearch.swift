import UIKit

/// Экран мгновенного поиска: поле ввода с «Cancel», недавние запросы, подсказки,
/// категории и товары.
///
/// Источник: Figma Mobile SDK UI Kit, страница InstantSearchField — Instant Search/Text
/// (151:3976), /Input (310:10207), /With Images (310:9829), /Clear Recent Searches
/// (310:10016). Поле — `PersonalizationInputField` типа Search размера MD, ссылки —
/// `PersonalizationLink`, подписи блоков — `PersonalizationListLabel`, теги —
/// `PersonalizationTag` с переносом по строкам, строки — `PersonalizationSuggestionRow`.
///
/// Недавние запросы — теги с крестиком, в конце синий тег «ещё»; подсказки при вводе —
/// такие же теги без крестика. Перед категориями и перед товарами разделитель 1px.
/// Совпадение с запросом в строках выделяется полужирным само.
///
/// Внимание: шаг колонки в макете 13 — такого значения в шкале нет, взят LG (12).
/// Разделитель в макете чёрный 4%, ближайший токен Line/Generic Subtle (5%).
/// Картинки хост грузит через `imageLoader`.
@_spi(PersonalizationUI) public final class PersonalizationInstantSearch: UIView {

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

    /// Поле ввода: наружу отдано ради клавиатуры и фокуса.
    public let input = PersonalizationInputField(size: .md, type: .search)

    public var query: String? {
        get { input.text }
        set { input.text = newValue; applyHighlight() }
    }

    public var placeholder: String? {
        get { input.placeholder }
        set { input.placeholder = newValue }
    }

    /// Подпись ссылки справа от поля. `nil` — без ссылки.
    public var cancelText: String? {
        didSet {
            cancelLink.text = cancelText
            cancelLink.isHidden = (cancelText ?? "").isEmpty
        }
    }

    public var onCancel: (() -> Void)?
    public var onQueryChanged: ((String) -> Void)?
    public var onSubmit: ((String) -> Void)?

    /// Подпись над недавними запросами. `nil` — блок без подписи и без «Clear».
    public var recentLabel: String? {
        didSet {
            recentLabelView.text = recentLabel
            applyRecentVisibility()
        }
    }

    public var clearText: String? {
        didSet {
            clearLink.text = clearText
            clearLink.isHidden = (clearText ?? "").isEmpty
        }
    }

    public var onClearRecent: (() -> Void)?

    /// Подпись синего тега в конце недавних запросов. `nil` — без него.
    public var moreText: String? {
        didSet { rebuildRecent() }
    }

    public var onMoreRecent: (() -> Void)?
    public var onRecentTap: ((String) -> Void)?
    public var onRecentRemove: ((String) -> Void)?
    public var onSuggestionTap: ((String) -> Void)?

    public var categoriesLabel: String? {
        didSet {
            categoriesLabelView.text = categoriesLabel
            applySectionVisibility()
        }
    }

    public var productsLabel: String? {
        didSet {
            productsLabelView.text = productsLabel
            applySectionVisibility()
        }
    }

    /// Показывать ли картинки у строк: в макете есть оба варианта.
    public var showImages: Bool = false {
        didSet { rows.forEach { $0.showImage = showImages } }
    }

    public var imageLoader: ((UIImageView, Suggestion) -> Void)?
    public var onCategoryTap: ((Suggestion) -> Void)?
    public var onProductTap: ((Suggestion) -> Void)?

    private let stack = UIStackView()
    private let header = UIStackView()
    private let cancelLink = PersonalizationLink()
    private let recentHeader = UIStackView()
    private let recentLabelView = PersonalizationListLabel()
    private let clearLink = PersonalizationLink()
    private let recentFlow = PersonalizationFlowView(horizontalGap: PersonalizationSpacing.md, verticalGap: PersonalizationSpacing.md)
    private let suggestionsFlow = PersonalizationFlowView(horizontalGap: PersonalizationSpacing.md, verticalGap: PersonalizationSpacing.md)
    private let categoriesSeparator = UIView()
    private let categoriesLabelView = PersonalizationListLabel()
    private let categories = UIStackView()
    private let productsSeparator = UIView()
    private let productsLabelView = PersonalizationListLabel()
    private let products = UIStackView()

    private var recentSearches: [String] = []
    private var suggestions: [String] = []
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
        let gap = PersonalizationSpacing.lg  // 12

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

        input.onTextChange = { [weak self] text in
            self?.applyHighlight()
            self?.onQueryChanged?(text)
        }
        input.textField.returnKeyType = .search
        input.textField.addTarget(self, action: #selector(submitted), for: .editingDidEndOnExit)
        cancelLink.isHidden = true
        cancelLink.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = PersonalizationSpacing.xl  // 16
        header.addArrangedSubview(input)
        header.addArrangedSubview(cancelLink)
        stack.addArrangedSubview(header)

        clearLink.isHidden = true
        clearLink.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        recentHeader.axis = .horizontal
        recentHeader.alignment = .center
        recentHeader.spacing = gap
        recentHeader.addArrangedSubview(recentLabelView)
        recentHeader.addArrangedSubview(clearLink)
        recentHeader.isHidden = true
        stack.addArrangedSubview(recentHeader)

        recentFlow.isHidden = true
        stack.addArrangedSubview(recentFlow)
        suggestionsFlow.isHidden = true
        stack.addArrangedSubview(suggestionsFlow)

        addSection(separator: categoriesSeparator, label: categoriesLabelView, column: categories, gap: gap)
        addSection(separator: productsSeparator, label: productsLabelView, column: products, gap: gap)
    }

    private func addSection(separator: UIView, label: PersonalizationListLabel, column: UIStackView, gap: CGFloat) {
        separator.backgroundColor = PersonalizationColor.lineGenericSubtle
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        separator.isHidden = true
        stack.addArrangedSubview(separator)
        label.isHidden = true
        stack.addArrangedSubview(label)
        column.axis = .vertical
        column.alignment = .fill
        column.spacing = gap
        column.isHidden = true
        stack.addArrangedSubview(column)
    }

    public func setRecentSearches(_ items: [String]) {
        recentSearches = items
        rebuildRecent()
    }

    public func setSuggestions(_ items: [String]) {
        suggestions = items
        suggestionsFlow.setItems(items.enumerated().map { index, item in
            let tag = PersonalizationTag(text: item, view: .secondary)
            tag.tag = index
            tag.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(suggestionTapped(_:))))
            return tag
        })
        suggestionsFlow.isHidden = items.isEmpty
    }

    public func setCategories(_ items: [Suggestion]) {
        categoryItems = items
        fill(categories, items, kind: .category, action: #selector(categoryTapped(_:)))
        applySectionVisibility()
    }

    public func setProducts(_ items: [Suggestion]) {
        productItems = items
        fill(products, items, kind: .product, action: #selector(productTapped(_:)))
        applySectionVisibility()
    }

    private func rebuildRecent() {
        var views: [UIView] = recentSearches.enumerated().map { index, item in
            let tag = PersonalizationTag(text: item, view: .secondary) { [weak self] in
                self?.onRecentRemove?(item)
            }
            tag.tag = index
            tag.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(recentTapped(_:))))
            return tag
        }
        if let more = moreText, !more.isEmpty, !recentSearches.isEmpty {
            let tag = PersonalizationTag(text: more, view: .primary)
            tag.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(moreTapped)))
            views.append(tag)
        }
        recentFlow.setItems(views)
        applyRecentVisibility()
    }

    private func applyRecentVisibility() {
        let has = !recentSearches.isEmpty
        recentFlow.isHidden = !has
        recentHeader.isHidden = !(has && !(recentLabel ?? "").isEmpty)
    }

    private func applySectionVisibility() {
        let hasCategories = !categoryItems.isEmpty
        categoriesSeparator.isHidden = !hasCategories
        categoriesLabelView.isHidden = !(hasCategories && !(categoriesLabel ?? "").isEmpty)
        categories.isHidden = !hasCategories
        let hasProducts = !productItems.isEmpty
        productsSeparator.isHidden = !hasProducts
        productsLabelView.isHidden = !(hasProducts && !(productsLabel ?? "").isEmpty)
        products.isHidden = !hasProducts
    }

    private func applyHighlight() {
        let highlight = input.text ?? ""
        rows.forEach { $0.highlight = highlight }
    }

    private func fill(_ column: UIStackView, _ items: [Suggestion], kind: PersonalizationSuggestionRow.Kind, action: Selector) {
        column.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, item) in items.enumerated() {
            let row = PersonalizationSuggestionRow(kind: kind)
            row.tag = index
            row.title = item.title
            row.subtitle = item.subtitle
            row.showImage = showImages
            row.highlight = input.text ?? ""
            row.addTarget(self, action: action, for: .touchUpInside)
            if showImages { imageLoader?(row.imageView, item) }
            column.addArrangedSubview(row)
        }
    }

    @objc private func submitted() {
        onSubmit?(input.text ?? "")
    }

    @objc private func cancelTapped() {
        onCancel?()
    }

    @objc private func clearTapped() {
        onClearRecent?()
    }

    @objc private func moreTapped() {
        onMoreRecent?()
    }

    @objc private func recentTapped(_ recognizer: UITapGestureRecognizer) {
        guard let index = recognizer.view?.tag, recentSearches.indices.contains(index) else { return }
        onRecentTap?(recentSearches[index])
    }

    @objc private func suggestionTapped(_ recognizer: UITapGestureRecognizer) {
        guard let index = recognizer.view?.tag, suggestions.indices.contains(index) else { return }
        onSuggestionTap?(suggestions[index])
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
