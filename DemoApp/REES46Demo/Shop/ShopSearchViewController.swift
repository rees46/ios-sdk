import UIKit
@_spi(PersonalizationUI) import REES46

/// Search results: the kit's `PersonalizationSearchResultsScreen` for the phrase submitted on Home.
///
/// The widget searches, pages, filters and tracks `search` on its own; the host only routes. Its
/// title carries a back arrow, so the navigation bar steps aside on this screen, and back returns
/// to Home. A tapped product opens its page, the card button adds it to the cart. The design has
/// no sort picker, so the sort button is off.
final class ShopSearchViewController: UIViewController {

    private let screen = PersonalizationSearchResultsScreen()

    init(query: String) {
        super.init(nibName: nil, bundle: nil)
        screen.shopId = AppEnvironments.shopId
        screen.query = query
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PersonalizationColor.backgroundGeneric

        screen.productActionText = Shop.actionText
        screen.showSort = false
        screen.onBack = { [weak self] in self?.navigationController?.popViewController(animated: true) }
        screen.onProductTap = { [weak self] product in self?.openShopProduct(product.id) }
        screen.onProductAction = { product in Shop.addToCart(productId: product.id, price: product.price) }

        screen.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(screen)
        NSLayoutConstraint.activate([
            screen.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            screen.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            screen.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            screen.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}
