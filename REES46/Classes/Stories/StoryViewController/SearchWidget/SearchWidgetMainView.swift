import UIKit

open class SearchWidgetMainView: UIView, SearchResultsViewDelegate {
    
    let width = UIScreen.main.bounds.width
    let height = UIScreen.main.bounds.height
    
    open var recommendSearchCategoryLabel: UILabel!
    open var sdkSearchWidgetCategoriesButtons = [SearchWidgetCategoriesButton]()
    
    open var searchHistoryLabel: UILabel!
    open var searchRecentlyLabel: UILabel!
    
    open var sdkSearchWidgetHistoryViews = [SearchWidgetHistoryView]()
    open var sdkSearchWidgetHistoryButtons = [SearchWidgetHistoryButton]()
    open var clearHistoryButton: UIButton!
    
    var margin: CGFloat = 16
    open var delegate: SearchWidgetMainViewDelegate?
    
    open var sdkSearchWidget = SearchWidget()
    
    private let searchResultsView: SearchResultsView = {
        let view = SearchResultsView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
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
    }
    
    @objc
    open func closeButtonClicked(_ sender: UIButton) {
        sdkSearchWidget.deleteSearchHistories(index: sender.tag)
        self.redrawSearchRecentlyTableView()
    }
    
    open func initView(constructorCategories: [String]) {
        setupMockResults()
        
        setupRecommendSearchCategoryLabel()
        
        setupCategoryButtons(with: constructorCategories)
        
        setupSearchHistoryLabel()
        
        redrawSearchRecentlyTableView()
    }
    
    open func redrawSearchRecentlyTableView() {
        clearOldViews()
        
        let histories = fetchSearchHistories()
        
        let limitedHistories = limitItems(histories)
        
        guard let searchHistoryLabel = searchHistoryLabel else {
            print("searchHistoryLabel is nil")
            return
        }
        
        let scrollView = createScrollView()
        
        let contentHeight = addSearchHistories(to: scrollView, histories: limitedHistories, under: searchHistoryLabel)
        
        configureViewAllButton()
        updateScrollView(scrollView)
        
        setupSearchResultsView(below: contentHeight)
        
        self.delegate?.sdkSearchWidgetMainViewHistoryChanged()
    }
    
    private func setupMockResults() {
        // TODO remove
        let mockResults = createMockResults()
        updateSearchResults(mockResults)
        // TODO remove
    }
    
    private func setupRecommendSearchCategoryLabel() {
        self.recommendSearchCategoryLabel = UILabel(frame: CGRect(x: margin, y: -20, width: width - 40, height: 50))
        self.recommendSearchCategoryLabel.text = ""
        self.recommendSearchCategoryLabel.font = UIFont.boldSystemFont(ofSize: 11)
        self.recommendSearchCategoryLabel.textColor = UIColor.darkGray
        self.addSubview(self.recommendSearchCategoryLabel)
    }
    
    private func setupCategoryButtons(with categories: [String]) {
        let wFont = UIFont.systemFont(ofSize: 12)
        let userAttributes = [NSAttributedString.Key.font: wFont, NSAttributedString.Key.foregroundColor: UIColor.gray]
        
        var formerWidth: CGFloat = margin
        var formerHeight: CGFloat = 12
        
        for i in 0..<categories.count {
            let size = categories[i].size(withAttributes: userAttributes)
            if i > 0 {
                formerWidth = sdkSearchWidgetCategoriesButtons[i - 1].frame.size.width + sdkSearchWidgetCategoriesButtons[i - 1].frame.origin.x + 6
                if formerWidth + size.width + margin > UIScreen.main.bounds.width {
                    formerHeight += sdkSearchWidgetCategoriesButtons[i - 1].frame.size.height + 5
                    formerWidth = margin
                }
            }
            
            let button = createCategoryButton(title: categories[i], at: i, width: size.width + 20, height: size.height + 17, xPosition: formerWidth, yPosition: formerHeight)
            sdkSearchWidgetCategoriesButtons.append(button)
            self.addSubview(button)
        }
    }
    
