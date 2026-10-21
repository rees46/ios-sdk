import UIKit

/// Тексты сторис, которые хост может заменить; локализация — за хостом. Одни и те же
/// у виджета, просмотрщика и `PersonalizationStories.show`.
@_spi(PersonalizationUI) public struct PersonalizationStoriesTexts {
    /// Подпись над промокодом, если админка не задала свою.
    public var promoCaption: String?
    /// Тост после копирования промокода; `nil` — без тоста.
    public var promoCopiedText: String?
    /// Кнопка товарного слайда без своих кнопок.
    public var productButtonText: String
    /// Подписи переключателя товаров, если админка их не задала.
    public var showProductsText: String
    public var hideProductsText: String
    /// Кнопка повтора, когда медиа не загрузилось.
    public var retryText: String
    /// VoiceOver: крестик, включение и выключение звука.
    public var closeLabel: String?
    public var soundOnLabel: String?
    public var soundOffLabel: String?

    public init(
        promoCaption: String? = "Promo code",
        promoCopiedText: String? = "Copied",
        productButtonText: String = "More info",
        showProductsText: String = "Used products",
        hideProductsText: String = "Hide products",
        retryText: String = "Retry",
        closeLabel: String? = "Close",
        soundOnLabel: String? = "Sound on",
        soundOffLabel: String? = "Sound off"
    ) {
        self.promoCaption = promoCaption
        self.promoCopiedText = promoCopiedText
        self.productButtonText = productButtonText
        self.showProductsText = showProductsText
        self.hideProductsText = hideProductsText
        self.retryText = retryText
        self.closeLabel = closeLabel
        self.soundOnLabel = soundOnLabel
        self.soundOffLabel = soundOffLabel
    }

    var slideTexts: PersonalizationStorySlideView.Texts {
        PersonalizationStorySlideView.Texts(
            productButton: productButtonText,
            promoCaption: promoCaption,
            promoCopied: promoCopiedText,
            showProducts: showProductsText,
            hideProducts: hideProductsText,
            retry: retryText,
            soundOn: soundOnLabel,
            soundOff: soundOffLabel
        )
    }
}

/// Полноэкранный просмотрщик сторис.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), фреймы Card/Story 402x874.
/// Показывается модально во весь экран, статус-бар скрыт. Сторис листаются горизонтальным
/// свайпом, слайд — `PersonalizationStorySlideView` под шапкой `PersonalizationStoryNavigation`.
/// Решения — куда идти, когда стоять — принимает `PersonalizationStoriesViewerState`.
///
/// Поведение:
/// - слайд идёт `duration` секунд, видео — свою длину по позиции воспроизведения, GIF фона —
///   не меньше одного своего круга; отсчёт стартует, когда медиа готово (у GIF — первый кадр
///   на экране); не дождались за 10 с или не загрузилось — «Повторить»;
/// - нажатие в левой трети — назад, в правой — вперёд, в середине — ничего (в RTL края
///   наоборот); назад на первом слайде первой сторис — тот же слайд с начала; вперёд после
///   последнего слайда последней сторис — закрыть;
/// - удержание и свайп — пауза; свайп вниз закрывает, крестик тоже;
/// - открытый лист товаров ставит паузу и не даёт листать, нажатие мимо него его закрывает;
/// - пауза в фоне, при неактивной сцене и под чужим экраном, а также по `pause()` хоста;
///   в паузе ролик и GIF стоят на текущем кадре;
/// - медиа-слайды — в тёмной теме кита, остальные — в теме приложения;
/// - звук — на весь запуск: выключен при первом открытии, дальше как выбрал пользователь.
///
/// Сеть, трекинг и ссылки — не его дело: наружу отданы колбэки. Данные SDK подключает
/// виджет `PersonalizationStories`; хост может показать просмотрщик и со своими данными.
@_spi(PersonalizationUI) public final class PersonalizationStoriesViewController: UIViewController {

