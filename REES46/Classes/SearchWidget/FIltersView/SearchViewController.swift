//import UIKit

//class SearchViewController: SearchWidgetViewController, SearchWidgetDelegate {
//    
//    public var suggestsCategories: [String] = []
//    
//    public var lastQueriesHistories: [String] = []
//    public var recommendQueries: [String] = []
//    
//    public var allProductFilters: [String: Filter]?
//    
//    public var indFilters: IndustrialFilters?
//    public var indColorsFilters: IndustrialFilters?
//    
//    public var currentCurrency: String?
//    
//    public var sdk: PersonalizationSDK?
//    
//    @IBOutlet private weak var filtersButton: UIButton!
//    @IBOutlet private weak var backButton: UIButton!
//    
//    @IBOutlet var searchPlaceholder: UIView!
//    
//    @IBOutlet weak var searchProductsCollectionView: UICollectionView!
//    
//    @IBOutlet weak var blankHeaderView: UIView!
//    @IBOutlet weak var searchHeaderView: UIView!
//    
//    @IBOutlet weak var foundProductsCoutLbl: UILabel!
//    
//    //var addToCart = CartButton(image: UIImage(named: "cart"))
//    
//    var selectedProduct: String?
//    
//    public var notNeedShowInteresting: Bool = false
//    
//    public var dontShowFiltersButton: Bool = false
//    
//    private(set) public var products = [ShopCartPrepareProduct]()
//    var cartItemCount: Int = 0
//    
//    var filtersList = [FiltersMenu]()
//    var minP: Double = 0
//    var maxP: Double = 0
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        
//        searchProductsCollectionView.delegate = self
//        searchProductsCollectionView.dataSource = self
//        searchProductsCollectionView.isHidden = true
//        
//        blankHeaderView.isHidden = true
//        searchHeaderView.isHidden = true
//        
//        navigationItem.rightBarButtonItem = addToCart
//        //addToCart.setBadge(with: cartItemCount)
//        
//        addToCart.tapAction = {
//            self.performSegue(withIdentifier: "CheckoutVC", sender: self)
//        }
//        
//        self.searchPlaceholder.isHidden = true
//        
//        self.sdkSearchWidgetInit()
//        self.delegate = self
//        
//        self.navigationController?.setNavigationBarHidden(true, animated: false)
//        
//        self.setSearchWidgetCategoriesButtonType(type: .blacked)
//        
//        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
//        filtersButton.addTarget(self, action: #selector(filtersTap), for: .touchUpInside)
//        filtersButton.isHidden = true
//        
//        foundProductsCoutLbl.text = ""
//        
//        if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO_MAX {
//            UIView.animate(withDuration: 0.5, animations: {
//                self.backButton.frame.origin.x += 5
//            }, completion: { (isFinished) in
//            })
//        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO {
//            UIView.animate(withDuration: 0.5, animations: {
//                self.backButton.frame.origin.y += 3
//                self.backButton.frame.origin.x += 3
//            }, completion: { (isFinished) in
//            })
//            
//        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_XS {
//            UIView.animate(withDuration: 0.5, animations: {
//                self.backButton.frame.origin.y += 7
//            }, completion: { (isFinished) in
//            })
//            
//        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_XS_MAX {
//            UIView.animate(withDuration: 0.5, animations: {
//                self.backButton.frame.origin.y += 3
//                self.backButton.frame.origin.x += 3
//            }, completion: { (isFinished) in
//            })
//            
//        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_SE {
//            UIView.animate(withDuration: 0.5, animations: {
//                self.backButton.frame.origin.y += 7
//                self.backButton.frame.origin.x += 3
//            }, completion: { (isFinished) in
//            })
//            
//        } else {
//            UIView.animate(withDuration: 0.5, animations: {
//                self.backButton.frame.origin.y += 3
//                self.backButton.frame.origin.x += 3
//            }, completion: { (isFinished) in
//            })
//        }
//    }
//    
//    override func viewWillAppear(_ animated: Bool) {
//        if dontShowFiltersButton {
//            filtersButton.isHidden = true
//        }
//    }
//    
//    func sdkSearchWidgetListViewDidScroll() {
//        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.endEditing(true)
//    }
//    
//    func sdkSearchWidgetHistoryButtonClickedStart(productSearchText: String) {
//        print(productSearchText)
//    }
//    
//    func sdkSearchWidgetHistoryButtonClickedOpenProductCard(productId: String, productName: String, productPrice: String, productImage: String, productImagesArray: String) {
//        var numericPrice = 0
//        let expression: String = productPrice
//        let stringArray = expression.components(separatedBy: CharacterSet.decimalDigits.inverted)
//        for item in stringArray {
//            if let number = Int(item) {
//                print(number)
//                numericPrice = number
//            }
//        }
//        
//        products.removeAll()
//        
//        let storyboard = UIStoryboard(name: "Main", bundle: nil)
//        let fullSearchViewController = storyboard.instantiateViewController(withIdentifier: "detailVC") as! DetailScreenViewController
//        fullSearchViewController.modalPresentationStyle = .fullScreen
//        
//        if products.count == 0 {
//            globalSDK?.track(event: .productView(id: productId)) { trackResponse in
//                switch trackResponse {
//                case .success(_):
//                    break
//                case let .failure(error):
//                    switch error {
//                    case let .custom(customError):
//                        print("Error:", customError)
//                    default:
//                        print("Error:", error.description)
//                    }
//                }
//            }
//            
//            let sProductCollection = ShopCartPrepareProduct(productId: "", brandTitle: productName, title: productName, price: productPrice, priceNum: Double(numericPrice), oldPrice: "", description: "", mainImage: productImage, imagesArray: [productImagesArray])
//            self.products.append(sProductCollection)
//            
//            fullSearchViewController.product = sProductCollection
//            
//            self.present(fullSearchViewController, animated: true, completion: nil)
//        }
//    }
//    
//    func sdkSearchWidgetHistoryButtonClicked(productSearchText: String) {
//        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.endEditing(true)
//        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.text = productSearchText
//    }
//    
//    func sdkSearchWidgetHistoryButtonClickedFull(productSearchText: String) {
//        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.endEditing(true)
//        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.text = productSearchText
//        
//        self.sdkSearchWidgetTextFieldView.cancelButton.isHidden = false
//        self.delegate?.minimizeSearchTextField()
//        
//        UserDefaults.standard.set(false, forKey: "clientCurrencyDetect")
//        self.pushFullSearchViewController(productText: productSearchText)
//    }
//    
//    func searchWidgetCategoriesButtonClicked(productSearchText: String) {
//        UserDefaults.standard.set(false, forKey: "needShowOnTapButtonsResults")
//        
//        sdk?.suggest(query: productSearchText) { searchResponse in
//            switch searchResponse {
//            case let .success(searchResponse):
//                
//                var queriesArray = [String]()
//                for q in searchResponse.queries {
//                    let product = q.name
//                    queriesArray.append(product)
//                }
//                
//                var productSuggestArray = [String]()
//                for item in searchResponse.products {
//                    let productId = item.id
//                    let product = item.name
//                    let price = item.priceFormatted
//                    let img = item.imageUrl
//                    let description = "^" + productId + "^" + "!" + product + "!" + "\n" + "|" + price + "|" + "[" + img + "]"
//                    productSuggestArray.append(description)
//                }
//                
//                var categoriesRecommendedInputArray = [String]()
//                for catName in searchResponse.categories {
//                    let categoryName = catName.name
//                    categoriesRecommendedInputArray.append(categoryName)
//                }
//                
//                let sdkSearchWidget = SearchWidget()
//                sdkSearchWidget.setCategoriesSuggests(value: categoriesRecommendedInputArray)
//                sdkSearchWidget.setRequestHistories(value: productSuggestArray)
//                sdkSearchWidget.setSearchSuggest(value: queriesArray)
//                
//                if productSuggestArray.count != 0 {
//                    DispatchQueue.main.async {
//                        self.searchPlaceholder.isHidden = true
//                    }
//                } else {
//                    if queriesArray.count != 0 {
//                        DispatchQueue.main.async {
//                            self.searchPlaceholder.isHidden = true
//                        }
//                    } else {
//                        DispatchQueue.main.async {
//                            self.searchPlaceholder.isHidden = false
//                        }
//                    }
//                }
//                print(categoriesRecommendedInputArray.count)
//                print(self.suggestsCategories.count)
//                
//                let productSelectedSearchText1 = UserDefaults.standard.string(forKey: "savedSearchWidgetLastButtonTap") ?? ""
//                print(productSelectedSearchText1)
//                if (productSearchText == productSelectedSearchText1 && self.suggestsCategories.count == 0) {
//                    UserDefaults.standard.set(true, forKey: "needShowOnTapButtonsResults")
//                    UserDefaults.standard.set("", forKey: "savedSearchWidgetLastButtonTap")
//                } else {
//                    UserDefaults.standard.set(productSearchText, forKey: "savedSearchWidgetLastButtonTap")
//                }
//                
//                DispatchQueue.main.async {
//                    self.sdkSearchWidgetView.sdkSearchWidgetListView.sdkSearchWidgetTextFieldEnteredText = productSearchText
//                    self.sdkSearchWidgetView.sdkSearchWidgetMainView.redrawSearchRecentlyTableView()
//                }
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    print("Error:", customError)
//                default:
//                    print("Error:", error.description)
//                }
//                
//                let sdkSearchWidget = SearchWidget()
//                sdkSearchWidget.setCategoriesSuggests(value: [])
//                sdkSearchWidget.setSearchSuggest(value: [])
//                DispatchQueue.main.async {
//                    self.searchPlaceholder.isHidden = true
//                    self.sdkSearchWidgetView.sdkSearchWidgetListView.sdkSearchWidgetTextFieldEnteredText = productSearchText
//                }
//            }
//        }
//    }
//    
//    func reloadBlankSearch() {
//        UserDefaults.standard.set(true, forKey: "notNeedShowInteresting")
//        UserDefaults.standard.set(false, forKey: "needShowOnTapButtonsResults")
//        UserDefaults.standard.set(false, forKey: "clientCurrencyDetect")
//        
//        DispatchQueue.main.async {
//            self.searchProductsCollectionView.isHidden = true
//            self.blankHeaderView.isHidden = true
//            self.searchHeaderView.isHidden = true
//            
//            self.view.sendSubviewToBack(self.searchProductsCollectionView)
//            
//            self.filtersButton.isHidden = true
//            
//            self.searchProductsCollectionView.reloadData()
//            
//            if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO_MAX {
//                UIView.animate(withDuration: 0.5, delay: 0.0,
//                               usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
//                               options: .allowAnimatedContent, animations: {
//                    self.filtersButton.frame.origin.x -= 4
//                }) { (isFinished) in }
//            } else if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO {
//                UIView.animate(withDuration: 0.5, delay: 0.0,
//                               usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
//                               options: .allowAnimatedContent, animations: {
//                    self.filtersButton.frame.origin.y -= 3
//                }) { (isFinished) in }
//            } else if SdkGlobalHelper.DeviceType.IS_IPHONE_XS {
//                UIView.animate(withDuration: 0.5, delay: 0.0,
//                               usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
//                               options: .allowAnimatedContent, animations: {
//                    self.filtersButton.frame.origin.y -= 7
//                }) { (isFinished) in }
//            } else if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PLUS {
//                UIView.animate(withDuration: 0.5, delay: 0.0,
//                               usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
//                               options: .allowAnimatedContent, animations: {
//                    self.filtersButton.frame.origin.x -= 5
//                    self.filtersButton.frame.origin.y -= 3
//                }) { (isFinished) in }
//            } else if SdkGlobalHelper.DeviceType.IS_IPHONE_XS_MAX {
//                UIView.animate(withDuration: 0.5, delay: 0.0,
//                               usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
//                               options: .allowAnimatedContent, animations: {
//                    self.backButton.frame.origin.y -= 1
//                    self.filtersButton.frame.origin.x -= 3
//                    self.filtersButton.frame.origin.y -= 4
//                }) { (isFinished) in }
//                
//            } else if SdkGlobalHelper.DeviceType.IS_IPHONE_SE {
//                UIView.animate(withDuration: 0.5, delay: 0.0,
//                               usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
//                               options: .allowAnimatedContent, animations: {
//                    self.filtersButton.frame.origin.x -= 3
//                    self.filtersButton.frame.origin.y -= 7
//                }) { (isFinished) in }
//                
//            } else {
//                UIView.animate(withDuration: 0.5, animations: {
//                    self.filtersButton.frame.origin.x -= 5
//                    self.filtersButton.frame.origin.y -= 3
//                }, completion: { (isFinished) in
//                })
//            }
//        }
//        
//        globalSDK?.searchBlank { searchResponse in
//            switch searchResponse {
//            case let .success(response):
//                
//                var suggestArray = [String]()
//                for item in response.suggests {
//                    let product = item.name
//                    suggestArray.append(product)
//                }
//                
//                var lastQueriesArray = [String]()
//                for item in response.lastQueries {
//                    let product = item.name
//                    lastQueriesArray.append(product)
//                }
//                
//                var productsRecentlyViewedArray = [String]()
//                for item in response.products {
//                    let productId = item.id
//                    let product = item.name
//                    let price = item.priceFormatted
//                    let img = item.imageUrl
//                    let description = "^" + productId + "^" + "!" + product + "!" + "\n" + "|" + price + "|" + "[" + img + "]"
//                    productsRecentlyViewedArray.append(description)
//                }
//                
//                DispatchQueue.main.async {
//                    let sdkSearchWidget = SearchWidget()
//                    
//                    sdkSearchWidget.setCategoriesSuggests(value: lastQueriesArray)
//                    sdkSearchWidget.setRequestHistories(value: productsRecentlyViewedArray)
//                    sdkSearchWidget.setSearchSuggest(value: [])
//                    
//                    self.searchPlaceholder.isHidden = true
//                    self.sdkSearchWidgetView.sdkSearchWidgetMainView.redrawSearchRecentlyTableView()
//                    
//                    self.sdkSearchWidgetView.sdkSearchWidgetScrollView.setContentOffset(.zero, animated: true)
//                }
//                
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    DispatchQueue.main.async {
//                        self.openSearchAnyway()
//                    }
//                    print("Error:", customError)
//                default:
//                    DispatchQueue.main.async {
//                        self.openSearchAnyway()
//                    }
//                    print("Error:", error.description)
//                }
//            }
//        }
//    }
//    
//    func resetSearchToSimple() {
//        UserDefaults.standard.set(false, forKey: "needShowOnTapButtonsResults")
//        
//        DispatchQueue.main.async {
//            self.searchProductsCollectionView.isHidden = true
//            self.blankHeaderView.isHidden = true
//            self.searchHeaderView.isHidden = true
//            
//            self.view.sendSubviewToBack(self.searchProductsCollectionView)
//            
//            self.filtersButton.isHidden = true
//            
//            self.searchProductsCollectionView.reloadData()
//            
//            if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO_MAX {
//                UIView.animate(withDuration: 0.5, delay: 0.0,
//                               usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
//                               options: .allowAnimatedContent, animations: {
//                    self.filtersButton.frame.origin.x -= 5
//                }) { (isFinished) in }
//            } else if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO {
//                UIView.animate(withDuration: 0.5, delay: 0.0,
//                               usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
//                               options: .allowAnimatedContent, animations: {
//                    self.filtersButton.frame.origin.y -= 3
//                }) { (isFinished) in }
//            } else if SdkGlobalHelper.DeviceType.IS_IPHONE_XS {
//                UIView.animate(withDuration: 0.5, delay: 0.0,
//                               usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
//                               options: .allowAnimatedContent, animations: {
//                    self.filtersButton.frame.origin.y -= 7
//                }) { (isFinished) in }
//            } else if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PLUS {
//                UIView.animate(withDuration: 0.5, delay: 0.0,
//                               usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
//                               options: .allowAnimatedContent, animations: {
//                    self.filtersButton.frame.origin.x -= 5
//                    self.filtersButton.frame.origin.y -= 3
//                }) { (isFinished) in }
//            } else if SdkGlobalHelper.DeviceType.IS_IPHONE_XS_MAX {
//                UIView.animate(withDuration: 0.5, delay: 0.0,
//                               usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
//                               options: .allowAnimatedContent, animations: {
//                    self.backButton.frame.origin.y -= 1
//                    self.filtersButton.frame.origin.x -= 3
//                    self.filtersButton.frame.origin.y -= 4
//                }) { (isFinished) in }
//                
//            } else if SdkGlobalHelper.DeviceType.IS_IPHONE_SE {
//                UIView.animate(withDuration: 0.5, delay: 0.0,
//                               usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
//                               options: .allowAnimatedContent, animations: {
//                    self.filtersButton.frame.origin.x -= 3
//                    self.filtersButton.frame.origin.y -= 7
//                }) { (isFinished) in }
//                
//            } else {
//                UIView.animate(withDuration: 0.5, animations: {
//                    self.filtersButton.frame.origin.x -= 5
//                    self.filtersButton.frame.origin.y -= 3
//                }, completion: { (isFinished) in
//                })
//            }
//        }
//    }
//    
//    private func openSearchAnyway() {
//        let sdkSearchWidget = SearchWidget()
//        sdkSearchWidget.setCategoriesSuggests(value: [])
//        sdkSearchWidget.setRequestHistories(value: [])
//        sdkSearchWidget.setSearchSuggest(value: [])
//        
//        let storyboard = UIStoryboard(name: "Main", bundle: nil)
//        let searchVC = storyboard.instantiateViewController(withIdentifier: "searchVC") as! SearchViewController
//        searchVC.modalPresentationStyle = .fullScreen
//        searchVC.sdk = globalSDK
//        searchVC.suggestsCategories = []
//        searchVC.lastQueriesHistories = []
//        
//        self.present(searchVC, animated: true, completion: nil)
//    }
//    
//    func sdkSearchWidgetListViewClicked(productSearchKey: String) {
//        self.pushFullSearchViewController(productText: productSearchKey)
//        UserDefaults.standard.set(false, forKey: "clientCurrencyDetect")
//    }
//    
//    func sdkSearchWidgetListViewClicked(object: Any) {
//        print(object)
//    }
//    
//    func sdkSearchWidgetListView(_ sdkSearchWidgetListView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        let cell = self.sdkSearchWidgetView.sdkSearchWidgetListView.dequeueReusableCell(withIdentifier: SearchWidgetListViewCell.ID) as! SearchWidgetListViewCell
//        if let sModel = self.sdkSearchWidgetView.sdkSearchWidgetListView.searchResultDatabase[indexPath.row] as? MainSearchModel {
//            cell.searchLabel.text = sModel.key
//        }
//        return cell
//    }
//    
//    func sdkSearchWidgetListView(_ sdkSearchWidgetListView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        if let sModel = self.sdkSearchWidgetView.sdkSearchWidgetListView.searchResultDatabase[indexPath.row] as? MainSearchModel, let kValue = sModel.key {
//            self.sdkSearchWidgetView.sdkSearchWidgetListView.sdkSearchWidgetListViewDelegate?.sdkSearchWidgetListViewClicked(productSearchKey: kValue)
//            self.sdkSearchWidgetView.sdkSearchWidgetListView.sdkSearchWidgetListViewDelegate?.sdkSearchWidgetListViewClicked(object: self.sdkSearchWidgetView.sdkSearchWidgetListView.database[indexPath.row])
//            self.sdkSearchWidgetView.sdkSearchWidgetListView.sdkSearchWidget.appendSearchHistories(value: kValue)
//        }
//    }
//    
//    func pushFullSearchViewController(productText: String) {
//        self.products.removeAll()
//        self.filtersList.removeAll()
//        
//        sdk?.search(query: productText, sortBy: "popular", filtersSearchBy: "name", timeOut: 0.3) { searchResponse in
//            switch searchResponse {
//            case let .success(searchResponse):
//                var                     imagesFindedProductArray = [String]()
//                var arrayOfPreparedFilters = [String]()
//                let strToFiltersRepresentation: [String : Filter] = searchResponse.filters ?? [:]
//                
//                let clientCurrency = UserDefaults.standard.string(forKey: "client_currency") ?? ""
//                
//                let clientCurrencyDetect: Bool = UserDefaults.standard.bool(forKey: "clientCurrencyDetect")
//                if !clientCurrencyDetect {
//                    let currencyFilterTitle = "Price ( " + clientCurrency + " )"
//                    self.filtersList.insert(FiltersMenu(filterId: 9999990, title: currencyFilterTitle, titleFiltersValues: [], selected: false), at: 0)
//                    UserDefaults.standard.set(true, forKey: "clientCurrencyDetect")
//                }
//                
//                for (index, key) in strToFiltersRepresentation {
//                    var dsValue = [String]()
//                    for va in key.values {
//                        dsValue.append(va.key)
//                    }
//                    arrayOfPreparedFilters.append(index)
//                    
//                    if dsValue.count == 0 {
//                        print("SDK: Command Not found Filters in Category")
//                    } else {
//                        self.filtersList.append(FiltersMenu(filterId: index.count, title: index, titleFiltersValues: dsValue, selected: true))
//                    }
//                }
//                
//                self.indFilters = searchResponse.industrialFilters
//                
//                self.minP = searchResponse.priceRange?.min ?? 0
//                self.maxP = searchResponse.priceRange?.max ?? 9999990
//                
//                if searchResponse.priceRange?.min == searchResponse.priceRange?.max {
//                    UserDefaults.standard.set(0, forKey: "minimumInstalledPriceConstant")
//                    UserDefaults.standard.set(self.maxP, forKey: "maximumInstalledPriceConstant")
//                } else {
//                    UserDefaults.standard.set(self.minP, forKey: "minimumInstalledPriceConstant")
//                    UserDefaults.standard.set(self.maxP, forKey: "maximumInstalledPriceConstant")
//                }
//                
//                if (searchResponse.filters != nil) {
//                    var newDic = Array(searchResponse.filters!.keys).reduce(into: [String: Bool]()) { $0[$1] = false }
//                    let aDictionary = [String:[String]]()
//                    let notEmptValues = aDictionary.values.filter { $0.count > 0 }.reduce([], +)
//                    let duplicates = Array(Set(notEmptValues.filter { i in notEmptValues.filter { $0 == i }.count > 1 })).sorted(by: { $0 < $1 })
//                    if let result = aDictionary.first(where: { $0.value.sorted(by: { $0 < $1 }) == duplicates })?.key {
//                        newDic[result] = true
//                    }
//                    
//                    var wFilterArrayWithStrings = [String]()
//                    for key in newDic.keys {
//                        wFilterArrayWithStrings.append(key)
//                        for arr in aDictionary[key, default:[]] {
//                            if !(aDictionary[arr, default:[]].contains(key)){
//                                newDic[key] = true
//                            }
//                        }
//                    }
//                }
//                
//                for item in searchResponse.products {
//                    let productId = item.id
//                    let brandProduct = item.brand
//                    let product = item.name
//                    let price = item.priceFormatted
//                    
//                    let priceNum = item.priceFull
//                    let oldPrice = item.oldPriceFormatted
//                    let img = item.imageUrl
//                    let desc = item.productDescription
//                    
//                                        imagesFindedProductArray.insert(img, at: 0)
//                    
//                    let productSearchedByUser = ShopCartPrepareProduct(productId: productId, brandTitle: brandProduct, title: product, price: price, priceNum: priceNum, oldPrice: oldPrice, description: desc, mainImage: img, imagesArray:                     imagesFindedProductArray)
//                    self.products.append(productSearchedByUser)
//                }
//                
//                let totalFindedProducts = searchResponse.productsTotal
//                DispatchQueue.main.async {
//                    self.foundProductsCoutLbl.text = "found " + "\(totalFindedProducts)" + " products"
//                    self.sdkSearchWidgetTextFieldView.cancelButton.isHidden = false
//                    
//                    self.filtersButton.isHidden = false
//                    self.searchProductsCollectionView.isHidden = false
//                    self.blankHeaderView.isHidden = false
//                    self.searchHeaderView.isHidden = false
//                    self.view.bringSubviewToFront(self.blankHeaderView)
//                    self.view.bringSubviewToFront(self.searchHeaderView)
//                    
//                    self.view.bringSubviewToFront(self.searchProductsCollectionView)
//                    self.view.bringSubviewToFront(self.sdkSearchWidgetTextFieldView)
//                    
//                    if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO_MAX {
//                        UIView.animate(withDuration: 0.5, delay: 0.0,
//                                       usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
//                                       options: .allowAnimatedContent, animations: {
//                            self.filtersButton.frame.origin.x += 5
//                            
//                            self.filtersButton.isHidden = false
//                            self.filtersButton.alpha = 1.0
//                            self.filtersButton.isUserInteractionEnabled = true
//                        }) { (isFinished) in
//                            self.filtersButton.isHidden = false
//                            self.filtersButton.alpha = 1.0
//                            self.filtersButton.isUserInteractionEnabled = true
//                        }
//                    } else if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO {
//                        UIView.animate(withDuration: 0.5, delay: 0.0,
//                                       usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
//                                       options: .allowAnimatedContent, animations: {
//                            self.filtersButton.frame.origin.y += 3
//                            
//                            self.filtersButton.isHidden = false
//                            self.filtersButton.alpha = 1.0
//                            self.filtersButton.isUserInteractionEnabled = true
//                        }) { (isFinished) in
//                            self.filtersButton.isHidden = false
//                            self.filtersButton.alpha = 1.0
//                            self.filtersButton.isUserInteractionEnabled = true
//                        }
//                    } else if SdkGlobalHelper.DeviceType.IS_IPHONE_XS {
//                        UIView.animate(withDuration: 0.5, delay: 0.0,
//                                       usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
//                                       options: .allowAnimatedContent, animations: {
//                            self.filtersButton.frame.origin.y += 7
//                            self.filtersButton.isHidden = false
//                            self.filtersButton.alpha = 1.0
//                            self.filtersButton.isUserInteractionEnabled = true
//                        }) { (isFinished) in
//                            self.filtersButton.isHidden = false
//                            self.filtersButton.alpha = 1.0
//                            self.filtersButton.isUserInteractionEnabled = true
//                        }
//                    } else if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PLUS {
//                        UIView.animate(withDuration: 0.5, delay: 0.0,
//                                       usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
//                                       options: .allowAnimatedContent, animations: {
//                            self.filtersButton.frame.origin.x += 5
//                            self.filtersButton.frame.origin.y += 3
//                        }) { (isFinished) in
//                            self.filtersButton.isHidden = false
//                            self.filtersButton.alpha = 1.0
//                            self.filtersButton.isUserInteractionEnabled = true
//                        }
//                        
//                    } else if SdkGlobalHelper.DeviceType.IS_IPHONE_XS_MAX {
//                        UIView.animate(withDuration: 0.5, delay: 0.0,
//                                       usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
//                                       options: .allowAnimatedContent, animations: {
//                            self.backButton.frame.origin.y += 1
//                            self.filtersButton.frame.origin.x += 4
//                            self.filtersButton.frame.origin.y += 4
//                        }) { (isFinished) in
//                            self.filtersButton.isHidden = false
//                            self.filtersButton.alpha = 1.0
//                            self.filtersButton.isUserInteractionEnabled = true
//                        }
//                        
//                    } else if SdkGlobalHelper.DeviceType.IS_IPHONE_SE {
//                        UIView.animate(withDuration: 0.5, delay: 0.0,
//                                       usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
//                                       options: .allowAnimatedContent, animations: {
//                            self.filtersButton.frame.origin.x += 3
//                            self.filtersButton.frame.origin.y += 7
//                        }) { (isFinished) in
//                            self.filtersButton.isHidden = false
//                            self.filtersButton.alpha = 1.0
//                            self.filtersButton.isUserInteractionEnabled = true
//                        }
//                        
//                    } else {
//                        UIView.animate(withDuration: 0.5, animations: {
//                            self.backButton.frame.origin.y += 0.5
//                            self.filtersButton.frame.origin.x += 5
//                            self.filtersButton.frame.origin.y += 3
//                        }, completion: { (isFinished) in
//                        })
//                    }
//                    
//                    self.view.insertSubview(self.filtersButton, aboveSubview: self.sdkSearchWidgetTextFieldView)
//                    self.searchProductsCollectionView.reloadData()
//                }
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    print("Error:", customError)
//                default:
//                    print("Error:", error.description)
//                }
//            }
//        }
//    }
//    
//    @objc private func filtersTap() {
//        let storyboard = UIStoryboard(name: "Main", bundle: nil)
//        let fullSearchViewController = storyboard.instantiateViewController(withIdentifier: "FilterVC") as! FiltersAccordeonViewController
//        fullSearchViewController.modalPresentationStyle = .fullScreen
//        fullSearchViewController.data = self.filtersList
//        self.present(fullSearchViewController, animated: true, completion: nil)
//    }
//    
//    @objc private func didTapBack() {
//        UserDefaults.standard.set(false, forKey: "clientCurrencyDetect")
//        filtersButton.isHidden = true
//        self.dontShowFiltersButton = true
//        self.dismiss(animated: false, completion: nil)
//    }
//    
//    override func didReceiveMemoryWarning() {
//        super.didReceiveMemoryWarning()
//    }
//}
//
//class SearchWidgetDropDownMenu: MainSearchModel {
//    //
//}
//
//class SearchWidgetData: MainSearchModel {
//    //
//}
//
//class SearchWidgetExpandableCell: MainSearchModel {
//    //
//}
//
//extension SearchViewController: UICollectionViewDelegate {
//    //
//}
//
//extension SearchViewController: UICollectionViewDataSource {
//    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        return products.count
//    }
//    
//    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProductCell", for: indexPath) as? ProductCell {
//            cell.delegate = self
//            let product = products[indexPath.row]
//            cell.updateCell(with: product)
//            return cell
//        }
//        return ProductCell()
//    }
//    
//    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        let selectedProduct = products[indexPath.row]
//        globalSDK?.track(event: .productView(id: selectedProduct.productId)) { trackResponse in
//            switch trackResponse {
//            case .success(_):
//                break
//            case let .failure(error):
//                switch error {
//                case let .custom(customError):
//                    print("Error:", customError)
//                default:
//                    print("Error:", error.description)
//                }
//            }
//        }
//        
//        let storyboard = UIStoryboard(name: "Main", bundle: nil)
//        let fullSearchViewController = storyboard.instantiateViewController(withIdentifier: "detailVC") as! DetailScreenViewController
//        fullSearchViewController.modalPresentationStyle = .fullScreen
//        fullSearchViewController.product = selectedProduct
//        self.present(fullSearchViewController, animated: true, completion: nil)
//    }
//}
//
//extension SearchViewController: updateCartCountDelegate {
//    func updateCart(with count: Int) {
//        cartItemCount = count
//        addToCart.setBadge(with: count)
//    }
//}
