import UIKit

// Показ попапов v3: своё окно над приложением на каждый попап. Модалка и фуллскрин — одно окно
// на процесс, общее со старыми попапами SDK: v3 не открывается поверх старого и наоборот.
// Баннер — по одному сверху и снизу, модалку не ждёт; касания вне баннера уходят в приложение,
// если у него нет затемнения и `lockBackgroundScroll`.

/// Слоты окон на весь процесс (все инстансы SDK).
final class PopupV3Slots {

    static let shared = PopupV3Slots()

    /// Открыта ли модалка v3 — читают и старые попапы со своей очереди.
    static var isModalOpen: Bool {
        lock.lock()
        defer { lock.unlock() }
        return modalOpen
    }

    private static let lock = NSLock()
    private static var modalOpen = false

    /// Открыт ли старый попап (`NotificationWidget`) какого-нибудь инстанса.
    var legacyOpen: () -> Bool = { PopupPresenter.isAnyPresenting }

    private var open = Set<Int>()
    private var modal: Int?
    private var banners: [PopupV3.Placement: Int] = [:]

    func isOpen(_ id: Int) -> Bool { open.contains(id) }

    func canOpen(_ popup: PopupV3) -> (ok: Bool, reason: String?) {
        if open.contains(popup.id) { return (false, "already open") }
        if popup.isModal {
            if modal != nil { return (false, "another modal is open") }
            if legacyOpen() { return (false, "an old popup is open") }
        } else if banners[popup.placement] != nil {
            return (false, "a banner is already at the \(popup.placement.rawValue)")
        }
        return (true, nil)
    }

    func reserve(_ popup: PopupV3) {
        open.insert(popup.id)
        if popup.isModal {
            modal = popup.id
            Self.setModal(true)
        } else {
            banners[popup.placement] = popup.id
        }
    }

    func release(_ popup: PopupV3) {
        open.remove(popup.id)
        if modal == popup.id {
            modal = nil
            Self.setModal(false)
        }
        if banners[popup.placement] == popup.id { banners[popup.placement] = nil }
        NotificationCenter.default.post(name: .personalizationPopupsV3SlotFreed, object: nil)
    }

    private static func setModal(_ value: Bool) {
        lock.lock()
        modalOpen = value
        lock.unlock()
    }
}

extension Notification.Name {
    /// Попап v3 закрылся: старые попапы и очереди v3 других инстансов могут показываться.
    static let personalizationPopupsV3SlotFreed = Notification.Name("PersonalizationPopupsV3SlotFreed")
    /// Старый попап закрылся: очередь v3 может показываться.
    static let personalizationLegacyPopupClosed = Notification.Name("PersonalizationLegacyPopupClosed")
}

/// Окна попапов одного инстанса SDK; слоты — общие.
final class PopupV3WindowPresenter: PopupsV3Presenting {

    /// Сколько ждать сцену на экране при холодном старте.
    static var sceneTimeout: TimeInterval = 10

    private weak var sdkObject: AnyObject?
    private let appHost: () -> String
    private let linkHandler: () -> ((URL) -> Bool)?
    private let productHandler: () -> ((PersonalizationProduct) -> Bool)?
    private let slots: PopupV3Slots
    private var controllers: [Int: PopupV3ViewController] = [:]

    init(
        sdk: AnyObject?,
        appHost: @escaping () -> String,
        linkHandler: @escaping () -> ((URL) -> Bool)?,
        productHandler: @escaping () -> ((PersonalizationProduct) -> Bool)? = { nil },
        slots: PopupV3Slots = .shared
    ) {
        self.sdkObject = sdk
        self.appHost = appHost
        self.linkHandler = linkHandler
        self.productHandler = productHandler
        self.slots = slots
    }

    func isOpen(_ id: Int) -> Bool { slots.isOpen(id) }

    func canOpen(_ popup: PopupV3) -> (ok: Bool, reason: String?) { slots.canOpen(popup) }

