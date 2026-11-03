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
///
/// С `apiV3Domain` лента, кампания по ссылке и события идут в API v3 на этом хосте: у слайдов
/// со ссылкой есть кнопка «Поделиться», ссылку открывает `handleLink(_:)`.
@_spi(PersonalizationUI) public final class PersonalizationStories: UIView {

    /// Хост API v3 по умолчанию — для виджетов, `show` и `handleLink`, которым свой не задан.
    /// Без схемы, как `apiDomain` SDK, например `app.rees46.ru`. `nil` — старый API
    /// (`stories/{code}`, `track/stories`): ни кнопки «Поделиться», ни ссылок. Берётся при
    /// создании виджета и при вызове `show` / `handleLink`.
    public static var apiV3Domain: String?

    /// Хост без пробелов; пустой — `nil`.
    static func v3Domain(_ domain: String?) -> String? {
        guard let domain = domain?.trimmingCharacters(in: .whitespacesAndNewlines), !domain.isEmpty else { return nil }
        return domain
    }

    /// Хост API v3 этого виджета: лента и события его просмотрщика. По умолчанию — глобальный
    /// `PersonalizationStories.apiV3Domain` на момент создания; `nil` — старый API, даже если
    /// глобальный задан. Смена перезагружает ленту.
    public var apiV3Domain: String? {
        didSet { if oldValue != apiV3Domain { reload() } }
    }

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

    /// Ссылка слайда прямо перед окном «Поделиться» — например, со схемой приложения вместо
    /// `https`. `nil` — как есть. Событие `share` не меняется.
    public var shareUrlTransform: ((String) -> String)?

    /// Транспорт опросов слайдов вместо клиента API v3 — для тестов и офлайн-демо; `nil` —
    /// ответы уходят в API v3 на `apiV3Domain`. Без `apiV3Domain` опросов нет.
    public var pollTransport: PersonalizationStoryPollTransport?

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
    /// API v3 загруженной ленты: события просмотрщика идут туда же.
    private var loadedV3Domain: String?
    /// Открыть сторис, когда блок загрузится.
    var pendingOpen: ((PersonalizationStories) -> Void)?

    /// - Parameters:
    ///   - code: код блока сторис.
    ///   - shopId: магазин; `nil` — единственный зарегистрированный.
    ///   - sdk: явный инстанс вместо резолва по `shopId`, то же, что `attach(_:)`.
    ///   - apiV3Domain: хост API v3 виджета; по умолчанию — глобальный, `nil` — старый API.
    public init(
        code: String,
        shopId: String? = nil,
        sdk: PersonalizationSDK? = nil,
        apiV3Domain: String? = PersonalizationStories.apiV3Domain
    ) {
        self.code = code
        self.shopId = shopId
        self.apiV3Domain = apiV3Domain
        super.init(frame: .zero)
        setup()
        if let sdk { attach(sdk) }
    }

