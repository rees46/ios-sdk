import UIKit

open class SearchWidgetMainView: UIView {
    let width = UIScreen.main.bounds.width
    let height = UIScreen.main.bounds.height
    
    open var recommendSearchCategoryLabel: UILabel!
    open var sdkSearchWidgetCategoriesButtons = [SearchWidgetCategoriesButton]()
    
    open var yourReqHistoryLabel: UILabel!
    
    open var requestsSearchHistoryLabel: UILabel!
    open var searchRecentlyLabel: UILabel!
    open var additionalLabel: UILabel!
    
    open var lineZeroSectionHelper: UIView!
    
    open var lineMainSectionHelper: UIView!
    open var lineSecondSectionHelper: UIView!
    
    open var lineAdditionalneSectionHelper: UIView!
    
    open var viewMainResults: SearchWidgetHistoryView!
    open var viewAdditionalResults: SearchWidgetHistoryView!
    
    open var sdkSearchWidgetHistoryViews = [SearchWidgetHistoryView]()
    open var sdkSearchWidgetHistoryButtons = [SearchWidgetHistoryButton]()
    open var viewAllSearchResultsButton: UIButton!
    
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
    
    @objc open func searchWidgetCategoriesButtonClicked(_ sender: UIButton) {
        guard let searchText = sdkSearchWidgetCategoriesButtons[sender.tag].titleLabel?.text else {
            return
        }
        
        self.delegate?.sdkSearchWidgetHistoryButtonClicked(searchProductText: searchText)
        self.delegate?.searchWidgetCategoriesButtonClicked(searchProductText: searchText)
    }
    
    @objc open func sdkSearchWidgetHistoryButtonClicked(_ sender: UIButton) {
        //self.sdkSearchWidgetTextField.endEditing(true)
        
        let categoryTag = sender.tag
        let constructorCategories = sdkSearchWidget.getSearchSuggest() ?? [String]()
        let suitableCategories = sdkSearchWidget.getCategories() ?? [String]()
        
        if suitableCategories.count != 0 {
            if categoryTag < suitableCategories.count {
                let scName = suitableCategories[categoryTag]
                self.delegate?.sdkSearchWidgetHistoryButtonClickedFull(searchProductText: scName)
            } else {
                //let constructorCategories = sdkSearchWidget.getCategories() ?? [String]()
                //print("SDK: suitableCategories")
            }
        } else {
            if constructorCategories.count != 0 {
                if categoryTag < constructorCategories.count {
                    let sConstructorName = constructorCategories[categoryTag]
                    self.delegate?.sdkSearchWidgetHistoryButtonClickedFull(searchProductText: sConstructorName)
                } else {
                    //let constructorCategories = sdkSearchWidget.getCategories() ?? [String]()
                    print("SDK: constructorCategories need constructorCategories")
                }
            }
        }
    }
    
    @objc open func viewAllSearchResultsButtonClickedStart(_ sender: UIButton) {
        let categoryTag = sender.tag
        let parsedData = sdkSearchWidget.getSearchHistories()
        
        if categoryTag < parsedData?.count ?? 0 {
            let internalValues = parsedData?[categoryTag]
            let mainValue = internalValues?.slice(from: "^", to: "^") ?? ""
            let addValue1 = internalValues?.slice(from: "!", to: "!") ?? ""
            let addValue2 = internalValues?.slice(from: "|", to: "|") ?? ""
            let addValue3 = internalValues?.slice(from: "[", to: "]") ?? ""
            
            self.delegate?.sdkSearchWidgetHistoryButtonClickedOpenProductCard(productId: mainValue, productName: addValue1, productPrice: addValue2, productImage: addValue3, productImagesArray: addValue3)
        }
    }
    
    @objc open func viewAllSearchResultsButtonClicked() {
        self.delegate?.sdkSearchWidgetHistoryButtonClicked(searchProductText: "")
    }
    
    @objc open func viewAllSearchResultsButtonClickedFull() {
        let productSelectedText = UserDefaults.standard.string(forKey: "viewAllSearchResultsButtonClickedFull") ?? ""
        self.delegate?.sdkSearchWidgetHistoryButtonClickedFull(searchProductText: productSelectedText)
    }
    
    @objc open func closeButtonClicked(_ sender: UIButton) {
        sdkSearchWidget.deleteSearchHistories(index: sender.tag)
        self.redrawSearchRecentlyTableView()
    }
    
