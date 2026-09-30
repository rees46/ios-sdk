import UIKit

/// Экран полной выдачи с данными SDK: заголовок с числом найденного, плитка ⇄ список,
/// теги применённых фильтров, счётчик, «загрузить ещё» или бесконечная прокрутка,
/// пустое состояние и экран фильтров — виджет сам ходит в `search` и держит состояние.
///
/// Паттерн SearchResultsScreen из Figma (страница 1:30), источник — `searchFull(query)`.
/// Визуальный слой — `PersonalizationSearchResultsTitle` в заголовке
/// `PersonalizationCatalog`; фильтры — `PersonalizationFilters` поверх выдачи внутри
/// этого же виджета, так что экран занимает весь отведённый ему экран хоста.
///
/// Инстанс SDK: `shopId` или единственный зарегистрированный; резолвится при показе
/// через `Rees46.awaitInstance`, явный — через `attach(_:)`.
///
/// Фасеты строятся из ответа: диапазон цены (`price_range`), бренды, цвета и размеры
/// (`industrial_filters`) и произвольные фасеты магазина (`filters`), из которых
/// показываются только те, где больше одного значения. Применённые значения идут
/// тегами в заголовок и параметрами в следующий запрос. Заголовок секции произвольного
/// фасета — его имя, приведённое через `facetTitle`.
///
/// Сортировки: кнопка в заголовке отдаёт `onSortTap` хосту (пикер в макете не
/// нарисован), выбранное хост кладёт в `sortBy` / `sortDir`. Каждый новый запрос
/// трекается событием `search`; нажатие на карточку запоминает источник `full_search`
/// и отдаёт товар хосту через `onProductTap`, кнопка карточки — через `onProductAction`.
@_spi(PersonalizationUI) public final class PersonalizationSearchResultsScreen: UIView {

    /// Значения фильтров, ушедшие в запрос.
    public struct Applied: Equatable {
        public var brands: Set<String> = []
        public var priceMin: String?
        public var priceMax: String?
        public var colors: Set<String> = []
        public var sizes: Set<String> = []
        public var facets: [String: Set<String>] = [:]

        public init() {}

        public var isEmpty: Bool {
            brands.isEmpty && (priceMin ?? "").isEmpty && (priceMax ?? "").isEmpty &&
                colors.isEmpty && sizes.isEmpty && facets.values.allSatisfy { $0.isEmpty }
        }
    }

    /// Заголовок выдачи.
    public let title = PersonalizationSearchResultsTitle()

    /// Каталог с плиткой, счётчиком и «загрузить ещё».
    public let catalog = PersonalizationCatalog()

    /// Экран фильтров; показывается поверх выдачи.
    public let filters = PersonalizationFilters()

    /// Магазин; `nil` — единственный зарегистрированный. Менять до показа.
    public var shopId: String?

    /// Поисковая фраза; смена перезапрашивает первую страницу.
    public var query: String? {
        didSet {
            title.text = titleText ?? query
            if oldValue != query { scheduleReload() }
        }
    }

    /// Заголовок экрана; `nil` — сама фраза.
    public var titleText: String? {
        didSet { title.text = titleText ?? query }
    }

    public var pageSize = 20

    /// `popular`, `price`, `discount`, `sales_rate`, `date`; `nil` — релевантность.
    public var sortBy: String? {
        didSet { if oldValue != sortBy { scheduleReload() } }
    }

    /// `asc` / `desc`.
    public var sortDir: String? {
        didSet { if oldValue != sortDir { scheduleReload() } }
    }

    /// Список id локаций через запятую.
    public var locations: String?

    /// Бесконечная прокрутка вместо кнопки «загрузить ещё».
    public var infiniteScroll = false {
        didSet { applyLoadMore() }
    }

    public var showFilters = true {
        didSet { title.showFiltersButton = showFilters }
    }

    public var showSort = true {
        didSet { title.showSortButton = showSort }
    }

    /// Какие фасеты из `filters` показывать; `nil` — все с более чем одним значением.
    public var facets: Set<String>?

