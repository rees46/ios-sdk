import UIKit

open class SearchWidgetMainView: UIView {
    let width = UIScreen.main.bounds.width
    let height = UIScreen.main.bounds.height

    open var recommendSearchCategoryLabel: UILabel!
    open var sdkSearchWidgetCategoriesButtons = [SearchWidgetCategoriesButton]()
    
    open var searchHistoryLabel: UILabel!
    open var searchRecentlyLabel: UILabel!
    
    open var sdkSearchWidgetHistoryViews = [SearchWidgetHistoryView]()
    open var sdkSearchWidgetHistoryButtons = [SearchWidgetHistoryButton]()
    open var clearHistoryButton: UIButton!
    
    var margin: CGFloat = 15
    open var delegate: SearchWidgetMainViewDelegate?
    
    open var sdkSearchWidget = SearchWidget()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        guard let constructorCategories = SearchWidget.shared.getCategories() else {
            return
        }
        
        self.initView(constructorCategories: constructorCategories)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open func setSearchWidgetCategoriesButtonType(type: SearchWidgetCategoriesButtonType) {
        for searchWidgetCategoriesButton in self.sdkSearchWidgetCategoriesButtons {
            searchWidgetCategoriesButton.type = type
        }
    }
    
    @objc
    open func searchWidgetCategoriesButtonClicked(_ sender: UIButton) {
        guard let productText = sdkSearchWidgetCategoriesButtons[sender.tag].titleLabel?.text else {
            return
        }
        sdkSearchWidget.appendSearchHistories(value: productText)
        self.delegate?.searchWidgetCategoriesButtonClicked(productText: productText)
    }
    
    @objc
    open func sdkSearchWidgetHistoryButtonClicked(_ sender: UIButton) {
        guard let productText = sdkSearchWidgetHistoryButtons[sender.tag].textLabel.text else {
            return
        }
        self.delegate?.sdkSearchWidgetHistoryButtonClicked(productText: productText)
    }
    
    @objc
    open func clearHistoryButtonClicked() {
        //sdkSearchWidget.setSearchHistories(value: [String]())
        //self.redrawSearchRecentlyTableView()
    }
    
    @objc
    open func closeButtonClicked(_ sender: UIButton) {
        sdkSearchWidget.deleteSearchHistories(index: sender.tag)
        self.redrawSearchRecentlyTableView()
    }
    