    open func initView(constructorCategories: [String]) {
        UserDefaults.standard.set(false, forKey: "notNeedShowInteresting")
        redrawSearchRecentlyTableView()
    }
    
    open func redrawSearchRecentlyTableView() {
        if viewMainResults != nil {
            viewMainResults.sdkSearchWidgetHistoryButton.removeFromSuperview()
            viewMainResults.removeFromSuperview()
        }
        
        for buttons in sdkSearchWidgetCategoriesButtons {
            buttons.removeFromSuperview()
        }
        
        for view in sdkSearchWidgetHistoryViews {
            view.sdkSearchWidgetHistoryButton.searchResultProductTitleLabel.removeFromSuperview()
            view.sdkSearchWidgetHistoryButton.searchResultProductPriceLabel.removeFromSuperview()
            view.sdkSearchWidgetHistoryButton.searchResultProductImage.removeFromSuperview()
            view.sdkSearchWidgetHistoryButton.searchCategoriesArrowImage.removeFromSuperview()
        }
        
        sdkSearchWidgetHistoryViews.removeAll()
        sdkSearchWidgetHistoryButtons.removeAll()
        sdkSearchWidgetCategoriesButtons.removeAll()
        
        if requestsSearchHistoryLabel != nil {
            requestsSearchHistoryLabel.removeFromSuperview()
        }
        
        if yourReqHistoryLabel != nil {
            yourReqHistoryLabel.removeFromSuperview()
        }
        
        if searchRecentlyLabel != nil {
            searchRecentlyLabel.removeFromSuperview()
        }
        
        let wFont = UIFont.systemFont(ofSize: 14)
        let userAttributes = [NSAttributedString.Key.font: wFont, NSAttributedString.Key.foregroundColor: UIColor.gray]
        
        var formerWidth: CGFloat = margin
        var formerHeight: CGFloat = 22
        
        let suitableCategories = sdkSearchWidget.getCategories() ?? [String]()
        let constructorCategories = sdkSearchWidget.getSearchSuggest() ?? [String]()
        let suitableProducts = sdkSearchWidget.getSearchHistories() ?? [String]()
        let cachedUserRequestsArray = sdkSearchWidget.getUserCachedRequests() ?? [String]()
        
        if suitableCategories.count != 0 {
            if cachedUserRequestsArray.count == 999999 {
                //print("SDK: 500 cachedUserRequestsArray")
            } else {
                for i in 0..<constructorCategories.count {
                    let size = constructorCategories[i].size(withAttributes: userAttributes)
                    if i > 0 {
                        formerWidth = sdkSearchWidgetCategoriesButtons[i-1].frame.size.width + sdkSearchWidgetCategoriesButtons[i-1].frame.origin.x + 8
                        if formerWidth + size.width + margin > UIScreen.main.bounds.width {
                            formerHeight += sdkSearchWidgetCategoriesButtons[i-1].frame.size.height + 11
                            formerWidth = margin
                        }
                    }
                    let button = SearchWidgetCategoriesButton(frame: CGRect(x: formerWidth, y: formerHeight, width: size.width + 26, height: size.height + 19))
                    button.addTarget(self, action: #selector(searchWidgetCategoriesButtonClicked(_:)), for: .touchUpInside)
                    button.setTitle(constructorCategories[i], for: .normal)
                    button.tag = i
                    
                    sdkSearchWidgetCategoriesButtons.append(button)
                    self.addSubview(button)
                }
            }
        } else {
            //print("SDK: Zero suitableCategories")
        }
        
        var originYq = (sdkSearchWidgetCategoriesButtons.last?.frame.origin.y ?? +36)
        if constructorCategories.count == 0 {
            originYq = (sdkSearchWidgetCategoriesButtons.last?.frame.origin.y ?? -36)
        }
        if (constructorCategories.count != 0 && cachedUserRequestsArray.count != 0) {
            originYq = (sdkSearchWidgetCategoriesButtons.last?.frame.origin.y ?? -36)
        }
        
        var sCatRequestsValueLabel = "SUITABLE CATEGORIES"
        let notNeedShowInteresting: Bool = UserDefaults.standard.bool(forKey: "notNeedShowInteresting")
        if !notNeedShowInteresting {
            if (constructorCategories.count != 0 && suitableCategories.count == 0) {
                sCatRequestsValueLabel = "YOUR REQUESTS HISTORY"
            }
        } else {
            if (constructorCategories.count == 0 && suitableCategories.count != 0) {
                sCatRequestsValueLabel = "YOUR REQUESTS HISTORY"
            }
        }
        
        let yourRequestsAttributedString = NSMutableAttributedString(string: sCatRequestsValueLabel)
        yourRequestsAttributedString.addAttribute(NSAttributedString.Key.kern, value: 1.3, range: NSMakeRange(0, yourRequestsAttributedString.length))
        
        self.requestsSearchHistoryLabel = UILabel(frame: CGRect(x: margin, y: originYq + 57, width: width - 40, height: 36))
        self.requestsSearchHistoryLabel.attributedText = yourRequestsAttributedString
        self.requestsSearchHistoryLabel.font = UIFont.systemFont(ofSize: 13.0, weight: UIFont.Weight.heavy)
        self.requestsSearchHistoryLabel.textColor = UIColor.black.withAlphaComponent(0.7)
        
        if suitableCategories.count != 0 {
            self.addSubview(self.requestsSearchHistoryLabel)
        } else {
            if constructorCategories.count != 0 {
                //
            }
        }
        
        for sdkSearchWidgetHistoryView in sdkSearchWidgetHistoryViews {
            sdkSearchWidgetHistoryView.removeFromSuperview()
        }
        sdkSearchWidgetHistoryViews.removeAll()
        sdkSearchWidgetHistoryButtons.removeAll()
        
        if viewMainResults != nil {
            viewMainResults.removeFromSuperview()
        }
        
        for view in sdkSearchWidgetHistoryViews {
            view.removeFromSuperview()
        }
        
        sdkSearchWidgetHistoryViews.removeAll()
        
        if lineZeroSectionHelper != nil {
            lineZeroSectionHelper.removeFromSuperview()
        }
        
        if lineMainSectionHelper != nil {
            lineMainSectionHelper.removeFromSuperview()
        }
        
        if lineSecondSectionHelper != nil {
            lineSecondSectionHelper.removeFromSuperview()
        }
        
        if lineAdditionalneSectionHelper != nil {
            lineAdditionalneSectionHelper.removeFromSuperview()
        }
        
        if suitableCategories.count != 0 {
            if self.yourReqHistoryLabel != nil {
                self.yourReqHistoryLabel.removeFromSuperview()
            }
            
            lineMainSectionHelper = UIView(frame: CGRect(x: 0 , y: self.requestsSearchHistoryLabel.frame.origin.y - 7, width: width, height: 1.1))
            lineMainSectionHelper.layer.borderWidth = 1.1
            lineMainSectionHelper.layer.borderColor = UIColor.lightGray.cgColor
            self.addSubview(lineMainSectionHelper)
            
            let requestsSearchHistoryLabelOriginResultsY: CGFloat = requestsSearchHistoryLabel.frame.origin.y + requestsSearchHistoryLabel.frame.height
            for i in 0..<suitableCategories.count {
                let categoryForWidget = suitableCategories[i]
                let priceCatProductForWidget = suitableCategories[i].slice(from: "|", to: "|") ?? ""
                
                viewMainResults = SearchWidgetHistoryView(frame: CGRect(x: margin, y: requestsSearchHistoryLabelOriginResultsY + CGFloat(i * 40), width: width - (margin * 2), height: 36))
                viewMainResults.sdkSearchWidgetHistoryButton.addTarget(self, action: #selector(sdkSearchWidgetHistoryButtonClicked(_:)), for: .touchUpInside)
                viewMainResults.sdkSearchWidgetHistoryButton.searchResultProductTitleLabel.text = categoryForWidget
                
                let pcsp = "             " + priceCatProductForWidget
                let priceCatProductForWidgetStr = NSMutableAttributedString(string: pcsp)
                priceCatProductForWidgetStr.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 14), range: NSMakeRange(0, priceCatProductForWidgetStr.length))
                viewMainResults.sdkSearchWidgetHistoryButton.searchResultProductPriceLabel.attributedText = priceCatProductForWidgetStr
                
                var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
                frameworkBundle = Bundle.module
#endif
                let search_history = UIImage(named: "arrowRight", in: frameworkBundle, compatibleWith: nil)
                viewMainResults.sdkSearchWidgetHistoryButton.searchCategoriesArrowImage.image = search_history
                viewMainResults.sdkSearchWidgetHistoryButton.tag = i
                sdkSearchWidgetHistoryViews.append(viewMainResults)
                self.addSubview(viewMainResults)
            }
        } else {
            if self.searchRecentlyLabel != nil {
                self.searchRecentlyLabel.removeFromSuperview()
            }
            if constructorCategories.count != 0 {
                let originYs = sdkSearchWidgetHistoryViews.last?.frame.origin.y ?? +0
                let searchRecentlyLabelOriginY: CGFloat = originYs
                
                var recentlyRequestsValue = ""
                if self.yourReqHistoryLabel != nil {
                    self.yourReqHistoryLabel.removeFromSuperview()
                }
                if suitableCategories.count == 0 {
                    let suitableProducts = sdkSearchWidget.getSearchHistories() ?? [String]()
                    if suitableProducts.count == 0 {
                        if lineMainSectionHelper != nil {
                            lineMainSectionHelper.removeFromSuperview()
                        }
                        recentlyRequestsValue = "FREQUENT QUERIES"
                    } else {
                        if constructorCategories.count != 0 {
                            self.lineZeroSectionHelper = UIView(frame: CGRect(x: 0, y: searchRecentlyLabelOriginY + 17, width: width, height: 1.1))
                            self.lineZeroSectionHelper.layer.borderWidth = 1.1
                            self.lineZeroSectionHelper.layer.borderColor = UIColor.lightGray.cgColor
                            self.addSubview(self.lineZeroSectionHelper)
//                            if (suitableCategories.count == 0 && cachedUserRequestsArray.count == 0) {
//                                recentlyRequestsValue = ""
//                            } else {
//                                recentlyRequestsValue = "YOUR REQUESTS HISTORY"
//                            }
                            recentlyRequestsValue = "YOUR REQUESTS HISTORY"
                        } else {
                            recentlyRequestsValue = "YOUR REQUESTS HISTORY"
                        }
                    }
                }
                
                let recentlyRequestsAttributedString = NSMutableAttributedString(string: recentlyRequestsValue)
                recentlyRequestsAttributedString.addAttribute(NSAttributedString.Key.kern, value: 1.3, range: NSMakeRange(0, recentlyRequestsAttributedString.length))
                
//                if self.yourReqHistoryLabel != nil {
//                    self.yourReqHistoryLabel.removeFromSuperview()
//                }
                self.yourReqHistoryLabel = UILabel(frame: CGRect(x: margin, y: searchRecentlyLabelOriginY + 62, width: width - 40, height: 36))
                if suitableCategories.count == 0 {
                    self.yourReqHistoryLabel = UILabel(frame: CGRect(x: margin, y: searchRecentlyLabelOriginY + 22, width: width - 40, height: 36))
                }
                
                self.yourReqHistoryLabel.attributedText = recentlyRequestsAttributedString
                self.yourReqHistoryLabel.font = UIFont.systemFont(ofSize: 13.0, weight: UIFont.Weight.heavy)
                self.yourReqHistoryLabel.textColor = UIColor.black.withAlphaComponent(0.7)
                
                if (suitableCategories.count == 0 && constructorCategories.count == 0 && cachedUserRequestsArray.count == 0) {
                    if self.yourReqHistoryLabel != nil {
                        self.yourReqHistoryLabel.removeFromSuperview()
                    }
                } else {
                    self.addSubview(self.yourReqHistoryLabel)
                }
                //self.addSubview(self.yourReqHistoryLabel)
                
                let originY = (sdkSearchWidgetCategoriesButtons.last?.frame.origin.y ?? +55)
                
                for i in 0..<constructorCategories.count {
                    let catsWithSuite = constructorCategories[i]
                    
                    viewMainResults = SearchWidgetHistoryView(frame: CGRect(x: margin, y: originY + CGFloat(i * 45), width: width - (margin * 2), height: 36))
                    viewMainResults.sdkSearchWidgetHistoryButton.addTarget(self, action: #selector(sdkSearchWidgetHistoryButtonClicked(_:)), for: .touchUpInside)
                    viewMainResults.sdkSearchWidgetHistoryButton.searchResultProductTitleLabel.text = catsWithSuite
                    let str1 = NSMutableAttributedString(string: catsWithSuite)
                    str1.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 14), range: NSMakeRange(0, str1.length))
                    
                    viewMainResults.sdkSearchWidgetHistoryButton.searchResultProductPriceLabel.attributedText = nil
                    var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
                    frameworkBundle = Bundle.module
#endif
                    let search_history = UIImage(named: "arrowRight", in: frameworkBundle, compatibleWith: nil)
                    viewMainResults.sdkSearchWidgetHistoryButton.searchCategoriesArrowImage.image = search_history
                    viewMainResults.sdkSearchWidgetHistoryButton.tag = i
                    sdkSearchWidgetHistoryViews.append(viewMainResults)
                    self.addSubview(viewMainResults)
                }
                
                if suitableCategories.count != 0 {
                    let scView = viewMainResults.frame.maxY + 55
                    lineMainSectionHelper = UIView(frame: CGRect(x: 0 , y: scView, width: width, height: 1.1))
                    lineMainSectionHelper.layer.borderWidth = 1.1
                    lineMainSectionHelper.layer.borderColor = UIColor.lightGray.cgColor
                    self.addSubview(lineMainSectionHelper)
                } else {
                    if constructorCategories.count != 0 {
                        //
                    }
                }
            }
        }
        
