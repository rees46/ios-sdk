import UIKit

/// Экран каталога: заголовок, плитка или список товаров, внизу лоадер, счётчик
/// и кнопка «загрузить ещё».
///
/// Источник: Figma Mobile SDK UI Kit, секция Card — Search results (167:4477) и
/// Category (167:4856). Оба одной формы, разница только в заголовке: у выдачи
/// `PersonalizationSearchResultsTitle`, у категории `PersonalizationTitle` с
/// переключателем вида. Поэтому заголовок здесь — слот, а не вариант.
/// Три нижних элемента в макете скрываемые (showLoader, showCount, showLoadMore).
/// Шаг блока 12, внутри плитки — 16 по обеим осям.
///
/// Пустая выдача — страница SearchResultsScreen, Search Results/Empty State (319:7743):
/// заголовок тот же, вместо плитки `PersonalizationEmptyState`. Показывается, когда
/// задан `emptyText` и товаров нет.
///
/// Весь каталог — одна лента `UICollectionView`: заголовок, карточки и нижние элементы —
/// её строки. Поэтому его не вкладывают в прокрутку, он прокручивается сам: карточки
/// создаются только под видимую часть и переиспользуются, сколько бы страниц ни
/// догрузилось. Внутри чужой вертикальной прокрутки свою выключают
/// (`isScrollEnabled = false`): тогда высота каталога идёт по содержимому, и он
/// раскладывается целиком, как обычный блок.
@_spi(PersonalizationUI) public final class PersonalizationCatalog: UIView {