    /// Подпись кнопки на карточке; `nil` — без кнопки.
    public var productActionText: String? {
        didSet { renderProducts() }
    }

    public var layout: PersonalizationProductsList.Layout {
        get { catalog.layout }
        set {
            catalog.layout = newValue
            title.selectedViewIndex = newValue == .grid ? 0 : 1
        }
    }

    public var imageAspect: PersonalizationProductImage.Aspect {
        get { catalog.imageAspect }
        set { catalog.imageAspect = newValue }
    }

    /// Загрузчик картинок; `nil` — встроенный.
    public var imageLoader: ((UIImageView, String) -> Void)?

    public var onBack: (() -> Void)?
    public var onSortTap: (() -> Void)?
    public var onProductTap: ((Product) -> Void)?
    public var onProductAction: ((Product) -> Void)?
    public var onError: ((SdkError) -> Void)?

    /// Загруженные товары в порядке выдачи.
    public private(set) var products: [Product] = []

    /// Значения фильтров; смена перезапрашивает первую страницу.
    public var applied = Applied() {
        didSet { if oldValue != applied { scheduleReload() } }
    }

    // MARK: - Тексты; локализация за хостом

    public var foundPrefix: String? = "Found"
    public var foundSuffix: String? = "products"
    public var countPrefix: String? = "Showing"
    public var countSeparator = "of"
    public var loadMoreText: String? = "Load more" {
        didSet { applyLoadMore() }
    }
    public var emptyText: String? = "No results for your request." {
        didSet { applyEmpty() }
    }
    public var filtersTitle: String? = "Filters"
    public var resetText: String? = "Reset"
    public var applyText: String? = "Apply"
    public var showMoreText: String? = "Show more"
    public var showLessText: String? = "Show less"
    public var priceTitle = "Price"
    public var fromLabel = "From"
    public var toLabel = "to"
    public var brandsTitle = "Brand"
    public var colorsTitle = "Color"
    public var sizesTitle = "Size"

    /// Заголовок произвольного фасета по его имени в ответе.
    public var facetTitle: (String) -> String = { name in
        let spaced = name.replacingOccurrences(of: "_", with: " ")
        return spaced.prefix(1).uppercased() + String(spaced.dropFirst())
    }

    private let filtersScroll = UIScrollView()
    private var sdk: PersonalizationSDK?
    private var instanceHandle: Cancellable?
    private var total = 0
    private var page = 0
    private var loading = false
    private var facetSource: SearchResponse?
    private var requestSeq = 0
    /// Первая страница пришла и пуста — только тогда показывается пустое состояние.
    private var noResults = false
    private var pendingReload: DispatchWorkItem?

    public init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = PersonalizationColor.backgroundGeneric
        let padding = PersonalizationSpacing.xl

