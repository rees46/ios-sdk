import UIKit
import REES46

class SearchViewController: SearchWidgetViewController, SearchWidgetDelegate {
    
    private let activityIndicator: UIActivityIndicatorView
    private var searchWorkItem: DispatchWorkItem?
    private var suggestsCategories: [Suggest]?
    private var lastQueriesHistories: [Query]?
    public var sdk: PersonalizationSDK?
    
    private let debounceInterval: TimeInterval = 1.0
    private var searchDebounceTimer: Timer?
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        if #available(iOS 13.0, *) {
            activityIndicator = UIActivityIndicatorView(style: .medium)
        } else {
            activityIndicator = UIActivityIndicatorView(style: .gray)
        }
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        if #available(iOS 13.0, *) {
            activityIndicator = UIActivityIndicatorView(style: .medium)
        } else {
            activityIndicator = UIActivityIndicatorView(style: .gray)
        }
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.startBlankSearch()
        self.sdkSearchWidgetInit()
        self.delegate = self
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        self.setSearchWidgetCategoriesButtonType(type: .blacked)
        
        activityIndicator.hidesWhenStopped = true
        activityIndicator.center = view.center
        view.addSubview(activityIndicator)
    }
    
    func startBlankSearch() {
        sdk?.searchBlank { searchResponse in
            switch searchResponse {
            case let .success(response):
                self.suggestsCategories = response.suggests
                self.lastQueriesHistories = response.lastQueries
                let searchResults = response.products.map {
                    SearchResult(image: $0.imageUrl, name: $0.name, price: $0.price)
                }
                self.delegate?.updateSearchResults(searchResults)
            case let .failure(error):
                print("Error:", error)
            }
        }
    }
    
    private func showProgress(isShow: Bool){
        DispatchQueue.main.async {
            if isShow{
                self.activityIndicator.startAnimating()
            }else{
                self.activityIndicator.stopAnimating()
            }
        }
    }
    
    func sdkSearchWidgetListViewDidScroll() {
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.endEditing(true)
    }
    
    func sdkSearchWidgetHistoryButtonClicked(productText: String) {
        self.pushDetailViewController(productText: productText)
    }
    
    func searchWidgetCategoriesButtonClicked(productText: String) {
        print("CLICK Controller \(productText)")
        performSearch(query: productText)
    }
    
    func sdkSearchWidgetListViewClicked(productKey: String) {
        self.pushDetailViewController(productText: productKey)
    }
    
    func sdkSearchWidgetListViewClicked(object: Any) {
        print(object)
    }
    
    func sdkSearchWidgetListView(_ sdkSearchWidgetListView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.sdkSearchWidgetView.sdkSearchWidgetListView.dequeueReusableCell(withIdentifier: SearchWidgetListViewCell.ID) as! SearchWidgetListViewCell
        if let sModel = self.sdkSearchWidgetView.sdkSearchWidgetListView.searchResultDatabase[indexPath.row] as? MainSearchModel {
            cell.searchLabel.text = sModel.key
        }
        
        return cell
    }
    
    func sdkSearchWidgetListView(_ sdkSearchWidgetListView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let sModel = self.sdkSearchWidgetView.sdkSearchWidgetListView.searchResultDatabase[indexPath.row] as? MainSearchModel, let kValue = sModel.key {
            self.sdkSearchWidgetView.sdkSearchWidgetListView.sdkSearchWidgetListViewDelegate?.sdkSearchWidgetListViewClicked(productKey: kValue)
            self.sdkSearchWidgetView.sdkSearchWidgetListView.sdkSearchWidgetListViewDelegate?.sdkSearchWidgetListViewClicked(object: self.sdkSearchWidgetView.sdkSearchWidgetListView.database[indexPath.row])
            self.sdkSearchWidgetView.sdkSearchWidgetListView.sdkSearchWidget.appendSearchHistories(value: kValue)
        }
    }
    
    func pushDetailViewController(productText: String) {
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func sdkSearchWidgetTextFieldTextChanged(_ textField: UITextField) {
        super.sdkSearchWidgetTextFieldTextChanged(textField)
        
        guard let query = textField.text, !query.isEmpty else {
            showProgress(isShow: false)
            return
        }
        
        searchDebounceTimer?.invalidate()
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            self?.performSearch(query: query)
        }
    }
    
    private func performSearch(query: String) {
        showProgress(isShow: true)
        
        self.sdk?.search(query: query) { [weak self] response in
            self?.showProgress(isShow: false)
            
            switch response {
            case let .success(response):
                let searchResults = response.products.map {
                    SearchResult(image: $0.imageUrl, name: $0.name, price: $0.price)
                }
                self?.delegate?.updateSearchResults(searchResults)
                
            case let .failure(error):
                print("Error occurred during search:", error)
            }
        }
    }
    
    func updateSearchResults(_ results: [SearchResult]) {
        if let mainView = self.sdkSearchWidgetView.sdkSearchWidgetMainView {
            mainView.updateSearchResults(results)
        }
    }
}

class SearchWidgetDropDownMenu: MainSearchModel {
}

class SearchWidgetData: MainSearchModel {
}

class SearchWidgetExpandableCell: MainSearchModel {
}
