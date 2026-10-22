import UIKit
@_spi(PersonalizationUI) import REES46

/// Shop home: the instant search field on top, the stories bar, the recommender carousel and the
/// top-level categories.
///
/// The field renders its whole panel (recent searches, suggestions, categories, products) under
/// the input at all times, so Home shows only the input until it is focused: then the panel opens
/// and the rest of Home steps aside; "Cancel" closes it. A submitted phrase opens the results, a
/// product its page, a category with an id the category.
/// A product tapped in a story opens its page too: see `shouldOpenLinkBySdk(url:)`.
final class ShopHomeViewController: UIViewController {

    private let scroll = UIScrollView()
    private let searchClip = UIView()
    private let search = PersonalizationInstantSearchField()
    /// Browsing: the clip ends under the input, the panel below it is cut off.
    private lazy var searchCollapsed = searchClip.bottomAnchor.constraint(equalTo: search.view.input.bottomAnchor)
    /// Searching: the clip takes the whole field.
    private lazy var searchExpanded = searchClip.bottomAnchor.constraint(equalTo: search.bottomAnchor)
    private var isSearching = false
    private let stories = PersonalizationStories(code: AppEnvironments.storiesCode, shopId: AppEnvironments.shopId)
    private let recommender = PersonalizationRecommenderBlock(code: Shop.blockCode, shopId: AppEnvironments.shopId)
    private let categories = ShopCategoriesSection()
    /// Rows hidden while the search panel is open.
    private var browseRows: [UIView] = []
    private var sdkHandle: Cancellable?

    deinit {
        sdkHandle?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Shop"
        view.backgroundColor = PersonalizationColor.backgroundGeneric
        setupSearch()
        setupBlocks()
        setupLayout()
        sdkHandle = Shop.withSDK { [weak self] sdk in self?.categories.load(with: sdk) }
    }

    private func setupSearch() {
        search.shopId = AppEnvironments.shopId
        search.placeholder = "Search"
        search.recentLabel = "Recent searches"
        search.clearText = "Clear"
        search.moreText = "more"
        search.categoriesLabel = "Categories"
        search.productsLabel = "Products"
        search.showImages = true
        search.onSubmit = { [weak self] query in
            self?.closeSearch()
            self?.openShopSearch(query)
        }
        search.onCancel = { [weak self] in self?.closeSearch() }
        search.onProductTap = { [weak self] product in
            self?.view.endEditing(true)
            self?.openShopProduct(product.id)
        }
        search.onCategoryTap = { [weak self] category in
            // Popular categories of the empty state may come without an id — nothing to open them by.
            guard let id = category.id, !id.isEmpty else { return }
            self?.view.endEditing(true)
            self?.openShopCategory(id: id, name: category.name)
        }
        search.view.input.textField.addTarget(self, action: #selector(searchFocused), for: .editingDidBegin)
    }

    private func setupBlocks() {
        stories.bar.contentInsets = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)
        stories.promoCopiedText = "Code copied to clipboard"
        stories.hostViewController = self
        stories.communicationDelegate = self

        recommender.actionText = Shop.actionText
        recommender.onProductTap = { [weak self] product in self?.openShopProduct(product.id) }
        recommender.onProductAction = { product in Shop.addToCart(productId: product.id) }

        categories.onSelect = { [weak self] item in self?.openShopCategory(id: item.id, name: item.name) }
    }

    @objc private func searchFocused() {
        setSearching(true)
    }

    /// Back to Home: the field is emptied and drops its instant results.
    private func closeSearch() {
        search.query = nil
        // Text set in code does not send `.editingChanged`; sent here, it takes the field back to
        // its empty state the same way its own clear button does.
        search.view.input.textField.sendActions(for: .editingChanged)
        view.endEditing(true)
        setSearching(false)
    }

    private func setSearching(_ searching: Bool) {
        guard searching != isSearching else { return }
        isSearching = searching
        search.cancelText = searching ? "Cancel" : nil
        // Deactivate first: both pin the bottom of the clip.
        NSLayoutConstraint.deactivate([searching ? searchCollapsed : searchExpanded])
        NSLayoutConstraint.activate([searching ? searchExpanded : searchCollapsed])
        browseRows.forEach { $0.isHidden = searching }
        scroll.setContentOffset(CGPoint(x: 0, y: -scroll.adjustedContentInset.top), animated: false)
    }
}

// MARK: - Layout

private extension ShopHomeViewController {

    func setupLayout() {
        scroll.alwaysBounceVertical = true
        scroll.keyboardDismissMode = .onDrag
        scroll.shopPin(to: view)

        searchClip.clipsToBounds = true
        search.translatesAutoresizingMaskIntoConstraints = false
        searchClip.addSubview(search)
        NSLayoutConstraint.activate([
            search.topAnchor.constraint(equalTo: searchClip.topAnchor),
            search.leadingAnchor.constraint(equalTo: searchClip.leadingAnchor),
            search.trailingAnchor.constraint(equalTo: searchClip.trailingAnchor),
            searchCollapsed
        ])

        // The widgets hide themselves when they have nothing to show; Home hides their rows
        // instead, so leaving the search never brings back a block that hid itself.
        let storiesRow = stories.shopInset(horizontal: 0)
        let recommenderRow = recommender.shopInset()
        let categoriesRow = categories.shopInset()
        browseRows = [storiesRow, recommenderRow, categoriesRow]

        let column = UIStackView(arrangedSubviews: [searchClip.shopInset()] + browseRows)
        column.axis = .vertical
        column.spacing = 16
        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32),
            column.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            column.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
    }
}

// MARK: - Stories

/// The stories callbacks of the SDK. The product ones carry the tapped element without the product
/// id, so the shop routes on the link instead: the viewer is already closed when the SDK asks
/// whether to open it, and a product page of the shop opens here rather than in the browser.
extension ShopHomeViewController: StoriesCommunicationProtocol {

    func receiveIosLink(text: String) {}

    func receiveSelectedProductData(products: StoriesElement) {}

    func receiveSelectedCarouselProductData(products: StoriesProduct) {}

    func receiveSelectedPromocodeProductData(promoCodeSlide: StoriesPromoCodeElement) {}

    func shouldOpenLinkBySdk(url: String) -> Bool {
        guard let id = Shop.productId(fromLink: url) else { return true }
        openShopProduct(id)
        return false
    }
}