    open func initView(constructorCategories: [String]) {
//        self.recommendSearchCategoryLabel = UILabel(frame: CGRect(x: margin, y: -20, width: width - 40, height: 50))
//        self.recommendSearchCategoryLabel.text = ""
//        self.recommendSearchCategoryLabel.font = UIFont.boldSystemFont(ofSize: 11)
//        self.recommendSearchCategoryLabel.textColor = UIColor.darkGray
//        self.addSubview(self.recommendSearchCategoryLabel)
        
        let wFont = UIFont.systemFont(ofSize: 12)
        let userAttributes = [NSAttributedString.Key.font: wFont, NSAttributedString.Key.foregroundColor: UIColor.gray]
        
        var formerWidth: CGFloat = margin
        var formerHeight: CGFloat = 12
        
        for i in 0..<constructorCategories.count {
            let size = constructorCategories[i].size(withAttributes: userAttributes)
            if i > 0 {
                formerWidth = sdkSearchWidgetCategoriesButtons[i-1].frame.size.width + sdkSearchWidgetCategoriesButtons[i-1].frame.origin.x + 6
                if formerWidth + size.width + margin > UIScreen.main.bounds.width {
                    formerHeight += sdkSearchWidgetCategoriesButtons[i-1].frame.size.height + 5
                    formerWidth = margin
                }
            }
            let button = SearchWidgetCategoriesButton(frame: CGRect(x: formerWidth, y: formerHeight, width: size.width + 20, height: size.height + 17))
            button.addTarget(self, action: #selector(searchWidgetCategoriesButtonClicked(_:)), for: .touchUpInside)
            button.setTitle(constructorCategories[i], for: .normal)
            button.tag = i
            
            sdkSearchWidgetCategoriesButtons.append(button)
            self.addSubview(button)
            
        }
        guard let originY = sdkSearchWidgetCategoriesButtons.last?.frame.origin.y else {
            return
        }
        
        self.searchHistoryLabel = UILabel(frame: CGRect(x: margin, y: originY + 40, width: width - 40, height: 40))
        self.searchHistoryLabel.text = "YOUR REQUESTS"
        self.searchHistoryLabel.font = UIFont.boldSystemFont(ofSize: 11)
        self.searchHistoryLabel.textColor = UIColor.darkGray.withAlphaComponent(0.8)
        self.addSubview(self.searchHistoryLabel)
        
        self.searchRecentlyLabel = UILabel(frame: CGRect(x: margin, y: originY + 270, width: width - 40, height: 40))
        self.searchRecentlyLabel.text = "RECENTLY VIEWED PRODUCTS"
        self.searchRecentlyLabel.font = UIFont.boldSystemFont(ofSize: 11)
        self.searchRecentlyLabel.textColor = UIColor.darkGray.withAlphaComponent(0.8)
        //self.addSubview(self.searchRecentlyLabel)
        
        redrawSearchRecentlyTableView()
    }
    
    open func redrawSearchRecentlyTableView() {
        for sdkSearchWidgetHistoryView in sdkSearchWidgetHistoryViews {
            sdkSearchWidgetHistoryView.removeFromSuperview()
        }
        sdkSearchWidgetHistoryViews.removeAll()
        sdkSearchWidgetHistoryButtons.removeAll()

        if self.clearHistoryButton != nil {
            self.clearHistoryButton.removeFromSuperview()
        }
        
        let histories = sdkSearchWidget.getSearchHistories() ?? [String]()
        let recently = sdkSearchWidget.getSearchHistories() ?? [String]()
        
        let searchHistoryLabelOriginY: CGFloat = searchHistoryLabel.frame.origin.y + searchHistoryLabel.frame.height
        
        for i in 0..<histories.count {
            let view = SearchWidgetHistoryView(frame: CGRect(x: margin, y: searchHistoryLabelOriginY + CGFloat(i * 30) , width: width - (margin * 2), height: 20))
            view.sdkSearchWidgetHistoryButton.addTarget(self, action: #selector(sdkSearchWidgetHistoryButtonClicked(_:)), for: .touchUpInside)
            view.deleteButton.addTarget(self, action: #selector(closeButtonClicked(_:)), for: .touchUpInside)

            view.sdkSearchWidgetHistoryButton.textLabel.text = histories[i]
            view.sdkSearchWidgetHistoryButton.tag = i
            view.deleteButton.tag = i
            
            sdkSearchWidgetHistoryViews.append(view)
            sdkSearchWidgetHistoryButtons.append(view.sdkSearchWidgetHistoryButton)
            self.addSubview(view)
        }
        
        let searchRecentlyLabelOriginY: CGFloat = searchHistoryLabel.frame.origin.y + searchHistoryLabel.frame.height
        
        for i in 0..<recently.count {
            let view = SearchWidgetHistoryView(frame: CGRect(x: margin, y: searchRecentlyLabelOriginY + CGFloat(i * 30) , width: width - (margin * 2), height: 20))
            view.sdkSearchWidgetHistoryButton.addTarget(self, action: #selector(sdkSearchWidgetHistoryButtonClicked(_:)), for: .touchUpInside)
            view.deleteButton.addTarget(self, action: #selector(closeButtonClicked(_:)), for: .touchUpInside)

            view.sdkSearchWidgetHistoryButton.textLabel.text = recently[i]
            view.sdkSearchWidgetHistoryButton.tag = i
            view.deleteButton.tag = i
            
            sdkSearchWidgetHistoryViews.append(view)
            sdkSearchWidgetHistoryButtons.append(view.sdkSearchWidgetHistoryButton)
            self.addSubview(view)
        }
        
        let lastHistoryView = self.sdkSearchWidgetHistoryViews.last ?? SearchWidgetHistoryView()
        
        self.clearHistoryButton = UIButton(frame: CGRect(x: margin, y: lastHistoryView.frame.origin.y + lastHistoryView.frame.height + 20, width: width - (margin * 2), height: 42))
        self.clearHistoryButton.setTitle("View all", for: .normal)
        //self.clearHistoryButton.setTitle("CLEAR SEARCH HISTORY", for: .normal)
        self.clearHistoryButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        self.clearHistoryButton.setTitleColor(UIColor.sdkDefaultBlackColor, for: .normal)
        self.clearHistoryButton.setTitleColor(UIColor.lightGray, for: .highlighted)
        
        self.clearHistoryButton.layer.cornerRadius = 6
        self.clearHistoryButton.layer.borderWidth = 1.4
        self.clearHistoryButton.layer.masksToBounds = true
        self.clearHistoryButton.layer.borderColor = UIColor.sdkDefaultBlackColor.cgColor
        
        self.clearHistoryButton.addTarget(self, action: #selector(clearHistoryButtonClicked), for: .touchUpInside)
        self.addSubview(clearHistoryButton)
        
        self.delegate?.sdkSearchWidgetMainViewHistoryChanged()
    }
}