        if self.additionalLabel != nil {
            self.additionalLabel.removeFromSuperview()
        }
        
        //let suitableProducts = sdkSearchWidget.getSearchHistories() ?? [String]()
        if suitableProducts.count != 0 {
            
            let originYs = sdkSearchWidgetHistoryViews.last?.frame.origin.y ?? +0
            let searchRecentlyLabelOriginY: CGFloat = originYs
            
            if self.lineSecondSectionHelper != nil {
                self.lineSecondSectionHelper.removeFromSuperview()
            }
            
            if cachedUserRequestsArray.count != 0 {
                let originYs2 = sdkSearchWidgetHistoryViews.last?.frame.origin.y ?? +30
                let _: CGFloat = originYs2
                
                let fxText = "FREQUENT QUERIES"
                let fxMutableText = NSMutableAttributedString(string: fxText)
                fxMutableText.addAttribute(NSAttributedString.Key.kern, value: 1.3, range: NSMakeRange(0, fxMutableText.length))
                
                if self.additionalLabel != nil {
                    self.additionalLabel.removeFromSuperview()
                }
                
                self.additionalLabel = UILabel(frame: CGRect(x: margin, y: searchRecentlyLabelOriginY + 30, width: width - 40, height: 36))
                if cachedUserRequestsArray.count == 0 {
                    if constructorCategories.count != 0 {
                        self.additionalLabel = UILabel(frame: CGRect(x: margin, y: searchRecentlyLabelOriginY + 30, width: width - 40, height: 36))
                    } else {
                        self.additionalLabel = UILabel(frame: CGRect(x: margin, y: searchRecentlyLabelOriginY + 1, width: width - 40, height: 36))
                    }
                }
                
                self.additionalLabel.attributedText = fxMutableText
                self.additionalLabel.font = UIFont.systemFont(ofSize: 13.0, weight: UIFont.Weight.heavy)
                self.additionalLabel.textColor = UIColor.black.withAlphaComponent(0.7)
                self.addSubview(self.additionalLabel)
                
                if suitableCategories.count != 0 {
                    self.lineSecondSectionHelper = UIView(frame: CGRect(x: 0 , y: self.additionalLabel.frame.origin.y, width: width, height: 1.1))
                    self.lineSecondSectionHelper.layer.borderWidth = 1.1
                    self.lineSecondSectionHelper.layer.borderColor = UIColor.lightGray.cgColor
                    self.addSubview(self.lineSecondSectionHelper)
                } else {
                    self.lineSecondSectionHelper = UIView(frame: CGRect(x: 0 , y: self.additionalLabel.frame.origin.y, width: width, height: 1.1))
                    self.lineSecondSectionHelper.layer.borderWidth = 1.1
                    self.lineSecondSectionHelper.layer.borderColor = UIColor.lightGray.cgColor
                    self.addSubview(self.lineSecondSectionHelper)
                }
                
                for i in 0..<cachedUserRequestsArray.count {
                    let test0 = cachedUserRequestsArray[i]
                    _ = cachedUserRequestsArray[i].slice(from: "^", to: "^") ?? ""
                    
                    viewAdditionalResults = SearchWidgetHistoryView(frame: CGRect(x: margin, y: self.additionalLabel.frame.origin.y + self.additionalLabel.frame.height + CGFloat(i * 45) + 10, width: width - (margin * 2), height: 36))
                    viewAdditionalResults.sdkSearchWidgetHistoryButton.addTarget(self, action: #selector(sdkSearchWidgetHistoryButtonClicked(_:)), for: .touchUpInside)
                    viewAdditionalResults.sdkSearchWidgetHistoryButton.searchResultProductTitleLabel.text = test0
                    
                    let str1 = NSMutableAttributedString(string: test0)
                    str1.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 14), range: NSMakeRange(0, str1.length))
                    var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
                    frameworkBundle = Bundle.module
#endif
                    let search_history = UIImage(named: "arrowRight", in: frameworkBundle, compatibleWith: nil)
                    viewAdditionalResults.sdkSearchWidgetHistoryButton.searchCategoriesArrowImage.image = search_history
                    viewAdditionalResults.sdkSearchWidgetHistoryButton.tag = i
                    sdkSearchWidgetHistoryViews.append(viewAdditionalResults)
                    self.addSubview(viewAdditionalResults)
                }
            }
            
