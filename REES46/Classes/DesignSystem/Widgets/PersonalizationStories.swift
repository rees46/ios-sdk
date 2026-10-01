import UIKit

/// Сторис с данными SDK: лента блока `code` и полноэкранный просмотрщик по нажатию.
///
/// Паттерн Stories V2 из Figma (страница Stories, 1:32). Данные — `getStories(code:)`,
/// разбор ответа общий со старыми сторис; визуальный слой — `PersonalizationStoriesBar`
/// (доступен через `bar`) и `PersonalizationStoriesViewController`.
///
/// Инстанс SDK: `shopId` выбирает магазин при нескольких зарегистрированных; без него
/// берётся единственный. Резолвится при показе через `Rees46.awaitInstance`, явный —
/// параметром `sdk` или через `attach(_:)`.
///
/// Пока блок грузится, в ленте заглушки; пустой блок или ошибка — виджет скрывается
/// и схлопывается в ноль по высоте (ошибка ещё уходит в `onError`).
///
/// Просмотренные слайды хранятся в общем хранилище SDK по магазину — том же, что у старых
/// сторис: кольцо превью делится на сегменты по слайдам, просмотренные сегменты светлее,
/// досмотренная сторис серая, а закреплённая остаётся закреплённой (кольцо Semantic/Warning
/// и звезда). Начатая сторис открывается с первого непросмотренного слайда.
///
/// Трекинг: `storyView` на каждый показанный слайд, `storyClick` на кнопку, товар
/// и копирование промокода. Ссылки: кнопка и товар без `onProductClick` закрывают
/// просмотрщик и отдают ссылку `onLinkClick`, а без него открывают её системой
/// (`link_ios`, иначе `link`; у товара — `deeplink_ios`, иначе `url`).
@_spi(PersonalizationUI) public final class PersonalizationStories: UIView {

    /// Код блока сторис; смена перезагружает ленту.
    public var code: String {
        didSet { if oldValue != code { reload() } }
    }

    /// Магазин; `nil` — единственный зарегистрированный. Менять до показа.
    public var shopId: String?

    /// Лента: поля, шаг, заглушки.
    public let bar = PersonalizationStoriesBar()

    /// Ссылка кнопки или товара. `nil` — ссылку открывает система.
    public var onLinkClick: ((String) -> Void)?

    /// Нажатие на товар. `nil` — как ссылка, см. `onLinkClick`.
    public var onProductClick: ((PersonalizationStorySlide.Offer) -> Void)?

    public var onError: ((SdkError) -> Void)?

    /// Блок загружен: сколько в нём сторис (0 — виджет скрыт).
    public var onLoaded: ((Int) -> Void)?

    // MARK: - Тексты; локализация за хостом

    /// Тост после копирования промокода; `nil` — без тоста.
    public var promoCopiedText: String? = "Copied"
    public var promoCaption: String? = "Promo code"
    /// Подпись кнопки слайда с товаром, если у слайда нет своей кнопки.
    public var productButtonText = "More info"
    /// Подписи переключателя товаров, если админка их не задала.
    public var showProductsText = "Used products"
    public var hideProductsText = "Hide products"

    /// Загрузчик картинок; `nil` — встроенный.
    public var imageLoader: ((UIImageView, String) -> Void)?

    /// Кто показывает просмотрщик; `nil` — ближайший контроллер по цепочке ответчиков.
    public weak var hostViewController: UIViewController?

    /// Сторис загруженного блока.
    public private(set) var stories: [PersonalizationStory] = []

