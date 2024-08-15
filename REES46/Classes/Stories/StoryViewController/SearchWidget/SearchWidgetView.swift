import UIKit

open class SearchWidgetView: UIView, SearchWidgetMainViewDelegate, SearchWidgetListViewDelegate {
    open var delegate: SearchWidgetDelegate?
    
    open var sdkSearchWidgetScrollView: UIScrollView!
    open var sdkSearchWidgetMainView: SearchWidgetMainView!
    open var sdkSearchWidgetListView: SearchWidgetListView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.sdkSearchWidgetScrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        
        self.sdkSearchWidgetMainView = SearchWidgetMainView(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        self.sdkSearchWidgetMainView.delegate = self
        self.sdkSearchWidgetScrollView.addSubview(self.sdkSearchWidgetMainView)
        
        self.sdkSearchWidgetListView = SearchWidgetListView(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))
        self.sdkSearchWidgetListView.sdkSearchWidgetListViewDelegate = self
        self.sdkSearchWidgetListView.isHidden = true
        
        if let clearHistoryButton = self.sdkSearchWidgetMainView.clearHistoryButton {
        self.sdkSearchWidgetScrollView.contentSize = CGSize(width: self.frame.width, height: clearHistoryButton.frame.origin.y + clearHistoryButton.frame.height + 20)
        } else {
            self.sdkSearchWidgetScrollView.contentSize = CGSize(width: self.frame.width, height: self.frame.height)
        }
        self.sdkSearchWidgetScrollView.addSubview(self.sdkSearchWidgetListView)
        
        self.addSubview(sdkSearchWidgetScrollView)
    }
    
    open func sdkSearchWidgetMainViewHistoryChanged() {
        let size = CGSize(width: self.frame.width, height: self.sdkSearchWidgetMainView.clearHistoryButton.frame.origin.y + self.sdkSearchWidgetMainView.clearHistoryButton.frame.height + 20)
        self.sdkSearchWidgetScrollView.contentSize = size
        self.sdkSearchWidgetMainView.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: size)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open func scrollViewDidScroll() {
        self.delegate?.sdkSearchWidgetListViewDidScroll()
    }
    
    open func searchWidgetCategoriesButtonClicked(productText: String) {
        self.delegate?.searchWidgetCategoriesButtonClicked(productText: productText)
    }
    
    open func sdkSearchWidgetHistoryButtonClicked(productText: String) {
        self.delegate?.sdkSearchWidgetHistoryButtonClicked(productText: productText)
    }
    
    open func sdkSearchWidgetListViewClicked(productKey: String) {
        self.delegate?.sdkSearchWidgetListViewClicked(productKey: productKey)
    }
    
    open func sdkSearchWidgetListViewClicked(object: Any) {
        self.delegate?.sdkSearchWidgetListViewClicked(object: object)
    }
    
    open func loadSearchData() {
//        self.delegate?.loadSearchData()
    }
    
    open func updateSearchResults(_ results: [SearchResult]) {
        self.delegate?.updateSearchResults(results)
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
}
