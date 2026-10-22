import UIKit
@_spi(PersonalizationUI) import REES46

/// The "Shop" tab — a small store built from the kit's widgets and the SDK's public methods, the
/// way a host app would wire them: Home (instant search, stories, a recommender block, categories),
/// a category, a product page and search results, on one navigation stack.
///
/// There is no cart screen: "Add to cart" sends the `cart` event and shows a toast. Navigation is
/// the host's — the widgets only hand products and categories over.
enum Shop {

    /// The demo shop's recommender block: the carousel on Home and "Similar products" on a product.
    static let blockCode = "e6249bb15043644bf25b135006149962"

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

    /// Product id from a link of the demo shop: its product pages end with the id —
    /// `…/p/utyug-vitek-vt-1201-1276` is product 1276. Story callbacks carry links, not ids,
    /// so this is how the shop routes a product tapped in a story; a real app maps its own links.
    static func productId(fromLink link: String) -> String? {
        guard let url = URL(string: link), url.path.contains("/p/") else { return nil }
        guard let tail = url.lastPathComponent.split(separator: "-").last,
              !tail.isEmpty, tail.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return String(tail)
    }
}

// MARK: - Navigation

/// Every screen of the shop goes onto the tab's navigation stack.
extension UIViewController {

    func openShopProduct(_ id: String) {
        guard !id.isEmpty else { return }
        navigationController?.pushViewController(ShopProductViewController(productId: id), animated: true)
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
