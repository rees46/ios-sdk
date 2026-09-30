import UIKit
import AVFoundation

/// Полноэкранный просмотрщик сторис.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), фреймы Card/Story 402x874.
/// Показывается модально во весь экран (`modalPresentationStyle = .fullScreen`), статус-бар
/// скрыт. Сторис листаются горизонтальным свайпом, слайд — `PersonalizationStorySlideView`
/// под шапкой `PersonalizationStoryNavigation`.
///
/// Поведение:
/// - слайд идёт `duration` секунд (видео — до конца ролика), затем следующий; после
///   последнего слайда — следующая сторис, после последней сторис просмотрщик закрывается;
/// - нажатие в левой трети — предыдущий слайд, правее — следующий;
/// - долгое нажатие — пауза (отсчёт и видео), пока палец на экране;
/// - свайп вниз закрывает, крестик тоже;
/// - развёрнутые товары и уход приложения в фон ставят паузу;
/// - медиа-слайды — в тёмной теме кита, слайды с товаром — в теме приложения
///   (см. `PersonalizationStorySlide.interfaceStyle`);
/// - звук видео выключен при каждом открытии, как у старых сторис; включение переводит
///   аудиосессию в `.playback`, чтобы звук шёл и при беззвучном режиме.
///
/// Сеть, трекинг и ссылки — не его дело: наружу отданы колбэки. Данные SDK подключает
/// виджет `PersonalizationStories`; хост может показать просмотрщик и со своими данными.
@_spi(PersonalizationUI) public final class PersonalizationStoriesViewController: UIViewController {

    /// Сторис со слайдами: пустые отбрасываются при создании.
    public let stories: [PersonalizationStory]

    /// Индекс сторис на экране.
    public private(set) var currentIndex: Int

    // MARK: - Тексты; локализация за хостом

    /// Подпись кнопки слайда с товаром, если у слайда нет своей кнопки.
    public var productButtonText = "More info"
    public var promoCaption: String? = "Promo code"
    /// Тост после копирования промокода; `nil` — без тоста.
    public var promoCopiedText: String? = "Copied"
    /// Подписи переключателя товаров, если админка их не задала.
    public var showProductsText = "Used products"
    public var hideProductsText = "Hide products"
    public var closeAccessibilityLabel: String? = "Close"

    // MARK: - Настройка

    /// Загрузчик картинок: аватары, фоны, товары. `nil` — встроенный.
    /// Свой загрузчик о готовности не сообщает, поэтому отсчёт слайда идёт сразу.
    public var imageLoader: ((UIImageView, String) -> Void)?

    /// С какого слайда открыть сторис. `nil` — с `startPosition`.
    public var startSlide: ((PersonalizationStory) -> Int)?

    // MARK: - События

    /// Слайд показан — событие `view` для трекинга.
    public var onSlideView: ((PersonalizationStory, PersonalizationStorySlide) -> Void)?

    /// Нажата кнопка слайда.
    public var onButtonTap: ((PersonalizationStory, PersonalizationStorySlide, PersonalizationStorySlide.Button) -> Void)?

    /// Нажат товар: карточка слайда, его кнопка без своей ссылки или карточка карусели.
    public var onProductTap: ((PersonalizationStory, PersonalizationStorySlide, PersonalizationStorySlide.Offer) -> Void)?

    /// Промокод скопирован.
    public var onPromoCopied: ((PersonalizationStory, PersonalizationStorySlide, String) -> Void)?

    /// Просмотрщик закрывается.
    public var onClose: (() -> Void)?

    /// Звук видео.
    public private(set) var isMuted = true

    private let pager = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
    private var pages: [Int: PersonalizationStoryPageViewController] = [:]
    private var isTransitioning = false
    private var isClosing = false

    /// Сдвиг или скорость свайпа вниз, после которых просмотрщик закрывается.
    private static let closeDistance: CGFloat = 120
    private static let closeVelocity: CGFloat = 800

