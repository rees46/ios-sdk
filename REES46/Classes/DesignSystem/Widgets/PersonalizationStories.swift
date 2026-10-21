import UIKit

/// Сторис с данными SDK: лента блока `code` и полноэкранный просмотрщик по нажатию.
///
/// Паттерн Stories V2 из Figma (страница Stories, 1:32). Данные — запрос `stories/{code}`,
/// тот же, что у старых сторис; визуальный слой — `PersonalizationStoriesBar` (доступен
/// через `bar`) и `PersonalizationStoriesViewController`. Без ленты сторис блока показывает
/// `PersonalizationStories.show(...)`, в SwiftUI — `PersonalizationStoriesWidget`.
///
/// Инстанс SDK: `shopId` выбирает магазин при нескольких зарегистрированных; без него
/// берётся единственный. Резолвится при показе, явный — параметром `sdk` или `attach(_:)`.
///
/// Пока блок грузится, в ленте заглушки. Пустой блок, ошибка загрузки, пустой `code`
/// или неоднозначный магазин (несколько зарегистрировано, `shopId` не задан) — виджет
/// скрывается и схлопывается в ноль по высоте, ошибка уходит в `onError`. Загрузка,
/// не уложившаяся в 15 секунд, тоже считается ошибкой — вечных заглушек нет.
///
/// Просмотренные слайды хранятся по магазину в общем хранилище SDK — том же, что у старых
/// сторис. Начатая сторис открывается с первого непросмотренного слайда, досмотренная —
/// с начала; кольцо обложки подсвечивает просмотренные слайды по их номерам.
///
/// Нажатия на кнопки, товары и промокоды получает `communicationDelegate` — тот же
/// `StoriesCommunicationProtocol`, что у старых сторис; ссылку SDK открывает, если делегат
/// не вернул `false` из `shouldOpenLinkBySdk(url:)`, а просмотрщик закрывается до этого.
@_spi(PersonalizationUI) public final class PersonalizationStories: UIView {

    /// Код блока сторис; смена перезагружает ленту.
    public var code: String {
        didSet { if oldValue != code { reload() } }
    }

    /// Магазин; `nil` — единственный зарегистрированный. Менять до показа.
    public var shopId: String?

    /// Инстанс SDK — явный или найденный по `shopId`.
    public private(set) var sdk: PersonalizationSDK?

    /// Лента: поля, шаг, заглушки.
    public let bar = PersonalizationStoriesBar()

    /// Нажатия на кнопки, товары и промокоды; решает, открывать ли ссылку SDK.
    public weak var communicationDelegate: StoriesCommunicationProtocol?

    /// Блок не загрузился, пустой `code` или неоднозначный магазин; виджет при этом скрыт.
    public var onError: ((SdkError) -> Void)?

    /// Блок загружен: сколько в нём сторис (0 — виджет скрыт).
    public var onLoaded: ((Int) -> Void)?

    /// Тексты кита; доходят до просмотрщика.
    public var texts = PersonalizationStoriesTexts()

    /// Загрузчик картинок: обложки, фоны, товары; `nil` — встроенный. Заданный после
    /// загрузки, перегружает уже показанные обложки.
    public var imageLoader: ((UIImageView, String) -> Void)? {
        didSet { bar.imageLoader = barImageLoader }
    }

    /// Кто показывает просмотрщик; `nil` — ближайший контроллер по цепочке ответчиков.
    public weak var hostViewController: UIViewController?

    /// Сторис загруженного блока.
    public private(set) var stories: [PersonalizationStory] = []

    /// Сколько ждать блок, прежде чем сдаться.
    public static let loadTimeout: TimeInterval = 15

    private var instanceHandle: Cancellable?
    private var requestSeq = 0
    private var giveUp: DispatchWorkItem?
    private var isCollapsed = false
    private var collapsed: NSLayoutConstraint!
    private weak var viewer: PersonalizationStoriesViewController?
    /// Открыть сторис, когда блок загрузится.
    var pendingOpen: ((PersonalizationStories) -> Void)?

    /// - Parameters:
    ///   - code: код блока сторис.
    ///   - shopId: магазин; `nil` — единственный зарегистрированный.
    ///   - sdk: явный инстанс вместо резолва по `shopId`, то же, что `attach(_:)`.
    public init(code: String, shopId: String? = nil, sdk: PersonalizationSDK? = nil) {
        self.code = code
        self.shopId = shopId
        super.init(frame: .zero)
        setup()
        if let sdk { attach(sdk) }
    }

    required init?(coder: NSCoder) {
        self.code = ""
        super.init(coder: coder)
        setup()
    }

    deinit {
        giveUp?.cancel()
        instanceHandle?.cancel()
    }

