import UIKit
@_spi(PersonalizationUI) import REES46

/// The "Shop" tab — a small store built from the kit's widgets and the SDK's public methods, the
/// way a host app would wire them: Home (instant search, stories, a recommender block, categories),
/// a category, a product page and search results, on one navigation stack without a bar.
///
/// There is no cart screen: "Add to cart" sends the `cart` event and shows a toast. Navigation is
/// the host's — the widgets only hand products and categories over.
enum Shop {

    /// The demo shop's recommender block that has products: "Популярные" on Home and on a product.
    static let blockCode = "e6249bb15043644bf25b135006149962"
    /// Product page blocks driven by the product (`item`): "Похожие" and "С этим товаром также покупают".
    static let similarBlockCode = "007b87897f244b2a2a123567b3242a4b"
    static let alsoBoughtBlockCode = "fa6e8cd83434273dd8d47293329e00dd"
    /// The stories block on Home (API v3): one campaign with a poll of every kind on its slides.
    static let storiesCode = "272dd914ea13824a0abb6ef4e776ddaa"

    static let actionText = "Add to cart"
    static let errorText = "Something went wrong. Check your connection and try again."
    static let retryText = "Retry"

    /// The SDK instance of the demo shop, on the main thread, as soon as it is registered — the
    /// same resolution the kit's widgets do by `shopId`. A screen cancels the result when it goes
    /// away; a one-off call may drop it.
    @discardableResult
    static func withSDK(_ body: @escaping (PersonalizationSDK) -> Void) -> Cancellable {
        Rees46.awaitInstance(for: AppEnvironments.shopId) { sdk in
            if Thread.isMainThread {
                body(sdk)
            } else {
                DispatchQueue.main.async { body(sdk) }
            }
        }
    }

    /// "Add to cart": the `cart` event and a toast. The recommender block has already remembered
    /// itself as the source of the event (`dynamic` with its code) before it hands the product over.
    static func addToCart(productId: String, price: Double? = nil) {
        withSDK { sdk in
            sdk.tracking.addToCart(item: TrackingItem(id: productId, price: price))
        }
        PersonalizationToast.show("Added to cart")
    }
}

// MARK: - Popups v3 screens

/// Screen names the demo reports to popups v3 (`sdk.popups.screenOpened`): a marketer puts them
/// into a popup's `target_screens`.
enum DemoScreen {
    static let home = "home"
    static let category = "category"
    static let product = "product"
    static let search = "search"
    /// Tabs of the full demo.
    static let api = "api"
    static let uiKit = "ui_kit"
    static let legacyStories = "legacy_stories"

    static func opened(_ name: String) {
        Shop.withSDK { sdk in sdk.popups.screenOpened(name) }
    }
}

/// Popups v3 the header of Home shows by hand from its menu: `sdk.popups.show(id:)` — no trigger,
/// no screens, no frequency, so a popup already shown in this session shows again. A new popup is
/// one line here.
enum DemoPopups {
    static let manual: [(id: Int, title: String)] = [
        (181, "#181 Banner · top"),
        (182, "#182 Modal · center"),
        (185, "#185 Fullscreen")
    ]

    static func show(_ id: Int) {
        Shop.withSDK { sdk in sdk.popups.show(id: id) }
    }
}

extension Shop {

    /// A product tapped in a popup's recommender feed (`sdk.popups.productHandler`): its page goes
    /// onto the shop's stack — in the full demo the "Shop" tab comes forward first, a demo screen
    /// over the tabs goes. `false` — there is no shop stack, and the SDK opens the product's link.
    static func openProduct(_ id: String, from root: UIViewController?) -> Bool {
        guard !id.isEmpty, let root else { return false }
        let stack: UINavigationController?
        if let tabs = root as? UITabBarController {
            stack = tabs.viewControllers?
                .compactMap { $0 as? UINavigationController }
                .first { $0.viewControllers.first is ShopHomeViewController }
            if let stack { tabs.selectedViewController = stack }
        } else {
            stack = (root as? UINavigationController).flatMap { $0.viewControllers.first is ShopHomeViewController ? $0 : nil }
        }
        guard let stack else { return false }
        if root.presentedViewController != nil { root.dismiss(animated: false) }
        stack.pushViewController(ShopProductViewController(productId: id), animated: true)
        return true
    }
}

// MARK: - Navigation

/// The shop's navigation stack. Every screen of the shop draws its own top — Home its title with a
/// search button, a category and search results the kit's header with a back arrow, a product a
/// round back button over the photo — so the bar stays hidden on all of them.
///
/// A hidden bar turns the swipes back off: UIKit's own delegate of the swipes refuses them without
/// a bar. The stack becomes their delegate and lets them begin on every screen above the root — the
/// swipe from the edge and, from iOS 26, the one across the content. How a swipe shares the touch
/// with a carousel stays with the swipe itself.
final class ShopNavigationController: UINavigationController, UIGestureRecognizerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        setNavigationBarHidden(true, animated: false)
        interactivePopGestureRecognizer?.delegate = self
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            interactiveContentPopGestureRecognizer?.delegate = self
        }
        #endif
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Nothing to go back to on Home; a swipe in the middle of a push would break the stack.
        viewControllers.count > 1 && transitionCoordinator == nil
    }
}