    func present(_ presentation: PopupV3Presentation, completion: @escaping (Bool) -> Void) {
        let popup = presentation.popup
        slots.reserve(popup)
        PersonalizationStories.awaitPresenter(nil, until: Date().addingTimeInterval(Self.sceneTimeout)) { [weak self] host in
            guard let self, let host else {
                self?.slots.release(popup)
                return completion(false)
            }
            let actions = PopupV3SDKActions(
                sdk: self.sdkObject as? PersonalizationSDK, appHost: self.appHost(), linkHandler: self.linkHandler(),
                productHandler: self.productHandler(), onEvent: presentation.onEvent
            )
            let controller = PopupV3ViewController(presentation: presentation, actions: actions, hostStatusBar: host.personalizationTopmost)
            controller.onClosed = { [weak self] in
                self?.controllers[popup.id] = nil
                self?.slots.release(popup)
                presentation.onClose()
            }
            self.controllers[popup.id] = controller
            controller.show(over: host.view.window)
            completion(true)
        }
    }
}

/// Окно попапа над приложением. Касания мимо рамки баннера без затемнения проходят в приложение.
final class PopupV3Window: UIWindow {

    var passesTouchesThrough = false

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        if passesTouchesThrough, hit === rootViewController?.view { return nil }
        return hit
    }
}

/// Действия элементов через SDK: подписка, профиль, сегмент, отзыв, ссылки и буфер обмена.
final class PopupV3SDKActions: PopupV3Actions {

    weak var controller: PopupV3ViewController?
    private weak var sdkObject: AnyObject?
    private let appHost: String
    private let linkHandler: ((URL) -> Bool)?
    private let productHandler: ((PersonalizationProduct) -> Bool)?
    private let onEvent: (String, String?) -> Void

    init(
        sdk: PersonalizationSDK?,
        appHost: String,
        linkHandler: ((URL) -> Bool)?,
        productHandler: ((PersonalizationProduct) -> Bool)? = nil,
        onEvent: @escaping (String, String?) -> Void
    ) {
        self.sdkObject = sdk as AnyObject?
        self.appHost = appHost
        self.linkHandler = linkHandler
        self.productHandler = productHandler
        self.onEvent = onEvent
    }

    var sdk: PersonalizationSDK? { sdkObject as? PersonalizationSDK }

    static func url(_ link: String) -> URL? {
        URL(string: link) ?? link.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed).flatMap(URL.init(string:))
    }

    func open(_ link: String) {
        guard let url = Self.url(link) else {
            PopupsV3Log.log("bad link \(link)")
            return
        }
        if linkHandler?(url) == true { return }
        UIApplication.shared.open(url)
    }

    /// Товар ленты: хост открыл его сам — попап закрывается без `close`, как после перехода; иначе
    /// ссылка товара (`deeplink`, потом `url`) обычным путём, попап остаётся.
    func product(_ product: PersonalizationProduct) {
        if productHandler?(product) == true {
            controller?.close(sendingEvent: false)
            return
        }
        if let link = PopupV3Links.usable(product.deeplink) ?? PopupV3Links.usable(product.url) {
            open(link)
        }
    }

    func copy(_ text: String, toast: String?) {
        UIPasteboard.general.string = text
        if let toast { PersonalizationToast.show(toast, in: controller?.view) }
    }

    func event(_ name: String, channel: String?) {
        onEvent(name, channel)
    }

    func close() {
        controller?.close(sendingEvent: true)
    }

    func relayout() {
        controller?.relayout()
    }

    func reveal(_ view: UIView) {
        controller?.reveal(view)
    }

    func subscribe(email: String, consents: [String], completion: @escaping (Bool) -> Void) {
        guard let sdk else { return completion(false) }
        func flag(_ name: String) -> Bool? { consents.contains(name) ? true : nil }
        sdk.manageSubscription(
            email: email, phone: nil, userExternalId: nil, userLoyaltyId: nil, telegramId: nil,
            emailBulk: flag("email_bulk"), emailChain: flag("email_chain"), emailTransactional: flag("email_transactional"),
            smsBulk: nil, smsChain: nil, smsTransactional: nil, webPushBulk: nil, webPushChain: nil, webPushTransactional: nil,
            mobilePushBulk: nil, mobilePushChain: nil, mobilePushTransactional: nil, telegramBulk: nil, telegramChain: nil,
            telegramTransactional: nil, whatsappBulk: nil, whatsappChain: nil, whatsappTransactional: nil, maxBulk: nil,
            maxChain: nil, maxTransactional: nil, walletBulk: nil
        ) { result in
            Self.finish(result, "subscription", completion)
        }
    }

    func saveProfile(_ profile: PopupV3Profile, completion: @escaping (Bool) -> Void) {
        guard let sdk else { return completion(false) }
        var custom: [String: Any?] = profile.custom.mapValues { $0 }
        if let birthday = profile.birthday { custom["birthday"] = birthday }
        if let gender = profile.gender { custom["gender"] = gender }
        sdk.setProfileData(
            userEmail: profile.email, userPhone: profile.phone, firstName: profile.firstName, lastName: profile.lastName,
            customProperties: custom.isEmpty ? nil : custom
        ) { result in
            Self.finish(result, "profile", completion)
        }
    }

    func addToSegment(_ id: String, completion: @escaping (Bool) -> Void) {
        guard let sdk else { return completion(false) }
        sdk.addToSegment(segmentId: id, email: nil, phone: nil) { result in
            Self.finish(result, "segment \(id)", completion)
        }
    }

    func review(kind: PersonalizationStoryPoll.Scale, body: [String: Any], completion: @escaping (Bool) -> Void) {
        guard let sdk else { return completion(false) }
        StoriesPollsApi(api: StoriesApiV3(domain: appHost), sdk: sdk).review(kind: kind, body: body) { result in
            if case .failure(let error) = result { PopupsV3Log.log("\(kind.rawValue) review failed: \(error)") }
            completion((try? result.get()) != nil)
        }
    }

    private static func finish(_ result: Result<Void, SdkError>, _ what: String, _ completion: @escaping (Bool) -> Void) {
        if case .failure(let error) = result { PopupsV3Log.log("\(what) failed: \(error)") }
        let ok = (try? result.get()) != nil
        MainThread.run { completion(ok) }
    }
}

