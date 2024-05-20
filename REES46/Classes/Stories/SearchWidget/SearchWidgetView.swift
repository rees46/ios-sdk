import UIKit

public class SearchWidgetView: SearchWidgetViewController, SearchWidgetDelegate, UINavigationControllerDelegate {
    
    public var suggestsCategories: [String] = []
    
    public var lastQueriesHistories: [String] = []
    public var recommendQueries: [String] = []
    
    public var allProductFilters: [String: Filter]?
    
    public var industrialFilters: IndustrialFilters?
    public var industrialColorsFilters: IndustrialFilters?
    
    public var currentCurrency: String?
    
    public var sdk: PersonalizationSDK?
    
    @IBOutlet private weak var filtersButton: UIButton!
    @IBOutlet private weak var backButton: UIButton!
    
    @IBOutlet var searchPlaceholder: UIView!
    
    @IBOutlet weak var searchProductsCollectionView: UICollectionView!
    
    @IBOutlet weak var blankHeaderView: UIView!
    @IBOutlet weak var searchHeaderView: UIView!
    
    @IBOutlet weak var foundProductsCoutLbl: UILabel!
    
    var selectedProduct: String?
    
    public var notNeedShowInteresting: Bool = false
    public var dontNeedFiltersSelectedShowButton: Bool = false
    
    private(set) var findedProducts = [SearchWidgetProductDataPrepare]()
    
    var addToCart = SearchWidgetCartButton(image: UIImage(named: "cart"))
    var cartItemCount: Int = 0
    
    var filtersDataList = [FiltersDataMenuList]()
    
    var minP: Double = 0
    var maxP: Double = 0
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        searchProductsCollectionView.delegate = self
        searchProductsCollectionView.dataSource = self
        searchProductsCollectionView.isHidden = true
        
        var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        frameworkBundle = Bundle.module
#endif
        searchProductsCollectionView.register(UINib(nibName: "SearchWidgetProductCell", bundle: frameworkBundle), forCellWithReuseIdentifier: "SearchWidgetProductCell")
        
        //searchProductsCollectionView.register(UINib(nibName: "FiltersWidgetView", bundle: frameworkBundle), forCellWithReuseIdentifier: "FiltersWidgetView")
        
        blankHeaderView.isHidden = true
        searchHeaderView.isHidden = true
        
//        addToCart.setBadge(with: cartItemCount)
//        addToCart.tapAction = {
//            self.performSegue(withIdentifier: "searchCheckoutView", sender: self)
//        }
        
        self.searchPlaceholder.isHidden = true
        