    required init?(coder: NSCoder) {
        self.code = ""
        self.apiV3Domain = Self.apiV3Domain
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
    public var shareLabel: String? {
        get { texts.shareLabel }
        set { texts.shareLabel = newValue }
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
        let v3Domain = Self.v3Domain(apiV3Domain)
        StoriesBlockLoader.load(sdk: sdk, code: code, v3Domain: v3Domain) { [weak self] result in
            guard let self, seq == self.requestSeq else { return }
            switch result {
            case .success(let stories):
                self.loadedV3Domain = v3Domain
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
        let session = StoriesSession(sdk: sdk, code: code, v3Domain: loadedV3Domain)
        session.delegate = communicationDelegate
        session.texts = texts
        session.imageLoader = imageLoader
        session.shareUrlTransform = shareUrlTransform
        session.pollTransport = pollTransport
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
    /// (без него — поверх верхнего экрана ключевого окна), начиная со `startStoryId`. Сцены на
    /// экране ещё нет (холодный старт по ссылке или пушу) — показ ждёт её активации в пределах
    /// `loadTimeout` от вызова. Вызов кончается ровно одним колбэком: `onError` — просмотрщик
    /// так и не показан, `onClose` — показанный просмотрщик закрылся.
    ///
    /// - Parameters:
    ///   - code: код блока сторис.
    ///   - sdk: явный инстанс; без него — по `shopId`, а без `shopId` — единственный.
    ///   - shopId: магазин, когда их несколько.
    ///   - apiV3Domain: хост API v3 для ленты и событий; по умолчанию — глобальный, `nil` — старый API.
    ///   - startStoryId: с какой сторис начать; `nil` или неизвестный id — с первой.
    ///   - presenter: кто показывает просмотрщик.
    ///   - communicationDelegate: как у виджета; держится слабо.
    ///   - texts: тексты кита.
    ///   - imageLoader: загрузчик картинок; `nil` — встроенный.
    ///   - shareUrlTransform: ссылка слайда перед окном «Поделиться»; `nil` — как есть.
    ///   - pollTransport: транспорт опросов вместо клиента API v3; `nil` — API v3.
    ///   - onError: блок не загрузился, пуст, нет инстанса или магазин неоднозначен; за
    ///     `loadTimeout` так и не нашлось, откуда показать.
    ///   - onClose: просмотрщик закрылся — крестиком, свайпом, после последнего слайда,
    ///     перед переходом по ссылке или убранный хостом.
    public static func show(
        code: String,
        sdk: PersonalizationSDK? = nil,
        shopId: String? = nil,
        apiV3Domain: String? = PersonalizationStories.apiV3Domain,
        startStoryId: String? = nil,
        from presenter: UIViewController? = nil,
        communicationDelegate: StoriesCommunicationProtocol? = nil,
        texts: PersonalizationStoriesTexts = PersonalizationStoriesTexts(),
        imageLoader: ((UIImageView, String) -> Void)? = nil,
        shareUrlTransform: ((String) -> String)? = nil,
        pollTransport: PersonalizationStoryPollTransport? = nil,
        onError: ((SdkError) -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        guard !code.isEmpty else { return MainThread.run { onError?(missingCode) } }
        let v3Domain = Self.v3Domain(apiV3Domain)
        // Показ ждёт сцену на экране в пределах того же таймаута, что и загрузка.
        let deadline = Date().addingTimeInterval(loadTimeout)
        load(
            sdk: sdk,
            shopId: shopId,
            what: "the block \(code)",
            request: { StoriesBlockLoader.load(sdk: $0, code: code, v3Domain: v3Domain, completion: $1) },
            onError: { onError?($0) }
        ) { resolved, stories in awaitPresenter(presenter, until: deadline) { host in
            guard let host else {
                onError?(.custom(error: "Stories: nothing to present the viewer from"))
                return
            }
            let session = StoriesSession(sdk: resolved, code: code, v3Domain: v3Domain)
            session.delegate = communicationDelegate
            session.texts = texts
            session.imageLoader = imageLoader
            session.shareUrlTransform = shareUrlTransform
            session.pollTransport = pollTransport
            let start = startStoryId.flatMap { id in stories.firstIndex { $0.id == id } } ?? 0
            let viewer = session.makeViewer(stories: stories, startIndex: start)
            viewer.onClose = onClose
            host.personalizationTopmost.present(viewer, animated: true)
        } }
    }

    /// Ссылки «Поделиться», которые грузятся или открыты: повтор той же ссылки игнорируется.
    private static var openLinks: [StoriesShareLink] = []

    /// Ссылка «Поделиться» сторис: `https://<сайт>/<путь>?r46_stories=<код>&r46_story=<id>[&r46_slide=<id>]`,
    /// прочие параметры не мешают. Загружает кампанию из API v3 и показывает просмотрщик, как
    /// `show`: с первой сторис ответа и со слайда ссылки (`start_position` сервера, в обход
    /// «первого непросмотренного»). Открытый просмотрщик сторис на данных SDK — ленты, `show`
    /// или другой ссылки — закрывается перед показом. После показа уходит `shared_open`.
    ///
    /// Возвращает `true`, если это ссылка сторис и задан `apiV3Domain` (параметр, по умолчанию —
    /// глобальный), — дальше всё идёт асинхронно и кончается ровно одним колбэком, как у `show`:
    /// ошибка, 404, пустой ответ или таймаут — `onError`, без показа и событий. Иначе `false`,
    /// и ничего не происходит. Та же ссылка (код, кампания, слайд), пока грузится или открыта, —
    /// `true` без действий.
    ///
    /// Параметры — как у `show`.
    @discardableResult
    public static func handleLink(
        _ url: URL,
        sdk: PersonalizationSDK? = nil,
        shopId: String? = nil,
        apiV3Domain: String? = PersonalizationStories.apiV3Domain,
        from presenter: UIViewController? = nil,
        communicationDelegate: StoriesCommunicationProtocol? = nil,
        texts: PersonalizationStoriesTexts = PersonalizationStoriesTexts(),
        imageLoader: ((UIImageView, String) -> Void)? = nil,
        shareUrlTransform: ((String) -> String)? = nil,
        pollTransport: PersonalizationStoryPollTransport? = nil,
        onError: ((SdkError) -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) -> Bool {
        guard let link = StoriesShareLink(url: url), let v3Domain = Self.v3Domain(apiV3Domain) else { return false }
        guard !openLinks.contains(link) else { return true }
        openLinks.append(link)
        let release = { openLinks.removeAll { $0 == link } }
        let api = StoriesApiV3(domain: v3Domain)
        // Показ ждёт сцену на экране в пределах того же таймаута, что и загрузка.
        let deadline = Date().addingTimeInterval(loadTimeout)
        load(
            sdk: sdk,
            shopId: shopId,
            what: "the story \(link.storyId) of the block \(link.code)",
            request: { api.story(sdk: $0, link: link, completion: $1) },
            onError: { error in
                release()
                onError?(error)
            }
        ) { resolved, stories in awaitPresenter(presenter, until: deadline) { host in
            guard let host else {
                release()
                onError?(.custom(error: "Stories: nothing to present the viewer from"))
                return
            }
            let session = StoriesSession(sdk: resolved, code: link.code, v3Domain: v3Domain)
            session.delegate = communicationDelegate
            session.texts = texts
            session.imageLoader = imageLoader
            session.shareUrlTransform = shareUrlTransform
            session.pollTransport = pollTransport
            let other = StoriesSession.openViewer
            let viewer = session.makeViewer(stories: stories, startIndex: 0, fromLink: true)
            viewer.onClose = {
                release()
                onClose?()
            }
            let present = {
                host.personalizationTopmost.present(viewer, animated: true) {
                    guard let story = viewer.stories.first, let first = story.slides.first else { return }
                    let start = story.startPosition
                    session.sharedOpened(story, story.slides.indices.contains(start) ? story.slides[start] : first)
                }
            }
            if let other, other !== viewer, other.presentingViewController != nil {
                other.close(completion: present)
            } else {
                present()
            }
        } }
        return true
    }

    /// Корень окна на экране, когда показывать не от кого; подменяется в тестах.
    static var keyRoot: () -> UIViewController? = { UIViewController.personalizationKeyRoot }

    /// Кто покажет просмотрщик: `presenter`, иначе корень окна сцены на экране. Сцены на экране
    /// ещё нет (приложение запущено ссылкой или пушем и не вышло вперёд) — ждём её активации,
    /// но не дольше `deadline`; не дождались — `nil`. Ответ — на главной очереди.
    static func awaitPresenter(
        _ presenter: UIViewController?,
        until deadline: Date,
        _ completion: @escaping (UIViewController?) -> Void
    ) {
        if let host = presenter ?? keyRoot() { return completion(host) }
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else { return completion(nil) }
        let center = NotificationCenter.default
        var observers: [NSObjectProtocol] = []
        var finished = false
        let finish = { (host: UIViewController?) in
            guard !finished else { return }
            finished = true
            observers.forEach { center.removeObserver($0) }
            observers = []
            completion(host)
        }
        // Без сцен (iOS 12) — активация приложения; со сценами — и сцены, и приложения.
        var names = [UIApplication.didBecomeActiveNotification]
        if #available(iOS 13.0, *) {
            names += [UIScene.willEnterForegroundNotification, UIScene.didActivateNotification]
        }
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                if let host = keyRoot() { finish(host) }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining) { finish(keyRoot()) }
    }

    /// Инстанс SDK и загрузка сторис с отказом через `loadTimeout`. Ровно один исход на главной
    /// очереди: `onLoaded` с непустыми сторис или `onError` — нет инстанса, ошибка, пусто, таймаут.
    private static func load(
        sdk: PersonalizationSDK?,
        shopId: String?,
        what: String,
        request: (PersonalizationSDK, @escaping (Result<[PersonalizationStory], SdkError>) -> Void) -> Void,
        onError: @escaping (SdkError) -> Void,
        onLoaded: @escaping (PersonalizationSDK, [PersonalizationStory]) -> Void
    ) {
        let resolved: PersonalizationSDK
        do {
            resolved = try sdk ?? Rees46.instance(for: shopId)
        } catch {
            return MainThread.run { onError(.custom(error: "Stories: \(error)")) }
        }
        var finished = false
        let timeout = DispatchWorkItem {
            guard !finished else { return }
            finished = true
            onError(.custom(error: "Stories: \(what) did not load in \(Int(loadTimeout)) s"))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + loadTimeout, execute: timeout)
        request(resolved) { result in
            guard !finished else { return }
            finished = true
            timeout.cancel()
            switch result {
            case .failure(let error):
                onError(error)
            case .success(let stories) where stories.isEmpty:
                onError(.custom(error: "Stories: \(what) has no stories"))
            case .success(let stories):
                onLoaded(resolved, stories)
            }
        }
    }
}
