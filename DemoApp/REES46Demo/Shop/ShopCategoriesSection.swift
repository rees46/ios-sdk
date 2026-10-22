import UIKit
@_spi(PersonalizationUI) import REES46

/// "Categories" on Home: the top-level categories of the shop as kit rows with a chevron.
///
/// The list is the `categories` of the `products` response (the request behind `getProductsList`)
/// without a parent. `ProductsListResponse` on iOS does not carry `categories`, so the section sends
/// that same request through the SDK's raw `getRequest` and reads them from the JSON.
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
        // The parameters `getProductsList` sends; one product is enough — only the categories are read.
        var params = ["shop_id": sdk.shopId, "limit": "1"]
        if !sdk.deviceId.isEmpty { params["did"] = sdk.deviceId }
        if !sdk.userSeance.isEmpty {
            params["seance"] = sdk.userSeance
            params["sid"] = sdk.userSeance
        }
        sdk.getRequest(path: "products", params: params, false) { [weak self] result in
            let items: [Item]?
            if case .success(let json) = result {
                items = Self.topLevel(json["categories"] as? [[String: Any]] ?? [])
            } else {
                items = nil
            }
            DispatchQueue.main.async {
                guard let self, seq == self.requestSeq else { return }
                self.render(items)
            }
        }
    }

    /// Categories without a parent. Ids come as strings or numbers depending on the shop.
    static func topLevel(_ categories: [[String: Any]]) -> [Item] {
        categories.compactMap { category in
            guard let id = string(category["id"]), let name = string(category["name"]) else { return nil }
            let parent = string(category["parent"]) ?? string(category["parent_id"])
            return parent == nil ? Item(id: id, name: name) : nil
        }
    }

    private static func string(_ value: Any?) -> String? {
        let text = (value as? String) ?? (value as? NSNumber)?.stringValue
        guard let text, !text.isEmpty else { return nil }
        return text
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
