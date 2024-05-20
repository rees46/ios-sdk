import UIKit
import PersonaClick

class SearchViewController: SearchWidgetViewController, SearchWidgetDelegate {
    
    private var suggestsCategories: [Suggest]?
    
    private var lastQueriesHistories: [Query]?
    
    public var sdk: PersonalizationSDK?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.startBlankSearch()
        
        self.sdkSearchWidgetInit()
        
        self.delegate = self
        
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        self.setSearchWidgetCategoriesButtonType(type: .blacked)
    }
    
    func startBlankSearch() {
        sdk?.searchBlank { searchResponse in
            switch searchResponse {
            case let .success(response):
                
                self.suggestsCategories = response.suggests
                self.lastQueriesHistories = response.lastQueries
                
                var productRecommendationsArray = [String]()
                for item in response.suggests {
                    let product = item.name
                    productRecommendationsArray.append(product)
                }
                
                var productLastQueriesArray = [String]()
                for item in response.lastQueries {
                    let product = item.name
                    productLastQueriesArray.append(product)
                }
                
                var productPopularArray = [String]()
                for item in response.products {
                    let product = item.name
                    productPopularArray.append(product)
                }
                
                if productLastQueriesArray.count == 0 {
                    productLastQueriesArray = productPopularArray
                }
                
                let sdkSearchWidget = SearchWidget()
                sdkSearchWidget.setCategories(value: productRecommendationsArray)
                sdkSearchWidget.setSearchHistories(value: productLastQueriesArray)
                
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error:", customError)
                default:
                    print("Error:", error.description)
                }
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
        self.pushDetailViewController(productText: productText)
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
//        let storyboard = UIStoryboard(name: "Main", bundle: nil)
//        let detailViewController = storyboard.instantiateViewController(withIdentifier: "detailVC") as! DetailViewController
//        vc.clickedProduct = productText
//        self.present(detailViewController, animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

class SearchWidgetDropDownMenu: MainSearchModel {
}

class SearchWidgetData: MainSearchModel {
}

class SearchWidgetExpandableCell: MainSearchModel {
}