    public init(stories: [PersonalizationStory], startIndex: Int = 0) {
        let playable = stories.filter { !$0.slides.isEmpty }
        let requested = stories.indices.contains(startIndex) ? stories[startIndex].id : nil
        self.stories = playable
        self.currentIndex = playable.firstIndex { $0.id == requested } ?? 0
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalPresentationCapturesStatusBarAppearance = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public override var prefersStatusBarHidden: Bool { true }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .phone ? .portrait : .all
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        pager.dataSource = self
        pager.delegate = self
        addChild(pager)
        pager.view.frame = view.bounds
        pager.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(pager.view)
        pager.didMove(toParent: self)
        if !stories.isEmpty {
            pager.setViewControllers([page(at: currentIndex)], direction: .forward, animated: false)
        }

        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)
        // Горизонтальный свайп сторис ждёт, пока не станет ясно, что это не свайп вниз.
        for case let scroll as UIScrollView in pager.view.subviews {
            scroll.panGestureRecognizer.require(toFail: pan)
        }
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if stories.isEmpty { close() }
    }

    public override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        applySafeInsets()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applySafeInsets()
    }

    /// Безопасная зона экрана — страницам явно: они лежат в прокрутке `UIPageViewController`,
    /// и своя безопасная зона до них не доходит. Пересчитывается при повороте и смене зоны.
    private func applySafeInsets() {
        let insets = view.safeAreaInsets
        pages.values.forEach { $0.safeInsets = insets }
    }

    /// Закрывает просмотрщик; `completion` — после закрытия (или сразу, если он не показан).
    public func close(completion: (() -> Void)? = nil) {
        guard !isClosing else { return }
        isClosing = true
        currentPage?.deactivate()
        onClose?()
        guard presentingViewController != nil else {
            completion?()
            return
        }
        dismiss(animated: true, completion: completion)
    }

    // MARK: - Страницы

    private var currentPage: PersonalizationStoryPageViewController? {
        pager.viewControllers?.first as? PersonalizationStoryPageViewController
    }

    private func page(at index: Int) -> PersonalizationStoryPageViewController {
        if let cached = pages[index] { return cached }
        let story = stories[index]
        let requested = startSlide?(story) ?? story.startPosition
        let start = min(max(requested, 0), story.slides.count - 1)
        let page = PersonalizationStoryPageViewController(story: story, storyIndex: index, startSlide: start, viewer: self)
        if isViewLoaded { page.safeInsets = view.safeAreaInsets }
        pages[index] = page
        return page
    }

    /// Следующая сторис после последнего слайда; после последней сторис — закрыть.
    func showNext(after page: PersonalizationStoryPageViewController) {
        let next = page.storyIndex + 1
        guard next < stories.count else {
            close()
            return
        }
        move(to: next, direction: .forward)
    }

    /// Предыдущая сторис с первого слайда. `false` — предыдущей нет.
    @discardableResult
    func showPrevious(before page: PersonalizationStoryPageViewController) -> Bool {
        let previous = page.storyIndex - 1
        guard previous >= 0 else { return false }
        move(to: previous, direction: .reverse)
        return true
    }

    private func move(to index: Int, direction: UIPageViewController.NavigationDirection) {
        guard !isTransitioning, !isClosing else { return }
        isTransitioning = true
        let target = page(at: index)
        pager.setViewControllers([target], direction: direction, animated: true) { [weak self] _ in
            guard let self else { return }
            self.currentIndex = index
            // После анимированной смены UIPageViewController помнит старых соседей и при
            // следующем свайпе может отдать не ту страницу — перевыставляется без анимации.
            DispatchQueue.main.async {
                self.pager.setViewControllers([target], direction: direction, animated: false)
                self.isTransitioning = false
            }
        }
    }

    // MARK: - События страниц

    var slideTexts: PersonalizationStorySlideView.Texts {
        PersonalizationStorySlideView.Texts(
            productButton: productButtonText,
            promoCaption: promoCaption,
            promoCopied: promoCopiedText,
            showProducts: showProductsText,
            hideProducts: hideProductsText
        )
    }

    func slideShown(_ story: PersonalizationStory, _ slide: PersonalizationStorySlide) {
        onSlideView?(story, slide)
    }

    func buttonTapped(_ story: PersonalizationStory, _ slide: PersonalizationStorySlide, _ button: PersonalizationStorySlide.Button) {
        onButtonTap?(story, slide, button)
    }

    func productTapped(_ story: PersonalizationStory, _ slide: PersonalizationStorySlide, _ offer: PersonalizationStorySlide.Offer) {
        onProductTap?(story, slide, offer)
    }

    func promoCopied(_ story: PersonalizationStory, _ slide: PersonalizationStorySlide, _ code: String) {
        onPromoCopied?(story, slide, code)
    }

    /// Звук общий для всех видео просмотрщика.
    func setMuted(_ muted: Bool) {
        isMuted = muted
        if !muted {
            // Как у старых сторис: со звуком видео слышно и в беззвучном режиме.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        }
        pages.values.forEach { $0.applyMuted(muted) }
    }

    // MARK: - Свайп вниз

    @objc private func panned(_ gesture: UIPanGestureRecognizer) {
        let distance = max(0, gesture.translation(in: view).y)
        switch gesture.state {
        case .began:
            currentPage?.setPaused(true, reason: .drag)
        case .changed:
            pager.view.transform = CGAffineTransform(translationX: 0, y: distance)
        case .ended, .cancelled, .failed:
            let velocity = gesture.velocity(in: view).y
            if gesture.state == .ended, distance > Self.closeDistance || velocity > Self.closeVelocity {
                close()
            } else {
                UIView.animate(withDuration: 0.25) { self.pager.view.transform = .identity }
                currentPage?.setPaused(false, reason: .drag)
            }
        default:
            break
        }
    }
}

