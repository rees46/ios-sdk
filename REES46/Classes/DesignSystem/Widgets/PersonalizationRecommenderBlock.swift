import UIKit

/// Блок рекомендаций с данными SDK: сам грузит товары и показывает их блоком товаров
/// (`PersonalizationProductsBlock`) — каруселью, плиткой или списком.
///
/// Паттерн Recommender из Figma (секция Card — Recommender/Carousel, Grid, List). Источник
/// ровно один: блок рекомендаций `code` — `recommend(…, extended: true)`, заголовок и товары
/// из ответа, для «похожих» и «с этим покупают» ещё `itemId` и `categoryId`; или коллекция
/// `collectionId` — `getCollection`, товары без заголовка.
///
/// Инстанс SDK: `shopId` или единственный зарегистрированный; резолвится при показе,
/// явный — параметром `sdk` или `attach(_:)`. Несколько магазинов без `shopId` — ошибка.
///
/// Скелетона нет: пока блок грузится, он скрыт и по высоте ноль; появляется, когда пришёл
/// ответ, — коротким проявлением, если ответ шёл по сети. Товаров меньше `minProducts`
/// (пустой ответ тоже), ошибка, пустой код или id — блок скрыт, ошибка уходит в `onError`.
/// `onLoaded` получает число показанных товаров (0 — блок скрыт). Оба колбэка зовутся
/// на следующем витке главной очереди: хост успевает задать их после `init`.
///
/// Ответы идут через общий кэш виджетов: второй блок с теми же параметрами (лента пересоздала
/// ячейку) показывает товары сразу, без запроса. `reload()` грузит мимо кэша, а показанные
/// товары остаются на месте до ответа. Смена `source` — новая загрузка.
///
/// Нажатие на товар блока рекомендаций запоминает источник `dynamic` с кодом блока
/// (`tracking.setSource`) и отдаёт товар хосту; у коллекции источник не ставится.
@_spi(PersonalizationUI) public final class PersonalizationRecommenderBlock: UIView {

    /// Откуда блок берёт товары.
    public enum Source: Equatable {
        /// Блок рекомендаций `code`; `itemId` и `categoryId` — для «похожих» и «с этим
        /// покупают», `locations` — id локаций через запятую.
        case recommendations(code: String, itemId: String? = nil, categoryId: String? = nil, locations: String? = nil)
        /// Коллекция товаров: заголовка в ответе нет.
        case collection(id: String)
    }

    /// Источник товаров; смена грузит блок заново.
    public var source: Source {
        didSet { if oldValue != source { load() } }
    }

    /// Магазин; `nil` — единственный зарегистрированный. Менять до показа.
    public var shopId: String?

    /// Инстанс SDK — явный или найденный по `shopId`.
    public private(set) var sdk: PersonalizationSDK?

    public var layout: PersonalizationProductsList.Layout {
        get { block.layout }
        set { if block.layout != newValue { block.layout = newValue } }
    }

    /// Заголовок: `nil` — из ответа (у коллекции его нет), пустая строка — без строки заголовка.
    public var title: String? {
        didSet { if oldValue != title { render() } }
    }

    /// Сколько товаров показать; `nil` — все из ответа.
    public var limit: Int? {
        didSet { if oldValue != limit { render() } }
    }

    /// Меньше товаров — блок скрыт.
    public var minProducts = 1 {
        didSet { if oldValue != minProducts { render() } }
    }

    /// Пропорция картинок карточек, см. `PersonalizationProductCard.imageAspect`.
    public var imageAspect: PersonalizationProductImage.Aspect {
        get { block.imageAspect }
        set { if block.imageAspect != newValue { block.imageAspect = newValue } }
    }

    /// Подпись кнопки на карточке; `nil` — без кнопки.
    public var actionText: String? {
        didSet { if oldValue != actionText { render() } }
    }

    /// Подпись кнопки «показать все» у карусели; `nil` — без кнопки.
    public var showAllText: String? {
        get { block.showAllText }
        set { if block.showAllText != newValue { block.showAllText = newValue } }
    }

