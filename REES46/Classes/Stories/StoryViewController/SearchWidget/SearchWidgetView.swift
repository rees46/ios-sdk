import UIKit

open class SearchWidgetView: UIView, SearchWidgetMainViewDelegate, SearchWidgetListViewDelegate {
    
    open var delegate: SearchWidgetDelegate?
    
    open var sdkSearchWidgetScrollView: UIScrollView!
    open var sdkSearchWidgetMainView: SearchWidgetMainView!
    open var sdkSearchWidgetListView: SearchWidgetListView!
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
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
    
    open func scrollViewDidScroll() {
        self.delegate?.sdkSearchWidgetListViewDidScroll()
    }
    
    open func searchWidgetCategoriesButtonClicked(productSearchText: String) {
        self.delegate?.searchWidgetCategoriesButtonClicked(productSearchText: productSearchText)
    }
    
    public func sdkSearchWidgetHistoryButtonClickedOpenProductCard(productId: String, productName: String, productPrice: String, productImage: String, productImagesArray: String) {
        self.delegate?.sdkSearchWidgetHistoryButtonClickedOpenProductCard(productId: productId, productName: productName, productPrice: productPrice, productImage: productImage, productImagesArray: productImagesArray)
    }
    
    open func sdkSearchWidgetHistoryButtonClickedStart(productSearchText: String) {
        self.delegate?.sdkSearchWidgetHistoryButtonClickedStart(productSearchText: productSearchText)
    }
    
    open func sdkSearchWidgetHistoryButtonClicked(productSearchText: String) {
        self.delegate?.sdkSearchWidgetHistoryButtonClicked(productSearchText: productSearchText)
    }
    
    open func sdkSearchWidgetHistoryButtonClickedFull(productSearchText: String) {
        self.delegate?.sdkSearchWidgetHistoryButtonClickedFull(productSearchText: productSearchText)
    }
    
    public func reloadBlankSearch() {
        self.delegate?.reloadBlankSearch()
    }
    
    open func resetSearchToSimple() {
        self.delegate?.resetSearchToSimple()
    }
    
    open func sdkSearchWidgetListViewClicked(productSearchKey: String) {
        self.delegate?.sdkSearchWidgetListViewClicked(productSearchKey: productSearchKey)
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