    /// Сторис со слайдами: пустые отбрасываются при создании.
    public let stories: [PersonalizationStory]

    /// Индекс сторис на экране.
    public var currentIndex: Int { state.story }

    /// Тексты кита.
    public var texts = PersonalizationStoriesTexts()

    /// Загрузчик картинок: аватары, фоны, товары. `nil` — встроенный с дисковым кэшем.
    public var imageLoader: ((UIImageView, String) -> Void)?

    /// С какого слайда открыть сторис. `nil` — с `startPosition`.
    public var startSlide: ((PersonalizationStory) -> Int)?

    // MARK: - События

    /// Слайд стал текущим на остановившейся странице — событие `view` для трекинга.
    public var onSlideView: ((PersonalizationStory, PersonalizationStorySlide) -> Void)?

    /// Нажата кнопка слайда.
    public var onButtonTap: ((PersonalizationStory, PersonalizationStorySlide, PersonalizationStorySlide.Button) -> Void)?

    /// Нажат товар: кнопка товарного слайда без своих кнопок, карточка карусели. Картинка
    /// товара не нажимается — касание по ней листает слайд.
    public var onProductTap: ((PersonalizationStory, PersonalizationStorySlide, PersonalizationStorySlide.Offer) -> Void)?

    /// Промокод скопирован — из блока цены или из текстового блока.
    public var onPromoCopied: ((PersonalizationStory, PersonalizationStorySlide, String) -> Void)?

    /// Просмотрщик закрывается.
    public var onClose: (() -> Void)?

    /// Видео сейчас без звука: так выбрал пользователь (выбор общий на весь запуск) или звук
    /// забрала система — выдернули наушники, прервал звонок.
    public var isMuted: Bool { PersonalizationStoryAudio.shared.isPlaybackMuted }

    var state: PersonalizationStoriesViewerState
    let pager = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
    var pages: [Int: PersonalizationStoryPageViewController] = [:]
    weak var activePage: PersonalizationStoryPageViewController?
    var isTransitioning = false
    var hasAppeared = false
    var isDismissed = false
    var closeCompletions: [() -> Void] = []
    var displayLink: CADisplayLink?
    var lastTimestamp: CFTimeInterval?
    var observers: [NSObjectProtocol] = []

    /// Сдвиг или скорость свайпа вниз, после которых просмотрщик закрывается.
    static let closeDistance: CGFloat = 120
    static let closeVelocity: CGFloat = 800

    public init(stories: [PersonalizationStory], startIndex: Int = 0) {
        let playable = stories.filter { !$0.slides.isEmpty }
        let requested = stories.indices.contains(startIndex) ? stories[startIndex].id : nil
        self.stories = playable
        let start = playable.firstIndex { $0.id == requested } ?? 0
        self.state = PersonalizationStoriesViewerState(slideCounts: playable.map(\.slides.count), story: start)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalPresentationCapturesStatusBarAppearance = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        displayLink?.invalidate()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    public override var prefersStatusBarHidden: Bool { true }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .phone ? .portrait : .all
    }
}

// MARK: - Жизненный цикл и управление