/// Корень окна попапа: затемнение, рамка, анимации, клавиатура, закрытие.
final class PopupV3ViewController: UIViewController, UIGestureRecognizerDelegate {

    let presentation: PopupV3Presentation
    let actions: PopupV3SDKActions
    let frameView: PopupV3FrameView
    let overlay = UIView()
    var onClosed: (() -> Void)?
    private(set) var window: PopupV3Window?
    private weak var hostStatusBar: UIViewController?
    private var anchor: NSLayoutConstraint!
    private var centerX: NSLayoutConstraint!
    private var keyboard: CGFloat = 0
    private(set) var isClosing = false
    private weak var previousKeyWindow: UIWindow?
    private var pan: UIPanGestureRecognizer?

    private var popup: PopupV3 { presentation.popup }
    private var style: PopupV3FrameStyle { presentation.design.frame }

    /// Затемнение: у модалки — по умолчанию да, у баннера — нет; фуллскрин его не видит.
    var hasOverlay: Bool {
        switch popup.layout {
        case .fullscreen: return false
        case .modal: return style.overlayEnabled ?? true
        case .banner: return style.overlayEnabled ?? false
        }
    }

    /// Касания вне рамки заблокированы: модалка и фуллскрин всегда, баннер — с затемнением или `lockBackgroundScroll`.
    var blocksOutside: Bool {
        popup.layout != .banner || hasOverlay || style.lockBackgroundScroll
    }

    init(presentation: PopupV3Presentation, actions: PopupV3SDKActions, hostStatusBar: UIViewController?, screenSize: CGSize = UIScreen.main.bounds.size) {
        self.presentation = presentation
        self.actions = actions
        self.hostStatusBar = hostStatusBar
        let context = PopupV3RenderContext(
            runtime: presentation.runtime, texts: .current, screenSize: screenSize,
            background: presentation.design.frame.background, actions: actions
        )
        frameView = PopupV3FrameView(design: presentation.design, context: context)
        super.init(nibName: nil, bundle: nil)
        actions.controller = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        hostStatusBar?.preferredStatusBarStyle ?? .default
    }

