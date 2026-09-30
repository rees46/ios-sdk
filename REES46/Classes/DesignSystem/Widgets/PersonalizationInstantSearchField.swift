import UIKit

/// Мгновенный поиск с данными SDK: поле ввода, недавние запросы, подсказки, категории и
/// товары — виджет сам ходит в `suggest` (instant search) / `searchBlank` и держит состояние.
///
/// Паттерн InstantSearchField из Figma (страница 1:29): «компонент владеет вводом»,
/// источник — `searchInstant(query)`. Визуальный слой — `PersonalizationInstantSearch`,
/// доступен через `view` для тонкой настройки; тексты подписей проксированы сюда.
///
/// Инстанс SDK: `shopId` выбирает магазин при нескольких зарегистрированных; без него
/// берётся единственный. Инстанс резолвится при показе через `Rees46.awaitInstance` —
/// дожидается регистрации, если хост ещё не успел. Явный инстанс — через `attach(_:)`.
///
/// Пока запрос короче `minChars` показывается пустое состояние: история запросов
/// (локальная, по магазину), а из `searchBlank` — товары и популярные категории;
/// популярные фразы (`suggests`) подставляются тегами, только если истории ещё нет.
/// При вводе после `debounce` уходит instant-поиск: фразы из `queries` — тегами,
/// категории и товары — строками. Ответ на устаревший запрос отбрасывается.
///
/// Нажатие на товар или категорию запоминает источник `instant_search` в трекинге
/// и отдаёт объект хосту — навигация и `productView` за ним. Отправка (кнопка поиска
/// клавиатуры, тег истории или подсказки) кладёт фразу в историю и вызывает `onSubmit` —
/// экран полной выдачи открывает хост, событие `search` трекает `PersonalizationSearchResultsScreen`.
@_spi(PersonalizationUI) public final class PersonalizationInstantSearchField: UIView {

    /// Визуальный слой.
    public let view = PersonalizationInstantSearch()

    /// Магазин; `nil` — единственный зарегистрированный. Менять до показа.
    public var shopId: String?

    public var debounce: TimeInterval = 0.3
    public var minChars: Int = 2
    public var productsLimit: Int = 5
    public var categoriesLimit: Int = 3
    public var suggestionsLimit: Int = 8
    public var recentLimit: Int = 10

    /// Сколько недавних запросов видно до тега «ещё».
    public var recentCollapsed: Int = 5

    public var showRecent = true
    public var showSuggestions = true
    public var showCategories = true
    public var showProducts = true

    /// Список id локаций через запятую.
    public var locations: String?

    public var onSubmit: ((String) -> Void)?
    public var onCancel: (() -> Void)?
    public var onProductTap: ((Product) -> Void)?
    public var onCategoryTap: ((PersonalizationSearchCategory) -> Void)?
    public var onError: ((SdkError) -> Void)?

    /// Загрузчик картинок; `nil` — встроенный.
    public var imageLoader: ((UIImageView, String) -> Void)?

    public var query: String? {
        get { view.query }
        set { view.query = newValue }
    }

    public var placeholder: String? {
        get { view.placeholder }
        set { view.placeholder = newValue }
    }

    public var cancelText: String? {
        get { view.cancelText }
        set { view.cancelText = newValue }
    }

    public var recentLabel: String? {
        get { view.recentLabel }
        set { view.recentLabel = newValue }
    }

    public var clearText: String? {
        get { view.clearText }
        set { view.clearText = newValue }
    }

    /// Подпись тега «ещё»; показывается, когда история длиннее `recentCollapsed`.
    public var moreText: String? {
        didSet { renderRecent() }
    }

    public var categoriesLabel: String? {
        get { view.categoriesLabel }
        set { view.categoriesLabel = newValue }
    }

    public var productsLabel: String? {
        get { view.productsLabel }
        set { view.productsLabel = newValue }
    }

    public var showImages: Bool {
        get { view.showImages }
        set { view.showImages = newValue }
    }

    private var sdk: PersonalizationSDK?
    private var instanceHandle: Cancellable?
    private var recent: RecentSearches?
    private var recentItems: [String] = []
    private var recentExpanded = false
    private var blank: SearchBlankResponse?
    private var instant: SearchResponse?
    private var requestSeq = 0
    private var debounceWork: DispatchWorkItem?

