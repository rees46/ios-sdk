import UIKit
@_spi(PersonalizationUI) import REES46

/// Category: `getCategory(id, limit: 20, page)` page by page in the kit's catalogue — the category
/// title with the grid/list switch, "Showing N of M", "Load more", the empty state, and the error
/// with "Retry" when the first page fails; a failed next page turns "Load more" into "Retry".
/// No filters or sorting in this iteration. Opening the category sends `categoryView`.
final class ShopCategoryViewController: UIViewController {

    private static let pageSize = 20

    private let categoryId: String
    private let name: String
    private var sdk: PersonalizationSDK?
    private var sdkHandle: Cancellable?

    private let catalog = PersonalizationCatalog()
    private var products: [CategoryProduct] = []
    private var total = 0
    /// Last page that came in; pages are numbered from 1.
    private var page = 0
    private var loading = false
    /// The page that failed: the first one shows the error instead of the grid, a later one turns
    /// "Load more" into "Retry". Cleared by the next request.
    private var failedPage: Int?
    /// The first page came in empty — only then the empty state is shown.
    private var noProducts = false

    init(categoryId: String, name: String) {
        self.categoryId = categoryId
        self.name = name
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
        setupCatalog()
        catalog.shopPin(to: view)
        catalog.isLoading = true
        sdkHandle = Shop.withSDK { [weak self] sdk in
            guard let self else { return }
            self.sdk = sdk
            sdk.tracking.categoryView(categoryId: self.categoryId)
            self.request(page: 1)
        }
    }

    private func setupCatalog() {
        let header = PersonalizationTitle(text: name)
        let views = PersonalizationButtonGroup(items: [
            .init(icon: PersonalizationIcons.grid2x2, activeIcon: PersonalizationIcons.grid2x2Fill),
            .init(icon: PersonalizationIcons.list, activeIcon: PersonalizationIcons.listFill)
        ], size: .md)
        views.onSelected = { [weak self] index in self?.catalog.layout = index == 0 ? .grid : .list }
        header.trailing = views
        catalog.header = header

        catalog.showRating = false
        catalog.contentInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        catalog.imageLoader = { imageView, product in DemoImageLoader.shared.load(product.imageUrl, into: imageView) }
        catalog.onProductTap = { [weak self] product in self?.openShopProduct(product.id) }
        catalog.onProductAction = { [weak self] card in
            let price = self?.products.first { $0.id == card.id }?.price
            Shop.addToCart(productId: card.id, price: price)
        }
        catalog.onLoadMore = { [weak self] in self?.loadMore() }
        catalog.retryText = Shop.retryText
        catalog.onRetry = { [weak self] in self?.request(page: 1) }
    }

    /// The next page — or, after a failed one, the same page again.
    private func loadMore() {
        if let failedPage {
            request(page: failedPage)
        } else if products.count < total {
            request(page: page + 1)
        }
    }

    private func request(page next: Int) {
        guard let sdk, !loading else { return }
        loading = true
        failedPage = nil
        catalog.isLoading = true
        renderFooter()
        sdk.getCategory(category: categoryId, limit: Self.pageSize, page: next) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.loading = false
                self.catalog.isLoading = false
                switch result {
                case .success(let response):
                    self.page = next
                    self.products = next == 1 ? response.products : self.products + response.products
                    // An empty page ends the list even if the total promised more.
                    self.total = response.products.isEmpty ? self.products.count : response.productsTotal
                    self.noProducts = next == 1 && response.products.isEmpty
                    self.catalog.products = self.products.map(\.shopCard)
                case .failure:
                    self.failedPage = next
                }
                self.renderFooter()
            }
        }
    }

    private func renderFooter() {
        if products.isEmpty {
            catalog.setCount(prefix: nil, shown: 0, separator: "of", total: 0)
        } else {
            catalog.setCount(prefix: "Showing", shown: products.count, separator: "of", total: total)
        }
        catalog.emptyText = noProducts ? "No products in this category yet." : nil
        catalog.errorText = failedPage == 1 ? Shop.errorText : nil
        if let failedPage, failedPage > 1 {
            catalog.loadMoreText = Shop.retryText
        } else {
            catalog.loadMoreText = !products.isEmpty && products.count < total ? "Load more" : nil
        }
    }
}