    override var prefersStatusBarHidden: Bool {
        hostStatusBar?.prefersStatusBarHidden ?? false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = popup.layout == .fullscreen ? style.background.uiColor : .clear
        view.accessibilityViewIsModal = blocksOutside
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = hasOverlay ? style.overlayColor.with(opacity: style.overlayOpacity).uiColor : .clear
        overlay.isHidden = !blocksOutside
        view.addSubview(overlay)
        frameView.translatesAutoresizingMaskIntoConstraints = false
        frameView.accessibilityIdentifier = "popupV3.\(popup.id)"
        view.addSubview(frameView)
        switch popup.layout {
        case .modal:
            anchor = frameView.centerYAnchor.constraint(equalTo: view.topAnchor)
        case .banner where popup.placement == .bottom:
            anchor = frameView.bottomAnchor.constraint(equalTo: view.topAnchor)
        case .banner, .fullscreen:
            anchor = frameView.topAnchor.constraint(equalTo: view.topAnchor)
        }
        centerX = frameView.centerXAnchor.constraint(equalTo: view.leadingAnchor)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            anchor, centerX
        ])
        let outside = UITapGestureRecognizer(target: self, action: #selector(tappedOutside))
        overlay.addGestureRecognizer(outside)
        // Касание по рамке убирает клавиатуру, но не мешает элементам.
        let tap = UITapGestureRecognizer(target: self, action: #selector(tappedFrame))
        tap.cancelsTouchesInView = false
        frameView.addGestureRecognizer(tap)
        if popup.layout == .banner {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
            pan.delegate = self
            frameView.addGestureRecognizer(pan)
            self.pan = pan
        }
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChanged(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(editingEnded(_:)), name: UITextField.textDidEndEditingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(editingEnded(_:)), name: UITextView.textDidEndEditingNotification, object: nil)
    }

    /// Ввод в поле попапа закончился: ключевым снова становится окно приложения (если фокус не
    /// перешёл в соседнее поле попапа).
    @objc private func editingEnded(_ note: Notification) {
        guard let field = note.object as? UIView, let window, field.window === window else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window, window.isKeyWindow,
                  Self.firstResponder(in: self.frameView) == nil else { return }
            self.previousKeyWindow?.makeKey()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        applyGeometry()
    }

    /// Размеры под нынешний экран, безопасные зоны и клавиатуру.
    var geometry: PopupV3Geometry {
        PopupV3Geometry(layout: popup.layout, placement: popup.placement, style: style, bounds: view.bounds.size, safe: safeInsets, keyboard: keyboard)
    }

    private var safeInsets: UIEdgeInsets { view.safeAreaInsets }

    private func applyGeometry() {
        let geometry = self.geometry
        frameView.apply(geometry)
        anchor.constant = geometry.anchorY
        centerX.constant = geometry.centerX
    }

    /// Содержимое поменяло высоту.
    func relayout() {
        guard isViewLoaded else { return }
        UIView.animate(withDuration: 0.2) {
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }

    /// Вью внутри прокрутки рамки — в видимую часть.
    func reveal(_ target: UIView) {
        guard isViewLoaded, target.isDescendant(of: frameView.scrollView) else { return }
        view.layoutIfNeeded()
        let scroll = frameView.scrollView
        scroll.scrollRectToVisible(target.convert(target.bounds, to: scroll).insetBy(dx: 0, dy: -8), animated: true)
    }

    // MARK: - Показ и закрытие

    func show(over host: UIWindow?) {
        let window: PopupV3Window
        if #available(iOS 13.0, *), let scene = host?.windowScene {
            window = PopupV3Window(windowScene: scene)
        } else {
            window = PopupV3Window(frame: host?.bounds ?? UIScreen.main.bounds)
        }
        window.frame = host?.bounds ?? UIScreen.main.bounds
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + (popup.isModal ? 2 : 1))
        window.backgroundColor = .clear
        window.passesTouchesThrough = !blocksOutside
        window.rootViewController = self
        self.window = window
        previousKeyWindow = host
        // Окно попапа не забирает статус ключевого: хост и дальше находит своё окно через
        // `keyWindow`. Ключевым оно становится только на время ввода в своё поле.
        window.isHidden = false
        view.layoutIfNeeded()
        animateIn()
    }

    private func animateIn() {
        let overlayView = overlay
        overlayView.alpha = 0
        switch popup.layout {
        case .banner:
            let height = frameView.bounds.height + max(0, geometry.anchorY) + 40
            frameView.transform = CGAffineTransform(translationX: 0, y: popup.placement == .bottom ? height : -height)
        case .modal, .fullscreen:
            frameView.alpha = 0
            frameView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut]) {
            overlayView.alpha = 1
            self.frameView.alpha = 1
            self.frameView.transform = .identity
        }
    }

    /// Закрыть: событие `close` (крестик, кнопка, затемнение, свайп), анимация, освобождение слота.
    func close(sendingEvent: Bool) {
        guard !isClosing else { return }
        isClosing = true
        if sendingEvent { actions.event("close", channel: nil) }
        view.endEditing(true)
        let offset = frameView.bounds.height + max(0, geometry.anchorY) + 40
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn], animations: {
            self.overlay.alpha = 0
            switch self.popup.layout {
            case .banner:
                self.frameView.transform = CGAffineTransform(translationX: 0, y: self.popup.placement == .bottom ? offset : -offset)
            case .modal, .fullscreen:
                self.frameView.alpha = 0
                self.frameView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }
        }, completion: { _ in
            self.finishClose()
        })
    }

    private func finishClose() {
        let wasKey = window?.isKeyWindow == true
        window?.isHidden = true
        if wasKey { previousKeyWindow?.makeKey() }
        window?.rootViewController = nil
        window = nil
        onClosed?()
        onClosed = nil
    }

    /// Касание мимо рамки: сначала убирает клавиатуру, если она есть, а без неё закрывает попап —
    /// только по затемнению. Без затемнения касание поглощается.
    @objc func tappedOutside() {
        if let responder = Self.firstResponder(in: frameView) {
            responder.resignFirstResponder()
            return
        }
        guard hasOverlay else { return }
        close(sendingEvent: true)
    }

    @objc private func tappedFrame() {
        view.endEditing(true)
    }

    // MARK: - Свайп баннера к краю

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === pan, let pan else { return true }
        // Прокрутка содержимого не закрывает попап.
        if frameView.isScrollable { return false }
        let velocity = pan.velocity(in: view)
        return abs(velocity.y) > abs(velocity.x)
    }

    @objc private func panned(_ pan: UIPanGestureRecognizer) {
        let towardsEdge: CGFloat = popup.placement == .bottom ? 1 : -1
        let shift = pan.translation(in: view).y * towardsEdge
        switch pan.state {
        case .changed:
            let distance = shift > 0 ? shift : shift / 4
            frameView.transform = CGAffineTransform(translationX: 0, y: distance * towardsEdge)
        case .ended, .cancelled:
            let speed = pan.velocity(in: view).y * towardsEdge
            if pan.state == .ended && (shift > frameView.bounds.height / 3 || speed > 600) {
                close(sendingEvent: true)
            } else {
                UIView.animate(withDuration: 0.2) { self.frameView.transform = .identity }
            }
        default:
            break
        }
    }

    // MARK: - Клавиатура

    @objc private func keyboardChanged(_ note: Notification) {
        guard let window, isViewLoaded else { return }
        let end = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
        let overlap = note.name == UIResponder.keyboardWillHideNotification ? 0 : max(0, window.bounds.maxY - window.convert(end, from: nil).minY)
        guard overlap != keyboard else { return }
        keyboard = overlap
        let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        UIView.animate(withDuration: duration, animations: {
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.revealFirstResponder()
        })
    }

    /// Поле с клавиатурой — в видимую часть прокрутки.
    private func revealFirstResponder() {
        guard let responder = Self.firstResponder(in: frameView.grid) else { return }
        let scroll = frameView.scrollView
        let rect = responder.convert(responder.bounds, to: scroll).insetBy(dx: 0, dy: -12)
        scroll.scrollRectToVisible(rect, animated: true)
    }

    private static func firstResponder(in view: UIView) -> UIView? {
        if view.isFirstResponder { return view }
        for subview in view.subviews {
            if let found = firstResponder(in: subview) { return found }
        }
        return nil
    }
}
