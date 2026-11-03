import UIKit
@_spi(PersonalizationUI) import REES46

/// Product page: `getProductInfo` — image, brand, name, price with the old price and the discount,
/// "Add to cart"; below it recommender blocks for this product — similar, bought with it and
/// popular, each titled by the server and hidden while it has no products. Opening the page sends
/// `productView`. While the product loads the page shows the kit's loader; a failed request shows
/// the error text with "Retry". The shop's instant search sits on top and behaves as on Home: while
/// its panel is open the page steps aside.
final class ShopProductViewController: UIViewController {

    private enum State {
        case loading, failed, loaded(ProductInfo)
    }

    private let productId: String
    private var sdk: PersonalizationSDK?
    private var sdkHandle: Cancellable?
    private var product: ProductInfo?
    /// Number of the request in flight: a late answer to an older one is dropped.
    private var requestSeq = 0

    private let scroll = UIScrollView()
    private let searchBar = ShopSearchBar()
    /// Everything of the page under the search: hidden while the search panel is open.
    private let page = UIStackView()
    private let loaderRow = UIView()
    private let loader = PersonalizationLoader()
    private let errorState = PersonalizationEmptyState(message: Shop.errorText)
    private let content = UIStackView()
    private let image = PersonalizationProductImage(aspect: .square)
    private let brandLabel = UILabel()
    private let nameLabel = UILabel()
    private let priceLabel = UILabel()
    private let oldPriceLabel = UILabel()
    private let discountBadge = PersonalizationBadge(size: .md, view: .danger)
    private let cartButton = PersonalizationButton(text: Shop.actionText, size: .lg, view: .primary)
    private let blocks: [PersonalizationRecommenderBlock]

    init(productId: String) {
        self.productId = productId
        blocks = [Shop.similarBlockCode, Shop.alsoBoughtBlockCode, Shop.blockCode].map {
            PersonalizationRecommenderBlock(code: $0, itemId: productId, shopId: AppEnvironments.shopId)
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        sdkHandle?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PersonalizationColor.backgroundGeneric
        navigationItem.largeTitleDisplayMode = .never
        setupLayout()
        setupActions()
        render(.loading)
        sdkHandle = Shop.withSDK { [weak self] sdk in
            guard let self else { return }
            self.sdk = sdk
            // One event per opened page: "Retry" repeats the request, not the view.
            sdk.tracking.productView(itemId: self.productId)
            self.load()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DemoScreen.opened(DemoScreen.product)
    }

    private func load() {
        guard let sdk else { return }
        requestSeq += 1
        let seq = requestSeq
        render(.loading)
        sdk.getProductInfo(id: productId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, seq == self.requestSeq else { return }
                switch result {
                case .success(let product) where !product.id.isEmpty:
                    self.render(.loaded(product))
                case .success, .failure:
                    self.render(.failed)
                }
            }
        }
    }

    private func render(_ state: State) {
        loaderRow.isHidden = true
        errorState.isHidden = true
        content.isHidden = true
        switch state {
        case .loading:
            loaderRow.isHidden = false
        case .failed:
            errorState.isHidden = false
        case .loaded(let product):
            content.isHidden = false
            fill(product)
        }
    }

    /// The page shows the same strings a card of this product would: one mapper for both.
    private func fill(_ product: ProductInfo) {
        self.product = product
        let card = product.shopCard
        DemoImageLoader.shared.load(card.imageUrl, into: image.imageView)
        brandLabel.isHidden = card.brand == nil
        brandLabel.attributedText = styled(card.brand, PersonalizationTypography.smDefault, PersonalizationColor.textSecondary)
        nameLabel.attributedText = styled(card.name, PersonalizationTypography.xlEmphasized, PersonalizationColor.textPrimary)
        priceLabel.attributedText = styled(card.price, PersonalizationTypography.xl2Emphasized, PersonalizationColor.textPrimary)
        oldPriceLabel.isHidden = card.oldPrice == nil
        oldPriceLabel.attributedText = styled(
            card.oldPrice, PersonalizationTypography.baseDefault, PersonalizationColor.textSecondary, strikethrough: true
        )
        discountBadge.isHidden = card.discount == nil
        discountBadge.text = card.discount
    }

    /// Kit text style with a colour: only an attributed string carries the line height.
    private func styled(
        _ text: String?,
        _ style: PersonalizationTextStyle,
        _ color: UIColor,
        strikethrough: Bool = false
    ) -> NSAttributedString? {
        guard let text else { return nil }
        var attributes = style.attributes
        attributes[.foregroundColor] = color
        if strikethrough { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        return NSAttributedString(string: text, attributes: attributes)
    }

    @objc private func cartTapped() {
        guard let product else { return }
        Shop.addToCart(productId: product.id, price: product.price)
    }
}

// MARK: - Layout

private extension ShopProductViewController {

    func setupLayout() {
        scroll.alwaysBounceVertical = true
        scroll.keyboardDismissMode = .onDrag
        scroll.shopPin(to: view)

        loader.translatesAutoresizingMaskIntoConstraints = false
        loaderRow.addSubview(loader)
        NSLayoutConstraint.activate([
            loader.centerXAnchor.constraint(equalTo: loaderRow.centerXAnchor),
            loader.topAnchor.constraint(equalTo: loaderRow.topAnchor, constant: 92),
            loader.bottomAnchor.constraint(equalTo: loaderRow.bottomAnchor)
        ])
        loader.startAnimating()

        brandLabel.numberOfLines = 0
        nameLabel.numberOfLines = 0
        let titleBlock = UIStackView(arrangedSubviews: [brandLabel, nameLabel])
        titleBlock.axis = .vertical
        titleBlock.spacing = 4

        for view in [priceLabel, oldPriceLabel, discountBadge] {
            view.setContentHuggingPriority(.required, for: .horizontal)
        }
        let priceRow = UIStackView(arrangedSubviews: [priceLabel, oldPriceLabel, discountBadge, UIView()])
        priceRow.axis = .horizontal
        priceRow.alignment = .center
        priceRow.spacing = 8

        content.axis = .vertical
        content.spacing = 16
        for view in [image, titleBlock, priceRow, cartButton] + blocks {
            content.addArrangedSubview(view)
        }
        // A block with no products is hidden, and the stack skips it along with its spacing.
        for view in [cartButton] + blocks {
            content.setCustomSpacing(32, after: view)
        }

        for view in [loaderRow, errorState, content] {
            page.addArrangedSubview(view)
        }
        page.axis = .vertical

        let column = UIStackView(arrangedSubviews: [searchBar, page])
        column.axis = .vertical
        column.spacing = 16
        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32),
            column.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            column.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            column.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        ])
    }

    func setupActions() {
        searchBar.host = self
        searchBar.onSearchingChanged = { [weak self] searching in
            guard let self else { return }
            self.page.isHidden = searching
            self.scroll.setContentOffset(CGPoint(x: 0, y: -self.scroll.adjustedContentInset.top), animated: false)
        }

        errorState.actionText = Shop.retryText
        errorState.onAction = { [weak self] in self?.load() }
        cartButton.addTarget(self, action: #selector(cartTapped), for: .touchUpInside)

        // The blocks load on their own as soon as they are on screen, in parallel with the product.
        for block in blocks {
            block.actionText = Shop.actionText
            block.onProductTap = { [weak self] product in self?.openShopProduct(product.id) }
            block.onProductAction = { product in Shop.addToCart(productId: product.id) }
        }
    }
}