    private func setup() {
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)
        // Схлопнутый виджет — ноль по высоте; низ ленты ему уступает.
        collapsed = heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: topAnchor),
            bar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: bottomAnchor).withPriority(UILayoutPriority(999))
        ])
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        bar.imageLoader = barImageLoader
        bar.onItemTap = { [weak self] _, index in self?.open(at: index) }
        bar.isLoading = true
    }

    private var barImageLoader: (UIImageView, PersonalizationStoriesBar.Item) -> Void {
        { [weak self] imageView, item in
            PersonalizationStoryImages.load(into: imageView, url: item.imageUrl, loader: self?.imageLoader)
        }
    }

    /// Высота — лента, у схлопнутого — ноль: по ней виджет встаёт в стек и в SwiftUI.
    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: isCollapsed ? 0 : bar.intrinsicContentSize.height)
    }

    // MARK: - Тексты по одному

    public var promoCaption: String? {
        get { texts.promoCaption }
        set { texts.promoCaption = newValue }
    }
    public var promoCopiedText: String? {
        get { texts.promoCopiedText }
        set { texts.promoCopiedText = newValue }
    }
    public var productButtonText: String {
        get { texts.productButtonText }
        set { texts.productButtonText = newValue }
    }
    public var showProductsText: String {
        get { texts.showProductsText }
        set { texts.showProductsText = newValue }
    }
    public var hideProductsText: String {
        get { texts.hideProductsText }
        set { texts.hideProductsText = newValue }
    }
    public var retryText: String {
        get { texts.retryText }
        set { texts.retryText = newValue }
    }
    public var closeLabel: String? {
        get { texts.closeLabel }
        set { texts.closeLabel = newValue }
    }
    public var soundOnLabel: String? {
        get { texts.soundOnLabel }
        set { texts.soundOnLabel = newValue }
    }
    public var soundOffLabel: String? {
        get { texts.soundOffLabel }
        set { texts.soundOffLabel = newValue }
    }
}

// MARK: - Загрузка

extension PersonalizationStories {

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
        resolveSDK()
    }

    /// Инстанс по `shopId`: готовый — сразу, ещё не зарегистрированный — когда появится.
    /// Несколько магазинов без `shopId` — ошибка, а не чужой магазин.
    private func resolveSDK() {
        guard !code.isEmpty else { return fail(Self.missingCode) }
        do {
            attach(try Rees46.instance(for: shopId))
        } catch Rees46Error.ambiguousShop(let shops) {
            fail(.custom(error: "Stories: several shops are registered (\(shops.joined(separator: ", "))), pass shopId"))
        } catch {
            beginLoading()
            instanceHandle = Rees46.awaitInstance(for: shopId) { [weak self] resolved in
                MainThread.run { self?.attach(resolved) }
            }
        }
    }

    /// Загрузить блок заново.
    public func reload() {
        guard let sdk else { return }
        guard !code.isEmpty else { return fail(Self.missingCode) }
        beginLoading()
        let seq = requestSeq
        let code = self.code
        StoriesBlockLoader.load(sdk: sdk, code: code) { [weak self] result in
            guard let self, seq == self.requestSeq else { return }
            switch result {
            case .success(let stories):
                self.loaded(stories)
            case .failure(let error):
                self.fail(error)
            }
        }
    }

    /// Блок пришёл: лента, высота, `onLoaded` и отложенное открытие.
    func loaded(_ stories: [PersonalizationStory]) {
        giveUp?.cancel()
        self.stories = stories
        renderBar()
        bar.isLoading = false
        setCollapsed(stories.isEmpty)
        onLoaded?(stories.count)
        let open = pendingOpen
        pendingOpen = nil
        open?(self)
    }

    static var missingCode: SdkError { .custom(error: "Stories: the block code is empty") }

    /// Заглушки в ленте и отсчёт до отказа: блок, не пришедший за 15 секунд, — ошибка.
    private func beginLoading() {
        requestSeq += 1
        let seq = requestSeq
        setCollapsed(false)
        bar.isLoading = true
        giveUp?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, seq == self.requestSeq, self.bar.isLoading else { return }
            self.fail(.custom(error: "Stories: the block did not load in \(Int(Self.loadTimeout)) s"))
        }
        giveUp = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.loadTimeout, execute: work)
    }

    /// Ошибка: виджет скрыт, поздний ответ игнорируется.
    private func fail(_ error: SdkError) {
        giveUp?.cancel()
        requestSeq += 1
        pendingOpen = nil
        stories = []
        renderBar()
        bar.isLoading = false
        setCollapsed(true)
        onError?(error)
    }

    private func setCollapsed(_ value: Bool) {
        isCollapsed = value
        isHidden = value
        collapsed.isActive = value
        invalidateIntrinsicContentSize()
    }

    func renderBar() {
        let state = StoriesSeenState(sdk: sdk)
        bar.items = stories.map { state.barItem($0) }
    }
}

