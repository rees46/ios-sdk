import UIKit

/// Значения фильтров экрана выдачи, ушедшие в запрос.
@_spi(PersonalizationUI) public struct PersonalizationAppliedFilters: Equatable {
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

/// Параметры запроса из применённых фильтров — одни и те же у поиска и категории.
extension PersonalizationAppliedFilters {
    /// Бренды через запятую; `nil` — не выбраны.
    var brandsParam: String? {
        brands.isEmpty ? nil : brands.sorted().joined(separator: ",")
    }

    /// Фасеты с выбранными значениями: имя → значения; `nil` — ни одного.
    var facetsParam: [String: Any]? {
        let values = facets.filter { !$0.value.isEmpty }.mapValues { $0.sorted() }
        return values.isEmpty ? nil : values
    }

    var priceMinValue: Double? { priceMin.flatMap { Double($0.trimmingCharacters(in: .whitespaces)) } }
    var priceMaxValue: Double? { priceMax.flatMap { Double($0.trimmingCharacters(in: .whitespaces)) } }
}

/// Значение фильтра из ответа: строка, которая уходит в запрос, и сколько товаров с ним,
/// если сервер это сказал.
struct ResultsFacetValue {
    var value: String
    var count: Int?
}

/// Фасеты первой страницы выдачи, из которых строится экран фильтров.
struct ResultsFacets {
    var priceRange: PriceRange?
    var brands: [ResultsFacetValue] = []
    /// Цвета и размеры — `industrial_filters` поиска; у категории их нет.
    var colors: [ResultsFacetValue] = []
    var sizes: [ResultsFacetValue] = []
    var filters: [String: Filter] = [:]
}

/// Страница выдачи, приведённая к общему виду.
struct ResultsPage<Item> {
    var items: [Item]
    var total: Int
    var facets: ResultsFacets
}

/// Тексты по умолчанию: у дженерика не бывает своих статических свойств.
private enum ResultsDefaults {
    static let errorText = "Something went wrong. Check your connection and try again."
    static let retryText = "Retry"
}

/// `title` значения-объекта: значение, которое после пробелов по краям начинается с `{` и разбирается
/// как JSON-объект с непустой строкой `title` (так некоторые магазины отдают, например, стикеры
/// со слагом и цветами). Иначе `nil` — значение показывается как есть.
private func jsonObjectTitle(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("{"),
          let data = trimmed.data(using: .utf8),
          let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          let title = (object["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
          !title.isEmpty else { return nil }
    return title
}

private enum SectionId {
    static let price = "price"
    static let brands = "brands"
    static let colors = "colors"
    static let sizes = "sizes"
    static let facet = "facet:"
}

/// Общее ядро экранов полной выдачи с данными SDK — поиска (`PersonalizationSearchResultsScreen`)
/// и категории (`PersonalizationCategoryScreen`): заголовок с числом товаров, плитка ⇄ список,
/// теги применённых фильтров, счётчик, «загрузить ещё» или бесконечная прокрутка, пустое
/// состояние, ошибка с повтором и экран фильтров. Наследник задаёт только источник: ключ
/// выдачи, запрос страницы, событие новой выдачи и карточку товара.
///
/// Визуальный слой — `PersonalizationSearchResultsTitle` в заголовке `PersonalizationCatalog`;
/// фильтры — `PersonalizationFilters` поверх выдачи внутри этого же виджета, так что экран
/// занимает весь отведённый ему экран хоста.
///
/// Инстанс SDK: `shopId` или единственный зарегистрированный; резолвится при показе
/// через `Rees46.awaitInstance`, явный — через `attach(_:)`.
///
/// Фасеты строятся из ответа: диапазон цены (`price_range`), бренды, цвета и размеры
/// (`industrial_filters`, есть только у поиска) и произвольные фасеты магазина (`filters`).
/// Приоритета у произвольных фасетов в ответе нет, а их бывают сотни, поэтому показываются
/// те, где больше одного значения, по убыванию числа товаров с фасетом, первые `maxFacets`.
/// Явный список `facets` главнее — в его порядке. Применённые значения идут тегами
/// в заголовок и параметрами в следующий запрос; применённый фасет виден всегда.
/// Заголовок секции произвольного фасета — его имя, приведённое через `facetTitle`.
///
/// Подпись значения произвольного фасета — `facetValueTitle` хоста, иначе `title` значения,
/// если оно JSON-объект, иначе само значение; в запрос всегда уходит исходное значение. Кит
/// опирается только на формат ответа: что значат фасеты конкретного магазина, задаёт хост.
/// Рядом с вариантом — число товаров из ответа («Samsung (801)»), если оно есть и включено
/// `showValueCounts`; в тегах применённых фильтров числа нет.
///
/// Сортировки: кнопка в заголовке отдаёт `onSortTap` хосту (пикер в макете не
/// нарисован), выбранное хост кладёт в `sortBy` / `sortDir`. Нажатие на карточку отдаёт
/// товар хосту через `onProductTap`, кнопка карточки — через `onProductAction`.
///
/// Ошибка загрузки: если не пришла первая страница, вместо выдачи — `errorText` и кнопка
/// `retryText`; если следующая — `retryText` встаёт на место «загрузить ещё». Нажатие
/// повторяет ту же страницу, `onError` зовётся на каждую ошибку.
@_spi(PersonalizationUI) public class PersonalizationResultsScreen<Item>: UIView {

    /// Значения фильтров, ушедшие в запрос.
    public typealias Applied = PersonalizationAppliedFilters

    /// Заголовок выдачи.
    public let title = PersonalizationSearchResultsTitle()

    /// Каталог с плиткой, счётчиком и «загрузить ещё».
    public let catalog = PersonalizationCatalog()

    /// Экран фильтров; показывается поверх выдачи.
    public let filters = PersonalizationFilters()

    /// Магазин; `nil` — единственный зарегистрированный. Менять до показа.
    public var shopId: String?

    /// Заголовок экрана; `nil` — заголовок по умолчанию (у поиска — сама фраза).
    public var titleText: String? {
        didSet { applyTitle() }
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

    /// Какие фасеты из `filters` показывать и в каком порядке; `nil` — `maxFacets` фасетов
    /// с более чем одним значением, которые есть у наибольшего числа товаров.
    public var facets: [String]?

    /// Сколько фасетов показывать без явного `facets`; `nil` или 0 — все.
    public var maxFacets: Int? = 10

    /// Подпись кнопки на карточке; `nil` — без кнопки.
    public var productActionText: String? {
        didSet { renderProducts() }
    }

    /// Рейтинг на карточках. В ответах поиска и категории рейтинга нет, поэтому по умолчанию выключен.
    public var showRating = false {
        didSet { catalog.showRating = showRating }
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
    public var onProductTap: ((Item) -> Void)?
    public var onProductAction: ((Item) -> Void)?
    public var onError: ((SdkError) -> Void)?

    /// Загруженные товары в порядке выдачи.
    public private(set) var products: [Item] = []

    /// Значения фильтров; смена перезапрашивает первую страницу.
    public var applied = Applied() {
        didSet { if oldValue != applied { scheduleReload() } }
    }

    // MARK: - Тексты; локализация за хостом

    /// Счётчик в заголовке: «`foundPrefix` N `foundSuffix`»; оба `nil` — счётчика нет.
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
    /// Текст ошибки первой страницы. `nil` или пустая строка — текст по умолчанию:
    /// без него ошибка выглядела бы пустым экраном.
    public var errorText: String? = ResultsDefaults.errorText {
        didSet {
            if (errorText ?? "").isEmpty { errorText = ResultsDefaults.errorText }
            applyError()
        }
    }
    /// Подпись кнопки повтора. `nil` или пустая строка — подпись по умолчанию: без кнопки
    /// выдача после ошибки не восстановилась бы, бесконечная прокрутка ждёт именно её.
    public var retryText: String? = ResultsDefaults.retryText {
        didSet {
            if (retryText ?? "").isEmpty { retryText = ResultsDefaults.retryText }
            applyError()
            applyLoadMore()
        }
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

    /// Подпись значения произвольного фасета: имя фасета и значение, как они пришли в ответе.
    /// `nil` или пустая строка — подпись по умолчанию: `title` значения-объекта JSON, иначе
    /// само значение. В запрос уходит исходное значение, а не подпись.
    public var facetValueTitle: ((_ facet: String, _ value: String) -> String?)?

    /// Число товаров рядом со значением фильтра — «Samsung (801)»; без числа в ответе — без скобок.
    public var showValueCounts = true

    /// Подложка экрана фильтров: он сам держит заголовок и кнопки на месте и прокручивает секции.
    private let filtersPanel = UIView()
    private(set) var sdk: PersonalizationSDK?
    private var instanceHandle: Cancellable?
    private var total = 0
    private var page = 0
    private var loading = false
    private var facetSource: ResultsFacets?
    private var requestSeq = 0
    /// Первая страница пришла и пуста — только тогда показывается пустое состояние.
    private var noResults = false
    /// Ответила ли первая страница нынешнего запроса: до этого число найденного неизвестно.
    private var answered = false
    /// Страница, которая не загрузилась: первая — ошибка вместо выдачи, следующая —
    /// «повторить» вместо «загрузить ещё». Снимается следующим запросом.
    private var failedPage: Int?
    private var pendingReload: DispatchWorkItem?

    public init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - Источник выдачи; задаёт наследник

    /// Ключ выдачи — фраза или id категории без пробелов по краям; пусто — запроса нет.
    var requestKey: String { "" }

    /// Заголовок, когда `titleText` не задан.
    var defaultTitle: String? { nil }

    /// Новая выдача — первая страница заново. Повтор после ошибки и следующие страницы
    /// сюда не попадают.
    func trackNewResults(_ sdk: PersonalizationSDK, key: String) {}

    /// Страница `page` (с 1) выдачи `key` с текущими фильтрами, сортировкой и локациями.
    func fetch(
        _ sdk: PersonalizationSDK,
        key: String,
        page: Int,
        completion: @escaping (Result<ResultsPage<Item>, SdkError>) -> Void
    ) {}

    /// Данные карточки товара.
    func card(of item: Item, actionText: String?) -> PersonalizationProduct {
        preconditionFailure("The screen subclass maps its products to cards")
    }

    /// Нажатие на карточку товара.
    func productTapped(_ item: Item) {
        onProductTap?(item)
    }

    private func setup() {
        backgroundColor = PersonalizationColor.backgroundGeneric
        let padding = PersonalizationSpacing.xl

        catalog.header = title
        catalog.showRating = showRating
        catalog.imageLoader = { [weak self] imageView, product in self?.loadImage(imageView, url: product.imageUrl) }
        catalog.onProductTap = { [weak self] card in
            guard let self, let item = self.item(for: card) else { return }
            self.productTapped(item)
        }
        catalog.onProductAction = { [weak self] card in
            guard let self, let item = self.item(for: card) else { return }
            self.onProductAction?(item)
        }
        catalog.onLoadMore = { [weak self] in self?.loadMore() }
        catalog.onNearEnd = { [weak self] in
            // После ошибки догрузка ждёт нажатия «повторить», а не повторяет запрос
            // на каждом сдвиге ленты.
            guard let self, self.infiniteScroll, self.failedPage == nil else { return }
            self.loadMore()
        }
        catalog.onRetry = { [weak self] in self?.retryFailedPage() }
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
        filtersPanel.translatesAutoresizingMaskIntoConstraints = false
        filtersPanel.backgroundColor = PersonalizationColor.backgroundGeneric
        addSubview(filtersPanel)
        filters.translatesAutoresizingMaskIntoConstraints = false
        filtersPanel.addSubview(filters)
        NSLayoutConstraint.activate([
            filtersPanel.topAnchor.constraint(equalTo: topAnchor),
            filtersPanel.bottomAnchor.constraint(equalTo: bottomAnchor),
            filtersPanel.leadingAnchor.constraint(equalTo: leadingAnchor),
            filtersPanel.trailingAnchor.constraint(equalTo: trailingAnchor),
            filters.topAnchor.constraint(equalTo: filtersPanel.topAnchor, constant: padding),
            filters.bottomAnchor.constraint(equalTo: filtersPanel.safeAreaLayoutGuide.bottomAnchor, constant: -padding),
            filters.leadingAnchor.constraint(equalTo: filtersPanel.leadingAnchor, constant: padding),
            filters.trailingAnchor.constraint(equalTo: filtersPanel.trailingAnchor, constant: -padding)
        ])
        filtersPanel.isHidden = true

        applyLoadMore()
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

    public var isFiltersOpen: Bool { !filtersPanel.isHidden }

    public func openFilters() {
        filters.text = filtersTitle
        filters.resetText = resetText
        filters.applyText = applyText
        filters.setSections(buildSections())
        filters.scrollToTop()
        filtersPanel.isHidden = false
    }

    public func closeFilters() {
        filtersPanel.isHidden = true
    }

    /// Первая страница заново — сразу; отложенный перезапрос от смены свойств снимается.
    public func reload() {
        pendingReload?.cancel()
        pendingReload = nil
        guard let sdk else { return }
        let key = requestKey
        // Запрос в полёте отменяется всегда, и его флаги сбрасываются здесь же: ответ
        // отбросится по seq и сам их уже не снимет — лоадер крутился бы вечно,
        // а loadMore остался бы заблокирован.
        requestSeq += 1
        loading = false
        catalog.isLoading = false
        noResults = false
        answered = false
        failedPage = nil
        products = []
        total = 0
        page = 0
        renderProducts()
        // Новая выдача — с начала ленты, а не с места, где пользователь бросил прошлую.
        catalog.scrollToTop()
        guard !key.isEmpty else { return }
        trackNewResults(sdk, key: key)
        request(sdk, key: key, nextPage: 1)
    }

    /// Смена свойств перезапрашивает на следующем витке главного цикла: несколько смен
    /// подряд (сортировка и направление, обе границы цены) — один запрос и одно событие.
    func scheduleReload() {
        guard pendingReload == nil else { return }
        let work = DispatchWorkItem { [weak self] in self?.reload() }
        pendingReload = work
        DispatchQueue.main.async(execute: work)
    }

    /// Следующая страница, если она есть и запрос не в полёте.
    public func loadMore() {
        guard let sdk else { return }
        let key = requestKey
        guard !key.isEmpty, !loading, products.count < total else { return }
        request(sdk, key: key, nextPage: page + 1)
    }

    /// Первая страница заново после ошибки — без нового события: выдача та же.
    /// Следующую страницу повторяет `loadMore`.
    private func retryFailedPage() {
        guard let sdk, failedPage == 1, !loading else { return }
        let key = requestKey
        guard !key.isEmpty else { return }
        request(sdk, key: key, nextPage: 1)
    }

    private func request(_ sdk: PersonalizationSDK, key: String, nextPage: Int) {
        requestSeq += 1
        let seq = requestSeq
        loading = true
        catalog.isLoading = true
        failedPage = nil
        applyError()
        applyLoadMore()
        fetch(sdk, key: key, page: nextPage) { [weak self] result in
            MainThread.run {
                guard let self, seq == self.requestSeq else { return }
                self.loading = false
                self.catalog.isLoading = false
                switch result {
                case .success(let response):
                    self.page = nextPage
                    self.products = nextPage == 1 ? response.items : self.products + response.items
                    // Пустая страница заканчивает ленту, даже если сервер обещал больше: иначе
                    // «загрузить ещё» и бесконечная прокрутка просили бы её снова и снова.
                    self.total = response.items.isEmpty ? self.products.count : response.total
                    if nextPage == 1 {
                        self.facetSource = response.facets
                        self.noResults = response.items.isEmpty
                        self.answered = true
                    }
                    self.renderProducts()
                case .failure(let error):
                    self.failedPage = nextPage
                    self.applyError()
                    self.applyLoadMore()
                    self.onError?(error)
                }
            }
        }
    }

    // MARK: - Раскладка

    func applyTitle() {
        title.text = titleText ?? defaultTitle
    }

    private func renderProducts() {
        catalog.products = products.map { card(of: $0, actionText: productActionText) }
        // Пока первая страница нынешнего запроса не ответила (загрузка, новые фильтры или
        // сортировка, ошибка), «Найдено 0» на лоадере вводило бы в заблуждение.
        title.setResults(prefix: foundPrefix, count: answered ? total : nil, suffix: foundSuffix)
        if products.isEmpty {
            catalog.setCount(prefix: nil, shown: 0, separator: countSeparator, total: 0)
        } else {
            catalog.setCount(prefix: countPrefix, shown: products.count, separator: countSeparator, total: total)
        }
        applyEmpty()
        applyError()
        applyLoadMore()
        renderAppliedTags()
    }

    /// Товар нажатой карточки: карточки каталога идут в порядке `products`.
    private func item(for card: PersonalizationProduct) -> Item? {
        guard let index = catalog.products.firstIndex(where: { $0.id == card.id }), index < products.count else {
            return nil
        }
        return products[index]
    }

    /// «Ничего не найдено» — только после успешной пустой первой страницы: не на время
    /// загрузки, не без ключа выдачи (запроса нет) и не после ошибки.
    private func applyEmpty() {
        catalog.emptyText = noResults ? emptyText : nil
    }

    private func applyError() {
        catalog.errorText = failedPage == 1 ? errorText : nil
        catalog.retryText = retryText
    }

    private func applyLoadMore() {
        if let failedPage, failedPage > 1 {
            // Та же кнопка повторяет упавшую страницу — и при бесконечной прокрутке.
            catalog.loadMoreText = retryText
            return
        }
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
                tags.append(.init(label: valueLabel(facet: name, value: value)) { [weak self] in
                    self?.applied.facets[name]?.remove(value)
                })
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

    // MARK: - Фасеты ⇄ секции экрана фильтров

    /// Варианты секции: значения ответа по порядку, за ними применённые, которых в ответе нет.
    /// Вариант — исходное значение (оно уйдёт в запрос) с подписью `label` и числом товаров.
    private func options(
        _ values: [ResultsFacetValue],
        checked: Set<String>,
        label: (String) -> String = { $0 }
    ) -> [PersonalizationFilters.Option] {
        var seen = Set<String>()
        let all = values + checked.sorted().map { ResultsFacetValue(value: $0, count: nil) }
        return all.filter { seen.insert($0.value).inserted }.map { item in
            var text = label(item.value)
            if showValueCounts, let count = item.count { text += " (\(count))" }
            return PersonalizationFilters.Option(id: item.value, label: text, checked: checked.contains(item.value))
        }
    }

    /// Подпись значения произвольного фасета без числа: хоста, иначе `title` значения-объекта,
    /// иначе само значение.
    private func valueLabel(facet: String, value: String) -> String {
        if let custom = facetValueTitle?(facet, value), !custom.isEmpty { return custom }
        return jsonObjectTitle(value) ?? value
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
        let groups: [(id: String, title: String, values: [ResultsFacetValue], checked: Set<String>)] = [
            (SectionId.brands, brandsTitle, source?.brands ?? [], applied.brands),
            (SectionId.colors, colorsTitle, source?.colors ?? [], applied.colors),
            (SectionId.sizes, sizesTitle, source?.sizes ?? [], applied.sizes)
        ]
        for group in groups where !group.values.isEmpty || !group.checked.isEmpty {
            sections.append(.options(
                id: group.id, title: group.title, options: options(group.values, checked: group.checked),
                showMoreText: showMoreText, showLessText: showLessText
            ))
        }
        let all = source?.filters ?? [:]
        for name in facetNames(all) {
            guard let facet = all[name] else { continue }
            let values = facet.values.keys.sorted().map { ResultsFacetValue(value: $0, count: facet.values[$0]) }
            sections.append(.options(
                id: SectionId.facet + name, title: facetTitle(name),
                options: options(values, checked: applied.facets[name] ?? []) { valueLabel(facet: name, value: $0) },
                showMoreText: showMoreText, showLessText: showLessText
            ))
        }
        return sections
    }

    /// Произвольные фасеты экрана фильтров по порядку: явный список `facets` как есть, иначе
    /// фасеты с более чем одним значением по убыванию числа товаров с ними (при равенстве —
    /// по имени), первые `maxFacets`. Фасет с применёнными значениями остаётся в конце,
    /// даже если в список не попал: иначе снять их можно было бы только тегами.
    private func facetNames(_ all: [String: Filter]) -> [String] {
        let byCount = all.keys.sorted { lhs, rhs in
            let left = all[lhs]?.count ?? 0
            let right = all[rhs]?.count ?? 0
            return left != right ? left > right : lhs < rhs
        }
        var names: [String]
        if let wanted = facets {
            names = wanted.filter { all[$0] != nil }
        } else {
            let multiValued = byCount.filter { (all[$0]?.values.count ?? 0) > 1 }
            let limit = maxFacets ?? 0
            names = limit > 0 ? Array(multiValued.prefix(limit)) : multiValued
        }
        names += byCount.filter { !(applied.facets[$0] ?? []).isEmpty }
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
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