            let lastHistoryView0 = self.sdkSearchWidgetHistoryViews.last ?? SearchWidgetHistoryView()
            if suitableProducts.count != 0 {
                let originYs = sdkSearchWidgetHistoryViews.last?.frame.origin.y ?? +0
                let searchRecentlyLabelOriginY: CGFloat = originYs
                var recentlyRequestsValue = "SUITABLE PRODUCTS"
                
                let notNeedShowInteresting: Bool = UserDefaults.standard.bool(forKey: "notNeedShowInteresting")
                if !notNeedShowInteresting {
                    if suitableCategories.count == 0 {
                        if constructorCategories.count == 0 {
                            if cachedUserRequestsArray.count == 0 {
                                if self.requestsSearchHistoryLabel != nil {
                                    self.requestsSearchHistoryLabel.removeFromSuperview()
                                }
                            }
                            
                            if self.yourReqHistoryLabel != nil {
                                self.yourReqHistoryLabel.removeFromSuperview()
                            }
                            
                            self.lineAdditionalneSectionHelper = UIView(frame: CGRect(x: 0, y: lastHistoryView0.frame.origin.y + lastHistoryView0.frame.height + 19, width: width, height: 1.1))
                            self.lineAdditionalneSectionHelper.layer.borderWidth = 1.1
                            self.lineAdditionalneSectionHelper.layer.borderColor = UIColor.lightGray.cgColor
                            self.addSubview(self.lineAdditionalneSectionHelper)
                            
                            recentlyRequestsValue = "INTERESTING OFFERS FOR YOU"
                        } else {
                            UserDefaults.standard.set(true, forKey: "notNeedShowInteresting")
                            recentlyRequestsValue = "RECENTLY VIEWED PRODUCTS"
                            self.lineAdditionalneSectionHelper = UIView(frame: CGRect(x: 0, y: lastHistoryView0.frame.origin.y + lastHistoryView0.frame.height + 8, width: width, height: 1.1))
                            self.lineAdditionalneSectionHelper.layer.borderWidth = 1.1
                            self.lineAdditionalneSectionHelper.layer.borderColor = UIColor.lightGray.cgColor
                            self.addSubview(self.lineAdditionalneSectionHelper)
                        }
                    } else {
                        self.lineAdditionalneSectionHelper = UIView(frame: CGRect(x: 0, y: lastHistoryView0.frame.origin.y + lastHistoryView0.frame.height + 8, width: width, height: 1.1))
                        self.lineAdditionalneSectionHelper.layer.borderWidth = 1.1
                        self.lineAdditionalneSectionHelper.layer.borderColor = UIColor.lightGray.cgColor
                        self.addSubview(self.lineAdditionalneSectionHelper)
                    }
                } else {
                    UserDefaults.standard.set(false, forKey: "notNeedShowInteresting")
                    if suitableCategories.count != 0 {
                        if constructorCategories.count == 0 {
                            self.lineAdditionalneSectionHelper = UIView(frame: CGRect(x: 0, y: lastHistoryView0.frame.origin.y + lastHistoryView0.frame.height + 10, width: width, height: 1.1))
                            self.lineAdditionalneSectionHelper.layer.borderWidth = 1.1
                            self.lineAdditionalneSectionHelper.layer.borderColor = UIColor.lightGray.cgColor
                            self.addSubview(self.lineAdditionalneSectionHelper)
                            
                            recentlyRequestsValue = "RECENTLY VIEWED PRODUCTS"
                        } else {
                            self.lineAdditionalneSectionHelper = UIView(frame: CGRect(x: 0, y: lastHistoryView0.frame.origin.y + lastHistoryView0.frame.height + 10, width: width, height: 1.1))
                            self.lineAdditionalneSectionHelper.layer.borderWidth = 1.1
                            self.lineAdditionalneSectionHelper.layer.borderColor = UIColor.lightGray.cgColor
                            self.addSubview(self.lineAdditionalneSectionHelper)
                        }
                    } else {
                        self.lineAdditionalneSectionHelper = UIView(frame: CGRect(x: 0, y: lastHistoryView0.frame.origin.y + lastHistoryView0.frame.height + 19, width: width, height: 1.1))
                        self.lineAdditionalneSectionHelper.layer.borderWidth = 1.1
                        self.lineAdditionalneSectionHelper.layer.borderColor = UIColor.lightGray.cgColor
                        self.addSubview(self.lineAdditionalneSectionHelper)
                        
                        recentlyRequestsValue = "RECENTLY VIEWED PRODUCTS"
                    }
                }
                
                let recentlyRequestsAttributedString = NSMutableAttributedString(string: recentlyRequestsValue)
                recentlyRequestsAttributedString.addAttribute(NSAttributedString.Key.kern, value: 1.3, range: NSMakeRange(0, recentlyRequestsAttributedString.length))
                
                if suitableCategories.count != 0 {
                    let notNeedShowInteresting: Bool = UserDefaults.standard.bool(forKey: "notNeedShowInteresting")
                    if !notNeedShowInteresting {
                        if self.searchRecentlyLabel != nil {
                            self.searchRecentlyLabel.removeFromSuperview()
                        }
                    }
                }
                
                if suitableCategories.count == 0 {
                    if constructorCategories.count != 0 {
                        self.searchRecentlyLabel = UILabel(frame: CGRect(x: margin, y: searchRecentlyLabelOriginY + 52, width: width - 40, height: 40))
                    } else {
                        self.searchRecentlyLabel = UILabel(frame: CGRect(x: margin, y: searchRecentlyLabelOriginY + 25, width: width - 40, height: 40))
                    }
                } else {
                    self.searchRecentlyLabel = UILabel(frame: CGRect(x: margin, y: searchRecentlyLabelOriginY + 52, width: width - 40, height: 40))
                }
                
                self.searchRecentlyLabel.attributedText = recentlyRequestsAttributedString
                self.searchRecentlyLabel.font = UIFont.systemFont(ofSize: 13.0, weight: UIFont.Weight.heavy)
                self.searchRecentlyLabel.textColor = UIColor.black.withAlphaComponent(0.7)
                self.addSubview(self.searchRecentlyLabel)
            }
            
