import UIKit

open class SearchWidgetMainView: UIView, SearchResultsViewDelegate {
    
    open var delegate: SearchWidgetMainViewDelegate?

    open var sdkSearchWidgetCategoriesButtons = [SearchWidgetCategoriesButton]()
    open var sdkSearchWidgetHistoryButtons = [SearchWidgetHistoryButton]()
    open var sdkSearchWidgetHistoryViews = [SearchWidgetHistoryView]()
    open var sdkSearchWidget = SearchWidget()
    open var recommendSearchCategoryLabel: UILabel!
    open var searchRecentlyLabel: UILabel!
    open var searchHistoryLabel: UILabel!
    open var showAllButton: UIButton!

    let height = UIScreen.main.bounds.height
    let width = UIScreen.main.bounds.width

    var margin: CGFloat = 16

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
    open func showAllButtonClicked() {
        //TODO handle click
    }
    
    @objc
    open func closeButtonClicked(_ sender: UIButton) {
        sdkSearchWidget.deleteSearchHistories(index: sender.tag)
        self.redrawSearchRecentlyTableView()
    }
    
    open func initView(constructorCategories: [String]) {
        setupRecommendSearchCategoryLabel()
        setupCategoryButtons(with: constructorCategories)
        setupSearchHistoryLabel()
        redrawSearchRecentlyTableView()
    }
    
    open func redrawSearchRecentlyTableView() {
        clearOldViews()
        
        guard let searchHistoryLabel = searchHistoryLabel else {
            print("searchHistoryLabel is nil")
            return
        }
        
        let scrollView = createScrollView()
        configureViewAllButton()
        updateScrollView(scrollView)
        setupSearchResultsView(
            below: addSearchHistories(
                to: scrollView,
                histories: limitItems(fetchSearchHistories()),
                under: searchHistoryLabel
            )
        )
        self.delegate?.sdkSearchWidgetMainViewHistoryChanged()
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
        
        showAllButton?.removeFromSuperview()
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
            searchResultsView.heightAnchor.constraint(equalToConstant: 320)
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
        showAllButton = UIButton()
        showAllButton?.setTitle("View all", for: .normal)
        showAllButton?.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        showAllButton?.setTitleColor(UIColor.sdkDefaultBlackColor, for: .normal)
        showAllButton?.setTitleColor(UIColor.lightGray, for: .highlighted)
        
        showAllButton?.layer.cornerRadius = 6
        showAllButton?.layer.borderWidth = 1.4
        showAllButton?.layer.masksToBounds = true
        showAllButton?.layer.borderColor = UIColor.sdkDefaultBlackColor.cgColor
        
        showAllButton?.addTarget(self, action: #selector(showAllButtonClicked), for: .touchUpInside)
        showAllButton?.translatesAutoresizingMaskIntoConstraints = false
        
        self.addSubview(showAllButton!)
        
        NSLayoutConstraint.activate([
            showAllButton!.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor, constant: -70),
            showAllButton!.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: margin),
            showAllButton!.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -margin),
            showAllButton!.heightAnchor.constraint(equalToConstant: 42)
        ])
    }
    
    private func updateScrollView(_ scrollView: UIScrollView) {
        let width = self.bounds.width
        scrollView.frame = CGRect(x: 0, y: 0, width: width, height: self.bounds.height - (showAllButton?.frame.height ?? 0) - 20)
    }
    
    open func updateSearchResults(_ results: [SearchResult]) {
        DispatchQueue.main.async {
            print("SEARCH RESULT: \(results)")
            self.searchResultsView.updateResults(results)
            self.searchResultsView.isHidden = results.isEmpty
        }
    }
    
    open func didSelectResult(_ result: SearchResult) {
        print("didSelectResult: \(result.name)")
    }
}