extension PersonalizationStoriesViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let page = viewController as? PersonalizationStoryPageViewController, page.storyIndex > 0 else { return nil }
        return self.page(at: page.storyIndex - 1)
    }

    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let page = viewController as? PersonalizationStoryPageViewController, page.storyIndex + 1 < stories.count else { return nil }
        return self.page(at: page.storyIndex + 1)
    }

    public func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed, let page = currentPage {
            currentIndex = page.storyIndex
        }
    }
}

extension PersonalizationStoriesViewController: UIGestureRecognizerDelegate {

    /// Свайп закрытия — только вниз и заметно вертикальный.
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, pan.view === view else { return true }
        let velocity = pan.velocity(in: view)
        return velocity.y > 0 && velocity.y > abs(velocity.x)
    }
}

// MARK: - Страница сторис

/// Одна сторис: шапка, текущий слайд и отсчёт. Активна, пока на экране.
final class PersonalizationStoryPageViewController: UIViewController, UIGestureRecognizerDelegate {

    /// Почему стоит пауза: отсчёт идёт, только когда причин нет.
    enum PauseReason {
        case hold, products, drag, background
    }

    let story: PersonalizationStory
    let storyIndex: Int
    private(set) var slideIndex: Int

    /// Безопасная зона экрана от просмотрщика: шапка — на 16 ниже её верха, содержимое
    /// слайда — внутри неё. Фон слайда при этом от края до края.
    var safeInsets: UIEdgeInsets = .zero {
        didSet {
            guard oldValue != safeInsets else { return }
            applySafeInsets()
        }
    }

    private weak var viewer: PersonalizationStoriesViewController?
    private let content = UIView()
    private let navigation = PersonalizationStoryNavigation()
    private var slideView: PersonalizationStorySlideView?
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var elapsed: TimeInterval = 0
    private var waited: TimeInterval = 0
    private var isActive = false
    private var reported = false
    /// Слайд доигран и отдан просмотрщику: при возврате на страницу он начнётся заново.
    private var finished = false
    private var pauses = Set<PauseReason>()
    private var navigationTop: NSLayoutConstraint?
    private var navigationLeading: NSLayoutConstraint?
    private var navigationTrailing: NSLayoutConstraint?

