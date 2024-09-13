import UIKit

public protocol SearchWidgetDelegate: SearchWidgetMainViewDelegate, SearchWidgetListViewDelegate { }

public protocol SearchWidgetMainViewDelegate {
    func searchWidgetCategoriesButtonClicked(productText: String)
    func sdkSearchWidgetHistoryButtonClicked(productText: String)
    func sdkSearchWidgetMainViewHistoryChanged()
    func updateSearchResults(
        _ results: [SearchResult],
        sdk:PersonalizationSDK?
    )
}

public protocol SearchWidgetListViewDelegate {
    func sdkSearchWidgetListViewClicked(productKey: String)
    func sdkSearchWidgetListViewClicked(object: Any)
    func sdkSearchWidgetListView(_ sdkSearchWidgetListView: UITableView, didSelectRowAt indexPath: IndexPath)
    func sdkSearchWidgetListView(_ sdkSearchWidgetListView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    func sdkSearchWidgetListViewDidScroll()
}

public extension SearchWidgetMainViewDelegate {
    func sdkSearchWidgetMainViewHistoryChanged() {
        // Default implementation
    }
}

public extension SearchWidgetListViewDelegate {
    func sdkSearchWidgetListViewClicked(object: Any) {
        // Default implementation
    }
    
    func sdkSearchWidgetListViewDidScroll() {
        // Default implementation
    }
}
