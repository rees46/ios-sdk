import SwiftUI
import UIKit
@_spi(PersonalizationUI) import REES46

/// "UI Kit" tab — the design system, one exhibit per component.
///
/// "Components" walks through the primitives in every size, view and state the design file
/// defines; "Blocks" shows the compositions built from them (product cards, recommender layouts,
/// instant search, the catalogue, the filters screen). "Search" runs the two data-bound search widgets
/// against the demo shop: the instant search field, and the results screen it opens on submit.
/// "Stories" keeps the stories block through the SDK's SwiftUI wrapper, the counterpart of the
/// "Legacy UI" tab.
///
/// The kit is SPI until its release, hence the `@_spi(PersonalizationUI)` import. Product data is
/// static: the kit does not fetch or format anything itself, and images are loaded by the host —
/// `DemoImageLoader` here, through the components' `imageLoader` slot.
final class UIKitShowcaseViewController: UIViewController {

    private let segments = UISegmentedControl(items: ["Components", "Blocks", "Search", "Stories"])
    private let container = UIView()
    private let appearanceButton = UIButton(type: .system)
    private var current: UIViewController?

    /// Colour scheme forced on the app by the switch; `.unspecified` hands control back to the device.
    private var appearance: UIUserInterfaceStyle = .unspecified

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        segments.selectedSegmentIndex = 0
        segments.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segments.translatesAutoresizingMaskIntoConstraints = false
        appearanceButton.addTarget(self, action: #selector(appearanceTapped), for: .touchUpInside)
        appearanceButton.translatesAutoresizingMaskIntoConstraints = false
        renderAppearanceTitle()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(appearanceButton)
        view.addSubview(segments)
        view.addSubview(container)
        NSLayoutConstraint.activate([
            appearanceButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            appearanceButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            segments.topAnchor.constraint(equalTo: appearanceButton.bottomAnchor, constant: 4),
            segments.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            segments.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            container.topAnchor.constraint(equalTo: segments.bottomAnchor, constant: 8),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        show(segment: 0)
    }

    /// Appearance switch: cycles the app between following the device, light and dark, so the kit's
    /// dark set can be checked without leaving for Settings. The override goes on the window rather
    /// than on this controller, so presented screens — the filters overlay, alerts — follow too; the
    /// kit's colours are dynamic `UIColor`s and repaint on the trait change by themselves.
    @objc private func appearanceTapped() {
        switch appearance {
        case .unspecified: appearance = .light
        case .light: appearance = .dark
        default: appearance = .unspecified
        }
        view.window?.overrideUserInterfaceStyle = appearance
        renderAppearanceTitle()
    }

    /// Title of the switch: the mode it is in now, not the one it would go to.
    private func renderAppearanceTitle() {
        let title: String
        switch appearance {
        case .light: title = "Light"
        case .dark: title = "Dark"
        default: title = "Auto"
        }
        appearanceButton.setTitle(title, for: .normal)
    }

    @objc private func segmentChanged() {
        show(segment: segments.selectedSegmentIndex)
    }

    private func show(segment: Int) {
        let next: UIViewController
        switch segment {
        case 0: next = ShowcaseViewController(exhibits: Exhibits.components())
        case 1: next = ShowcaseViewController(exhibits: Exhibits.blocks())
        case 2: next = SearchFlowViewController(shopId: AppEnvironments.shopId)
        default: next = UIHostingController(rootView: SwiftUIStoriesScreen())
        }

        current?.willMove(toParent: nil)
        current?.view.removeFromSuperview()
        current?.removeFromParent()

        addChild(next)
        next.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(next.view)
        NSLayoutConstraint.activate([
            next.view.topAnchor.constraint(equalTo: container.topAnchor),
            next.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            next.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            next.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        next.didMove(toParent: self)
        current = next
    }
}

// MARK: - Search flow

/// The search flow as a host would wire it: the instant search field resolves the SDK by shopId and
/// searches on its own; submitting a phrase swaps it for the results screen, whose back button
/// returns. Taps on products and categories only show an alert here — navigation is the host's.
private final class SearchFlowViewController: UIViewController {

    private let shopId: String
    private var currentView: UIView?

    init(shopId: String) {
        self.shopId = shopId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PersonalizationColor.backgroundGeneric
        showField()
    }

    private func showField() {
        let field = PersonalizationInstantSearchField()
        field.shopId = shopId
        field.placeholder = "Search"
        field.cancelText = "Cancel"
        field.recentLabel = "Recent searches"
        field.clearText = "Clear"
        field.moreText = "more"
        field.categoriesLabel = "Categories"
        field.productsLabel = "Products"
        field.showImages = true
        field.onSubmit = { [weak self] query in self?.showResults(query) }
        field.onCancel = { field.query = nil }
        field.onProductTap = { [weak self] product in self?.alert("Product: \(product.name)") }
        field.onCategoryTap = { [weak self] category in self?.alert("Category: \(category.name)") }
        field.onError = { [weak self] error in self?.alert("Search error: \(error)") }

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.keyboardDismissMode = .onDrag
        field.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(field)
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            field.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            field.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            field.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            field.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        swap(to: scroll)
    }

    private func showResults(_ query: String) {
        let screen = PersonalizationSearchResultsScreen()
        screen.shopId = shopId
        screen.productActionText = "Add to cart"
        screen.onBack = { [weak self] in self?.showField() }
        screen.onProductTap = { [weak self] product in self?.alert("Product: \(product.name)") }
        screen.onProductAction = { [weak self] product in self?.alert("Add to cart: \(product.name)") }
        // No sort picker in the design file: cycle relevance → price ↑ → price ↓ on tap.
        screen.onSortTap = { [weak screen] in
            guard let screen else { return }
            switch (screen.sortBy, screen.sortDir) {
            case (nil, _): screen.sortBy = "price"; screen.sortDir = "asc"
            case ("price", "asc"): screen.sortDir = "desc"
            default: screen.sortBy = nil; screen.sortDir = nil
            }
        }
        screen.onError = { [weak self] error in self?.alert("Search error: \(error)") }
        screen.query = query
        swap(to: screen)
    }

    private func swap(to next: UIView) {
        currentView?.removeFromSuperview()
        next.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(next)
        NSLayoutConstraint.activate([
            next.topAnchor.constraint(equalTo: view.topAnchor),
            next.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            next.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            next.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        currentView = next
    }

    private func alert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Showcase scroll

/// A vertical list of captioned exhibits. Each exhibit is built once, on demand, so the views keep
/// their own state (selected segment, expanded accordion) while the screen is scrolled.
private final class ShowcaseViewController: UIViewController {

    typealias Exhibit = (title: String, build: () -> UIView)

    private let exhibits: [Exhibit]

    init(exhibits: [Exhibit]) {
        self.exhibits = exhibits
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        ])

        for exhibit in exhibits {
            let caption = UILabel()
            caption.text = exhibit.title
            caption.font = .preferredFont(forTextStyle: .footnote)
            caption.textColor = .secondaryLabel
            caption.numberOfLines = 0

            let section = UIStackView(arrangedSubviews: [caption, exhibit.build()])
            section.axis = .vertical
            section.spacing = 8
            stack.addArrangedSubview(section)
        }
    }
}

// MARK: - Exhibits

private enum Exhibits {

    static func components() -> [ShowcaseViewController.Exhibit] {
        [
            ("Button — LG / MD / SM, primary · secondary · ghost", {
                column([PersonalizationButton.Size.lg, .md, .sm].map { size in
                    scrollableRow([
                        PersonalizationButton(text: "Primary", size: size, view: .primary),
                        PersonalizationButton(text: "Secondary", size: size, view: .secondary),
                        PersonalizationButton(text: "Ghost", size: size, view: .ghost)
                    ])
                })
            }),
            ("Button — icons and disabled", {
                let disabled = PersonalizationButton(text: "Disabled", size: .md)
                disabled.isEnabled = false
                return scrollableRow([
                    PersonalizationButton(text: "Filters", size: .md, iconStart: PersonalizationIcons.equalizerHorizontal),
                    PersonalizationButton(text: "Sort", size: .md, view: .secondary, iconEnd: PersonalizationIcons.arrowsUpDown),
                    PersonalizationButton(size: .md, view: .ghost, iconStart: PersonalizationIcons.copy),
                    disabled
                ])
            }),
            ("Button Group — MD and SM", {
                row([buttonGroup(size: .md), buttonGroup(size: .sm)])
            }),
            ("Input Field — search LG, input MD, select SM, disabled", {
                let filled = PersonalizationInputField(size: .md, type: .input)
                filled.text = "Running shoes"
                let select = PersonalizationInputField(size: .sm, type: .select)
                select.text = "Size 42"
                let disabled = PersonalizationInputField(size: .md, type: .input, placeholder: "Disabled")
                disabled.isEnabled = false
                return column([
                    PersonalizationInputField(size: .lg, type: .search, placeholder: "Search"),
                    filled,
                    select,
                    disabled
                ])
            }),
            ("Title — plain, with trailing action, with leading back", {
                let withAction = PersonalizationTitle(text: "Recently viewed")
                withAction.trailing = PersonalizationButton(text: "Show all", size: .sm, view: .ghost, iconEnd: PersonalizationIcons.angleLargeRight)
                let withBack = PersonalizationTitle(text: "Sneakers")
                withBack.leading = PersonalizationButton(size: .sm, view: .ghost, iconStart: PersonalizationIcons.arrowLeft)
                return column([PersonalizationTitle(text: "Recommended for you"), withAction, withBack])
            }),
            ("Link — text action next to a field or a label", {
                row([PersonalizationLink(text: "Cancel"), PersonalizationLink(text: "Clear")])
            }),
            ("Search Results Title", { searchResultsTitle() }),
            ("Accordion — collapsed with count, expanded", {
                column([
                    PersonalizationAccordion(text: "Brand", count: 12),
                    PersonalizationAccordion(text: "Size", expanded: true)
                ])
            }),
            ("List Label", { PersonalizationListLabel(text: "Popular categories") }),
            ("Badge — warning LG / MD / SM, danger", {
                row([
                    PersonalizationBadge(text: "New", size: .lg),
                    PersonalizationBadge(text: "New", size: .md),
                    PersonalizationBadge(text: "New", size: .sm),
                    PersonalizationBadge(text: "-15%", size: .md, view: .danger)
                ])
            }),
            ("Tag — primary with remove, secondary", {
                row([
                    PersonalizationTag(text: "Nike", onRemove: {}),
                    PersonalizationTag(text: "Size 42", view: .secondary, onRemove: {}),
                    PersonalizationTag(text: "Running", view: .secondary)
                ])
            }),
            ("Checkbox — unchecked, checked, indeterminate, disabled; with label", {
                let disabled = PersonalizationCheckbox(state: .checked)
                disabled.isEnabled = false
                return column([
                    row([
                        PersonalizationCheckbox(state: .unchecked),
                        PersonalizationCheckbox(state: .checked),
                        PersonalizationCheckbox(state: .indeterminate),
                        disabled
                    ]),
                    PersonalizationCheckboxWithLabel(text: "In stock only", state: .checked)
                ])
            }),
            ("Dots, Count, Rating", {
                let count = PersonalizationCount()
                count.set(prefix: "Showing", shown: 12, separator: "of", total: 128)
                let rating = PersonalizationRating()
                rating.set(value: "4.7", reviews: 128)
                return column([PersonalizationDots(count: 5, selectedIndex: 1), count, rating], alignment: .leading)
            }),
            ("Loader, Favorites Badge", {
                let loader = PersonalizationLoader()
                loader.startAnimating()
                return row([loader, PersonalizationFavoritesBadge()])
            }),
            ("Product Image — 1:1, 4:3, 3:4", {
                row([
                    productImage(aspect: .square, product: DemoProducts.all[0]),
                    productImage(aspect: .landscape, product: DemoProducts.all[1]),
                    productImage(aspect: .portrait, product: DemoProducts.all[2])
                ])
            }),
            ("Empty State", { PersonalizationEmptyState(message: "No results for your request.") }),
            ("Icons — the full set, 24 pt", {
                scrollableRow(DemoIcons.all.map(icon))
            })
        ]
    }

    static func blocks() -> [ShowcaseViewController.Exhibit] {
        [
            ("Product Card — carousel, grid, list", {
                let carousel = productCard(type: .carousel, product: DemoProducts.all[0])
                carousel.widthAnchor.constraint(equalToConstant: 220).isActive = true
                let grid = productCard(type: .grid, product: DemoProducts.all[1])
                grid.widthAnchor.constraint(equalToConstant: 161).isActive = true
                return column([carousel, grid, productCard(type: .list, product: DemoProducts.all[2])], alignment: .leading)
            }),
            ("Product Card — image 4:3, 1:1, 3:4 (carousel and list)", {
                let aspects: [PersonalizationProductImage.Aspect] = [.landscape, .square, .portrait]
                let carousel = aspects.enumerated().map { index, aspect -> UIView in
                    let card = productCard(type: .carousel, product: DemoProducts.all[index + 3])
                    card.imageAspect = aspect
                    card.widthAnchor.constraint(equalToConstant: 220).isActive = true
                    return card
                }
                let list = aspects.enumerated().map { index, aspect -> UIView in
                    let card = productCard(type: .list, product: DemoProducts.all[index + 3])
                    card.imageAspect = aspect
                    return card
                }
                return column([scrollableRow(carousel)] + list)
            }),
            ("Recommender Block — carousel", {
                recommender(layout: .carousel, title: "Recommended for you", products: DemoProducts.all)
            }),
            ("Recommender Block — grid", {
                recommender(layout: .grid, title: "Similar products", products: Array(DemoProducts.all.prefix(4)))
            }),
            ("Recommender Block — list", {
                recommender(layout: .list, title: "Recently viewed", products: Array(DemoProducts.all.prefix(3)))
            }),
            ("Instant Search — recent searches", { instantSearch(typing: false, images: false) }),
            ("Instant Search — typing, matches in bold", { instantSearch(typing: true, images: false) }),
            ("Instant Search — with images", { instantSearch(typing: false, images: true) }),
            ("Catalog — header, grid ⇄ list, count, load more", { catalog() }),
            ("Catalog — empty state", { catalogEmpty() }),
            ("Filters — range, checkbox lists with show more, reset / apply", { filters() }),
            ("In App Popup — image, one button", { inAppPopup(.image) }),
            ("In App Popup — image background, both buttons", {
                inAppPopup(.imageBackground, closeText: "Not now")
            }),
            ("In App Popup — text only, close button with text", {
                inAppPopup(.text, closeText: "Maybe later")
            }),
            ("In App Popup — icon, no buttons (cross only)", {
                inAppPopup(.icon, actionText: nil)
            }),
            ("In App Popup, fullscreen — image", { inAppPopup(.image, fullscreen: true) }),
            ("In App Popup, fullscreen — image background, both buttons", {
                inAppPopup(.imageBackground, closeText: "Not now", fullscreen: true)
            }),
            ("In App Popup, fullscreen — text only", { inAppPopup(.text, fullscreen: true) }),
            ("In App Popup, fullscreen — icon", { inAppPopup(.icon, fullscreen: true) })
        ]
    }

    /// The popup as the SDK will hand it over: the host loads the image and wires the two
    /// callbacks. Fixed height here only because the showcase is a scrolling column — on screen
    /// the popup is sized by whoever presents it.
    private static func inAppPopup(
        _ view: PersonalizationInAppPopup.ContentView,
        actionText: String? = "Action",
        closeText: String? = nil,
        fullscreen: Bool = false
    ) -> UIView {
        let popup = PersonalizationInAppPopup()
        popup.presentation = fullscreen ? .fullscreen : .modal
        popup.contentView = view
        popup.title = "Pizza ipsum dolor meat lovers"
        popup.text = "Cheese ranch Philly roll pepperoni hand thin garlic bacon."
        popup.actionText = actionText
        popup.closeText = closeText
        popup.icon = UIImage(systemName: "checkmark.shield.fill")
        popup.imageLoader = { image in DemoImageLoader.shared.load(DemoProducts.popupImage, into: image) }
        popup.translatesAutoresizingMaskIntoConstraints = false
        // Полноэкранному нужно больше места: отступы и кегли там на ступень крупнее.
        popup.heightAnchor.constraint(equalToConstant: fullscreen ? 620 : 460).isActive = true
        return popup
    }

    // MARK: Layout helpers

    private static func row(_ views: [UIView]) -> UIView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        // A spacer absorbs the leftover width so the exhibits keep their intrinsic sizes.
        let spacer = UIView()
        spacer.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        stack.addArrangedSubview(spacer)
        return stack
    }

    private static func scrollableRow(_ views: [UIView]) -> UIView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            scroll.heightAnchor.constraint(equalTo: stack.heightAnchor)
        ])
        return scroll
    }

    private static func column(_ views: [UIView], alignment: UIStackView.Alignment = .fill) -> UIView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.alignment = alignment
        stack.spacing = 12
        return stack
    }