extension PersonalizationStoriesViewController {

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
            pager.setViewControllers([page(at: state.story)], direction: .forward, animated: false)
        }

        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)
        // Горизонтальный свайп сторис ждёт, пока не станет ясно, что это не свайп вниз.
        pagerScrollView?.panGestureRecognizer.require(toFail: pan)
        observeSystem()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !stories.isEmpty else {
            close()
            return
        }
        if !hasAppeared {
            hasAppeared = true
            PersonalizationStoryAudio.shared.begin()
            startClock()
            if let page = pager.viewControllers?.first as? PersonalizationStoryPageViewController {
                settle(on: page)
            }
        }
        setPaused(.hidden, false)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Не закрытие — значит, просмотрщик накрыл другой экран.
        if !state.isClosing { setPaused(.hidden, true) }
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Хост убрал просмотрщик сам, а не через `close()`: звук всё равно возвращается.
        guard isBeingDismissed, state.close() else { return }
        wrapUp()
        isDismissed = true
        runCloseCompletions()
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

    var pagerScrollView: UIScrollView? {
        pager.view.subviews.compactMap { $0 as? UIScrollView }.first
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

    // MARK: - Управление хостом

    /// Закрывает просмотрщик; `completion` — после закрытия. Повторный вызов во время
    /// закрытия не теряет свой `completion`: все зовутся по порядку, когда экран ушёл.
    public func close(completion: (() -> Void)? = nil) {
        if let completion { closeCompletions.append(completion) }
        guard state.close() else {
            if isDismissed { runCloseCompletions() }
            return
        }
        wrapUp()
        guard presentingViewController != nil else {
            isDismissed = true
            runCloseCompletions()
            return
        }
        dismiss(animated: true) { [weak self] in
            self?.isDismissed = true
            self?.runCloseCompletions()
        }
    }

    /// Просмотр кончился: часы, видео и звук отпускаются, хост узнаёт о закрытии.
    private func wrapUp() {
        stopClock()
        activePage?.slideView?.pause()
        if hasAppeared { PersonalizationStoryAudio.shared.end() }
        onClose?()
    }

    private func runCloseCompletions() {
        let completions = closeCompletions
        closeCompletions = []
        completions.forEach { $0() }
    }

    /// Перейти к сторис по индексу.
    public func open(at index: Int) {
        guard stories.indices.contains(index), index != state.story, !state.isClosing else { return }
        move(to: index, forward: index > state.story)
    }

    /// Перейти к сторис по id.
    public func open(storyId: String) {
        guard let index = stories.firstIndex(where: { $0.id == storyId }) else { return }
        open(at: index)
    }

    /// Пауза от хоста: отсчёт и видео стоят до `resume()`.
    public func pause() {
        setPaused(.host, true)
    }

    public func resume() {
        setPaused(.host, false)
    }
}

// MARK: - Страницы и переходы

extension PersonalizationStoriesViewController {

    /// Слайд, с которого открывается сторис: по просмотренности, в пределах сторис.
    func startSlideIndex(of story: PersonalizationStory) -> Int {
        let requested = startSlide?(story) ?? story.startPosition
        return min(max(requested, 0), story.slides.count - 1)
    }

    func page(at index: Int) -> PersonalizationStoryPageViewController {
        if let cached = pages[index] { return cached }
        let story = stories[index]
        let page = PersonalizationStoryPageViewController(story: story, storyIndex: index, startSlide: startSlideIndex(of: story), viewer: self)
        if isViewLoaded { page.safeInsets = view.safeAreaInsets }
        pages[index] = page
        return page
    }

    /// Страница остановилась на экране: её сторис становится текущей. Сторис, в которую
    /// вернулись, открывается по просмотренности заново.
    func settle(on page: PersonalizationStoryPageViewController) {
        guard page !== activePage, !state.isClosing else { return }
        activePage?.deactivate()
        let start = startSlideIndex(of: page.story)
        if page.slideIndex != start || page.slideView == nil { page.show(start) }
        activePage = page
        state.enter(story: page.storyIndex, slide: page.slideIndex, mediaReady: page.slideView?.isMediaReady ?? true)
        slideBecameCurrent()
        evictDistantPages()
    }

    func apply(_ command: PersonalizationStoriesViewerState.Command) {
        guard let page = activePage else { return }
        switch command {
        case .none:
            return
        case .showSlide(let index):
            page.show(index)
            state.enter(slide: index, mediaReady: page.slideView?.isMediaReady ?? true)
            slideBecameCurrent()
        case .showStory(let index, let forward):
            move(to: index, forward: forward)
        case .restartSlide:
            state.restart()
            page.slideView?.restart()
            page.navigation.progress.progress = 0
        case .close:
            close()
        case .closeSheet:
            page.slideView?.collapseProducts()
        case .mediaFailed:
            page.slideView?.setRetryVisible(true)
        case .retryMedia:
            page.slideView?.setRetryVisible(false)
            page.slideView?.loadMedia()
        }
        sync()
    }