// MARK: - Просмотрщик

extension PersonalizationStories {

    /// Открыть сторис по индексу в ленте. До загрузки блока — откроется, когда он придёт;
    /// при открытом просмотрщике — перелистнёт на неё.
    public func open(at index: Int) {
        guard !stories.isEmpty else {
            // Блок ещё грузится — откроется по приходу; не загрузился или пуст — нечего открывать.
            if bar.isLoading { pendingOpen = { $0.open(at: index) } }
            return
        }
        guard stories.indices.contains(index) else { return }
        if let viewer {
            viewer.open(at: index)
            return
        }
        guard let host = hostViewController ?? personalizationNearestViewController else { return }
        let session = StoriesSession(sdk: sdk, code: code)
        session.delegate = communicationDelegate
        session.texts = texts
        session.imageLoader = imageLoader
        session.onSeen = { [weak self] in self?.renderBar() }
        let viewer = session.makeViewer(stories: stories, startIndex: index)
        self.viewer = viewer
        host.personalizationTopmost.present(viewer, animated: true)
    }

    /// Открыть сторис по id.
    public func open(storyId: String) {
        if stories.isEmpty, bar.isLoading {
            pendingOpen = { $0.open(storyId: storyId) }
            return
        }
        guard let index = stories.firstIndex(where: { $0.id == storyId }) else { return }
        open(at: index)
    }

    /// Пауза открытого просмотрщика: отсчёт и видео стоят до `resume()`. Без открытого
    /// просмотрщика `pause()` и `resume()` ничего не делают и на следующий показ не влияют.
    public func pause() {
        viewer?.pause()
    }

    public func resume() {
        viewer?.resume()
    }

    /// Сторис блока без ленты: загружает блок и показывает просмотрщик поверх `presenter`
    /// (без него — поверх верхнего экрана ключевого окна), начиная со `startStoryId`.
    /// Вызов кончается ровно одним колбэком: `onError` — просмотрщик так и не показан,
    /// `onClose` — показанный просмотрщик закрылся.
    ///
    /// - Parameters:
    ///   - code: код блока сторис.
    ///   - sdk: явный инстанс; без него — по `shopId`, а без `shopId` — единственный.
    ///   - shopId: магазин, когда их несколько.
    ///   - startStoryId: с какой сторис начать; `nil` или неизвестный id — с первой.
    ///   - presenter: кто показывает просмотрщик.
    ///   - communicationDelegate: как у виджета; держится слабо.
    ///   - texts: тексты кита.
    ///   - imageLoader: загрузчик картинок; `nil` — встроенный.
    ///   - onError: блок не загрузился, пуст, нет инстанса или магазин неоднозначен.
    ///   - onClose: просмотрщик закрылся — крестиком, свайпом, после последнего слайда,
    ///     перед переходом по ссылке или убранный хостом.
    public static func show(
        code: String,
        sdk: PersonalizationSDK? = nil,
        shopId: String? = nil,
        startStoryId: String? = nil,
        from presenter: UIViewController? = nil,
        communicationDelegate: StoriesCommunicationProtocol? = nil,
        texts: PersonalizationStoriesTexts = PersonalizationStoriesTexts(),
        imageLoader: ((UIImageView, String) -> Void)? = nil,
        onError: ((SdkError) -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        guard !code.isEmpty else { return MainThread.run { onError?(missingCode) } }
        let resolved: PersonalizationSDK
        do {
            resolved = try sdk ?? Rees46.instance(for: shopId)
        } catch {
            return MainThread.run { onError?(.custom(error: "Stories: \(error)")) }
        }
        let session = StoriesSession(sdk: resolved, code: code)
        session.delegate = communicationDelegate
        session.texts = texts
        session.imageLoader = imageLoader
        var finished = false
        let timeout = DispatchWorkItem {
            guard !finished else { return }
            finished = true
            onError?(.custom(error: "Stories: the block did not load in \(Int(loadTimeout)) s"))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + loadTimeout, execute: timeout)
        StoriesBlockLoader.load(sdk: resolved, code: code) { result in
            guard !finished else { return }
            finished = true
            timeout.cancel()
            switch result {
            case .failure(let error):
                onError?(error)
            case .success(let stories) where stories.isEmpty:
                onError?(.custom(error: "Stories: the block \(code) has no stories"))
            case .success(let stories):
                guard let host = presenter ?? UIViewController.personalizationKeyRoot else {
                    onError?(.custom(error: "Stories: nothing to present the viewer from"))
                    return
                }
                let start = startStoryId.flatMap { id in stories.firstIndex { $0.id == id } } ?? 0
                let viewer = session.makeViewer(stories: stories, startIndex: start)
                viewer.onClose = onClose
                host.personalizationTopmost.present(viewer, animated: true)
            }
        }
    }
}
