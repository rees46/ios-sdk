import UIKit

open class SearchWidgetListView: UITableView, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate {
    open var database = [Any]()
    open var searchResultDatabase = [Any]()
    
    open var sdkSearchWidgetListViewDelegate: SearchWidgetListViewDelegate?
    open var sdkSearchWidget = SearchWidget()
    
    open var sdkSearchWidgetTextFieldEnteredText: String? {
        didSet {
            guard let searchFieldText = sdkSearchWidgetTextFieldEnteredText else {
                return
            }
            
            let objectification = Objectification(objects: database, type: .all)
            let result = objectification.objects(contain: searchFieldText)
            
            UserDefaults.standard.set(searchFieldText, forKey: "viewAllSearchResultsButtonClickedFull")
            
            self.searchResultDatabase = result
            if searchFieldText.isEmpty {
                self.initData(database: database)
            }
            self.reloadData()
        }
    }
    
    public override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        self.initView()
    }
    
    open func initData(database: [Any]) {
        self.database = database
        self.searchResultDatabase = database
        
        self.reloadData()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = self.sdkSearchWidgetListViewDelegate?.sdkSearchWidgetListView(tableView, cellForRowAt: indexPath) else {
            return UITableViewCell()
        }
        return cell
    }
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResultDatabase.count
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.sdkSearchWidgetListViewDelegate?.sdkSearchWidgetListView(tableView, didSelectRowAt: indexPath)
    }
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.sdkSearchWidgetListViewDelegate?.sdkSearchWidgetListViewDidScroll()
    }
    
    open func initView() {
        self.delegate = self
        self.dataSource = self
        self.register(SearchWidgetListViewCell.self, forCellReuseIdentifier: SearchWidgetListViewCell.ID)
    }
}