    func move(to index: Int, forward: Bool) {
        guard !isTransitioning, !state.isClosing, stories.indices.contains(index) else { return }
        isTransitioning = true
        state.setPaused(.drag, true)
        sync()
        let target = page(at: index)
        let direction: UIPageViewController.NavigationDirection = forward ? .forward : .reverse
        pager.setViewControllers([target], direction: direction, animated: true) { [weak self] _ in
            guard let self else { return }
            // После анимированной смены UIPageViewController помнит старых соседей и при
            // следующем свайпе может отдать не ту страницу — перевыставляется без анимации.
            DispatchQueue.main.async {
                self.pager.setViewControllers([target], direction: direction, animated: false)
                self.isTransitioning = false
                self.state.setPaused(.drag, false)
                self.settle(on: target)
                self.sync()
            }
        }
    }

    /// Слайд стал текущим: событие `view`, заранее — медиа следующего слайда.
    private func slideBecameCurrent() {
        guard let page = activePage, let slide = page.currentSlide else { return }
        page.slideView?.setRetryVisible(false)
        onSlideView?(page.story, slide)
        prefetch(after: page)
        sync()
    }

    /// Медиа следующего слайда — в кэш: картинка целиком, у ролика — начало.
    private func prefetch(after page: PersonalizationStoryPageViewController) {
        let next: PersonalizationStorySlide?
        if page.slideIndex + 1 < page.story.slides.count {
            next = page.story.slides[page.slideIndex + 1]
        } else if page.storyIndex + 1 < stories.count {
            let story = stories[page.storyIndex + 1]
            next = story.slides[startSlideIndex(of: story)]
        } else {
            next = nil
        }
        guard let next else { return }
        switch next.media {
        case .image(let url):
            if imageLoader == nil { PersonalizationStoryImages.shared.prefetch(url) }
        case .video(let url):
            PersonalizationStoryVideos.shared.prefetchHead(url)
            if imageLoader == nil { PersonalizationStoryImages.shared.prefetch(next.preview) }
        case .none:
            break
        }
    }

    /// Страницы дальше соседних отпускают плееры и уходят из памяти.
    private func evictDistantPages() {
        for (index, page) in pages where abs(index - state.story) > 1 {
            page.release()
            pages[index] = nil
        }
    }

    func setPaused(_ reason: PersonalizationStoriesViewerState.PauseReason, _ paused: Bool) {
        state.setPaused(reason, paused)
        sync()
    }

    /// Видео, свайпы и «Повторить» — по состоянию.
    func sync() {
        guard let slideView = activePage?.slideView else { return }
        if state.isRunning {
            slideView.play()
        } else {
            slideView.pause()
        }
        slideView.setRetryVisible(state.hasFailed)
        pagerScrollView?.isScrollEnabled = state.canSwipe && !isTransitioning
        if state.isRunning { lastTimestamp = nil }
    }
}

// MARK: - Часы и события страниц

extension PersonalizationStoriesViewController {

    /// Самый длинный шаг часов: после паузы кадров (фон, тяжёлая отрисовка) слайд не перескакивает.
    static let maxTick: CFTimeInterval = 0.25