    // MARK: Component factories

    private static func buttonGroup(size: PersonalizationButtonGroup.Size) -> PersonalizationButtonGroup {
        PersonalizationButtonGroup(items: [
            .init(icon: PersonalizationIcons.grid2x2, activeIcon: PersonalizationIcons.grid2x2Fill),
            .init(icon: PersonalizationIcons.list, activeIcon: PersonalizationIcons.listFill)
        ], size: size)
    }

    private static func icon(_ image: UIImage?) -> UIView {
        let view = UIImageView(image: image?.withRenderingMode(.alwaysTemplate))
        view.tintColor = PersonalizationColor.textPrimary
        view.contentMode = .scaleAspectFit
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 24),
            view.heightAnchor.constraint(equalToConstant: 24)
        ])
        return view
    }

    private static func searchResultsTitle(count: Int = 128) -> PersonalizationSearchResultsTitle {
        let title = PersonalizationSearchResultsTitle()
        title.text = "Sneakers"
        title.setResults(prefix: "Found", count: count, suffix: "products")
        title.setFilters([
            .init(label: "Nike", onRemove: {}),
            .init(label: "Size 42", onRemove: {})
        ])
        return title
    }

    private static func productImage(aspect: PersonalizationProductImage.Aspect, product: PersonalizationProduct) -> PersonalizationProductImage {
        let image = PersonalizationProductImage(aspect: aspect)
        image.widthAnchor.constraint(equalToConstant: 104).isActive = true
        DemoImageLoader.shared.load(product.imageUrl, into: image.imageView)
        return image
    }

    private static func productCard(type: PersonalizationProductCard.CardType, product: PersonalizationProduct) -> PersonalizationProductCard {
        let card = PersonalizationProductCard(type: type)
        card.brand = product.brand
        card.name = product.name
        card.price = product.price
        card.oldPrice = product.oldPrice
        card.discount = product.discount
        card.actionText = product.actionText
        if let rating = product.ratingValue { card.setRating(value: rating, reviews: product.reviews) }
        DemoImageLoader.shared.load(product.imageUrl, into: card.image.imageView)
        return card
    }

    private static func recommender(layout: PersonalizationProductsList.Layout, title: String, products: [PersonalizationProduct]) -> PersonalizationRecommenderBlock {
        let block = PersonalizationRecommenderBlock(layout: layout)
        block.text = title
        block.showAllText = "Show all"
        block.onShowAll = {}
        block.imageLoader = DemoProducts.imageLoader
        block.products = products
        return block
    }

    /// The catalogue as a host would wire it: the results title in the header slot drives the
    /// grid/list switch, "load more" appends a page after a short simulated delay.
    /// Instant search in its three states: recent searches before typing, suggestions with the
    /// query highlighted while typing, and rows with images. The host owns the data; the kit only
    /// renders what it is given and reports the taps.
    private static func instantSearch(typing: Bool, images: Bool) -> PersonalizationInstantSearch {
        let search = PersonalizationInstantSearch()
        search.placeholder = "want to buy..."
        search.cancelText = "Cancel"
        search.showImages = images
        search.imageLoader = { view, suggestion in DemoImageLoader.shared.load(suggestion.imageUrl, into: view) }
        search.categoriesLabel = typing ? "Category" : "Popular category"
        search.productsLabel = typing ? "Products" : "Frequently searched"
        if typing {
            search.query = "boots"
            search.setSuggestions(["winter", "mens", "kids", "for outdoor", "womens", "low", "black", "orange"])
            search.setCategories([
                PersonalizationInstantSearch.Suggestion(id: "c1", title: "Womens boots"),
                PersonalizationInstantSearch.Suggestion(id: "c2", title: "Mens boots"),
                PersonalizationInstantSearch.Suggestion(id: "c3", title: "Kids boots")
            ])
            search.setProducts([
                PersonalizationInstantSearch.Suggestion(id: "p1", title: "winter womens boots"),
                PersonalizationInstantSearch.Suggestion(id: "p2", title: "boots for mens"),
                PersonalizationInstantSearch.Suggestion(id: "p3", title: "winter boots for mens"),
                PersonalizationInstantSearch.Suggestion(id: "p4", title: "kids winter boots")
            ])
        } else {
            search.recentLabel = "Recent searches"
            search.clearText = "Clear"
            search.moreText = "more"
            search.setRecentSearches(["mens winter boots", "kids shoes", "bag", "accessories", "black boots"])
            search.setCategories([
                // Categories come without pictures: the search API returns none for them, so the
                // "with images" state only illustrates product rows.
                PersonalizationInstantSearch.Suggestion(id: "c1", title: "Running shoes", subtitle: "Shoes"),
                PersonalizationInstantSearch.Suggestion(id: "c2", title: "Running apparel", subtitle: "Clothing"),
                PersonalizationInstantSearch.Suggestion(id: "c3", title: "Trail gear", subtitle: "Outdoor")
            ])
            search.setProducts(DemoProducts.all.prefix(images ? 3 : 5).map {
                PersonalizationInstantSearch.Suggestion(id: $0.id, title: $0.name, subtitle: $0.price, imageUrl: $0.imageUrl)
            })
        }
        return search
    }

    /// The filters screen with the sections from the design file; toggles and ranges update its own state.
    private static func filters() -> PersonalizationFilters {
        let filters = PersonalizationFilters()
        filters.text = "Filters"
        filters.resetText = "Reset"
        filters.applyText = "Apply"
        let colors = ["All", "Black", "White", "Red", "Light blue", "Green", "Yellow", "Brown", "Grey", "Pink"]
        let ratings = ["All", "5 stars", "4+ stars", "3+ stars"]
        filters.setSections([
            .range(id: "size", title: "Size", fromLabel: "From", toLabel: "to", from: "42", to: "43", select: true),
            .options(
                id: "colors", title: "Colors",
                options: colors.enumerated().map { PersonalizationFilters.Option(id: $1.lowercased(), label: $1, checked: $0 == 1) },
                showMoreText: "Show more", showLessText: "Show less"
            ),
            .range(id: "price", title: "Price (USD)", fromLabel: "From", toLabel: "to", from: "50", to: "500"),
            .options(
                id: "rating", title: "Rating",
                options: ratings.enumerated().map { PersonalizationFilters.Option(id: $1, label: $1, checked: $0 == 1) }
            )
        ])
        return filters
    }

    /// The catalogue as a host would wire it: the category title (title + view switch, as on the
    /// CatalogGrid page) sits in the header slot and drives the grid/list switch, "load more"
    /// appends a page after a short simulated delay. The search results title with back, filters
    /// and sort belongs to the search flow — see the Search segment.
    private static func catalog() -> PersonalizationCatalog {
        let catalog = PersonalizationCatalog()
        let header = PersonalizationTitle(text: "Sneakers")
        let views = buttonGroup(size: .md)
        views.onSelected = { [weak catalog] index in
            catalog?.layout = index == 0 ? .grid : .list
        }
        header.trailing = views
        var shown = Array(DemoProducts.all.prefix(4))
        func render() {
            catalog.products = shown
            catalog.setCount(prefix: "Showing", shown: shown.count, separator: "of", total: DemoProducts.total)
        }
        catalog.header = header
        catalog.imageLoader = DemoProducts.imageLoader
        catalog.loadMoreText = "Load more"
        catalog.onLoadMore = { [weak catalog] in
            catalog?.isLoading = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                let page = DemoProducts.all.dropFirst(shown.count % DemoProducts.all.count).prefix(4)
                shown += page.map { $0.copy(id: "\($0.id)-\(shown.count)") }
                catalog?.isLoading = false
                render()
            }
        }
        render()
        return catalog
    }

    /// Empty results: the same header, the empty state in place of the grid, nothing below.
    private static func catalogEmpty() -> PersonalizationCatalog {
        let catalog = PersonalizationCatalog()
        catalog.header = searchResultsTitle(count: 0)
        catalog.emptyText = "No results for your request."
        catalog.products = []
        return catalog
    }
}