    public init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        wireView()
    }

    private func wireView() {
        view.imageLoader = { [weak self] imageView, suggestion in
            guard let self else { return }
            if let loader = self.imageLoader, let url = suggestion.imageUrl {
                loader(imageView, url)
            } else {
                SearchImages.shared.load(imageView, url: suggestion.imageUrl)
            }
        }
        view.onQueryChanged = { [weak self] text in self?.typed(text) }
        view.onSubmit = { [weak self] text in self?.submit(text) }
        view.onCancel = { [weak self] in self?.onCancel?() }
        view.onClearRecent = { [weak self] in
            guard let self else { return }
            self.recentItems = self.recent?.clear() ?? []
            self.renderRecent()
        }
        view.onRecentRemove = { [weak self] item in
            guard let self else { return }
            self.recentItems = self.recent?.remove(item) ?? self.recentItems
            self.renderRecent()
        }
        view.onRecentTap = { [weak self] item in
            self?.view.query = item
            self?.submit(item)
        }
        view.onMoreRecent = { [weak self] in
            self?.recentExpanded = true
            self?.renderRecent()
        }
        view.onSuggestionTap = { [weak self] item in
            self?.view.query = item
            self?.submit(item)
        }
        view.onCategoryTap = { [weak self] suggestion in self?.categoryTapped(suggestion.id) }
        view.onProductTap = { [weak self] suggestion in self?.productTapped(suggestion.id) }
    }

    /// Явный инстанс вместо резолва по `shopId`.
    public func attach(_ sdk: PersonalizationSDK) {
        instanceHandle?.cancel()
        instanceHandle = nil
        self.sdk = sdk
        recent = RecentSearches(shopKey: sdk.shopId, limit: recentLimit)
        recentItems = recent?.load() ?? []
        renderRecent()
        loadBlank()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else {
            instanceHandle?.cancel()
            instanceHandle = nil
            return
        }
        guard sdk == nil, instanceHandle == nil else { return }
        // Неоднозначный запрос (несколько магазинов без shopId) awaitInstance молча роняет —
        // виджет остаётся пустым, а не валит экран.
        instanceHandle = Rees46.awaitInstance(for: shopId) { [weak self] resolved in
            MainThread.run { self?.attach(resolved) }
        }
    }

    private func loadBlank() {
        guard let sdk else { return }
        requestSeq += 1
        let seq = requestSeq
        sdk.searchBlank { [weak self] result in
            MainThread.run {
                guard let self else { return }
                switch result {
                case .success(let response):
                    self.blank = response
                    if seq == self.requestSeq { self.renderBlank() }
                case .failure(let error):
                    self.onError?(error)
                }
            }
        }
    }

    private func typed(_ text: String) {
        debounceWork?.cancel()
        if text.trimmingCharacters(in: .whitespaces).count < minChars {
            requestSeq += 1
            instant = nil
            renderBlank()
            return
        }
        let work = DispatchWorkItem { [weak self] in self?.runInstant() }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: work)
    }

    private func runInstant() {
        guard let sdk else { return }
        let text = (view.query ?? "").trimmingCharacters(in: .whitespaces)
        guard text.count >= minChars else { return }
        requestSeq += 1
        let seq = requestSeq
        sdk.suggest(query: text, locations: locations) { [weak self] result in
            MainThread.run {
                guard let self, seq == self.requestSeq else { return }
                switch result {
                case .success(let response):
                    self.instant = response
                    self.renderInstant(response)
                case .failure(let error):
                    self.onError?(error)
                }
            }
        }
    }

    private func submit(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        recentItems = recent?.add(trimmed) ?? recentItems
        recentExpanded = false
        onSubmit?(trimmed)
    }

    private var typing: Bool {
        (view.query ?? "").trimmingCharacters(in: .whitespaces).count >= minChars
    }

    // MARK: - Раскладка данных по визуальному слою

    private func renderRecent() {
        guard !typing else { return }
        let items = showRecent ? recentItems : []
        let collapsed = !recentExpanded && items.count > recentCollapsed
        view.setRecentSearches(collapsed ? Array(items.prefix(recentCollapsed)) : items)
        view.moreText = collapsed ? moreText : nil
        // Популярные фразы сервера заменяют пустую историю.
        let suggests = blank?.suggests.map(\.name) ?? []
        view.setSuggestions(items.isEmpty && showSuggestions ? Array(suggests.prefix(suggestionsLimit)) : [])
    }

    private func renderBlank() {
        renderRecent()
        let categories = showCategories ? Array((blank?.popularCategories ?? []).prefix(categoriesLimit)) : []
        view.setCategories(categories.map {
            PersonalizationInstantSearch.Suggestion(id: $0.url.isEmpty ? $0.name : $0.url, title: $0.name)
        })
        let products = showProducts ? Array((blank?.products ?? []).prefix(productsLimit)) : []
        view.setProducts(products.map { $0.toSuggestion() })
    }

    private func renderInstant(_ response: SearchResponse) {
        view.setRecentSearches([])
        view.moreText = nil
        let queries = showSuggestions ? response.queries.map(\.name) : []
        view.setSuggestions(Array(queries.prefix(suggestionsLimit)))
        let categories = showCategories ? response.categories : []
        view.setCategories(categories.prefix(categoriesLimit).map { category in
            PersonalizationInstantSearch.Suggestion(
                id: category.id,
                title: category.name,
                subtitle: parentName(of: category, in: response.categories)
            )
        })
        let products = showProducts ? response.products : []
        view.setProducts(products.prefix(productsLimit).map { $0.toSuggestion() })
    }

    /// В ответе родитель — это id; имя ищем среди пришедших категорий.
    private func parentName(of category: Category, in all: [Category]) -> String? {
        guard let parentId = category.parentId, !parentId.isEmpty else { return nil }
        return all.first { $0.id == parentId }?.name
    }

    private func productTapped(_ id: String) {
        let candidates = (instant?.products ?? []) + (blank?.products ?? [])
        guard let product = candidates.first(where: { $0.id == id }) else { return }
        rememberSource()
        onProductTap?(product)
    }

    private func categoryTapped(_ id: String) {
        if let category = instant?.categories.first(where: { $0.id == id }) {
            rememberSource()
            onCategoryTap?(PersonalizationSearchCategory(id: category.id, name: category.name, url: category.url))
        } else if let popular = blank?.popularCategories.first(where: { ($0.url.isEmpty ? $0.name : $0.url) == id }) {
            rememberSource()
            onCategoryTap?(PersonalizationSearchCategory(id: nil, name: popular.name, url: popular.url))
        }
    }

    private func rememberSource() {
        let text = (view.query ?? "").trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        sdk?.tracking.setSource(TrackingSource(type: .instantSearch, code: text))
    }
}

private extension Product {
    func toSuggestion() -> PersonalizationInstantSearch.Suggestion {
        let card = toCardProduct(actionText: nil)
        return PersonalizationInstantSearch.Suggestion(id: id, title: name, subtitle: card.price, imageUrl: card.imageUrl)
    }
}
