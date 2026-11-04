import UIKit
@_spi(PersonalizationUI) import REES46

/// Shop home: the header ("Shop", a popups menu and a search button), the stories bar, the
/// recommender carousel and the top-level categories, one column under the status bar. The popups
/// menu shows a popup v3 of `DemoPopups` by hand.
///
/// The search is the shop's `ShopSearchBar` behind the header's button: the button puts the bar in
/// place of the header, focused, with its panel open, and the rest of Home steps aside; "Cancel" or
/// a submitted phrase brings the header and Home back. A product tapped in a story opens its page by
/// the id the stories callbacks carry.
final class ShopHomeViewController: UIViewController {

    private let scroll = UIScrollView()
    private let header = UILabel()
    private let popupsButton = ShopRoundButton.popups()
    private let searchButton = ShopRoundButton.search()
    private let searchBar = ShopSearchBar()
    /// The row of the title and the buttons, and the row of the search bar that takes its place
    /// while searching.
    private var headerRow = UIView()
    private var searchRow = UIView()
    /// On stories API v3: slides with a link get "Share", which hands out the demo's own scheme.
    private let stories = PersonalizationStories(
        code: Shop.storiesCode,
        shopId: AppEnvironments.shopId,
        apiV3Domain: DemoStoriesLinks.apiV3Domain
    )
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
        setupPopups()
        setupBlocks()
        setupLayout()
        sdkHandle = Shop.withSDK { [weak self] sdk in self?.categories.load(with: sdk) }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DemoScreen.opened(DemoScreen.home)
    }

    private func setupSearch() {
        searchBar.host = self
        searchBar.onSearchingChanged = { [weak self] searching in self?.showSearch(searching) }
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
    }

    private func setupPopups() {
        popupsButton.menuItems = DemoPopups.manual.map { popup in
            (title: popup.title, action: { DemoPopups.show(popup.id) })
        }
        // iOS 13 has no menus on controls: there the button shows the same items as an action sheet.
        if #available(iOS 14.0, *) { return }
        popupsButton.addTarget(self, action: #selector(popupsTapped), for: .touchUpInside)
    }

    @objc private func popupsTapped() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for popup in DemoPopups.manual {
            sheet.addAction(UIAlertAction(title: popup.title, style: .default) { _ in DemoPopups.show(popup.id) })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = popupsButton
        sheet.popoverPresentationController?.sourceRect = popupsButton.bounds
        present(sheet, animated: true)
    }

    @objc private func searchTapped() {
        // The bar has to be on screen to take the focus; the focus opens its panel.
        showSearch(true)
        searchBar.focus()
    }

    private func showSearch(_ searching: Bool) {
        headerRow.isHidden = searching
        searchRow.isHidden = !searching
        browseRows.forEach { $0.isHidden = searching }
        scroll.setContentOffset(CGPoint(x: 0, y: -scroll.adjustedContentInset.top), animated: false)
    }

    private func setupBlocks() {
        // The covers start at the page margin; the column sets the gaps above and below the bar.
        stories.bar.contentInsets = UIEdgeInsets(
            top: 0, left: PersonalizationSpacing.paddingX, bottom: 0, right: PersonalizationSpacing.paddingX
        )
        stories.promoCopiedText = "Code copied"
        stories.shareUrlTransform = DemoStoriesLinks.appSchemeLink
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

        var title = PersonalizationTypography.xl3Emphasized.attributes
        title[.foregroundColor] = PersonalizationColor.textPrimary
        header.attributedText = NSAttributedString(string: "Shop", attributes: title)
        header.accessibilityTraits = .header
        let headerStack = UIStackView(arrangedSubviews: [header, popupsButton, searchButton])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = PersonalizationSpacing.lg
        headerStack.setCustomSpacing(PersonalizationSpacing.md, after: popupsButton)  // 8
        headerRow = headerStack.shopInset()
        searchRow = searchBar.shopInset()
        searchRow.isHidden = true

        // The widgets hide themselves when they have nothing to show; Home hides their rows
        // instead, so leaving the search never brings back a block that hid itself.
        let storiesRow = stories.shopInset(horizontal: 0)
        let recommenderRow = recommender.shopInset()
        let categoriesRow = categories.shopInset()
        browseRows = [storiesRow, recommenderRow, categoriesRow]

        let column = UIStackView(arrangedSubviews: [headerRow, searchRow] + browseRows)
        column.axis = .vertical
        // A hidden row takes its gap along: the gap of the row before it stays.
        column.setCustomSpacing(PersonalizationSpacing.lg, after: headerRow)         // 12
        column.setCustomSpacing(PersonalizationSpacing.lg, after: searchRow)         // 12
        column.setCustomSpacing(PersonalizationSpacing.xl3, after: storiesRow)       // 24
        column.setCustomSpacing(PersonalizationSpacing.xl3, after: recommenderRow)   // 24
        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: PersonalizationSpacing.md),
            column.bottomAnchor.constraint(
                equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -PersonalizationSpacing.xl4
            ),
            column.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            column.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
        shopCoverStatusBar(with: PersonalizationColor.backgroundGeneric)
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