            for i in 0..<suitableProducts.count {
                var view = SearchWidgetHistoryView(frame: CGRect(x: 17 + margin, y: lastHistoryView0.frame.origin.y + self.searchRecentlyLabel.frame.height + 50 + CGFloat(i * 50), width: width - (margin * 2), height: 40))
                if (constructorCategories.count == 0 && suitableCategories.count == 0) {
                    view = SearchWidgetHistoryView(frame: CGRect(x: 17 + margin, y: lastHistoryView0.frame.origin.y + self.searchRecentlyLabel.frame.height + 20 + CGFloat(i * 50), width: width - (margin * 2), height: 40))
                }
                
                view.sdkSearchWidgetHistoryButton.searchResultProductImage.alpha = 0
                view.sdkSearchWidgetHistoryButton.addTarget(self, action: #selector(viewAllSearchResultsButtonClickedStart(_:)), for: .touchUpInside)
                view.deleteButton.addTarget(self, action: #selector(closeButtonClicked(_:)), for: .touchUpInside)
                
                view.sdkSearchWidgetHistoryButton.searchResultProductTitleLabel.text = suitableProducts[i]
                view.sdkSearchWidgetHistoryButton.searchResultProductPriceLabel.text = ""
                
                let add1 = suitableProducts[i].slice(from: "!", to: "!") ?? ""
                let add2 = suitableProducts[i].slice(from: "|", to: "|") ?? ""
                let imgLink = suitableProducts[i].slice(from: "[", to: "]") ?? ""
                
                let sValue = "         " + add1 + " \n " + add2
                view.sdkSearchWidgetHistoryButton.searchResultProductTitleLabel.text = sValue
                
                let mValue = "           " + add2
                
                let str1 = NSMutableAttributedString(string: mValue)
                str1.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 14), range: NSMakeRange(0, str1.length))
                view.sdkSearchWidgetHistoryButton.searchResultProductPriceLabel.attributedText = str1
                view.sdkSearchWidgetHistoryButton.tag = i
                
                if let url = URL(string: imgLink) {
                    URLSession.shared.dataTask(with: url) { (data, response, error) in
                        guard let imageData = data else {
                            return
                        }
                        DispatchQueue.main.async {
                            UIView.animate(withDuration: 0.7, delay: 0.0,
                                           usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
                                           options: .allowAnimatedContent, animations: {
                                view.sdkSearchWidgetHistoryButton.searchResultProductImage.alpha = 0
                                view.sdkSearchWidgetHistoryButton.searchResultProductImage.image = UIImage(data: imageData)
                            }) { (isFinished) in
                                view.sdkSearchWidgetHistoryButton.searchResultProductImage.alpha = 1
                            }
                        }
                    }.resume()
                }
                
                view.deleteButton.tag = i
                view.sdkSearchWidgetHistoryButton.addTarget(self, action: #selector(viewAllSearchResultsButtonClickedStart(_:)), for: .touchUpInside)
                sdkSearchWidgetHistoryViews.append(view)
                sdkSearchWidgetHistoryButtons.append(view.sdkSearchWidgetHistoryButton)
                self.addSubview(view)
            }
        } else {
            if self.lineAdditionalneSectionHelper != nil {
                self.lineAdditionalneSectionHelper.removeFromSuperview()
            }
        }
        