    /// Сколько ждать фон, прежде чем пустить слайд по таймеру.
    private static let readyTimeout: TimeInterval = 10

    init(story: PersonalizationStory, storyIndex: Int, startSlide: Int, viewer: PersonalizationStoriesViewController) {
        self.story = story
        self.storyIndex = storyIndex
        self.slideIndex = startSlide
        self.viewer = viewer
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        link?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)
        navigation.translatesAutoresizingMaskIntoConstraints = false
        navigation.closeAccessibilityLabel = viewer?.closeAccessibilityLabel
        navigation.progress.count = story.slides.count
        navigation.onClose = { [weak self] in self?.viewer?.close() }
        content.addSubview(navigation)

        let top = navigation.topAnchor.constraint(equalTo: content.topAnchor)
        let leading = navigation.leadingAnchor.constraint(equalTo: content.leadingAnchor)
        let trailing = navigation.trailingAnchor.constraint(equalTo: content.trailingAnchor)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.topAnchor),
            content.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            top, leading, trailing
        ])
        navigationTop = top
        navigationLeading = leading
        navigationTrailing = trailing
        applySafeInsets()

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.delegate = self
        view.addGestureRecognizer(tap)
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
        hold.minimumPressDuration = 0.2
        hold.delegate = self
        view.addGestureRecognizer(hold)

        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)

        // Фоны картинок следующих слайдов — заранее в кэш.
        if viewer?.imageLoader == nil {
            story.slides.filter { $0.kind == .image }.forEach { PersonalizationStoryImages.shared.prefetch($0.background) }
        }
        show(slideIndex)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        activate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        deactivate()
    }

    // MARK: - Активность

    func activate() {
        guard !isActive else { return }
        isActive = true
        if finished {
            // Вернулись на доигранную сторис — последний слайд заново.
            show(slideIndex)
        }
        slideView?.setMuted(viewer?.isMuted ?? true)
        lastTimestamp = nil
        let link = CADisplayLink(target: DisplayLinkProxy(self), selector: #selector(DisplayLinkProxy.tick(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
        reportView()
        if pauses.isEmpty { slideView?.play() }
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        link?.invalidate()
        link = nil
        slideView?.pause()
    }

    func setPaused(_ paused: Bool, reason: PauseReason) {
        let wasRunning = pauses.isEmpty
        if paused {
            pauses.insert(reason)
        } else {
            pauses.remove(reason)
        }
        guard wasRunning != pauses.isEmpty else { return }
        if pauses.isEmpty {
            if isActive { slideView?.play() }
        } else {
            slideView?.pause()
        }
    }

    func applyMuted(_ muted: Bool) {
        slideView?.setMuted(muted)
    }

    /// Шапка на 16 от краёв безопасной зоны, слайду — та же зона.
    private func applySafeInsets() {
        let side = PersonalizationSpacing.xl  // 16
        navigationTop?.constant = safeInsets.top + side
        navigationLeading?.constant = safeInsets.left + side
        navigationTrailing?.constant = -(safeInsets.right + side)
        slideView?.safeInsets = safeInsets
    }

    // MARK: - Слайды

    func show(_ index: Int) {
        guard story.slides.indices.contains(index) else { return }
        slideView?.stop()
        slideView?.removeFromSuperview()

        slideIndex = index
        elapsed = 0
        waited = 0
        reported = false
        finished = false
        pauses.remove(.products)

        let slide = story.slides[index]
        let next = PersonalizationStorySlideView(
            slide: slide,
            texts: viewer?.slideTexts ?? PersonalizationStorySlideView.Texts(),
            isMuted: viewer?.isMuted ?? true,
            imageLoader: viewer?.imageLoader
        )
        next.onButton = { [weak self] button in
            guard let self else { return }
            self.viewer?.buttonTapped(self.story, slide, button)
        }
        next.onProduct = { [weak self] offer in
            guard let self else { return }
            self.viewer?.productTapped(self.story, slide, offer)
        }
        next.onPromoCopied = { [weak self] code in
            guard let self else { return }
            self.viewer?.promoCopied(self.story, slide, code)
        }
        next.onProductsToggle = { [weak self] expanded in self?.setPaused(expanded, reason: .products) }
        next.onMuteToggle = { [weak self] muted in self?.viewer?.setMuted(muted) }
        next.onVideoEnd = { [weak self] in self?.next() }
        next.safeInsets = safeInsets

        next.translatesAutoresizingMaskIntoConstraints = false
        content.insertSubview(next, belowSubview: navigation)
        NSLayoutConstraint.activate([
            next.topAnchor.constraint(equalTo: content.topAnchor),
            next.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            next.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            next.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            next.contentGuide.topAnchor.constraint(equalTo: navigation.bottomAnchor, constant: PersonalizationSpacing.xl)
        ])
        // Тема слайда распространяется и на шапку: на фото прогресс и крестик светлые.
        if #available(iOS 13.0, *) {
            content.overrideUserInterfaceStyle = slide.interfaceStyle
        }
        navigation.progress.current = index
        navigation.progress.progress = 0
        slideView = next

        if isActive {
            reportView()
            if pauses.isEmpty { next.play() }
        }
    }

    func next() {
        if slideIndex + 1 < story.slides.count {
            show(slideIndex + 1)
        } else if !finished {
            finished = true
            viewer?.showNext(after: self)
        }
    }

    func previous() {
        if slideIndex > 0 {
            show(slideIndex - 1)
        } else if viewer?.showPrevious(before: self) != true {
            // Предыдущей сторис нет — первый слайд заново.
            show(slideIndex)
        }
    }

    private func reportView() {
        guard isActive, !reported, story.slides.indices.contains(slideIndex) else { return }
        reported = true
        viewer?.slideShown(story, story.slides[slideIndex])
    }

    fileprivate func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        let delta = lastTimestamp.map { now - $0 } ?? 0
        lastTimestamp = now
        guard isActive, pauses.isEmpty, !finished, let slideView else { return }

        guard slideView.isReady else {
            waited += delta
            if waited >= Self.readyTimeout { slideView.giveUpWaiting() }
            return
        }
        if slideView.isVideo {
            // Видео ведёт прогресс само; конец ролика придёт уведомлением.
            if let progress = slideView.videoProgress { navigation.progress.progress = progress }
            return
        }
        elapsed += delta
        let duration = max(slideView.slide.duration, 0.1)
        navigation.progress.progress = CGFloat(elapsed / duration)
        if elapsed >= duration { next() }
    }

    // MARK: - Жесты

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        if gesture.location(in: view).x < view.bounds.width / 3 {
            previous()
        } else {
            next()
        }
    }

    @objc private func held(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            setPaused(true, reason: .hold)
        case .ended, .cancelled, .failed:
            setPaused(false, reason: .hold)
        default:
            break
        }
    }

    /// Касания кнопок, цены, карточек и карусели — их, а не листания.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var current = touch.view
        while let candidate = current, candidate !== view {
            if candidate is UIControl || candidate is UIScrollView { return false }
            if let recognizers = candidate.gestureRecognizers, !recognizers.isEmpty { return false }
            current = candidate.superview
        }
        return true
    }

    @objc private func willResignActive() {
        setPaused(true, reason: .background)
    }

    @objc private func didBecomeActive() {
        setPaused(false, reason: .background)
    }
}

/// Прокладка для `CADisplayLink`: он держит цель сильной ссылкой, а страница должна уходить сама.
private final class DisplayLinkProxy: NSObject {
    private weak var target: PersonalizationStoryPageViewController?

    init(_ target: PersonalizationStoryPageViewController) {
        self.target = target
    }

    @objc func tick(_ link: CADisplayLink) {
        guard let target else {
            link.invalidate()
            return
        }
        target.tick(link)
    }
}