    func startClock() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: DisplayLinkProxy(self), selector: #selector(DisplayLinkProxy.tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastTimestamp = nil
    }

    func stopClock() {
        displayLink?.invalidate()
        displayLink = nil
    }

    fileprivate func tick(_ timestamp: CFTimeInterval) {
        let delta = lastTimestamp.map { min(timestamp - $0, Self.maxTick) } ?? 0
        lastTimestamp = timestamp
        guard let page = activePage, let slideView = page.slideView else { return }
        slideView.pollReadiness()
        // Ролик известной длины ведёт прогресс сам, остальное — по таймеру слайда
        // (у GIF — не короче его круга).
        let videoClock = slideView.isVideo && slideView.videoDuration != nil
        let duration = slideView.timerDuration
        let command = state.tick(delta, duration: videoClock ? nil : duration, isVideo: slideView.isVideo)
        page.navigation.progress.progress = videoClock
            ? (slideView.videoProgress ?? 0)
            : state.progress(duration: duration)
        apply(command)
    }

    // MARK: События текущей страницы

    func handleTap(at x: CGFloat, width: CGFloat, from page: PersonalizationStoryPageViewController) {
        guard page === activePage else { return }
        let rightToLeft = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        apply(state.tap(x: x, width: width, rightToLeft: rightToLeft))
    }

    func handleHold(_ holding: Bool) {
        setPaused(.hold, holding)
    }

    func mediaReady(on page: PersonalizationStoryPageViewController) {
        guard page === activePage else { return }
        state.mediaReady()
        sync()
    }

    func mediaFailed(on page: PersonalizationStoryPageViewController) {
        guard page === activePage else { return }
        state.mediaFailed()
        sync()
    }

    func retryTapped(on page: PersonalizationStoryPageViewController) {
        guard page === activePage, !state.isClosing else { return }
        state.retry()
        page.slideView?.setRetryVisible(false)
        page.slideView?.loadMedia()
        sync()
    }

    func videoEnded(on page: PersonalizationStoryPageViewController) {
        guard page === activePage else { return }
        apply(state.next())
    }

    /// Ролик остановила система, а не состояние: звук забран — ролик идёт дальше без него.
    func playbackStoppedBySystem(on page: PersonalizationStoryPageViewController) {
        guard page === activePage, !state.isClosing else { return }
        PersonalizationStoryAudio.shared.playbackStoppedBySystem()
    }

    func productsToggled(_ expanded: Bool, on page: PersonalizationStoryPageViewController) {
        guard page === activePage else { return }
        state.setSheetOpen(expanded)
        sync()
    }

    func buttonTapped(_ story: PersonalizationStory, _ slide: PersonalizationStorySlide, _ button: PersonalizationStorySlide.Button) {
        guard !state.isClosing else { return }
        onButtonTap?(story, slide, button)
    }

    func productTapped(_ story: PersonalizationStory, _ slide: PersonalizationStorySlide, _ offer: PersonalizationStorySlide.Offer) {
        guard !state.isClosing else { return }
        onProductTap?(story, slide, offer)
    }

    func promoCopied(_ story: PersonalizationStory, _ slide: PersonalizationStorySlide, _ code: String) {
        guard !state.isClosing else { return }
        onPromoCopied?(story, slide, code)
    }

    // MARK: Система

    /// Пауза при уходе приложения в фон, неактивной сцене (центр управления, звонок,
    /// погасший экран) и снова ход при возвращении; звук меняется у всех страниц сразу.
    /// Звук, отобранный системой, ролик не останавливает: он идёт дальше без звука.
    func observeSystem() {
        let center = NotificationCenter.default
        let pause: (Notification) -> Void = { [weak self] _ in self?.setPaused(.background, true) }
        let resume: (Notification) -> Void = { [weak self] _ in self?.setPaused(.background, false) }
        observers += [
            center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main, using: pause),
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main, using: pause),
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main, using: resume)
        ]
        if #available(iOS 13.0, *) {
            let scenePause: (Notification) -> Void = { [weak self] note in
                guard let self, note.object as? UIScene === self.view.window?.windowScene else { return }
                self.setPaused(.background, true)
            }
            let sceneResume: (Notification) -> Void = { [weak self] note in
                guard let self, note.object as? UIScene === self.view.window?.windowScene else { return }
                self.setPaused(.background, false)
            }
            observers += [
                center.addObserver(forName: UIScene.willDeactivateNotification, object: nil, queue: .main, using: scenePause),
                center.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main, using: sceneResume)
            ]
        }
        observers.append(center.addObserver(forName: PersonalizationStoryAudio.didChange, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            let muted = PersonalizationStoryAudio.shared.isPlaybackMuted
            self.pages.values.forEach { $0.slideView?.setMuted(muted) }
            // Система могла остановить ролик сама (наушники, прерывание): плеер снова
            // делает то, что велит состояние, и прогресс не расходится с видео.
            self.sync()
        })
    }

    @objc func panned(_ gesture: UIPanGestureRecognizer) {
        let distance = max(0, gesture.translation(in: view).y)
        switch gesture.state {
        case .began:
            setPaused(.drag, true)
        case .changed:
            pager.view.transform = CGAffineTransform(translationX: 0, y: distance)
        case .ended, .cancelled, .failed:
            let velocity = gesture.velocity(in: view).y
            if gesture.state == .ended, distance > Self.closeDistance || velocity > Self.closeVelocity {
                close()
            } else {
                UIView.animate(withDuration: 0.25) { self.pager.view.transform = .identity }
                setPaused(.drag, false)
            }
        default:
            break
        }
    }
}