// MARK: - Fixtures

private enum DemoIcons {
    static let all: [UIImage?] = [
        PersonalizationIcons.angleDown, PersonalizationIcons.angleLargeRight, PersonalizationIcons.angleUp,
        PersonalizationIcons.arrowLeft, PersonalizationIcons.arrowRotateCw, PersonalizationIcons.arrowsUpDown,
        PersonalizationIcons.copy, PersonalizationIcons.crossLarge, PersonalizationIcons.cross,
        PersonalizationIcons.equalizerHorizontal, PersonalizationIcons.grid2x2Fill, PersonalizationIcons.grid2x2,
        PersonalizationIcons.listFill, PersonalizationIcons.list, PersonalizationIcons.magnifier,
        PersonalizationIcons.spacingMd, PersonalizationIcons.starFill
    ]
}

/// Static products for the exhibits. Strings arrive formatted — that is the kit's contract.
private enum DemoProducts {
    static let total = 128

    static let imageLoader: (UIImageView, PersonalizationProduct) -> Void = { view, product in
        DemoImageLoader.shared.load(product.imageUrl, into: view)
    }

    /// Photos ship with the app (asset catalogue): the showcase must not depend on the network.
    private static func image(_ seed: String) -> String { "asset://uikit-\(seed)" }

    /// Stand-in artwork for the in-app popup exhibits.
    static let popupImage = image("jacket")

