import UIKit
@_spi(PersonalizationUI) import REES46

/// Shop home: the instant search field on top, the stories bar, the recommender carousel and the
/// top-level categories.
///
/// The search is the shop's `ShopSearchBar`: while its panel is open the rest of Home steps aside.
/// A product tapped in a story opens its page by the id the stories callbacks carry.
final class ShopHomeViewController: UIViewController {

    private let scroll = UIScrollView()
    private let searchBar = ShopSearchBar()
    private let stories = PersonalizationStories(code: AppEnvironments.storiesCode, shopId: AppEnvironments.shopId)
    private let recommender = PersonalizationRecommenderBlock(code: Shop.blockCode, shopId: AppEnvironments.shopId)
    private let categories = ShopCategoriesSection()
    /// Rows hidden while the search panel is open.
    private var browseRows: [UIView] = []
    /// The last story tap opened a product: its link stays with the shop, not the SDK.
    private var storyProductOpened = false
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
        searchBar.host = self
        searchBar.onSearchingChanged = { [weak self] searching in
            guard let self else { return }
            self.browseRows.forEach { $0.isHidden = searching }
            self.scroll.setContentOffset(CGPoint(x: 0, y: -self.scroll.adjustedContentInset.top), animated: false)
        }
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
}

// MARK: - Layout

private extension ShopHomeViewController {

    func setupLayout() {
        scroll.alwaysBounceVertical = true
        scroll.keyboardDismissMode = .onDrag
        scroll.shopPin(to: view)

        // The widgets hide themselves when they have nothing to show; Home hides their rows
        // instead, so leaving the search never brings back a block that hid itself.
        let storiesRow = stories.shopInset(horizontal: 0)
        let recommenderRow = recommender.shopInset()
        let categoriesRow = categories.shopInset()
        browseRows = [storiesRow, recommenderRow, categoriesRow]

        let column = UIStackView(arrangedSubviews: [searchBar.shopInset()] + browseRows)
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

/// The stories callbacks of the SDK: a tapped product comes with its id — the product element, the
/// slide button of a product slide, a carousel card — and opens its page here. The viewer is closed
/// by then; the SDK asks next whether to open the product's link itself, and the shop declines.
/// Other links (a button to a web page) the SDK opens.
extension ShopHomeViewController: StoriesCommunicationProtocol {

    func receiveIosLink(text: String) {}

    func receiveSelectedProductData(products: StoriesElement) {
        openStoryProduct(products.productId)
    }

    func receiveSelectedCarouselProductData(products: StoriesProduct) {
        openStoryProduct(products.id)
    }

    /// A copied promo code: nothing to open.
    func receiveSelectedPromocodeProductData(promoCodeSlide: StoriesPromoCodeElement) {}

    func shouldOpenLinkBySdk(url: String) -> Bool {
        defer { storyProductOpened = false }
        return !storyProductOpened
    }

    private func openStoryProduct(_ id: String?) {
        storyProductOpened = !(id ?? "").isEmpty
        if let id, storyProductOpened { openShopProduct(id) }
    }
}
