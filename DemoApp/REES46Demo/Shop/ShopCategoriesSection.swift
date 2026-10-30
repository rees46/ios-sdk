import UIKit
@_spi(PersonalizationUI) import REES46

/// "Categories" on Home: the top-level categories of the shop as kit rows with a chevron.
///
/// The list is the `categories` of `getProductsList` without a parent.
/// While it loads — the kit's loader; when it fails — the error text with "Retry"; no categories —
/// the section hides.
final class ShopCategoriesSection: UIStackView {

    struct Item {
        let id: String
        let name: String
    }

    var onSelect: ((Item) -> Void)?

    private var sdk: PersonalizationSDK?
    private var items: [Item] = []
    private var requestSeq = 0
    private let rows = UIStackView()
    private let loaderRow = UIView()
    private let errorState = PersonalizationEmptyState(message: "Couldn't load the categories.")

    init() {
        super.init(frame: .zero)
        axis = .vertical
        spacing = 12

        rows.axis = .vertical
        rows.spacing = 12

        let loader = PersonalizationLoader()
        loader.translatesAutoresizingMaskIntoConstraints = false
        loaderRow.addSubview(loader)
        NSLayoutConstraint.activate([
            loader.centerXAnchor.constraint(equalTo: loaderRow.centerXAnchor),
            loader.topAnchor.constraint(equalTo: loaderRow.topAnchor, constant: 8),
            loader.bottomAnchor.constraint(equalTo: loaderRow.bottomAnchor, constant: -8)
        ])
        loader.startAnimating()

        errorState.actionText = Shop.retryText
        errorState.onAction = { [weak self] in self?.reload() }

        for view in [PersonalizationListLabel(text: "Categories"), loaderRow, errorState, rows] {
            addArrangedSubview(view)
        }
        errorState.isHidden = true
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func load(with sdk: PersonalizationSDK) {
        self.sdk = sdk
        reload()
    }

    private func reload() {
        guard let sdk else { return }
        requestSeq += 1
        let seq = requestSeq
        loaderRow.isHidden = false
        errorState.isHidden = true
        // One product is enough: only the categories of the response are read.
        sdk.getProductsList(limit: 1) { [weak self] result in
            let items = try? result.get().categories
                .filter { !$0.id.isEmpty && ($0.parentId ?? "").isEmpty }
                .map { Item(id: $0.id, name: $0.name) }
            DispatchQueue.main.async {
                guard let self, seq == self.requestSeq else { return }
                self.render(items)
            }
        }
    }

    /// `nil` — the request failed.
    private func render(_ items: [Item]?) {
        loaderRow.isHidden = true
        errorState.isHidden = items != nil
        isHidden = items?.isEmpty == true
        self.items = items ?? []
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, item) in self.items.enumerated() {
            let row = PersonalizationSuggestionRow(kind: .category)
            row.title = item.name
            row.tag = index
            row.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)
            rows.addArrangedSubview(row)
        }
    }

    @objc private func rowTapped(_ row: UIControl) {
        guard items.indices.contains(row.tag) else { return }
        onSelect?(items[row.tag])
    }
}
