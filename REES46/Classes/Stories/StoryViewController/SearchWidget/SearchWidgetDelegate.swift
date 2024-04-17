import UIKit

public protocol SearchWidgetDelegate: SearchWidgetMainViewDelegate, SearchWidgetListViewDelegate { }

public protocol SearchWidgetMainViewDelegate {
    func searchWidgetCategoriesButtonClicked(searchProductText: String)
    
    func sdkSearchWidgetHistoryButtonClickedStart(searchProductText: String)
    
    func sdkSearchWidgetHistoryButtonClicked(searchProductText: String)
    
    func sdkSearchWidgetHistoryButtonClickedFull(searchProductText: String)
    
    func reloadBlankSearch()
    
    func resetSearchToSimple()
    
    func minimizeSearchTextField()
    
    func sdkSearchWidgetHistoryButtonClickedOpenProductCard(productId: String, productName: String, productPrice: String, productImage: String, productImagesArray: String)

    func sdkSearchWidgetMainViewHistoryChanged()
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
        //
    }
}


public extension SearchWidgetListViewDelegate {
    func sdkSearchWidgetListViewClicked(object: Any) {
        //
    }
    
    func sdkSearchWidgetListViewDidScroll() {
        //
    }
}


