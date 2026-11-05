import UIKit
import WebKit
@_spi(PersonalizationUI) import REES46

/// The mini-game a game link opens (`rees46://game`, see `DemoLinks`) — from outside the app, or
/// from a popup's or a slide's button, whose hooks give the link to the demo instead of the system.
/// For the SDK it is a link like any other; the game is what an app may hang on one. The game is a
/// web page — the built-in tic-tac-toe or an app's page from the link's `url`.
///
/// The screen gets a window of its own above the app's — and above the windows popups v3 show in:
/// a popup whose game link the demo opened closes under the game as it slides in. The window is the
/// key one while the game is open — VoiceOver reads the game rather than the screen under it — and
/// gives the key status back to the app's window on close. Closing the game hides its window, and
/// the screen it came from is there again. A game link while the game is open loads its page there.
enum DemoGame {

    private static var window: UIWindow?

    /// Opens the game for a game link. `false` — not one: the caller routes the link as before.
    @discardableResult
    static func open(_ url: URL) -> Bool {
        open(DemoLinks.kind(of: url))
    }

    /// The same for a link as text, the way the stories callbacks hand it over.
    @discardableResult
    static func open(_ link: String) -> Bool {
        open(DemoLinks.kind(of: link))
    }

    private static func open(_ kind: DemoLinks.Kind) -> Bool {
        guard case .game(let page) = kind else { return false }
        if Thread.isMainThread {
            show(page)
        } else {
            DispatchQueue.main.async { show(page) }
        }
        return true
    }

    private static func show(_ page: URL?) {
        if let game = window?.rootViewController as? DemoGameViewController {
            game.load(page)
            return
        }
        let app = UIApplication.shared.delegate?.window ?? nil
        let window: UIWindow
        if let scene = app?.windowScene {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        window.frame = app?.bounds ?? UIScreen.main.bounds
        // Above the windows of popups v3: a banner's is normal + 1, a modal's normal + 2.
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 3)
        // The theme switch of the UI Kit tab sets the app's window; the game follows it.
        window.overrideUserInterfaceStyle = app?.overrideUserInterfaceStyle ?? .unspecified
        let game = DemoGameViewController(page: page)
        game.onClose = { hide() }
        window.rootViewController = game
        self.window = window
        window.makeKeyAndVisible()
        game.slideIn()
    }

    private static func hide() {
        guard let window, let game = window.rootViewController as? DemoGameViewController else { return }
        // A game link while the screen slides away opens a new one.
        self.window = nil
        game.slideOut {
            window.isHidden = true
            window.rootViewController = nil
            if self.window == nil { (UIApplication.shared.delegate?.window ?? nil)?.makeKey() }
        }
    }
}

// MARK: - Screen

/// The game screen: a panel with the title and the close cross (the kit's title row), the page
/// under it. The page has its own "Ещё раз"; the screen and the page talk no further. The panel and
/// the web view stand on the kit's background, so nothing flashes white while the page loads, and
/// the page gets the app's theme: in the address of the built-in page and, when the theme changes,
/// through the page's `setGameTheme`.
final class DemoGameViewController: UIViewController {

    /// The close cross: the presenter takes the game away.
    var onClose: (() -> Void)?

    static let builtInTitle = "Крестики-нолики"

    private var page: URL?
    private let titleRow = PersonalizationTitle()
    private let closeButton = PersonalizationButton(size: .md, view: .secondary, iconStart: PersonalizationIcons.crossLarge)
    private let webView: WKWebView
    private var titleObservation: NSKeyValueObservation?

    init(page: URL?) {
        self.page = page
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PersonalizationColor.backgroundGeneric
        view.accessibilityViewIsModal = true

        closeButton.rounded = true
        // An icon without text: the kit's control is not an element of its own.
        closeButton.isAccessibilityElement = true
        closeButton.accessibilityTraits = .button
        closeButton.accessibilityLabel = "Закрыть"
        closeButton.accessibilityIdentifier = "game-close"
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        titleRow.trailing = closeButton

        webView.isOpaque = false
        webView.backgroundColor = PersonalizationColor.backgroundGeneric
        webView.scrollView.backgroundColor = PersonalizationColor.backgroundGeneric
        webView.navigationDelegate = self
        webView.accessibilityIdentifier = "game-page"
        // An app's page names itself; the built-in one has the panel's title.
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] _, _ in self?.updateTitle() }

        setupLayout()
        load(page)
    }

    private func setupLayout() {
        let margin = PersonalizationSpacing.paddingX  // 16
        for subview in [titleRow, webView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            titleRow.topAnchor.constraint(equalTo: safe.topAnchor, constant: PersonalizationSpacing.md),
            titleRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            titleRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),

            webView.topAnchor.constraint(equalTo: titleRow.bottomAnchor, constant: PersonalizationSpacing.md),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // To the bottom edge: the page keeps clear of the home indicator itself
            // (`viewport-fit=cover`, `env(safe-area-inset-bottom)`).
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    /// Loads the game: an app's `https` page, or the built-in one (`nil`).
    func load(_ page: URL?) {
        self.page = page
        updateTitle()
        guard let builtIn = Bundle.main.url(
            forResource: DemoGamePage.resource, withExtension: DemoGamePage.resourceExtension
        ) else {
            NSLog("REES46Demo: the game page is missing from the app")
            return
        }
        let address = DemoGamePage.address(page: page, builtIn: builtIn, dark: isDark)
        if address.isFileURL {
            webView.loadFileURL(address, allowingReadAccessTo: builtIn.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: address))
        }
    }

    private var isDark: Bool {
        traitCollection.userInterfaceStyle == .dark
    }

    private func updateTitle() {
        guard let page else {
            titleRow.text = Self.builtInTitle
            return
        }
        let title = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        titleRow.text = title.isEmpty ? page.host : title
    }

    /// The theme of the app to the page, if the page takes it.
    private func applyTheme() {
        let theme = isDark ? "dark" : "light"
        webView.evaluateJavaScript("window.setGameTheme && window.setGameTheme('\(theme)')", completionHandler: nil)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle { applyTheme() }
    }

    @objc private func closeTapped() {
        onClose?()
    }

    // MARK: Showing

    /// Up from the bottom edge, the way a full-screen modal comes.
    func slideIn() {
        view.transform = CGAffineTransform(translationX: 0, y: UIScreen.main.bounds.height)
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
            self.view.transform = .identity
        }
    }

    /// Down to the bottom edge. A picture of the screen slides, not the view: a view on its way down
    /// loses its safe area at once, and the panel would jump up under the status bar.
    func slideOut(completion: @escaping () -> Void) {
        let moving: UIView
        if let picture = view.snapshotView(afterScreenUpdates: false) {
            view.subviews.forEach { $0.isHidden = true }
            view.backgroundColor = .clear
            view.addSubview(picture)
            moving = picture
        } else {
            moving = view
        }
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseIn], animations: {
            moving.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
        }, completion: { _ in completion() })
    }
}

extension DemoGameViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // The theme may have changed while the page was loading.
        applyTheme()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NSLog("REES46Demo: the game page failed to load: %@", "\(error)")
    }
}