    static let all: [PersonalizationProduct] = [
        PersonalizationProduct(id: "1", name: "Air Zoom Pegasus 41 running shoes", price: "$140", imageUrl: image("pegasus"), brand: "Nike", ratingValue: "4.7", reviews: 128, oldPrice: "$165", discount: "-15%", actionText: "Add to cart"),
        PersonalizationProduct(id: "2", name: "Wireless over-ear headphones", price: "$299", imageUrl: image("headphones"), brand: "Sony", ratingValue: "4.8", reviews: 2140, actionText: "Add to cart"),
        PersonalizationProduct(id: "3", name: "Everyday backpack 20 L", price: "$89", imageUrl: image("backpack"), brand: "Peak Design", ratingValue: "4.6", reviews: 412, oldPrice: "$110", discount: "-19%", actionText: "Add to cart"),
        PersonalizationProduct(id: "4", name: "Trail running jacket", price: "$175", imageUrl: image("jacket"), brand: "Salomon", ratingValue: "4.5", reviews: 77, actionText: "Add to cart"),
        PersonalizationProduct(id: "5", name: "Polarized sunglasses", price: "$120", imageUrl: image("sunglasses"), brand: "Oakley", ratingValue: "4.4", reviews: 305, oldPrice: "$150", discount: "-20%", actionText: "Add to cart"),
        PersonalizationProduct(id: "6", name: "Insulated bottle 750 ml", price: "$35", imageUrl: image("bottle"), brand: "Hydro Flask", ratingValue: "4.9", reviews: 980, actionText: "Add to cart"),
        PersonalizationProduct(id: "7", name: "GPS running watch", price: "$449", imageUrl: image("watch"), brand: "Garmin", ratingValue: "4.7", reviews: 1532, actionText: "Add to cart"),
        PersonalizationProduct(id: "8", name: "Court sneakers", price: "$95", imageUrl: image("sneakers"), brand: "Adidas", ratingValue: "4.3", reviews: 64, oldPrice: "$120", discount: "-21%", actionText: "Add to cart")
    ]
}