    private var sdk: PersonalizationSDK?
    private var instanceHandle: Cancellable?
    private var requestSeq = 0
    private var collapsed: NSLayoutConstraint!
    private weak var viewer: PersonalizationStoriesViewController?

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
        bar.imageLoader = { [weak self] imageView, item in
            self?.load(imageView, item.imageUrl)
        }
        bar.onItemTap = { [weak self] _, index in self?.open(at: index) }
        bar.isLoading = true
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
        // Неоднозначный запрос (несколько магазинов без shopId) awaitInstance молча роняет —
        // лента остаётся в заглушках, а не валит экран.
        instanceHandle = Rees46.awaitInstance(for: shopId) { [weak self] resolved in
            MainThread.run { self?.attach(resolved) }
        }
    }

    /// Загрузить блок заново.
    public func reload() {
        guard let sdk, !code.isEmpty else { return }
        requestSeq += 1
        let seq = requestSeq
        setCollapsed(false)
        bar.isLoading = true
        StoriesBlockLoader.load(sdk: sdk, code: code) { [weak self] result in
            MainThread.run {
                guard let self, seq == self.requestSeq else { return }
                switch result {
                case .success(let stories):
                    self.stories = stories
                    // Превью собираются один раз — когда уходят заглушки.
                    self.renderBar()
                    self.bar.isLoading = false
                    self.setCollapsed(self.stories.isEmpty)
                    self.onLoaded?(self.stories.count)
                case .failure(let error):
                    self.stories = []
                    self.renderBar()
                    self.bar.isLoading = false
                    self.setCollapsed(true)
                    self.onError?(error)
                }
            }
        }
    }

    private func setCollapsed(_ value: Bool) {
        isHidden = value
        collapsed.isActive = value
    }

    private func renderBar() {
        let state = StoriesSeenState(sdk: sdk)
        bar.items = stories.map { state.barItem($0) }
    }

    // MARK: - Просмотрщик

    private func open(at index: Int) {
        guard stories.indices.contains(index), viewer == nil,
              let host = hostViewController ?? nearestViewController() else { return }
        let state = StoriesSeenState(sdk: sdk)
        let viewer = PersonalizationStoriesViewController(stories: stories, startIndex: index)
        viewer.productButtonText = productButtonText
        viewer.promoCaption = promoCaption
        viewer.promoCopiedText = promoCopiedText
        viewer.showProductsText = showProductsText
        viewer.hideProductsText = hideProductsText
        viewer.imageLoader = imageLoader
        viewer.startSlide = { state.startSlide($0) }
        viewer.onSlideView = { [weak self] story, slide in self?.slideShown(story, slide) }
        viewer.onButtonTap = { [weak self, weak viewer] story, slide, button in
            guard let self else { return }
            self.trackClick(story, slide)
            guard let link = button.link else { return }
            self.leave(viewer) { self.openLink(link) }
        }
        viewer.onProductTap = { [weak self, weak viewer] story, slide, offer in
            guard let self else { return }
            self.trackClick(story, slide)
            if let onProductClick = self.onProductClick {
                self.leave(viewer) { onProductClick(offer) }
            } else if let link = offer.link {
                self.leave(viewer) { self.openLink(link) }
            }
        }
        viewer.onPromoCopied = { [weak self] story, slide, _ in self?.trackClick(story, slide) }
        self.viewer = viewer

        var top = host
        while let presented = top.presentedViewController { top = presented }
        top.present(viewer, animated: true)
    }

    private func slideShown(_ story: PersonalizationStory, _ slide: PersonalizationStorySlide) {
        sdk?.tracking.storyView(storyId: story.id, slideId: slide.id, code: code)
        StoriesSeenState(sdk: sdk).markSeen(slide, of: story)
        renderBar()
    }

    private func trackClick(_ story: PersonalizationStory, _ slide: PersonalizationStorySlide) {
        sdk?.tracking.storyClick(storyId: story.id, slideId: slide.id, code: code)
    }

    /// Закрыть просмотрщик и потом перейти: хост навигирует уже со своего экрана.
    private func leave(_ viewer: PersonalizationStoriesViewController?, then action: @escaping () -> Void) {
        guard let viewer else {
            action()
            return
        }
        viewer.close(completion: action)
    }

    private func openLink(_ link: String) {
        if let onLinkClick {
            onLinkClick(link)
            return
        }
        guard let url = URL(string: link) else { return }
        UIApplication.shared.open(url)
    }

    private func load(_ imageView: UIImageView, _ url: String?) {
        guard let url, !url.isEmpty else {
            imageView.image = nil
            return
        }
        if let imageLoader {
            imageLoader(imageView, url)
        } else {
            SearchImages.shared.load(imageView, url: url)
        }
    }

    private func nearestViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }
}