extension PersonalizationStoriesViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard state.canSwipe, let page = viewController as? PersonalizationStoryPageViewController, page.storyIndex > 0 else { return nil }
        return self.page(at: page.storyIndex - 1)
    }

    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard state.canSwipe, let page = viewController as? PersonalizationStoryPageViewController, page.storyIndex + 1 < stories.count else { return nil }
        return self.page(at: page.storyIndex + 1)
    }

    /// Свайп между сторис — пауза, как удержание; подсмотренная наполовину страница
    /// не считается показанной.
    public func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        setPaused(.drag, true)
    }

    public func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed, let page = pageViewController.viewControllers?.first as? PersonalizationStoryPageViewController {
            settle(on: page)
        }
        setPaused(.drag, false)
    }
}

extension PersonalizationStoriesViewController: UIGestureRecognizerDelegate {

    /// Свайп закрытия — только вниз, заметно вертикальный и не при открытом листе товаров.
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, pan.view === view else { return true }
        guard state.canSwipe else { return false }
        let velocity = pan.velocity(in: view)
        return velocity.y > 0 && velocity.y > abs(velocity.x)
    }
}

/// Прокладка для `CADisplayLink`: он держит цель сильной ссылкой, а просмотрщик должен уходить сам.
private final class DisplayLinkProxy: NSObject {
    private weak var target: PersonalizationStoriesViewController?

    init(_ target: PersonalizationStoriesViewController) {
        self.target = target
    }

    @objc func tick(_ link: CADisplayLink) {
        guard let target else {
            link.invalidate()
            return
        }
        target.tick(link.timestamp)
    }
}

// MARK: - Страница сторис

/// Одна сторис: шапка и текущий слайд. Решений не принимает — нажатия, удержание и события
/// слайда уходят просмотрщику, он и говорит, какой слайд показать.
final class PersonalizationStoryPageViewController: UIViewController, UIGestureRecognizerDelegate {

    let story: PersonalizationStory
    let storyIndex: Int
    private(set) var slideIndex: Int
    let navigation = PersonalizationStoryNavigation()
    private(set) var slideView: PersonalizationStorySlideView?

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
    private var navigationTop: NSLayoutConstraint?
    private var navigationLeading: NSLayoutConstraint?
    private var navigationTrailing: NSLayoutConstraint?

    init(story: PersonalizationStory, storyIndex: Int, startSlide: Int, viewer: PersonalizationStoriesViewController) {
        self.story = story
        self.storyIndex = storyIndex
        self.slideIndex = startSlide
        self.viewer = viewer
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    var currentSlide: PersonalizationStorySlide? {
        story.slides.indices.contains(slideIndex) ? story.slides[slideIndex] : nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)
        navigation.translatesAutoresizingMaskIntoConstraints = false
        navigation.closeLabel = viewer?.texts.closeLabel
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

        if slideView == nil { show(slideIndex) }
    }