    public var onShowAll: (() -> Void)? {
        get { block.onShowAll }
        set { block.onShowAll = newValue }
    }

    /// Точки под каруселью.
    public var showDots: Bool {
        get { block.showDots }
        set { if block.showDots != newValue { block.showDots = newValue } }
    }

    /// Рейтинг на карточках. В ответах рейтинга нет, поэтому по умолчанию выключен.
    public var showRating: Bool {
        get { block.showRating }
        set { block.showRating = newValue }
    }

    /// Загрузчик картинок; `nil` — встроенный.
    public var imageLoader: ((UIImageView, String) -> Void)?

    /// Нажатие на карточку — открыть товар (`url` или `deeplink`).
    public var onProductTap: ((PersonalizationProduct) -> Void)?
    /// Нажатие на кнопку карточки.
    public var onProductAction: ((PersonalizationProduct) -> Void)?
    /// Ответ пришёл: сколько товаров показано, 0 — блок скрыт.
    public var onLoaded: ((Int) -> Void)?
    /// Ответ не пришёл, пустой код или id, неоднозначный магазин; блок скрыт.
    public var onError: ((SdkError) -> Void)?

    /// Показанные товары; пусто, пока блок скрыт.
    public private(set) var products: [PersonalizationProduct] = []

    /// Кэш ответов; тесты подставляют свой.
    var cache = ResponseCache.shared

    let block = PersonalizationProductsBlock()
    private var instanceHandle: Cancellable?
    /// Подписка на ответ кэша текущей загрузки.
    private var request: Cancellable?
    /// Последний ответ — по нему блок перерисовывается при смене вида.
    private var loaded: Loaded?
    private var isCollapsed = true
    /// Номер загрузки: колбэки устаревшей до хоста не доходят.
    private var loadSeq = 0
    /// Идёт `reload()` показанного блока — товары остаются до ответа.
    private var keepsContent = false
    /// Загрузка ещё внутри вызова: ответ из кэша появляется без проявления.
    private var loadsSynchronously = false
    private var collapsed: NSLayoutConstraint!
    private var lastWidth: CGFloat = -1

    private lazy var machine: LoadStateMachine<Loaded> = {
        let machine = LoadStateMachine<Loaded>(
            fetch: { [weak self] force, done in self?.fetch(force: force, done: done) },
            isEmpty: { $0.products.isEmpty }
        )
        machine.onChange = { [weak self] state in self?.stateChanged(state) }
        return machine
    }()

    /// - Parameters:
    ///   - source: блок рекомендаций или коллекция.
    ///   - shopId: магазин; `nil` — единственный зарегистрированный.
    ///   - sdk: явный инстанс вместо резолва по `shopId`, то же, что `attach(_:)`.
    public init(
        source: Source,
        shopId: String? = nil,
        sdk: PersonalizationSDK? = nil,
        layout: PersonalizationProductsList.Layout = .carousel
    ) {
        self.source = source
        self.shopId = shopId
        super.init(frame: .zero)
        block.layout = layout
        setup()
        if let sdk { attach(sdk) }
    }

    /// Блок рекомендаций `code`; `itemId` и `categoryId` — для «похожих» и «с этим покупают».
    public convenience init(
        code: String,
        itemId: String? = nil,
        categoryId: String? = nil,
        locations: String? = nil,
        shopId: String? = nil,
        sdk: PersonalizationSDK? = nil,
        layout: PersonalizationProductsList.Layout = .carousel
    ) {
        self.init(
            source: .recommendations(code: code, itemId: itemId, categoryId: categoryId, locations: locations),
            shopId: shopId, sdk: sdk, layout: layout
        )
    }

    /// Коллекция `collectionId`: товары без заголовка.
    public convenience init(
        collectionId: String,
        shopId: String? = nil,
        sdk: PersonalizationSDK? = nil,
        layout: PersonalizationProductsList.Layout = .carousel
    ) {
        self.init(source: .collection(id: collectionId), shopId: shopId, sdk: sdk, layout: layout)
    }