private extension PersonalizationProduct {
    func copy(id: String) -> PersonalizationProduct {
        PersonalizationProduct(
            id: id, name: name, price: price, imageUrl: imageUrl, brand: brand, ratingValue: ratingValue,
            reviews: reviews, oldPrice: oldPrice, discount: discount, actionText: actionText
        )
    }
}

/// The smallest possible image loader: URLSession plus an in-memory cache. The kit hands the host
/// an `UIImageView` and stays out of networking; a real app would plug in its own library here.
final class DemoImageLoader {
    static let shared = DemoImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    /// The URL each image view is waiting for, so a late response cannot overwrite a newer request.
    private var pending: [ObjectIdentifier: URL] = [:]

    func load(_ urlString: String?, into imageView: UIImageView) {
        imageView.image = nil
        guard let urlString, let url = URL(string: urlString) else {
            pending[ObjectIdentifier(imageView)] = nil
            return
        }
        // Bundled photos: `asset://<name>` resolves in the asset catalogue, no request.
        if url.scheme == "asset", let host = url.host {
            pending[ObjectIdentifier(imageView)] = nil
            imageView.image = UIImage(named: host)
            return
        }
        if let cached = cache.object(forKey: urlString as NSString) {
            imageView.image = cached
            return
        }
        pending[ObjectIdentifier(imageView)] = url
        URLSession.shared.dataTask(with: url) { [weak self, weak imageView] data, _, _ in
            guard let self, let data, let image = UIImage(data: data) else { return }
            self.cache.setObject(image, forKey: urlString as NSString)
            DispatchQueue.main.async {
                guard let imageView, self.pending[ObjectIdentifier(imageView)] == url else { return }
                self.pending[ObjectIdentifier(imageView)] = nil
                imageView.image = image
            }
        }.resume()
    }
}