    private func createCategoryButton(title: String, at index: Int, width: CGFloat, height: CGFloat, xPosition: CGFloat, yPosition: CGFloat) -> SearchWidgetCategoriesButton {
        let button = SearchWidgetCategoriesButton(frame: CGRect(x: xPosition, y: yPosition, width: width, height: height))
        button.addTarget(self, action: #selector(searchWidgetCategoriesButtonClicked(_:)), for: .touchUpInside)
        button.setTitle(title, for: .normal)
        button.tag = index
        
        return button
    }
    
    private func setupSearchHistoryLabel() {
        guard let originY = sdkSearchWidgetCategoriesButtons.last?.frame.origin.y else { return }
        
        self.searchHistoryLabel = UILabel(frame: CGRect(x: margin, y: originY + 40, width: width - 40, height: 40))
        self.searchHistoryLabel.text = "YOUR REQUESTS"
        self.searchHistoryLabel.font = UIFont.boldSystemFont(ofSize: 11)
        self.searchHistoryLabel.textColor = UIColor.darkGray.withAlphaComponent(0.8)
        self.addSubview(self.searchHistoryLabel)
    }
    
    private func clearOldViews() {
        for sdkSearchWidgetHistoryView in sdkSearchWidgetHistoryViews {
            sdkSearchWidgetHistoryView.removeFromSuperview()
        }
        sdkSearchWidgetHistoryViews.removeAll()
        sdkSearchWidgetHistoryButtons.removeAll()
        
        clearHistoryButton?.removeFromSuperview()
    }
    
    private func fetchSearchHistories() -> [String] {
        return sdkSearchWidget.getSearchHistories() ?? []
    }
    
    private func fetchRecentlyViewedProducts() -> [String] {
        return sdkSearchWidget.getSearchHistories() ?? []
    }
    
    private func limitItems(_ items: [String], limit: Int = 5) -> [String] {
        return Array(items.prefix(limit))
    }
    
    private func createScrollView() -> UIScrollView {
        let scrollView = UIScrollView(frame: self.bounds)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(scrollView)
        return scrollView
    }
    
    private func addSearchHistories(to scrollView: UIScrollView, histories: [String], under label: UILabel) -> CGFloat {
        let width = self.bounds.width
        let startY: CGFloat = label.frame.origin.y + label.frame.height
        var contentHeight: CGFloat = 0
        
        for (i, history) in histories.enumerated() {
            let view = createHistoryView(for: history, at: i, yPosition: startY + CGFloat(i * 30), width: width, margin: margin)
            sdkSearchWidgetHistoryViews.append(view)
            sdkSearchWidgetHistoryButtons.append(view.sdkSearchWidgetHistoryButton)
            scrollView.addSubview(view)
            
            contentHeight = view.frame.maxY
        }
        
        return contentHeight
    }
    
    private func setupSearchResultsView(below contentHeight: CGFloat) {
        addSubview(searchResultsView)
        
        NSLayoutConstraint.activate([
            searchResultsView.topAnchor.constraint(equalTo: self.topAnchor, constant: contentHeight + 10),
            searchResultsView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: margin),
            searchResultsView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -margin),
            searchResultsView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    private func createHistoryView(for history: String, at index: Int, yPosition: CGFloat, width: CGFloat, margin: CGFloat) -> SearchWidgetHistoryView {
        let view = SearchWidgetHistoryView(frame: CGRect(x: margin, y: yPosition, width: width - (margin * 2), height: 20))
        view.sdkSearchWidgetHistoryButton.addTarget(self, action: #selector(sdkSearchWidgetHistoryButtonClicked(_:)), for: .touchUpInside)
        view.deleteButton.addTarget(self, action: #selector(closeButtonClicked(_:)), for: .touchUpInside)
        
        view.sdkSearchWidgetHistoryButton.textLabel.text = history
        view.sdkSearchWidgetHistoryButton.tag = index
        view.deleteButton.tag = index
        
        return view
    }
    
    private func configureViewAllButton() {
        let width = self.bounds.width
        
        clearHistoryButton = UIButton(frame: CGRect(x: margin, y: self.bounds.height - 62, width: width - (margin * 2), height: 42))
        clearHistoryButton?.setTitle("View all", for: .normal)
        clearHistoryButton?.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        clearHistoryButton?.setTitleColor(UIColor.sdkDefaultBlackColor, for: .normal)
        clearHistoryButton?.setTitleColor(UIColor.lightGray, for: .highlighted)
        
        clearHistoryButton?.layer.cornerRadius = 6
        clearHistoryButton?.layer.borderWidth = 1.4
        clearHistoryButton?.layer.masksToBounds = true
        clearHistoryButton?.layer.borderColor = UIColor.sdkDefaultBlackColor.cgColor
        
        clearHistoryButton?.addTarget(self, action: #selector(clearHistoryButtonClicked), for: .touchUpInside)
        self.addSubview(clearHistoryButton!)
    }
    
    private func updateScrollView(_ scrollView: UIScrollView) {
        let width = self.bounds.width
        scrollView.frame = CGRect(x: 0, y: 0, width: width, height: self.bounds.height - (clearHistoryButton?.frame.height ?? 0) - 20)
    }
    
    private func createMockResults() -> [SearchResult] {
        return [
            SearchResult(image: "image1.png", name: "Mock Product 1", price: 10.0),
            SearchResult(image: "image2.png", name: "Mock Product 2", price: 15.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image3.png", name: "Mock Product 3", price: 20.0),
            SearchResult(image: "image4.png", name: "Mock Product 4", price: 25.0)
        ]
    }
    open func updateSearchResults(_ results: [SearchResult]) {
        searchResultsView.updateResults(createMockResults())
        searchResultsView.isHidden = results.isEmpty
    }
    
    open func didSelectResult(_ result: SearchResult) {
        print("Выбран результат didSelectResult: \(result.name)")
    }
}