/// Every screen of the shop goes onto the shop's navigation stack.
extension UIViewController {

    func openShopProduct(_ id: String) {
        guard !id.isEmpty else { return }
        navigationController?.pushViewController(ShopProductViewController(productId: id), animated: true)
    }

    func openShopCategory(id: String, name: String) {
        navigationController?.pushViewController(ShopCategoryViewController(categoryId: id, name: name), animated: true)
    }

    func openShopSearch(_ query: String) {
        navigationController?.pushViewController(ShopSearchViewController(query: query), animated: true)
    }
}

// MARK: - Layout

extension UIViewController {

    /// A strip of `color` over the status bar: content scrolled up goes under it rather than under
    /// the clock — the shop has no navigation bar to cover it. Added on top of what is already there.
    func shopCoverStatusBar(with color: UIColor) {
        let strip = UIView()
        strip.backgroundColor = color
        strip.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(strip)
        NSLayoutConstraint.activate([
            strip.topAnchor.constraint(equalTo: view.topAnchor),
            strip.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            strip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}

extension UIView {

    /// The view inside a plain container with side margins — for rows of a full-width stack.
    func shopInset(horizontal: CGFloat = PersonalizationSpacing.paddingX) -> UIView {
        let container = UIView()
        translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: container.topAnchor),
            bottomAnchor.constraint(equalTo: container.bottomAnchor),
            leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: horizontal),
            trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -horizontal)
        ])
        return container
    }

    /// A full-screen kit widget (a category, search results) under the status bar: its own header
    /// starts 8 below the safe area, the rest of the screen is the widget's.
    func shopPinScreen(to parent: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parent.safeAreaLayoutGuide.topAnchor, constant: PersonalizationSpacing.md),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor)
        ])
    }

    /// Pins the view to the edges of `parent`.
    func shopPin(to parent: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parent.topAnchor),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor)
        ])
    }
}

/// A round 44 button with a kit icon: back over the product's card, the popups menu and search in
/// the header of Home.
final class ShopRoundButton: UIControl {

    private let icon = UIImageView()

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }

    /// Items of a menu the button opens on tap, at the button, instead of sending its action — from
    /// iOS 14. iOS 13 has no menus on controls: there the button sends its action as usual and the
    /// host shows the items itself.
    var menuItems: [(title: String, action: () -> Void)] = [] {
        didSet {
            guard #available(iOS 14.0, *) else { return }
            isContextMenuInteractionEnabled = !menuItems.isEmpty
            showsMenuAsPrimaryAction = !menuItems.isEmpty
        }
    }

    init(icon image: UIImage?, background: UIColor, label: String) {
        super.init(frame: .zero)
        backgroundColor = background
        layer.cornerRadius = min(PersonalizationRadius.rounded, Self.side / 2)

        icon.image = image
        icon.tintColor = PersonalizationColor.textPrimary
        icon.contentMode = .scaleAspectFit
        icon.isUserInteractionEnabled = false
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.side),
            heightAnchor.constraint(equalToConstant: Self.side),
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: Self.iconSide),
            icon.heightAnchor.constraint(equalToConstant: Self.iconSide)
        ])

        isAccessibilityElement = true
        accessibilityLabel = label
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @available(iOS 14.0, *)
    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard !menuItems.isEmpty else { return nil }
        let items = menuItems
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            UIMenu(children: items.map { item in UIAction(title: item.title) { _ in item.action() } })
        }
    }

    /// Back over the product's card: on the page background, the kit's chevron pointing back (the
    /// kit has it pointing right only, so it is mirrored).
    static func back() -> ShopRoundButton {
        ShopRoundButton(
            icon: PersonalizationIcons.angleLargeRight?.withHorizontallyFlippedOrientation(),
            background: PersonalizationColor.backgroundGeneric,
            label: "Back"
        )
    }

    /// The popups menu in the header of Home: on the card surface, the kit's rosette.
    static func popups() -> ShopRoundButton {
        ShopRoundButton(icon: PersonalizationIcons.rosette, background: PersonalizationColor.backgroundCard, label: "Show popup")
    }

    /// Search in the header of Home: on the card surface, the kit's magnifier.
    static func search() -> ShopRoundButton {
        ShopRoundButton(icon: PersonalizationIcons.magnifier, background: PersonalizationColor.backgroundCard, label: "Search")
    }

    private static let side: CGFloat = 44
    private static let iconSide: CGFloat = 24
}
