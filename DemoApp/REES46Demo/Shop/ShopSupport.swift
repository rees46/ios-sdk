import UIKit
@_spi(PersonalizationUI) import REES46

/// The "Shop" tab — a small store built from the kit's widgets and the SDK's public methods, the
/// way a host app would wire them: Home (instant search, stories, a recommender block, categories),
/// a category, a product page and search results, on one navigation stack.
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

/// Every screen of the shop goes onto the tab's navigation stack.
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

extension UIView {

    /// The view inside a plain container with side margins — for rows of a full-width stack.
    func shopInset(horizontal: CGFloat = 16) -> UIView {
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
