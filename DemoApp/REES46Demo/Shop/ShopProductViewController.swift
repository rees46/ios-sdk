import UIKit
@_spi(PersonalizationUI) import REES46

/// Product page: `getProductInfo` — image, brand, name, price with the old price and the discount,
/// "Add to cart"; below it the demo shop's recommender block for this product, titled
/// "Similar products". Opening the page sends `productView`. While the product loads the page
/// shows the kit's loader; a failed request shows the error text with "Retry".
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
    private let similar: PersonalizationRecommenderBlock

    init(productId: String) {
        self.productId = productId
        similar = PersonalizationRecommenderBlock(code: Shop.blockCode, itemId: productId, shopId: AppEnvironments.shopId)
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
        for view in [image, titleBlock, priceRow, cartButton, similar] {
            content.addArrangedSubview(view)
        }
        content.setCustomSpacing(32, after: cartButton)

        let column = UIStackView(arrangedSubviews: [loaderRow, errorState, content])
        column.axis = .vertical
        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32),
            column.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            column.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            column.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        ])
    }

    func setupActions() {
        errorState.actionText = Shop.retryText
        errorState.onAction = { [weak self] in self?.load() }
        cartButton.addTarget(self, action: #selector(cartTapped), for: .touchUpInside)

        // The block loads on its own as soon as it is on screen, in parallel with the product.
        similar.title = "Similar products"
        similar.actionText = Shop.actionText
        similar.onProductTap = { [weak self] product in self?.openShopProduct(product.id) }
        similar.onProductAction = { product in Shop.addToCart(productId: product.id) }
    }
}