    required init?(coder: NSCoder) {
        source = .recommendations(code: "")
        super.init(coder: coder)
        setup()
    }

    deinit {
        instanceHandle?.cancel()
    }

    private func setup() {
        block.translatesAutoresizingMaskIntoConstraints = false
        addSubview(block)
        // Скрытый блок — ноль по высоте; низ содержимого ему уступает.
        collapsed = heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            block.topAnchor.constraint(equalTo: topAnchor),
            block.leadingAnchor.constraint(equalTo: leadingAnchor),
            block.trailingAnchor.constraint(equalTo: trailingAnchor),
            block.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(UILayoutPriority(999)),
            collapsed
        ])
        isHidden = true
        block.showRating = false
        block.imageLoader = { [weak self] imageView, product in
            if let loader = self?.imageLoader, let url = product.imageUrl {
                loader(imageView, url)
            } else {
                SearchImages.shared.load(imageView, url: product.imageUrl)
            }
        }
        block.onProductTap = { [weak self] product in self?.productTapped(product) }
        block.onProductAction = { [weak self] product in self?.onProductAction?(product) }
    }

    /// Высота при ширине `width`, без раскладки: у скрытого — ноль. По ней блок встаёт
    /// в SwiftUI, см. `PersonalizationRecommenderBlockWidget`.
    func fittingHeight(forWidth width: CGFloat) -> CGFloat {
        isCollapsed ? 0 : block.fittingHeight(forWidth: width)
    }

    /// Высота — содержимое при нынешней ширине, у скрытого — ноль.
    public override var intrinsicContentSize: CGSize {
        if isCollapsed { return CGSize(width: UIView.noIntrinsicMetric, height: 0) }
        guard bounds.width > 0 else { return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric) }
        return CGSize(width: UIView.noIntrinsicMetric, height: fittingHeight(forWidth: bounds.width))
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        // Высота плитки и списка идёт за шириной.
        if bounds.width != lastWidth {
            lastWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
    }
}

// MARK: - Загрузка

extension PersonalizationRecommenderBlock {

    /// Ответ, общий для обоих источников; его и держит кэш. Карточки — без подписи кнопки:
    /// её блок ставит при показе.
    struct Loaded {
        let title: String?
        let products: [PersonalizationProduct]
    }

    /// Явный инстанс вместо резолва по `shopId`.
    public func attach(_ sdk: PersonalizationSDK) {
        instanceHandle?.cancel()
        instanceHandle = nil
        self.sdk = sdk
        load()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else {
            instanceHandle?.cancel()
            instanceHandle = nil
            return
        }
        guard sdk == nil, instanceHandle == nil else { return }
        resolveSDK()
    }

    /// Загрузить заново мимо кэша. Показанные товары остаются на месте до ответа.
    public func reload() {
        guard sdk != nil else { return }
        if let error = sourceError { return fail(error) }
        loadSeq += 1
        keepsContent = !isCollapsed
        loadsSynchronously = true
        machine.reload()
        loadsSynchronously = false
    }

    /// Инстанс по `shopId`: готовый — сразу, ещё не зарегистрированный — когда появится.
    /// Несколько магазинов без `shopId` — ошибка, а не чужой магазин.
    private func resolveSDK() {
        do {
            attach(try Rees46.instance(for: shopId))
        } catch Rees46Error.ambiguousShop(let shops) {
            fail(.custom(error: "Recommender block: several shops are registered (\(shops.joined(separator: ", "))), pass shopId"))
        } catch {
            instanceHandle = Rees46.awaitInstance(for: shopId) { [weak self] resolved in
                MainThread.run { self?.attach(resolved) }
            }
        }
    }

    /// Новая загрузка источника: прошлая больше не нужна, показанное прячется до ответа.
    private func load() {
        guard sdk != nil else { return }
        loadSeq += 1
        keepsContent = false
        if let error = sourceError { return fail(error) }
        loadsSynchronously = true
        machine.load()
        loadsSynchronously = false
    }