    /// Шапка на 16 от краёв безопасной зоны, слайду — та же зона.
    private func applySafeInsets() {
        let side = PersonalizationSpacing.xl  // 16
        navigationTop?.constant = safeInsets.top + side
        navigationLeading?.constant = safeInsets.left + side
        navigationTrailing?.constant = -(safeInsets.right + side)
        slideView?.safeInsets = safeInsets
    }

    /// Страница ушла с экрана: слайд стоит, GIF — на первом кадре, лист товаров свёрнут.
    func deactivate() {
        slideView?.pause()
        slideView?.rewindAnimation()
        slideView?.collapseProducts()
    }

    /// Страница уходит из памяти просмотрщика: плеер и загрузка ролика отпускаются.
    func release() {
        slideView?.stop()
    }
}

extension PersonalizationStoryPageViewController {

    /// Показывает слайд: прежний останавливается и уходит, новый — на паузе, пока
    /// просмотрщик не пустит его.
    func show(_ index: Int) {
        guard story.slides.indices.contains(index) else { return }
        slideIndex = index
        guard isViewLoaded else { return }
        slideView?.stop()
        slideView?.removeFromSuperview()

        let slide = story.slides[index]
        let next = PersonalizationStorySlideView(
            slide: slide,
            texts: viewer?.texts.slideTexts ?? PersonalizationStorySlideView.Texts(),
            isMuted: PersonalizationStoryAudio.shared.isPlaybackMuted,
            imageLoader: viewer?.imageLoader
        )
        let story = self.story
        next.onButton = { [weak self] button in self?.viewer?.buttonTapped(story, slide, button) }
        next.onProduct = { [weak self] offer in self?.viewer?.productTapped(story, slide, offer) }
        next.onPromoCopied = { [weak self] code in self?.viewer?.promoCopied(story, slide, code) }
        next.onProductsToggle = { [weak self] expanded in
            guard let self else { return }
            self.viewer?.productsToggled(expanded, on: self)
        }
        next.onMuteToggle = { muted in PersonalizationStoryAudio.shared.setMuted(muted) }
        next.onSystemStop = { [weak self] in
            guard let self else { return }
            self.viewer?.playbackStoppedBySystem(on: self)
        }
        next.onVideoEnd = { [weak self] in
            guard let self else { return }
            self.viewer?.videoEnded(on: self)
        }
        next.onMediaReady = { [weak self] in
            guard let self else { return }
            self.viewer?.mediaReady(on: self)
        }
        next.onMediaFailed = { [weak self] in
            guard let self else { return }
            self.viewer?.mediaFailed(on: self)
        }
        next.onRetry = { [weak self] in
            guard let self else { return }
            self.viewer?.retryTapped(on: self)
        }
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
        // Тема слайда распространяется и на шапку: на медиа прогресс и крестик светлые.
        if #available(iOS 13.0, *) {
            content.overrideUserInterfaceStyle = slide.interfaceStyle
        }
        navigation.forcesDarkTokens = slide.isMedia
        navigation.progress.current = index
        navigation.progress.progress = 0
        slideView = next
    }

    // MARK: - Жесты

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        viewer?.handleTap(at: gesture.location(in: view).x, width: view.bounds.width, from: self)
    }

    @objc private func held(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            viewer?.handleHold(true)
        case .ended, .cancelled, .failed:
            viewer?.handleHold(false)
        default:
            break
        }
    }

    /// Касания кнопок, карточек карусели и блока с промокодом — их, а не листания. Картинка
    /// товара, заголовок и цена без промокода касаний не забирают: по ним слайд листается.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var current = touch.view
        while let candidate = current, candidate !== view {
            if candidate is UIControl || candidate is UIScrollView { return false }
            // По раскрытому листу товаров нажатие не листает и не закрывает его.
            if let used = candidate as? PersonalizationStoryUsedProducts, used.isExpanded { return false }
            if let recognizers = candidate.gestureRecognizers, !recognizers.isEmpty { return false }
            current = candidate.superview
        }
        return true
    }
}
