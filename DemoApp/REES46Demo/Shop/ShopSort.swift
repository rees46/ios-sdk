import UIKit
@_spi(PersonalizationUI) import REES46

/// Sorting of the shop's results and categories. The kit's design has no sort picker, so the shop
/// shows a plain action sheet from the screen's sort button; the choice goes to the screen's
/// `sortBy` / `sortDir`, and the screen loads the first page again.
enum ShopSort: CaseIterable {
    case relevance, priceAscending, priceDescending, discount

    var title: String {
        switch self {
        case .relevance: return "Relevance"
        case .priceAscending: return "Price: low to high"
        case .priceDescending: return "Price: high to low"
        case .discount: return "Discount"
        }
    }

    /// `sort_by` / `sort_dir` of the request; relevance is no sorting at all.
    var params: (sortBy: String?, sortDir: String?) {
        switch self {
        case .relevance: return (nil, nil)
        case .priceAscending: return ("price", "asc")
        case .priceDescending: return ("price", "desc")
        case .discount: return ("discount", "desc")
        }
    }

    /// The sort button of `screen` opens the picker over `host`.
    static func attach<Item>(to screen: PersonalizationResultsScreen<Item>, host: UIViewController) {
        screen.onSortTap = { [weak screen, weak host] in
            guard let screen, let host else { return }
            let sheet = UIAlertController(title: "Sort by", message: nil, preferredStyle: .actionSheet)
            for option in allCases {
                let selected = option.params == (screen.sortBy, screen.sortDir)
                sheet.addAction(UIAlertAction(title: selected ? "✓ \(option.title)" : option.title, style: .default) { _ in
                    screen.sortBy = option.params.sortBy
                    screen.sortDir = option.params.sortDir
                })
            }
            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            // On iPad the sheet is a popover and needs an anchor: the screen's header.
            sheet.popoverPresentationController?.sourceView = screen.title
            sheet.popoverPresentationController?.sourceRect = screen.title.bounds
            host.present(sheet, animated: true)
        }
    }
}