    private var sourceError: SdkError? {
        switch source {
        case .recommendations(let code, _, _, _):
            return code.isEmpty ? .custom(error: "Recommender block: the block code is empty") : nil
        case .collection(let id):
            return id.isEmpty ? .custom(error: "Recommender block: the collection id is empty") : nil
        }
    }

    /// Запрос через общий кэш: готовый ответ приходит сразу, на этом же потоке.
    private func fetch(force: Bool, done: @escaping (Result<Loaded, SdkError>) -> Void) {
        request?.cancel()
        request = nil
        guard let sdk else { return }
        switch source {
        case let .recommendations(code, itemId, categoryId, locations):
            var params = ["code": code]
            params["itemId"] = itemId
            params["categoryId"] = categoryId
            params["locations"] = locations
            let key = ResponseCache.Key(shopId: sdk.shopId, kind: "recommend", params: params)
            request = cache.fetch(key, force: force, load: { finish in
                sdk.recommend(
                    blockId: code, currentProductId: itemId, currentCategoryId: categoryId,
                    locations: locations, extended: true
                ) { result in
                    finish(result.map { Loaded(title: $0.title, products: $0.recommended.map { $0.toCardProduct() }) })
                }
            }, completion: done)
        case let .collection(id):
            let key = ResponseCache.Key(shopId: sdk.shopId, kind: "collection", params: ["collectionId": id])
            request = cache.fetch(key, force: force, load: { finish in
                sdk.getCollection(collectionId: id) { result in
                    finish(result.map { Loaded(title: nil, products: $0.products.map { $0.toCardProduct() }) })
                }
            }, completion: done)
        }
    }

    private func stateChanged(_ state: LoadState<Loaded>) {
        switch state {
        case .idle:
            break
        case .loading:
            if !keepsContent {
                loaded = nil
                render()
            }
        case .content(let content):
            keepsContent = false
            loaded = content
            render(animated: !loadsSynchronously)
            let count = products.count
            notify { $0.onLoaded?(count) }
        case .empty:
            keepsContent = false
            loaded = nil
            render()
            notify { $0.onLoaded?(0) }
        case .error(let error):
            keepsContent = false
            loaded = nil
            render()
            notify { $0.onError?(error) }
        }
    }

    /// Ошибка ещё до запроса: блок скрыт, ответ в полёте отбросится.
    private func fail(_ error: SdkError) {
        loadSeq += 1
        request?.cancel()
        request = nil
        machine.reset()
        keepsContent = false
        loaded = nil
        render()
        notify { $0.onError?(error) }
    }

    /// Колбэк хосту — на следующем витке главной очереди, если загрузка за это время не сменилась.
    private func notify(_ body: @escaping (PersonalizationRecommenderBlock) -> Void) {
        let seq = loadSeq
        DispatchQueue.main.async { [weak self] in
            guard let self, seq == self.loadSeq else { return }
            body(self)
        }
    }

    // MARK: - Показ

    /// Последний ответ на экран: обрезка по `limit`, порог `minProducts`, заголовок
    /// и подпись кнопки карточки.
    private func render(animated: Bool = false) {
        let all = loaded?.products ?? []
        let shown = (limit.map { Array(all.prefix(max(0, $0))) } ?? all).map { $0.with(actionText: actionText) }
        let visible = !shown.isEmpty && shown.count >= minProducts
        products = visible ? shown : []
        block.text = title ?? loaded?.title
        block.products = products
        setCollapsed(!visible, animated: animated)
    }

    private func setCollapsed(_ value: Bool, animated: Bool) {
        let appears = isCollapsed && !value
        isCollapsed = value
        isHidden = value
        collapsed.isActive = value
        invalidateIntrinsicContentSize()
        guard appears else { return }
        if animated, window != nil {
            alpha = 0
            UIView.animate(withDuration: 0.15) { self.alpha = 1 }
        } else {
            alpha = 1
        }
    }

    private func productTapped(_ product: PersonalizationProduct) {
        if case .recommendations(let code, _, _, _) = source, let sdk {
            sdk.tracking.setSource(TrackingSource(type: .dynamic, code: code))
        }
        onProductTap?(product)
    }
}