        self.sdkSearchWidgetInit()
        self.delegate = self
        
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        self.setSearchWidgetCategoriesButtonType(type: .blacked)
        
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        filtersButton.addTarget(self, action: #selector(filtersOpenViewTap), for: .touchUpInside)
        filtersButton.isHidden = true
        
        foundProductsCoutLbl.text = ""
        
        if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO_MAX {
            UIView.animate(withDuration: 0.5, animations: {
                self.backButton.frame.origin.x += 5
            }, completion: { (isFinished) in
            })
        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO {
            UIView.animate(withDuration: 0.5, animations: {
                self.backButton.frame.origin.y += 3
                self.backButton.frame.origin.x += 3
            }, completion: { (isFinished) in
            })
        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_XS {
            UIView.animate(withDuration: 0.5, animations: {
                self.backButton.frame.origin.y += 7
            }, completion: { (isFinished) in
            })
        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_XS_MAX {
            UIView.animate(withDuration: 0.5, animations: {
                self.backButton.frame.origin.y += 3
                self.backButton.frame.origin.x += 3
            }, completion: { (isFinished) in
            })
        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_SE {
            UIView.animate(withDuration: 0.5, animations: {
                self.backButton.frame.origin.y += 7
                self.backButton.frame.origin.x += 3
            }, completion: { (isFinished) in
            })
        } else {
            UIView.animate(withDuration: 0.5, animations: {
                self.backButton.frame.origin.y += 3
                self.backButton.frame.origin.x += 3
            }, completion: { (isFinished) in
            })
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        if dontNeedFiltersSelectedShowButton {
            filtersButton.isHidden = true
        }
    }
    
    public func sdkSearchWidgetListViewDidScroll() {
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.endEditing(true)
    }
    
    public func sdkSearchWidgetHistoryButtonClickedStart(productSearchText: String) {
        print(productSearchText)
    }
    
    public func sdkSearchWidgetHistoryButtonClickedOpenProductCard(productId: String, productName: String, productPrice: String, productImage: String, productImagesArray: String) {
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
//        findedProducts.removeAll()
//        
//        let storyboard = UIStoryboard(name: "Main", bundle: nil)
//        let productWidgetMainView = storyboard.instantiateViewController(withIdentifier: "productView") as! ShopProductDetailsViewController
//        productWidgetMainView.modalPresentationStyle = .fullScreen
//
//        if findedProducts.count == 0 {
//            sdk?.track(event: .productView(id: productId)) { trackResponse in
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
//            let sProductCollection = SearchWidgetProductDataPrepare(productId: "", brandTitle: productName, title: productName, price: productPrice, priceNum: Double(numericPrice), oldPrice: "", description: "", mainImage: productImage, imagesArray: [productImagesArray])
//            self.findedProducts.append(sProductCollection)
//            productWidgetMainView.product = sProductCollection
//            self.present(productWidgetMainView, animated: true, completion: nil)
//        }
    }
    
    public func sdkSearchWidgetHistoryButtonClicked(productSearchText: String) {
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.endEditing(true)
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.text = productSearchText
    }
    
    public func sdkSearchWidgetHistoryButtonClickedFull(productSearchText: String) {
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.endEditing(true)
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.text = productSearchText
        
        self.sdkSearchWidgetTextFieldView.cancelButton.isHidden = false
        self.delegate?.minimizeSearchTextField()
        
        UserDefaults.standard.set(false, forKey: "clientCurrencyValueDetect")
        self.pushFullSearchWidgetMainView(productText: productSearchText)
    }
    
    public func searchWidgetCategoriesButtonClicked(productSearchText: String) {
        UserDefaults.standard.set(false, forKey: "needShowOnTapButtonsResults")
        
        sdk?.suggest(query: productSearchText) { response in
            switch response {
            case let .success(searchResponse):
                
                var queriesArray = [String]()
                for q in searchResponse.queries {
                    let product = q.name
                    queriesArray.append(product)
                }
                
                var productSuggestArray = [String]()
                for item in searchResponse.products {
                    let productId = item.id
                    let product = item.name
                    let price = item.priceFormatted
                    let img = item.imageUrl
                    let description = "^" + productId + "^" + "!" + product + "!" + "\n" + "|" + price + "|" + "[" + img + "]"
                    productSuggestArray.append(description)
                }
                
                var categoriesRecommendedInputArray = [String]()
                for catName in searchResponse.categories {
                    let categoryName = catName.name
                    categoriesRecommendedInputArray.append(categoryName)
                }
                
                let sdkSearchWidget = SearchWidget()
                sdkSearchWidget.setCategoriesSuggests(value: categoriesRecommendedInputArray)
                sdkSearchWidget.setRequestHistories(value: productSuggestArray)
                sdkSearchWidget.setSearchSuggest(value: queriesArray)
                
                if productSuggestArray.count != 0 {
                    DispatchQueue.main.async {
                        self.searchPlaceholder.isHidden = true
                    }
                } else {
                    if queriesArray.count != 0 {
                        DispatchQueue.main.async {
                            self.searchPlaceholder.isHidden = true
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.searchPlaceholder.isHidden = false
                        }
                    }
                }
                print(categoriesRecommendedInputArray.count)
                print(self.suggestsCategories.count)
                
                let productSelectedSearchText = UserDefaults.standard.string(forKey: "savedSearchWidgetLastButtonTap") ?? ""
                print(productSelectedSearchText)
                if (productSearchText == productSelectedSearchText && self.suggestsCategories.count == 0) {
                    UserDefaults.standard.set(true, forKey: "needShowOnTapButtonsResults")
                    UserDefaults.standard.set("", forKey: "savedSearchWidgetLastButtonTap")
                } else {
                    UserDefaults.standard.set(productSearchText, forKey: "savedSearchWidgetLastButtonTap")
                }
                
                DispatchQueue.main.async {
                    self.sdkSearchWidgetView.sdkSearchWidgetListView.sdkSearchWidgetTextFieldEnteredText = productSearchText
                    self.sdkSearchWidgetView.sdkSearchWidgetMainView.redrawSearchRecentlyTableView()
                }
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error:", customError)
                default:
                    print("Error:", error.description)
                }
                
                let sdkSearchWidget = SearchWidget()
                sdkSearchWidget.setCategoriesSuggests(value: [])
                sdkSearchWidget.setSearchSuggest(value: [])
                DispatchQueue.main.async {
                    self.searchPlaceholder.isHidden = true
                    self.sdkSearchWidgetView.sdkSearchWidgetListView.sdkSearchWidgetTextFieldEnteredText = productSearchText
                }
            }
        }
    }
    
    public func reloadBlankSearch() {
        UserDefaults.standard.set(true, forKey: "notNeedShowInteresting")
        UserDefaults.standard.set(false, forKey: "needShowOnTapButtonsResults")
        UserDefaults.standard.set(false, forKey: "clientCurrencyValueDetect")
        
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
        
        sdk?.searchBlank { searchResponse in
            switch searchResponse {
            case let .success(response):
                
                var suggestArray = [String]()
                for item in response.suggests {
                    let product = item.name
                    suggestArray.append(product)
                }
                
                var lastQueriesArray = [String]()
                for item in response.lastQueries {
                    let product = item.name
                    lastQueriesArray.append(product)
                }
                
                var productsRecentlyViewedArray = [String]()
                for item in response.products {
                    let productId = item.id
                    let product = item.name
                    let price = item.priceFormatted
                    let img = item.imageUrl
                    let description = "^" + productId + "^" + "!" + product + "!" + "\n" + "|" + price + "|" + "[" + img + "]"
                    productsRecentlyViewedArray.append(description)
                }
                
                DispatchQueue.main.async {
                    let sdkSearchWidget = SearchWidget()
                    
                    sdkSearchWidget.setCategoriesSuggests(value: lastQueriesArray)
                    sdkSearchWidget.setRequestHistories(value: productsRecentlyViewedArray)
                    sdkSearchWidget.setSearchSuggest(value: suggestArray)
                    
                    self.searchPlaceholder.isHidden = true
                    self.sdkSearchWidgetView.sdkSearchWidgetMainView.redrawSearchRecentlyTableView()
                    
                    self.sdkSearchWidgetView.sdkSearchWidgetScrollView.setContentOffset(.zero, animated: true)
                }
                
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    DispatchQueue.main.async {
                        self.openSearchAnyway()
                    }
                    print("Error:", customError)
                default:
                    DispatchQueue.main.async {
                        self.openSearchAnyway()
                    }
                    print("Error:", error.description)
                }
            }
        }
    }
    
    public func resetSearchToSimple() {
        UserDefaults.standard.set(false, forKey: "needShowOnTapButtonsResults")
        
        DispatchQueue.main.async {
            self.searchProductsCollectionView.isHidden = true
            self.blankHeaderView.isHidden = true
            self.searchHeaderView.isHidden = true
            
            self.view.sendSubviewToBack(self.searchProductsCollectionView)
            
            self.filtersButton.isHidden = true
            
            self.searchProductsCollectionView.reloadData()
            
            if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO_MAX {
                UIView.animate(withDuration: 0.5, delay: 0.0,
                               usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
                               options: .allowAnimatedContent, animations: {
                    self.filtersButton.frame.origin.x -= 5
                }) { (isFinished) in }
            } else if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO {
                UIView.animate(withDuration: 0.5, delay: 0.0,
                               usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
                               options: .allowAnimatedContent, animations: {
                    self.filtersButton.frame.origin.y -= 3
                }) { (isFinished) in }
            } else if SdkGlobalHelper.DeviceType.IS_IPHONE_XS {
                UIView.animate(withDuration: 0.5, delay: 0.0,
                               usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
                               options: .allowAnimatedContent, animations: {
                    self.filtersButton.frame.origin.y -= 7
                }) { (isFinished) in }
            } else if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PLUS {
                UIView.animate(withDuration: 0.5, delay: 0.0,
                               usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
                               options: .allowAnimatedContent, animations: {
                    self.filtersButton.frame.origin.x -= 5
                    self.filtersButton.frame.origin.y -= 3
                }) { (isFinished) in }
            } else if SdkGlobalHelper.DeviceType.IS_IPHONE_XS_MAX {
                UIView.animate(withDuration: 0.5, delay: 0.0,
                               usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
                               options: .allowAnimatedContent, animations: {
                    self.backButton.frame.origin.y -= 1
                    self.filtersButton.frame.origin.x -= 3
                    self.filtersButton.frame.origin.y -= 4
                }) { (isFinished) in }
                
            } else if SdkGlobalHelper.DeviceType.IS_IPHONE_SE {
                UIView.animate(withDuration: 0.5, delay: 0.0,
                               usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
                               options: .allowAnimatedContent, animations: {
                    self.filtersButton.frame.origin.x -= 3
                    self.filtersButton.frame.origin.y -= 7
                }) { (isFinished) in }
                
            } else {
                UIView.animate(withDuration: 0.5, animations: {
                    self.filtersButton.frame.origin.x -= 5
                    self.filtersButton.frame.origin.y -= 3
                }, completion: { (isFinished) in
                })
            }
        }
    }
    
    private func openSearchAnyway() {
        let sdkSearchWidget = SearchWidget()
        sdkSearchWidget.setCategoriesSuggests(value: [])
        sdkSearchWidget.setRequestHistories(value: [])
        sdkSearchWidget.setSearchSuggest(value: [])
        
        var frameworkBundle = Bundle(for: SearchWidgetMainView.self)
#if SWIFT_PACKAGE
        frameworkBundle = Bundle.module
#endif
        let searchView = frameworkBundle.loadNibNamed("SearchWidgetView", owner: nil, options: nil)?.first as! SearchWidgetView
        searchView.modalPresentationStyle = .fullScreen
        searchView.sdk = sdk
        searchView.suggestsCategories = []
        searchView.lastQueriesHistories = []
        
        self.present(searchView, animated: true, completion: nil)
    }
    
    public func sdkSearchWidgetListViewClicked(productSearchKey: String) {
        self.pushFullSearchWidgetMainView(productText: productSearchKey)
        UserDefaults.standard.set(false, forKey: "clientCurrencyValueDetect")
    }
    
    public func sdkSearchWidgetListViewClicked(object: Any) {
        print(object)
    }
    
    public func sdkSearchWidgetListView(_ sdkSearchWidgetListView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.sdkSearchWidgetView.sdkSearchWidgetListView.dequeueReusableCell(withIdentifier: SearchWidgetListViewCell.ID) as! SearchWidgetListViewCell
        if let searchModel = self.sdkSearchWidgetView.sdkSearchWidgetListView.searchResultDatabase[indexPath.row] as? SearchWidgetModel {
            cell.searchLabel.text = searchModel.key
        }
        return cell
    }
    
    public func sdkSearchWidgetListView(_ sdkSearchWidgetListView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let sModel = self.sdkSearchWidgetView.sdkSearchWidgetListView.searchResultDatabase[indexPath.row] as? SearchWidgetModel, let kValue = sModel.key {
            self.sdkSearchWidgetView.sdkSearchWidgetListView.sdkSearchWidgetListViewDelegate?.sdkSearchWidgetListViewClicked(productSearchKey: kValue)
            self.sdkSearchWidgetView.sdkSearchWidgetListView.sdkSearchWidgetListViewDelegate?.sdkSearchWidgetListViewClicked(object: self.sdkSearchWidgetView.sdkSearchWidgetListView.database[indexPath.row])
            self.sdkSearchWidgetView.sdkSearchWidgetListView.sdkSearchWidget.appendSearchHistories(value: kValue)
        }
    }
    
    func pushFullSearchWidgetMainView(productText: String) {
        self.findedProducts.removeAll()
        self.filtersDataList.removeAll()
        
        sdk?.search(query: productText, sortBy: "popular", filtersSearchBy: "name", timeOut: 0.3) { searchResponse in
            switch searchResponse {
            case let .success(searchResponse):
                var imagesProductArray = [String]()
                var arrayOfPreparedFilters = [String]()
                let strToFiltersRepresentation: [String : Filter] = searchResponse.filters ?? [:]
                
                let clientCurrencyValue = UserDefaults.standard.string(forKey: "clientCurrencyValue") ?? ""
                let clientCurrencyDetect: Bool = UserDefaults.standard.bool(forKey: "clientCurrencyValueDetect")
                if !clientCurrencyDetect {
                    let currencyFilterTitle = "Price ( " + clientCurrencyValue + " )"
                    self.filtersDataList.insert(FiltersDataMenuList(filterId: 9999990,
                                                                    title: currencyFilterTitle,
                                                                    titleFiltersValues: [],
                                                                    selected: false),
                                                at: 0)
                    UserDefaults.standard.set(true, forKey: "clientCurrencyValueDetect")
                }
                
                for (index, key) in strToFiltersRepresentation {
                    var fTitleValue = [String]()
                    for fValue in key.values {
                        fTitleValue.append(fValue.key)
                    }
                    arrayOfPreparedFilters.append(index)
                    
                    if fTitleValue.count == 0 {
                        print("SDK: Command Not found Filters in Category")
                    } else {
                        self.filtersDataList.append(FiltersDataMenuList(filterId: index.count,
                                                                        title: index,
                                                                        titleFiltersValues: fTitleValue,
                                                                        selected: true))
                    }
                }
                
                self.industrialFilters = searchResponse.industrialFilters
                
                self.minP = searchResponse.priceRange?.min ?? 0
                self.maxP = searchResponse.priceRange?.max ?? 9999990
                
                if searchResponse.priceRange?.min == searchResponse.priceRange?.max {
                    UserDefaults.standard.set(0, forKey: "minimumInstalledPriceConstant")
                    UserDefaults.standard.set(self.maxP, forKey: "maximumInstalledPriceConstant")
                } else {
                    UserDefaults.standard.set(self.minP, forKey: "minimumInstalledPriceConstant")
                    UserDefaults.standard.set(self.maxP, forKey: "maximumInstalledPriceConstant")
                }
                
                if (searchResponse.filters != nil) {
                    var newFiltersDict = Array(searchResponse.filters!.keys).reduce(into: [String: Bool]()) { $0[$1] = false }
                    let compareFiltersDict = [String:[String]]()
                    let notEmptyValues = compareFiltersDict.values.filter { $0.count > 0 }.reduce([], +)
                    let duplicates = Array(Set(notEmptyValues.filter { i in notEmptyValues.filter { $0 == i }.count > 1 })).sorted(by: { $0 < $1 })
                    if let result = compareFiltersDict.first(where: { $0.value.sorted(by: { $0 < $1 }) == duplicates })?.key {
                        newFiltersDict[result] = true
                    }
                    
                    var wFilterArrayWithStrings = [String]()
                    for key in newFiltersDict.keys {
                        wFilterArrayWithStrings.append(key)
                        for arr in compareFiltersDict[key, default:[]] {
                            if !(compareFiltersDict[arr, default:[]].contains(key)) {
                                newFiltersDict[key] = true
                            }
                        }
                    }
                }
                
                for item in searchResponse.products {
                    let productId = item.id
                    let brandProduct = item.brand
                    let product = item.name
                    let price = item.priceFormatted
                    
                    let priceNum = item.priceFull
                    let oldPrice = item.oldPriceFormatted
                    let img = item.imageUrl
                    let desc = item.productDescription
                    
                    imagesProductArray.insert(img, at: 0)
                    
                    let productSearchedByUser = SearchWidgetProductDataPrepare(productId: productId,
                                                                               brandTitle: brandProduct,
                                                                               title: product,
                                                                               price: price,
                                                                               priceNum: priceNum,
                                                                               oldPrice: oldPrice,
                                                                               description: desc,
                                                                               mainImage: img,
                                                                               imagesArray: imagesProductArray)
                    self.findedProducts.append(productSearchedByUser)
                }
                
                let totalFindedProducts = searchResponse.productsTotal
                DispatchQueue.main.async {
                    self.foundProductsCoutLbl.text = "found " + "\(totalFindedProducts)" + " products"
                    self.sdkSearchWidgetTextFieldView.cancelButton.isHidden = false
                    
                    self.filtersButton.isHidden = false
                    self.searchProductsCollectionView.isHidden = false
                    self.blankHeaderView.isHidden = false
                    self.searchHeaderView.isHidden = false
                    self.view.bringSubviewToFront(self.blankHeaderView)
                    self.view.bringSubviewToFront(self.searchHeaderView)
                    
                    self.view.bringSubviewToFront(self.searchProductsCollectionView)
                    self.view.bringSubviewToFront(self.sdkSearchWidgetTextFieldView)
                    
                    if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO_MAX {
                        UIView.animate(withDuration: 0.5,
                                       delay: 0.0,
                                       usingSpringWithDamping: 0.0,
                                       initialSpringVelocity: 0.0,
                                       options: .allowAnimatedContent,
                                       animations: {
                            self.filtersButton.frame.origin.x += 5
                            
                            self.filtersButton.isHidden = false
                            self.filtersButton.alpha = 1.0
                            self.filtersButton.isUserInteractionEnabled = true
                        }) { (isFinished) in
                            self.filtersButton.isHidden = false
                            self.filtersButton.alpha = 1.0
                            self.filtersButton.isUserInteractionEnabled = true
                        }
                    } else if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO {
                        UIView.animate(withDuration: 0.5, delay: 0.0,
                                       usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
                                       options: .allowAnimatedContent, animations: {
                            self.filtersButton.frame.origin.y += 3
                            
                            self.filtersButton.isHidden = false
                            self.filtersButton.alpha = 1.0
                            self.filtersButton.isUserInteractionEnabled = true
                        }) { (isFinished) in
                            self.filtersButton.isHidden = false
                            self.filtersButton.alpha = 1.0
                            self.filtersButton.isUserInteractionEnabled = true
                        }
                    } else if SdkGlobalHelper.DeviceType.IS_IPHONE_XS {
                        UIView.animate(withDuration: 0.5, delay: 0.0,
                                       usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
                                       options: .allowAnimatedContent, animations: {
                            self.filtersButton.frame.origin.y += 7
                            self.filtersButton.isHidden = false
                            self.filtersButton.alpha = 1.0
                            self.filtersButton.isUserInteractionEnabled = true
                        }) { (isFinished) in
                            self.filtersButton.isHidden = false
                            self.filtersButton.alpha = 1.0
                            self.filtersButton.isUserInteractionEnabled = true
                        }
                    } else if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PLUS {
                        UIView.animate(withDuration: 0.5, delay: 0.0,
                                       usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
                                       options: .allowAnimatedContent, animations: {
                            self.filtersButton.frame.origin.x += 5
                            self.filtersButton.frame.origin.y += 3
                        }) { (isFinished) in
                            self.filtersButton.isHidden = false
                            self.filtersButton.alpha = 1.0
                            self.filtersButton.isUserInteractionEnabled = true
                        }
                    } else if SdkGlobalHelper.DeviceType.IS_IPHONE_XS_MAX {
                        UIView.animate(withDuration: 0.5, delay: 0.0,
                                       usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
                                       options: .allowAnimatedContent, animations: {
                            self.backButton.frame.origin.y += 1
                            self.filtersButton.frame.origin.x += 4
                            self.filtersButton.frame.origin.y += 4
                        }) { (isFinished) in
                            self.filtersButton.isHidden = false
                            self.filtersButton.alpha = 1.0
                            self.filtersButton.isUserInteractionEnabled = true
                        }
                    } else if SdkGlobalHelper.DeviceType.IS_IPHONE_SE {
                        UIView.animate(withDuration: 0.5, delay: 0.0,
                                       usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
                                       options: .allowAnimatedContent, animations: {
                            self.filtersButton.frame.origin.x += 3
                            self.filtersButton.frame.origin.y += 7
                        }) { (isFinished) in
                            self.filtersButton.isHidden = false
                            self.filtersButton.alpha = 1.0
                            self.filtersButton.isUserInteractionEnabled = true
                        }
                    } else {
                        UIView.animate(withDuration: 0.5, animations: {
                            self.backButton.frame.origin.y += 0.5
                            self.filtersButton.frame.origin.x += 5
                            self.filtersButton.frame.origin.y += 3
                        }, completion: { (isFinished) in
                            //Implementation
                        })
                    }
                    
                    self.view.insertSubview(self.filtersButton, aboveSubview: self.sdkSearchWidgetTextFieldView)
                    self.searchProductsCollectionView.reloadData()
                }
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
    
    func getTopMostViewController() -> UIViewController? {
        var topMostViewController = UIApplication.shared.keyWindow?.rootViewController
        
        while let presentedViewController = topMostViewController?.presentedViewController {
            topMostViewController = presentedViewController
        }
        
        return topMostViewController
    }
    
    @objc func filtersOpenViewTap() {
        var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
            frameworkBundle = Bundle.module
#endif
        //let filtersWidgetMainView = frameworkBundle.loadNibNamed("FiltersWidgetView", owner: nil, options: nil)?.first as! FiltersWidgetView
        
      //  weak var pvc = self.presentingViewController

//        self.dismiss(animated: true, completion: {
//            let vc = frameworkBundle.loadNibNamed("FiltersWidgetView", owner: nil, options: nil)?.first as! FiltersWidgetView
//            //vc.modalPresentationStyle = .fullScreen
//            vc.filtersList = self.filtersDataList
//            pvc?.present(vc, animated: true, completion: nil)
//        })
        
        let filtersWidgetMainView = frameworkBundle.loadNibNamed("FiltersWidgetView", owner: nil, options: nil)?.first as! FiltersWidgetView
        
        //let filtersWidgetMainView = FiltersWidgetView()
        filtersWidgetMainView.modalPresentationStyle = .fullScreen
        filtersWidgetMainView.filtersList = self.filtersDataList
        
        DispatchQueue.main.async {
            self.getTopMostViewController()?.present(filtersWidgetMainView, animated: true, completion: nil)
        }
        
        //self.view.addSubview(filtersWidgetMainView)
        //self.present(filtersWidgetMainView, animated: true, completion: nil)
        //self.navigationController?.pushViewController(filtersWidgetMainView, animated: true)
            //var window: UIWindow?
        //let pushVC = FiltersWidgetView()
        //let navigationController = UINavigationController(rootViewController: filtersWidgetMainView)
       // mainVC?.addSubview(filtersWidgetMainView.view)// present(filtersWidgetMainView, animated: true)
        
        
//        self.view1 = UINib(nibName: self.nibName1, bundle: Bundle(for: type(of: self))).instantiate(withOwner: self, options: nil)[0] as! UIView //as! FiltersWidgetView
//        self.view1.frame = self.view.bounds
//        self.view1.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        self.view.addSubview(self.view1)
        
        
        //let vc = self.storyboard?.instantiateViewControllerWithIdentifier("YourViewController") as! YourViewController
        //let navigationController = UINavigationController(rootViewController: filtersWidgetMainView)
        //self.present(navigationController, animated: true, completion: nil)
    }
    
    @objc private func didTapBack() {
        UserDefaults.standard.set(false, forKey: "clientCurrencyValueDetect")
        filtersButton.isHidden = true
        self.dontNeedFiltersSelectedShowButton = true
        self.dismiss(animated: false, completion: nil)
    }
    
    public override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

class SearchWidgetData: SearchWidgetModel {
    //Implementation
}

extension SearchWidgetView: UICollectionViewDelegate {
    //Implementation
}

extension SearchWidgetView: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return findedProducts.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SearchWidgetProductCell", for: indexPath) as? SearchWidgetProductCell {
            cell.delegate = self
            let product = findedProducts[indexPath.row]
            cell.updateCell(with: product)
            return cell
        }
        return UICollectionViewCell()
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedProduct = findedProducts[indexPath.row]
        sdk?.track(event: .productView(id: selectedProduct.productId)) { trackResponse in
            switch trackResponse {
            case .success(_):
                break
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
}

extension SearchWidgetView: updateCartCountDelegate {
    func updateCart(with count: Int) {
        cartItemCount = count
        addToCart.setBadge(with: count)
    }
}
