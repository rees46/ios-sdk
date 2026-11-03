import UIKit
@_spi(PersonalizationUI) import REES46

/// Category: the kit's `PersonalizationCategoryScreen` under the shop's instant search.
///
/// The widget loads the category page by page, filters, sorts, tracks `categoryView` once and shows
/// the empty state and the error with "Retry" on its own; the host only routes. Its title is the
/// category name with a back arrow, so the navigation bar steps aside on this screen and back
/// returns along the shop's stack. A tapped product opens its page, the card button adds it to the
/// cart, the sort button opens the shop's sort picker. Facet titles and values of the demo feed are
/// named in `ShopFacets`.
///
/// The search on top behaves as on Home: while its panel is open it takes the screen and the
/// category steps aside.
final class ShopCategoryViewController: UIViewController {

    private let screen: PersonalizationCategoryScreen
    private let searchBar = ShopSearchBar()
    private let searchScroll = UIScrollView()
    /// Browsing: the search area is as tall as the input.
    private lazy var searchCollapsed = searchScroll.frameLayoutGuide.heightAnchor
        .constraint(equalTo: searchScroll.contentLayoutGuide.heightAnchor)
    /// Searching: the search area takes the whole screen and scrolls its panel.
    private lazy var searchExpanded = searchScroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)

    init(categoryId: String, name: String) {
        let screen = PersonalizationCategoryScreen(categoryId: categoryId, shopId: AppEnvironments.shopId)
        screen.titleText = name
        self.screen = screen
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PersonalizationColor.backgroundGeneric

        screen.productActionText = Shop.actionText
        screen.onBack = { [weak self] in self?.navigationController?.popViewController(animated: true) }
        screen.onProductTap = { [weak self] product in self?.openShopProduct(product.id ?? "") }
        screen.onProductAction = { product in
            guard let id = product.id, !id.isEmpty else { return }
            Shop.addToCart(productId: id, price: product.price)
        }
        ShopSort.attach(to: screen, host: self)
        ShopFacets.attach(to: screen)

        searchBar.host = self
        searchBar.onSearchingChanged = { [weak self] searching in self?.setSearching(searching) }
        setupLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DemoScreen.opened(DemoScreen.category)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func setSearching(_ searching: Bool) {
        // Deactivate first: the two disagree on the height of the search area.
        NSLayoutConstraint.deactivate([searching ? searchCollapsed : searchExpanded])
        NSLayoutConstraint.activate([searching ? searchExpanded : searchCollapsed])
        screen.isHidden = searching
        searchScroll.setContentOffset(CGPoint(x: 0, y: -searchScroll.adjustedContentInset.top), animated: false)
    }

    private func setupLayout() {
        searchScroll.keyboardDismissMode = .onDrag
        searchScroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchScroll)
        let row = searchBar.shopInset()
        row.translatesAutoresizingMaskIntoConstraints = false
        searchScroll.addSubview(row)

        screen.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(screen)
        NSLayoutConstraint.activate([
            searchScroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchCollapsed,
            row.topAnchor.constraint(equalTo: searchScroll.contentLayoutGuide.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: searchScroll.contentLayoutGuide.bottomAnchor),
            row.leadingAnchor.constraint(equalTo: searchScroll.contentLayoutGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: searchScroll.contentLayoutGuide.trailingAnchor),
            row.widthAnchor.constraint(equalTo: searchScroll.frameLayoutGuide.widthAnchor),
            screen.topAnchor.constraint(equalTo: searchScroll.bottomAnchor),
            screen.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            screen.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            screen.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}