        catalog.header = title
        catalog.imageLoader = { [weak self] imageView, product in self?.loadImage(imageView, url: product.imageUrl) }
        catalog.onProductTap = { [weak self] card in
            guard let self, let product = self.products.first(where: { $0.id == card.id }) else { return }
            self.productTapped(product)
        }
        catalog.onProductAction = { [weak self] card in
            guard let self, let product = self.products.first(where: { $0.id == card.id }) else { return }
            self.onProductAction?(product)
        }
        catalog.onLoadMore = { [weak self] in self?.loadMore() }
        catalog.onNearEnd = { [weak self] in
            guard let self, self.infiniteScroll else { return }
            self.loadMore()
        }
        // Каталог прокручивается сам, а не во внешнем скролле: там его лента раскладывалась бы
        // целиком, и каждая догруженная страница оставалась бы в памяти всеми карточками.
        catalog.contentInset = UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
        catalog.translatesAutoresizingMaskIntoConstraints = false
        addSubview(catalog)
        NSLayoutConstraint.activate([
            catalog.topAnchor.constraint(equalTo: topAnchor),
            catalog.bottomAnchor.constraint(equalTo: bottomAnchor),
            catalog.leadingAnchor.constraint(equalTo: leadingAnchor),
            catalog.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        title.onBack = { [weak self] in self?.onBack?() }
        title.onViewChanged = { [weak self] index in self?.catalog.layout = index == 0 ? .grid : .list }
        title.onFilters = { [weak self] in self?.openFilters() }
        title.onSort = { [weak self] in self?.onSortTap?() }

        filters.onClose = { [weak self] in self?.closeFilters() }
        filters.onReset = { [weak self] in
            self?.closeFilters()
            self?.applied = Applied()
        }
        filters.onApply = { [weak self] in
            guard let self else { return }
            self.closeFilters()
            self.applied = self.fromSections(self.filters.sections)
        }
        embed(filters, in: filtersScroll, padding: padding)
        filtersScroll.isHidden = true

        applyLoadMore()
    }

    private func embed(_ content: UIView, in scrollView: UIScrollView, padding: CGFloat) {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = PersonalizationColor.backgroundGeneric
        scrollView.alwaysBounceVertical = true
        addSubview(scrollView)
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: padding),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -padding),
            content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: padding),
            content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -padding),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * padding)
        ])
    }

    /// Явный инстанс вместо резолва по `shopId`.
    public func attach(_ sdk: PersonalizationSDK) {
        instanceHandle?.cancel()
        instanceHandle = nil
        self.sdk = sdk
        reload()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else {
            instanceHandle?.cancel()
            instanceHandle = nil
            return
        }
        guard sdk == nil, instanceHandle == nil else { return }
        instanceHandle = Rees46.awaitInstance(for: shopId) { [weak self] resolved in
            MainThread.run { self?.attach(resolved) }
        }
    }

    public var isFiltersOpen: Bool { !filtersScroll.isHidden }

    public func openFilters() {
        filters.text = filtersTitle
        filters.resetText = resetText
        filters.applyText = applyText
        filters.setSections(buildSections())
        filtersScroll.setContentOffset(.zero, animated: false)
        filtersScroll.isHidden = false
    }

    public func closeFilters() {
        filtersScroll.isHidden = true
    }

    /// Первая страница заново — сразу; отложенный перезапрос от смены свойств снимается.
    public func reload() {
        pendingReload?.cancel()
        pendingReload = nil
        guard let sdk else { return }
        let text = (query ?? "").trimmingCharacters(in: .whitespaces)
        // Запрос в полёте отменяется всегда, и его флаги сбрасываются здесь же: ответ
        // отбросится по seq и сам их уже не снимет — лоадер крутился бы вечно,
        // а loadMore остался бы заблокирован.
        requestSeq += 1
        loading = false
        catalog.isLoading = false
        noResults = false
        products = []
        total = 0
        page = 0
        renderProducts()
        // Новая выдача — с начала ленты, а не с места, где пользователь бросил прошлую.
        catalog.scrollToTop()
        guard !text.isEmpty else { return }
        sdk.tracking.search(query: text)
        request(sdk, text: text, nextPage: 1)
    }

    /// Смена свойств перезапрашивает на следующем витке главного цикла: несколько смен
    /// подряд (сортировка и направление, обе границы цены) — один запрос и одно событие `search`.
    private func scheduleReload() {
        guard pendingReload == nil else { return }
        let work = DispatchWorkItem { [weak self] in self?.reload() }
        pendingReload = work
        DispatchQueue.main.async(execute: work)
    }

    /// Следующая страница, если она есть и запрос не в полёте.
    public func loadMore() {
        guard let sdk else { return }
        let text = (query ?? "").trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !loading, products.count < total else { return }
        request(sdk, text: text, nextPage: page + 1)
    }

    private func request(_ sdk: PersonalizationSDK, text: String, nextPage: Int) {
        requestSeq += 1
        let seq = requestSeq
        loading = true
        catalog.isLoading = true
        let facetValues = applied.facets.filter { !$0.value.isEmpty }.mapValues { Array($0) }
        sdk.search(
            query: text,
            limit: pageSize,
            offset: (nextPage - 1) * pageSize,
            sortBy: sortBy,
            sortDir: sortDir,
            locations: locations,
            brands: applied.brands.isEmpty ? nil : applied.brands.joined(separator: ","),
            filters: facetValues.isEmpty ? nil : facetValues,
            priceMin: applied.priceMin.flatMap { Double($0.trimmingCharacters(in: .whitespaces)) },
            priceMax: applied.priceMax.flatMap { Double($0.trimmingCharacters(in: .whitespaces)) },
            colors: applied.colors.isEmpty ? nil : Array(applied.colors),
            fashionSizes: applied.sizes.isEmpty ? nil : Array(applied.sizes)
        ) { [weak self] result in
            MainThread.run {
                guard let self, seq == self.requestSeq else { return }
                self.loading = false
                self.catalog.isLoading = false
                switch result {
                case .success(let response):
                    self.page = nextPage
                    self.total = response.productsTotal
                    self.products = nextPage == 1 ? response.products : self.products + response.products
                    if nextPage == 1 {
                        self.facetSource = response
                        self.noResults = response.products.isEmpty
                    }
                    self.renderProducts()
                case .failure(let error):
                    self.onError?(error)
                }
            }
        }
    }

    // MARK: - Раскладка

    private func renderProducts() {
        catalog.products = products.map { $0.toCardProduct(actionText: productActionText) }
        title.setResults(prefix: foundPrefix, count: total, suffix: foundSuffix)
        if products.isEmpty {
            catalog.setCount(prefix: nil, shown: 0, separator: countSeparator, total: 0)
        } else {
            catalog.setCount(prefix: countPrefix, shown: products.count, separator: countSeparator, total: total)
        }
        applyEmpty()
        applyLoadMore()
        renderAppliedTags()
    }

    /// «Ничего не найдено» — только после успешной пустой первой страницы: не на время
    /// загрузки, не для пустой фразы (запроса нет) и не после ошибки.
    private func applyEmpty() {
        catalog.emptyText = noResults ? emptyText : nil
    }

    private func applyLoadMore() {
        let hasMore = !products.isEmpty && products.count < total
        catalog.loadMoreText = hasMore && !infiniteScroll ? loadMoreText : nil
    }

    private func renderAppliedTags() {
        var tags: [PersonalizationSearchResultsTitle.Filter] = []
        for brand in applied.brands.sorted() {
            tags.append(.init(label: brand) { [weak self] in self?.applied.brands.remove(brand) })
        }
        let priceMin = (applied.priceMin ?? "").trimmingCharacters(in: .whitespaces)
        let priceMax = (applied.priceMax ?? "").trimmingCharacters(in: .whitespaces)
        if !priceMin.isEmpty || !priceMax.isEmpty {
            let label = [priceMin, priceMax].filter { !$0.isEmpty }.joined(separator: " – ")
            tags.append(.init(label: "\(priceTitle) \(label)") { [weak self] in
                guard let self else { return }
                // Обе границы одним присваиванием — одна смена `applied`.
                var next = self.applied
                next.priceMin = nil
                next.priceMax = nil
                self.applied = next
            })
        }
        for color in applied.colors.sorted() {
            tags.append(.init(label: color) { [weak self] in self?.applied.colors.remove(color) })
        }
        for size in applied.sizes.sorted() {
            tags.append(.init(label: size) { [weak self] in self?.applied.sizes.remove(size) })
        }
        for (name, values) in applied.facets.sorted(by: { $0.key < $1.key }) {
            for value in values.sorted() {
                tags.append(.init(label: value) { [weak self] in self?.applied.facets[name]?.remove(value) })
            }
        }
        title.setFilters(tags)
    }

    private func loadImage(_ imageView: UIImageView, url: String?) {
        if let loader = imageLoader, let url {
            loader(imageView, url)
        } else {
            SearchImages.shared.load(imageView, url: url)
        }
    }

    private func productTapped(_ product: Product) {
        let text = (query ?? "").trimmingCharacters(in: .whitespaces)
        if !text.isEmpty {
            sdk?.tracking.setSource(TrackingSource(type: .fullSearch, code: text))
        }
        onProductTap?(product)
    }

    // MARK: - Фасеты ⇄ секции экрана фильтров

    private enum SectionId {
        static let price = "price"
        static let brands = "brands"
        static let colors = "colors"
        static let sizes = "sizes"
        static let facet = "facet:"
    }

    private func options(_ values: [String], checked: Set<String>) -> [PersonalizationFilters.Option] {
        var seen = Set<String>()
        return (values + checked.sorted()).filter { seen.insert($0).inserted }.map {
            PersonalizationFilters.Option(id: $0, label: $0, checked: checked.contains($0))
        }
    }

    private func buildSections() -> [PersonalizationFilters.Section] {
        let source = facetSource
        var sections: [PersonalizationFilters.Section] = []
        if source?.priceRange != nil || applied.priceMin != nil || applied.priceMax != nil {
            // Границы диапазона — подсказками: в запрос уходит только то, что ввёл пользователь.
            sections.append(.range(
                id: SectionId.price, title: priceTitle, fromLabel: fromLabel, toLabel: toLabel,
                from: applied.priceMin, to: applied.priceMax,
                fromPlaceholder: source?.priceRange.map { bound($0.min) },
                toPlaceholder: source?.priceRange.map { bound($0.max) }
            ))
        }
        let brands = source?.brands ?? []
        if !brands.isEmpty || !applied.brands.isEmpty {
            sections.append(.options(
                id: SectionId.brands, title: brandsTitle, options: options(brands, checked: applied.brands),
                showMoreText: showMoreText, showLessText: showLessText
            ))
        }
        let colors = source?.industrialFilters?.fashionColors.map(\.color) ?? []
        if !colors.isEmpty || !applied.colors.isEmpty {
            sections.append(.options(
                id: SectionId.colors, title: colorsTitle, options: options(colors, checked: applied.colors),
                showMoreText: showMoreText, showLessText: showLessText
            ))
        }
        let sizes = source?.industrialFilters?.fashionSizes.map(\.size) ?? []
        if !sizes.isEmpty || !applied.sizes.isEmpty {
            sections.append(.options(
                id: SectionId.sizes, title: sizesTitle, options: options(sizes, checked: applied.sizes),
                showMoreText: showMoreText, showLessText: showLessText
            ))
        }
        let wanted = facets
        for (name, facet) in (source?.filters ?? [:]).sorted(by: { $0.key < $1.key }) {
            let values = facet.values.keys.sorted()
            let checked = applied.facets[name] ?? []
            let visible = wanted.map { $0.contains(name) } ?? (values.count > 1)
            guard visible || !checked.isEmpty else { continue }
            sections.append(.options(
                id: SectionId.facet + name, title: facetTitle(name), options: options(values, checked: checked),
                showMoreText: showMoreText, showLessText: showLessText
            ))
        }
        return sections
    }

    /// Граница цены без хвоста «.0»: сервер отдаёт число, форматированной строки у него нет.
    private func bound(_ value: Double) -> String {
        value == value.rounded(.down) ? String(Int64(value)) : String(value)
    }

    private func fromSections(_ sections: [PersonalizationFilters.Section]) -> Applied {
        var next = Applied()
        for section in sections {
            switch section {
            case let .range(id, _, _, _, from, to, _, _, _):
                guard id == SectionId.price else { continue }
                next.priceMin = from.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
                next.priceMax = to.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
            case let .options(id, _, options, _, _, _):
                let checked = Set(options.filter(\.checked).map(\.id))
                switch id {
                case SectionId.brands: next.brands = checked
                case SectionId.colors: next.colors = checked
                case SectionId.sizes: next.sizes = checked
                default:
                    if id.hasPrefix(SectionId.facet) {
                        next.facets[String(id.dropFirst(SectionId.facet.count))] = checked
                    }
                }
            }
        }
        return next
    }
}