    /// Заголовок над товарами: выдача или категория. `nil` — убрать.
    public var header: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            // Высота заголовка меряется по его ограничениям, рамка в них не нужна.
            header?.translatesAutoresizingMaskIntoConstraints = false
            reload(.header)
        }
    }

    /// Плитка в две колонки или список; `.carousel` каталогу не свойственна и
    /// раскладывается плиткой.
    public var layout: PersonalizationProductsList.Layout = .grid {
        didSet { if oldValue != layout { reload(.products) } }
    }

    public var products: [PersonalizationProduct] = [] {
        didSet {
            // Следующая страница выдачи дописывается в конец: уже показанные карточки не
            // перепривязываются и не перезапрашивают картинки.
            let appended = !oldValue.isEmpty && products.count > oldValue.count &&
                zip(oldValue, products).allSatisfy { Self.sameCard($0, $1) }
            if appended {
                append(oldValue.count..<products.count)
            } else {
                reload(.products, .footer)
            }
        }
    }

    /// Текст пустой выдачи. `nil` — без пустого состояния, плитка остаётся на месте.
    public var emptyText: String? {
        didSet {
            emptyState.message = emptyText
            reload(.footer)
        }
    }

    /// Хост кладёт изображение товара в `UIImageView` своим загрузчиком. View
    /// переиспользуются: загрузчик должен ставить картинку, только если view всё ещё
    /// ждёт этот товар (так делает встроенный загрузчик поиска).
    public var imageLoader: ((UIImageView, PersonalizationProduct) -> Void)?

    public var onProductAction: ((PersonalizationProduct) -> Void)?

    /// Нажатие на карточку — открыть товар.
    public var onProductTap: ((PersonalizationProduct) -> Void)?

    /// Пропорция картинок карточек, см. `PersonalizationProductCard.imageAspect`.
    public var imageAspect: PersonalizationProductImage.Aspect = .square {
        didSet { if oldValue != imageAspect { reload(.products) } }
    }

    /// Во фреймах с лоадером (296:3544, 299:6606) счётчика и кнопки нет — на время
    /// загрузки лоадер встаёт на их место.
    public var isLoading: Bool = false {
        didSet { reload(.footer) }
    }

    /// Подпись кнопки «загрузить ещё». `nil` — без кнопки.
    public var loadMoreText: String? {
        didSet {
            loadMoreButton.text = loadMoreText
            reload(.footer)
        }
    }

    private var hasCount = false

    public var onLoadMore: (() -> Void)?

    /// Лента докручена до полэкрана от конца: хост с бесконечной прокруткой просит здесь
    /// следующую страницу. Зовётся на каждом сдвиге ленты, пока конец так близко, —
    /// запрос, который уже в полёте, хост отсекает сам.
    public var onNearEnd: (() -> Void)?

    /// Прокручивается ли каталог сам. `false` — для вложения в чужую вертикальную
    /// прокрутку: лента стоит, высота каталога идёт по содержимому, и карточки
    /// создаются все сразу — годится для коротких подборок, не для бесконечной выдачи.
    public var isScrollEnabled: Bool = true {
        didSet { applyScrolling() }
    }

    /// Поля ленты. Строки прокручиваются под ними, а не обрезаются рамкой, — так хост,
    /// у которого каталог занимает весь экран, задаёт отступы от его краёв.
    public var contentInset: UIEdgeInsets = .zero {
        didSet { invalidatePlan() }
    }

    private let emptyState = PersonalizationEmptyState()
    private let loaderRow = UIView()
    private let loader = PersonalizationLoader()
    private let count = PersonalizationCount()
    private let loadMoreButton = PersonalizationButton(size: .md, view: .secondary)

    private let feedLayout = FeedLayout()
    private let collectionView: UICollectionView
    private let adapter = Adapter()

    public init() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: feedLayout)
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: feedLayout)
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        feedLayout.catalog = self
        adapter.catalog = self
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.register(ProductCell.self, forCellWithReuseIdentifier: ProductCell.reuseId)
        collectionView.register(RowCell.self, forCellWithReuseIdentifier: RowCell.reuseId)
        collectionView.dataSource = adapter
        collectionView.delegate = adapter
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        // Лоадер в макете — по центру строки с полем 4 сверху и снизу.
        loader.translatesAutoresizingMaskIntoConstraints = false
        loaderRow.addSubview(loader)
        NSLayoutConstraint.activate([
            loader.centerXAnchor.constraint(equalTo: loaderRow.centerXAnchor),
            loader.topAnchor.constraint(equalTo: loaderRow.topAnchor, constant: PersonalizationSpacing.sm),
            loader.bottomAnchor.constraint(equalTo: loaderRow.bottomAnchor, constant: -PersonalizationSpacing.sm)
        ])
        // Кольцо крутится, пока строка на экране: вне окна лоадер снимает анимацию сам.
        loader.startAnimating()

        loadMoreButton.iconStart = PersonalizationIcons.arrowRotateCw
        loadMoreButton.addTarget(self, action: #selector(loadMoreTapped), for: .touchUpInside)

        for row in [emptyState, loaderRow, count, loadMoreButton] {
            row.translatesAutoresizingMaskIntoConstraints = false
        }
        applyScrolling()
    }

    @objc private func loadMoreTapped() {
        onLoadMore?()
    }

    /// Счётчик «показано N из M». Слова — параметры. `prefix == nil` — скрыть.
    public func setCount(prefix: String?, shown: Int, separator: String, total: Int) {
        hasCount = prefix != nil
        if let prefix { count.set(prefix: prefix, shown: shown, separator: separator, total: total) }
        reload(.footer)
    }

    /// В начало ленты: новая выдача показывается сверху, а не с места прошлой.
    public func scrollToTop() {
        let insets = collectionView.adjustedContentInset
        collectionView.setContentOffset(CGPoint(x: -insets.left, y: -insets.top), animated: false)
    }

    private func applyScrolling() {
        collectionView.isScrollEnabled = isScrollEnabled
        // Во вложенном каталоге строку состояния и безопасную зону обслуживает внешняя
        // прокрутка: свои поля безопасной зоны сделали бы высоту каталога зависимой
        // от его места на экране.
        collectionView.scrollsToTop = isScrollEnabled
        collectionView.contentInsetAdjustmentBehavior = isScrollEnabled ? .automatic : .never
        invalidateIntrinsicContentSize()
    }

    // MARK: - Высота по содержимому

    /// Без своей прокрутки высота — по всей ленте, чтобы каталог вставал в экран хоста
    /// целиком. Со своей прокруткой размер задаёт хост.
    public override var intrinsicContentSize: CGSize {
        guard !isScrollEnabled else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
        let width = max(0, bounds.width - contentInset.left - contentInset.right)
        let height = plan(width: width).height + contentInset.top + contentInset.bottom
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    /// Высота считается от ширины, а ширину каталог узнаёт только в первом layout:
    /// как только она меняется, intrinsic-высота объявляется устаревшей.
    private var lastLaidOutWidth: CGFloat = -1

    public override func layoutSubviews() {
        super.layoutSubviews()
        if !isScrollEnabled, bounds.width != lastLaidOutWidth {
            lastLaidOutWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
    }

    // MARK: - Строки ленты

    private enum Section: Int, CaseIterable {
        case header, products, footer
    }

    private var cardType: PersonalizationProductCard.CardType {
        layout == .list ? .list : .grid
    }

    private var columns: Int {
        layout == .list ? 1 : 2
    }

    /// Нижние строки в порядке макета. У каждой одна view на весь каталог.
    private var footerRows: [UIView] {
        var rows: [UIView] = []
        if products.isEmpty && !(emptyText ?? "").isEmpty { rows.append(emptyState) }
        if isLoading { rows.append(loaderRow) }
        if hasCount && !isLoading { rows.append(count) }
        if !(loadMoreText ?? "").isEmpty && !isLoading { rows.append(loadMoreButton) }
        return rows
    }

    private func rowViews(in section: Section) -> [UIView] {
        switch section {
        case .header: return header.map { [$0] } ?? []
        case .products: return []
        case .footer: return footerRows
        }
    }

    private func numberOfItems(in section: Section) -> Int {
        section == .products ? products.count : rowViews(in: section).count
    }

    /// Данные поменялись: план пересчитывается, перезагружаются только затронутые секции.
    private func reload(_ sections: Section...) {
        invalidatePlan()
        guard collectionView.window != nil else {
            // Вне окна ячеек на экране нет, перезагрузка целиком ничего не стоит.
            collectionView.reloadData()
            return
        }
        // Точечно, а не reloadData: тот перепривязал бы видимые карточки на каждое
        // включение лоадера, и их картинки грузились бы заново.
        UIView.performWithoutAnimation {
            collectionView.reloadSections(IndexSet(sections.map(\.rawValue)))
        }
    }

    /// Товары `range` дописаны в конец. Вставка сверяется с тем, сколько карточек коллекция
    /// уже знает: если она ещё не загружала данные, считать вставку не от чего.
    private func append(_ range: Range<Int>) {
        let section = Section.products.rawValue
        guard collectionView.window != nil,
              collectionView.numberOfItems(inSection: section) == range.lowerBound else {
            return reload(.products, .footer)
        }
        invalidatePlan()
        UIView.performWithoutAnimation {
            collectionView.performBatchUpdates({
                self.collectionView.insertItems(at: range.map { IndexPath(item: $0, section: section) })
                self.collectionView.reloadSections(IndexSet(integer: Section.footer.rawValue))
            })
        }
    }

    private static func sameCard(_ a: PersonalizationProduct, _ b: PersonalizationProduct) -> Bool {
        a.id == b.id && a.imageUrl == b.imageUrl && CardContent(a) == CardContent(b)
    }

    private func cell(_ collectionView: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
        guard let section = Section(rawValue: indexPath.section), section != .products else {
            return productCell(collectionView, at: indexPath)
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RowCell.reuseId, for: indexPath) as! RowCell
        cell.show(rowViews(in: section)[indexPath.item])
        cell.onLayout = { [weak self] view in self?.rowDidLayout(view) }
        return cell
    }

    private func productCell(_ collectionView: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ProductCell.reuseId, for: indexPath) as! ProductCell
        let product = products[indexPath.item]
        let card = cell.card
        if card.type != cardType { card.type = cardType }
        if card.imageAspect != imageAspect { card.imageAspect = imageAspect }
        card.show(product)
        card.onAction = { [weak self] in self?.onProductAction?(product) }
        card.onTap = { [weak self] in self?.onProductTap?(product) }
        // Карточка переиспользуется: картинка прошлого товара не должна в ней мелькнуть.
        card.image.imageView.image = nil
        imageLoader?(card.image.imageView, product)
        return cell
    }

    /// Следующая страница — за полэкрана до конца ленты.
    private func didScroll() {
        guard isScrollEnabled, let onNearEnd else { return }
        let height = collectionView.bounds.height
        let end = collectionView.contentSize.height + collectionView.adjustedContentInset.bottom
        if end - (collectionView.contentOffset.y + height) <= height / 2 { onNearEnd() }
    }

    // MARK: - План ленты

    /// Рамки строк по секциям при ширине `width`, от верха содержимого без полей.
    /// Один план раскладывает ленту и даёт высоту каталогу без своей прокрутки.
    private struct Plan {
        let width: CGFloat
        var frames: [[CGRect]]
        var height: CGFloat
    }

    private var plan: Plan?

    private func invalidatePlan() {
        plan = nil
        feedLayout.invalidateLayout()
        if !isScrollEnabled { invalidateIntrinsicContentSize() }
    }

    private func plan(width: CGFloat) -> Plan {
        if let plan, plan.width == width { return plan }
        let plan = makePlan(width: width)
        self.plan = plan
        return plan
    }

    private func makePlan(width: CGFloat) -> Plan {
        guard width > 0 else {
            // Ширины ещё нет: строки сложены в ноль, мерить их не от чего.
            let frames = Section.allCases.map { Array(repeating: CGRect.zero, count: numberOfItems(in: $0)) }
            return Plan(width: width, frames: frames, height: 0)
        }
        let block = PersonalizationSpacing.lg  // 12
        let tile = PersonalizationSpacing.xl   // 16
        var frames: [[CGRect]] = Section.allCases.map { _ in [] }
        var y: CGFloat = 0
        var placed = false

        // Шаг блока — только между строками, которые есть: скрытый элемент места не держит.
        func row(_ view: UIView) -> CGRect {
            if placed { y += block }
            placed = true
            let frame = CGRect(x: 0, y: y, width: width, height: measure(view, width: width))
            y = frame.maxY
            return frame
        }

        frames[Section.header.rawValue] = rowViews(in: .header).map(row)

        if !products.isEmpty {
            if placed { y += block }
            placed = true
            let columns = self.columns
            let cellWidth = columns == 1 ? width : floor((width - tile) / 2)
            let heights = cardHeights(width: cellWidth)
            var cards: [CGRect] = []
            for start in stride(from: 0, to: products.count, by: columns) {
                let items = start..<min(start + columns, products.count)
                if start > 0 { y += tile }
                // Карточки ряда одной высоты, по самой высокой: лишнее уходит в распорку
                // карточки, и цена с кнопкой у соседей остаются на одной линии.
                let height = items.map { heights[$0] }.max() ?? 0
                for index in items {
                    // Вторая колонка прижата к правому краю: остаток от округления — в зазор.
                    let x = index == start ? 0 : width - cellWidth
                    cards.append(CGRect(x: x, y: y, width: cellWidth, height: height))
                }
                y += height
            }
            frames[Section.products.rawValue] = cards
        }

        frames[Section.footer.rawValue] = rowViews(in: .footer).map(row)
        return Plan(width: width, frames: frames, height: y)
    }

    private func measure(_ view: UIView, width: CGFloat) -> CGFloat {
        ceil(view.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height)
    }

    /// Строка разложилась. Если её view теперь другой высоты, чем в плане (у заголовка
    /// появились теги фильтров, хост поменял его содержимое), план пересчитывается.
    private func rowDidLayout(_ view: UIView) {
        guard let plan, plan.width > 0 else { return }
        let planned: CGRect?
        if view === header {
            planned = plan.frames[Section.header.rawValue].first
        } else if let index = footerRows.firstIndex(where: { $0 === view }),
                  index < plan.frames[Section.footer.rawValue].count {
            planned = plan.frames[Section.footer.rawValue][index]
        } else {
            planned = nil
        }
        guard let planned, measure(view, width: plan.width) != planned.height else { return }
        invalidatePlan()
    }

    // MARK: - Высоты карточек

    /// Всё, от чего зависит высота карточки при данной ширине, виде и пропорции.
    private struct CardContent: Hashable {
        let brand: String?
        let name: String
        let price: String
        let oldPrice: String?
        let discount: String?
        let actionText: String?
        let ratingValue: String?
        let reviews: Int

        init(_ product: PersonalizationProduct) {
            brand = product.brand
            name = product.name
            price = product.price
            oldPrice = product.oldPrice
            discount = product.discount
            actionText = product.actionText
            ratingValue = product.ratingValue
            reviews = product.reviews
        }
    }

    private struct CardScope: Equatable {
        let width: CGFloat
        let type: PersonalizationProductCard.CardType
        let aspect: PersonalizationProductImage.Aspect
    }

    /// Промер карточки не бесплатный, поэтому высоты кэшируются по её содержимому:
    /// догруженная страница меряет только новые товары, а смена ширины, вида или
    /// пропорции сбрасывает кэш.
    private var heightCache: (scope: CardScope, heights: [CardContent: CGFloat])?

    /// Карточка для промера — одна на каталог, на экран она не попадает.
    private lazy var sizingCard = PersonalizationProductCard(type: cardType)

    private func cardHeights(width: CGFloat) -> [CGFloat] {
        let scope = CardScope(width: width, type: cardType, aspect: imageAspect)
        let cached = heightCache.flatMap { $0.scope == scope ? $0.heights : nil } ?? [:]
        var heights: [CardContent: CGFloat] = [:]
        let result = products.map { product -> CGFloat in
            let content = CardContent(product)
            let height = heights[content] ?? cached[content] ?? measureCard(product, width: width)
            heights[content] = height
            return height
        }
        // В кэше остаются только нынешние товары: прошлая выдача его не раздувает.
        heightCache = (scope, heights)
        return result
    }

    private func measureCard(_ product: PersonalizationProduct, width: CGFloat) -> CGFloat {
        let card = sizingCard
        if card.type != cardType { card.type = cardType }
        if card.imageAspect != imageAspect { card.imageAspect = imageAspect }
        card.show(product)
        return measure(card, width: width)
    }

    // MARK: - Коллекция

    /// Раскладка по готовому плану каталога, сдвинутому на поля ленты.
    private final class FeedLayout: UICollectionViewLayout {
        weak var catalog: PersonalizationCatalog?
        private var attributes: [[UICollectionViewLayoutAttributes]] = []
        private var contentSize: CGSize = .zero

        override func prepare() {
            super.prepare()
            guard let collectionView, let catalog else { return }
            let adjusted = collectionView.adjustedContentInset
            let insets = catalog.contentInset
            let visibleWidth = max(0, collectionView.bounds.width - adjusted.left - adjusted.right)
            let plan = catalog.plan(width: max(0, visibleWidth - insets.left - insets.right))
            attributes = plan.frames.enumerated().map { section, frames in
                frames.enumerated().map { item, frame in
                    let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: item, section: section))
                    attributes.frame = frame.offsetBy(dx: insets.left, dy: insets.top)
                    return attributes
                }
            }
            contentSize = CGSize(width: visibleWidth, height: plan.height + insets.top + insets.bottom)
        }

        override var collectionViewContentSize: CGSize { contentSize }

        override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
            attributes.joined().filter { $0.frame.intersects(rect) }
        }

        override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            guard indexPath.section < attributes.count,
                  indexPath.item < attributes[indexPath.section].count else { return nil }
            return attributes[indexPath.section][indexPath.item]
        }

        /// Прокрутка раскладку не меняет, меняет только ширина.
        override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
            newBounds.width != collectionView?.bounds.width
        }
    }

    /// Источник данных и делегат коллекции — отдельным объектом, чтобы их методы
    /// не торчали в публичном API каталога.
    private final class Adapter: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
        weak var catalog: PersonalizationCatalog?

        func numberOfSections(in collectionView: UICollectionView) -> Int {
            Section.allCases.count
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            guard let catalog, let section = Section(rawValue: section) else { return 0 }
            return catalog.numberOfItems(in: section)
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            guard let catalog else {
                return collectionView.dequeueReusableCell(withReuseIdentifier: ProductCell.reuseId, for: indexPath)
            }
            return catalog.cell(collectionView, at: indexPath)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            catalog?.didScroll()
        }
    }

    private final class ProductCell: UICollectionViewCell {
        static let reuseId = "PersonalizationCatalog.ProductCell"
        let card = PersonalizationProductCard(type: .grid)

        override init(frame: CGRect) {
            super.init(frame: frame)
            card.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(card)
            // Ячейка высотой с ряд; карточка занимает её целиком, лишнее забирает её распорка.
            NSLayoutConstraint.activate([
                card.topAnchor.constraint(equalTo: contentView.topAnchor),
                card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
            ])
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    }

    /// Ячейка одиночной строки: заголовка или нижнего элемента. View строки одна
    /// на весь каталог — ячейка её только принимает к себе.
    private final class RowCell: UICollectionViewCell {
        static let reuseId = "PersonalizationCatalog.RowCell"

        /// Строка разложилась — каталог сверяет её высоту с планом.
        var onLayout: ((UIView) -> Void)?

        private let host = Host()

        override init(frame: CGRect) {
            super.init(frame: frame)
            host.frame = contentView.bounds
            host.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            host.onLayout = { [weak self] view in self?.onLayout?(view) }
            contentView.addSubview(host)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        func show(_ view: UIView) {
            guard view.superview !== host else { return }
            // Здесь могла остаться view другой строки: на экране её уже нет, иначе её
            // забрала бы видимая ячейка.
            host.subviews.forEach { $0.removeFromSuperview() }
            view.removeFromSuperview()
            host.addSubview(view)
            // Высота у view своя. Низ прижат слабее всего — только чтобы view без
            // собственной высоты (пустое состояние) растянулась на строку.
            let bottom = view.bottomAnchor.constraint(equalTo: host.bottomAnchor)
            bottom.priority = UILayoutPriority(1)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: host.topAnchor),
                view.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                bottom
            ])
        }
    }

    /// Раскладывается, когда меняется рамка строки или высота её view: сама view
    /// о своём росте ячейке не сообщает.
    private final class Host: UIView {
        var onLayout: ((UIView) -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            if let view = subviews.first { onLayout?(view) }
        }
    }
}
