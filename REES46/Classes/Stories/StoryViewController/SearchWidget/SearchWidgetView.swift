import UIKit

open class SearchWidgetView: UIView, SearchWidgetMainViewDelegate, SearchWidgetListViewDelegate {
    
    open var delegate: SearchWidgetDelegate?
    
    open var sdkSearchWidgetScrollView: UIScrollView!
    open var sdkSearchWidgetMainView: SearchWidgetMainView!
    open var sdkSearchWidgetListView: SearchWidgetListView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.sdkSearchWidgetScrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height + 300))
        
        self.sdkSearchWidgetMainView = SearchWidgetMainView(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height + 700))
        self.sdkSearchWidgetMainView.delegate = self
        self.sdkSearchWidgetScrollView.addSubview(self.sdkSearchWidgetMainView)
        
        self.sdkSearchWidgetListView = SearchWidgetListView(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height + 400))
        self.sdkSearchWidgetListView.sdkSearchWidgetListViewDelegate = self
        self.sdkSearchWidgetListView.isHidden = true
        
        if let viewAllSearchResultsButton = self.sdkSearchWidgetMainView.viewAllSearchResultsButton {
            
            let size = CGSize(width: self.frame.width, height: self.sdkSearchWidgetMainView.viewAllSearchResultsButton.frame.origin.y + self.sdkSearchWidgetMainView.viewAllSearchResultsButton.frame.height + 1000)
            self.sdkSearchWidgetScrollView.contentSize = size
        } else {
            self.sdkSearchWidgetScrollView.contentSize = CGSize(width: self.frame.width, height: self.frame.height + 500)
        }
        
        self.sdkSearchWidgetScrollView.addSubview(self.sdkSearchWidgetListView)
        self.sdkSearchWidgetScrollView.resignFirstResponder()
        self.addSubview(sdkSearchWidgetScrollView)
    }
    
    open func sdkSearchWidgetMainViewHistoryChanged() {
        let size = CGSize(width: self.frame.width - 100, height: self.sdkSearchWidgetMainView.viewAllSearchResultsButton.frame.origin.y + self.sdkSearchWidgetMainView.viewAllSearchResultsButton.frame.height + 1400)
        self.sdkSearchWidgetScrollView.contentSize = size
        self.sdkSearchWidgetMainView.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: size)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open func scrollViewDidScroll() {
        self.delegate?.sdkSearchWidgetListViewDidScroll()
    }
    
    open func searchWidgetCategoriesButtonClicked(searchProductText: String) {
        self.delegate?.searchWidgetCategoriesButtonClicked(searchProductText: searchProductText)
    }
    
    public func sdkSearchWidgetHistoryButtonClickedOpenProductCard(productId: String, productName: String, productPrice: String, productImage: String, productImagesArray: String) {
        self.delegate?.sdkSearchWidgetHistoryButtonClickedOpenProductCard(productId: productId, productName: productName, productPrice: productPrice, productImage: productImage, productImagesArray: productImagesArray)
    }
    
    open func sdkSearchWidgetHistoryButtonClickedStart(searchProductText: String) {
        self.delegate?.sdkSearchWidgetHistoryButtonClickedStart(searchProductText: searchProductText)
    }
    
    open func sdkSearchWidgetHistoryButtonClicked(searchProductText: String) {
        self.delegate?.sdkSearchWidgetHistoryButtonClicked(searchProductText: searchProductText)
    }
    
    open func sdkSearchWidgetHistoryButtonClickedFull(searchProductText: String) {
        self.delegate?.sdkSearchWidgetHistoryButtonClickedFull(searchProductText: searchProductText)
    }
    
    public func reloadBlankSearch() {
        self.delegate?.reloadBlankSearch()
    }
    
    open func resetSearchToSimple() {
        self.delegate?.resetSearchToSimple()
    }
    
    open func sdkSearchWidgetListViewClicked(productKey: String) {
        self.delegate?.sdkSearchWidgetListViewClicked(productKey: productKey)
    }
    
    open func sdkSearchWidgetListViewClicked(object: Any) {
        self.delegate?.sdkSearchWidgetListViewClicked(object: object)
    }
    
    open func sdkSearchWidgetListView(_ sdkSearchWidgetListView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = self.delegate?.sdkSearchWidgetListView(sdkSearchWidgetListView, cellForRowAt: indexPath) else {
            return UITableViewCell()
        }
        return cell
    }

    open func sdkSearchWidgetListView(_ sdkSearchWidgetListView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.delegate?.sdkSearchWidgetListView(sdkSearchWidgetListView, didSelectRowAt: indexPath)
    }
    
    open func sdkSearchWidgetListViewDidScroll() {
        self.delegate?.sdkSearchWidgetListViewDidScroll()
    }
    
    public func minimizeSearchTextField() {
        self.delegate?.minimizeSearchTextField()
    }
}