        let lastHistoryView = self.sdkSearchWidgetHistoryViews.last ?? SearchWidgetHistoryView()
        if self.viewAllSearchResultsButton != nil {
            self.viewAllSearchResultsButton.removeFromSuperview()
        }
        
        self.viewAllSearchResultsButton = UIButton(frame: CGRect(x: margin, y: lastHistoryView.frame.origin.y + lastHistoryView.frame.height + 45, width: width - (margin * 2), height: 42))
        self.viewAllSearchResultsButton.setTitle("View all", for: .normal)
        self.viewAllSearchResultsButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        self.viewAllSearchResultsButton.setTitleColor(UIColor.sdkDefaultBlackColor, for: .normal)
        self.viewAllSearchResultsButton.setTitleColor(UIColor.lightGray, for: .highlighted)
        
        self.viewAllSearchResultsButton.layer.cornerRadius = 7
        self.viewAllSearchResultsButton.layer.borderWidth = 1.4
        self.viewAllSearchResultsButton.layer.masksToBounds = true
        self.viewAllSearchResultsButton.layer.borderColor = UIColor.sdkDefaultBlackColor.cgColor
        
        self.viewAllSearchResultsButton.addTarget(self, action: #selector(viewAllSearchResultsButtonClickedFull), for: .touchUpInside)
        self.addSubview(viewAllSearchResultsButton)
        
        if suitableCategories.count == 0 {
            self.viewAllSearchResultsButton.isHidden = true
        } else {
            self.viewAllSearchResultsButton.isHidden = false
            
            if suitableProducts.count != 0 {
                let vsCount = String(suitableProducts.count)
                let vsLbl = "View all " + "(" + vsCount + ")"
                self.viewAllSearchResultsButton.setTitle(vsLbl, for: .normal)
            }
        }
        
        self.delegate?.sdkSearchWidgetMainViewHistoryChanged()
    }
}

extension String {
    func slice(from: String, to: String) -> String? {
        guard let rangeFrom = range(of: from)?.upperBound else { return nil }
        guard let rangeTo = self[rangeFrom...].range(of: to)?.lowerBound else { return nil }
        return String(self[rangeFrom..<rangeTo])
    }
}

extension UIImageView {
    var isEmpty: Bool {
        image == nil
    }
}
