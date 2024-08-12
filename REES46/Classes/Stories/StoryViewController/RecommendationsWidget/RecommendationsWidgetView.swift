import UIKit

public protocol RecommendationsWidgetCommunicationProtocol: AnyObject {
    func addToCartProductData(product: Recommended)
    func addToFavoritesProductData(product: Recommended)
    func didTapOnProduct(product: Recommended)
}

open class RecommendationsWidgetView: UICollectionView, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, RecommendationsWidgetViewCellDelegate {
    
    public var cells = [Recommended]()
    
    private static var rowsCount = 9
    
    public let recommendationsCollectionWidgetIndicator = StoriesSlideReloadIndicator()
    
    public weak var recommendationsDelegate: RecommendationsWidgetCommunicationProtocol?
    
    public var recommendationsIndicatorView: SdkActivityIndicator!
    
    public var sdk: PersonalizationSDK?
    
    public init() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        super.init(frame: .zero, collectionViewLayout: layout)
        
        self.setupWidgetBgColor()
        
        delegate = self
        dataSource = self
        register(RecommendationsWidgetViewCell.self, forCellWithReuseIdentifier: RecommendationsWidgetViewCell.reuseRecommCellId)
        
        translatesAutoresizingMaskIntoConstraints = false
        layout.minimumLineSpacing = RecommendationsConstants.recommendationsCollectionMinimumLineSpacing
        contentInset = UIEdgeInsets(top: 0, left: RecommendationsConstants.recommendationsLeftDistanceToView, bottom: 0, right: RecommendationsConstants.recommendationsRightDistanceToView)
        
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        
//        setupRecommendationsActivityIndicator()
    }
    
    func setupRecommendationsActivityIndicator() {
        self.recommendationsIndicatorView = SdkActivityIndicator(frame: CGRect(x: 0, y: 0, width: 76, height: 76))
        self.recommendationsIndicatorView.lineWidth = 3
        self.recommendationsIndicatorView.indicatorColor = UIColor.green
        self.addSubview(self.recommendationsIndicatorView)
        
        self.recommendationsIndicatorView.center = center
        self.recommendationsIndicatorView.hideIndicatorWhenStopped = true
        
        self.recommendationsIndicatorView.startAnimating()
    }
    
    public func loadWidget(sdk: PersonalizationSDK, blockId: String) {
        self.sdk = sdk
        sdk.recommend(blockId: blockId,   currentProductId: "664",timeOut: 0.5) { recommendationsWidgetResponse in
            switch recommendationsWidgetResponse {
                case let .success(response):
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        self.setWidget(cells: response.recommended)
                        self.reloadData()
                    }
                case let .failure(error):
                    switch error {
                    case let .custom(customError):
                        print("RecommendationsWidgetView custom Error:", customError)
                    default:
                        print("RecommendationsWidgetView default Error:", error.description)
                    }
                }
        }
    }
    
    public func setWidget(cells: [Recommended]) {
        self.cells = cells
    }
    
    public func setupWidgetBgColor() {
        if SdkConfiguration.isDarkMode {
            let bgColor = SdkConfiguration.recommendations.widgetBackgroundColorDarkMode.hexToRGB()
            backgroundColor = UIColor(red: bgColor.red, green: bgColor.green, blue: bgColor.blue, alpha: 1)
        } else {
            let bgColor = SdkConfiguration.recommendations.widgetBackgroundColor.hexToRGB()
            backgroundColor = UIColor(red: bgColor.red, green: bgColor.green, blue: bgColor.blue, alpha: 1)
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cells.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = dequeueReusableCell(withReuseIdentifier: RecommendationsWidgetViewCell.reuseRecommCellId, for: indexPath) as! RecommendationsWidgetViewCell
        cell.widgetCellDelegate = self
        
        let url = URL(string: cells[indexPath.row].resizedImageUrl)
        if url != nil {
            cell.recommendationsImageView.load.request(with: url!)
        }
        
        cell.recommendationsProductNameLabel.text = cells[indexPath.row].name
        if SdkConfiguration.isDarkMode {
            cell.recommendationsProductNameLabel.textColor = .white
        } else {
            cell.recommendationsProductNameLabel.textColor = .black
        }
        
        cell.recommendationsClearLabel.text = ""
        
        let ss = cells[indexPath.row].oldPrice
        if ss == 0 {
            cell.recommendationsOldPrice.text = ""
        } else {
            cell.recommendationsOldPrice.attributedText = strikeThrough(str: cells[indexPath.row].oldPriceFormatted ?? "")
        }
        
        cell.recommendationsDiscountLabel.text = " Cashback 20% " //sample coming soon
        cell.recommendationsCreditLabel.text = " 0-0-12 " //sample coming soon
        
        let currentCurrency = cells[indexPath.row].currency
        let priceNotFormatted = cells[indexPath.row].priceFullFormatted
        let replaceCurrencyPriceWithPromocode = priceNotFormatted?.replacingOccurrences(of: currentCurrency, with: "") ?? cells[indexPath.row].priceFormatted
        let updatedPrice = replaceCurrencyPriceWithPromocode! + currentCurrency

        cell.recommendationsPriceLabel.text = updatedPrice
        
        if SdkConfiguration.isDarkMode {
            cell.recommendationsPriceLabel.textColor = .white
        } else {
            cell.recommendationsPriceLabel.textColor = .black
        }
        
        let ratingForStars = cells[indexPath.row].rating
        cell.update(Double(ratingForStars))
        if ratingForStars == 0 {
            cell.recommendationsRatingStars.isHidden = true
            cell.recommendationsRatingStarsNoReviewsLabel.isHidden = false
            cell.recommendationsRatingStarsNoReviewsLabel.text = SdkConfiguration.recommendations.widgetNoReviewsDefaultText
        } else {
            cell.update(Double(ratingForStars))
            cell.recommendationsRatingStars.isHidden = false
            cell.recommendationsRatingStarsNoReviewsLabel.isHidden = true
            cell.recommendationsRatingStarsNoReviewsLabel.text = ""
        }
        
        let pId = cells[indexPath.row].id
        let productCartId = "cart.product." + pId
        let cartItemsCachedArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(productCartId)) as? [String] ?? []
        let itemIdExistInCart = cartItemsCachedArray.contains(where: {
            $0.range(of: pId) != nil
        })
        configureCartButton(cell: cell, itemIdExistInCart: itemIdExistInCart)
        
        if SdkConfiguration.isDarkMode {
            let widgetCartButtonTextColorDarkMode = SdkConfiguration.recommendations.widgetCartButtonTextColorDarkMode.hexToRGB()
            let tColor = UIColor(red: widgetCartButtonTextColorDarkMode.red, green: widgetCartButtonTextColorDarkMode.green, blue: widgetCartButtonTextColorDarkMode.blue, alpha: 1)
            cell.recommendationsCartButton.setTitleColor(tColor, for: .normal)
            
            let widgetCartButtonBackgroundColorDarkMode = SdkConfiguration.recommendations.widgetCartButtonBackgroundColorDarkMode.hexToRGB()
            let bgColor = UIColor(red: widgetCartButtonBackgroundColorDarkMode.red, green: widgetCartButtonBackgroundColorDarkMode.green, blue: widgetCartButtonBackgroundColorDarkMode.blue, alpha: 1)
            cell.recommendationsCartButton.backgroundColor = bgColor
        } else {
            let widgetCartButtonTextColor = SdkConfiguration.recommendations.widgetCartButtonTextColor.hexToRGB()
            let tColor = UIColor(red: widgetCartButtonTextColor.red, green: widgetCartButtonTextColor.green, blue: widgetCartButtonTextColor.blue, alpha: 1)
            cell.recommendationsCartButton.setTitleColor(tColor, for: .normal)
            
            let widgetCartButtonBackgroundColor = SdkConfiguration.recommendations.widgetCartButtonBackgroundColor.hexToRGB()
            let bgColor = UIColor(red: widgetCartButtonBackgroundColor.red, green: widgetCartButtonBackgroundColor.green, blue: widgetCartButtonBackgroundColor.blue, alpha: 1)
            cell.recommendationsCartButton.backgroundColor = bgColor
        }
        
        let productFavoritesId = "favorites.product." + pId
        let favoritesItemsCachedArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(productFavoritesId)) as? [String] ?? []
        let itemIdExistInFavorites = favoritesItemsCachedArray.contains(where: {
            $0.range(of: pId) != nil
        })
        configureFavoritesButton(cell: cell, itemIdExistInFavorites: itemIdExistInFavorites)
        
        return cell
    }
    
    public func didTapWidgetAddToCartButtonInside(cell: RecommendationsWidgetViewCell, position: CGPoint) {
        if let indexPath = indexPath(for: cell) {
            let selectedProductForCartFromWidget = cells[indexPath.row]
            
            let productInCartId = "cart.product." + selectedProductForCartFromWidget.id
            var viewedSlidesCartCachedArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(productInCartId)) as? [String] ?? []
            let viewedCartSlideIdExists = viewedSlidesCartCachedArray.contains(where: {
                $0.range(of: selectedProductForCartFromWidget.id) != nil
            })
            
            if !viewedCartSlideIdExists {
                viewedSlidesCartCachedArray.append(selectedProductForCartFromWidget.id)
                UserDefaults.standard.setValue(viewedSlidesCartCachedArray, for: UserDefaults.Key(productInCartId))
                
                cell.recommendationsCartButton.setTitle(SdkConfiguration.recommendations.widgetRemoveFromCartButtonText, for: .normal)
                sdkAddToCart(productId: selectedProductForCartFromWidget.id)
            } else {
                if let index = viewedSlidesCartCachedArray.firstIndex(of: selectedProductForCartFromWidget.id) {
                    viewedSlidesCartCachedArray.remove(at: index)
                }
                UserDefaults.standard.setValue(viewedSlidesCartCachedArray, for: UserDefaults.Key(productInCartId))
                
                cell.recommendationsCartButton.setTitle(SdkConfiguration.recommendations.widgetAddToCartButtonText, for: .normal)
                sdkRemoveFromCart(productId: selectedProductForCartFromWidget.id)
            }
            
            configureCartButton(cell: cell, itemIdExistInCart: !viewedCartSlideIdExists)
            
            print("\nUser did tap Add/Remove 'Cart' from Recommendations widget\nUse 'recommendationsDelegate' for interactions\nProduct id: \(selectedProductForCartFromWidget.id)")
            print("Product name: \(selectedProductForCartFromWidget.name)")
            print("Product brand: \(selectedProductForCartFromWidget.brand)")
            print("Product model: \(selectedProductForCartFromWidget.model)")
            print("Product imageUrl: \(selectedProductForCartFromWidget.imageUrl)")
            print("Product resizedImageUrl: \(selectedProductForCartFromWidget.resizedImageUrl)")
            print("Product url: \(selectedProductForCartFromWidget.url)")
            print("Product deeplinkIos: \(selectedProductForCartFromWidget.deeplinkIos)")
            print("Product price: \(selectedProductForCartFromWidget.price)")
            print("Product priceFormatted: \(String(describing: selectedProductForCartFromWidget.priceFormatted))")
            print("Product priceFull: \(selectedProductForCartFromWidget.priceFull)")
            print("Product priceFullFormatted: \(String(describing: selectedProductForCartFromWidget.priceFullFormatted))")
            print("Product currency: \(selectedProductForCartFromWidget.currency)\n")
            
            if SdkConfiguration.recommendations.widgetCartButtonNeedOpenWebUrl {
                openWidgetUrl(link: selectedProductForCartFromWidget.url)
            }
        }
    }
    
    public func didTapWidgetAddToFavoritesButtonInside(cell: RecommendationsWidgetViewCell, position: CGPoint) {
        if let indexPath = indexPath(for: cell) {
            let selectedProductForFavoritesFromWidget = cells[indexPath.row]
            let productFavoritesId = "favorites.product." + selectedProductForFavoritesFromWidget.id
            
            var viewedSlidesFavoritesCachedArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(productFavoritesId)) as? [String] ?? []
            let viewedFavoritesSlideIdExists = viewedSlidesFavoritesCachedArray.contains(where: {
                $0.range(of: selectedProductForFavoritesFromWidget.id) != nil
            })
            
            var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
            frameworkBundle = Bundle.module
#endif
            if !viewedFavoritesSlideIdExists {
                viewedSlidesFavoritesCachedArray.append(selectedProductForFavoritesFromWidget.id)
                UserDefaults.standard.setValue(viewedSlidesFavoritesCachedArray, for: UserDefaults.Key(productFavoritesId))
                
                sdkAddToFavorites(productId: selectedProductForFavoritesFromWidget.id)
                
                var heartFillIcon = UIImage(named: "iconLikeHeartFillDark", in: frameworkBundle, compatibleWith: nil)
                if SdkConfiguration.isDarkMode {
                    heartFillIcon = UIImage(named: "iconLikeHeartFillLight", in: frameworkBundle, compatibleWith: nil)
                }
                let heartFillImageRender = heartFillIcon?.withRenderingMode(.alwaysTemplate)
                let heartFillImageView = UIImageView(image: heartFillImageRender)
                
                cell.recommendationsFavoritesButton.setImage(heartFillImageView.image, for: .normal)
                
                var customHeartTintColor = SdkConfiguration.recommendations.widgetFavoritesIconColor.hexToRGB()
                if SdkConfiguration.isDarkMode {
                    customHeartTintColor = SdkConfiguration.recommendations.widgetFavoritesIconColorDarkMode.hexToRGB()
                }
                cell.recommendationsFavoritesButton.tintColor = UIColor(red: customHeartTintColor.red, green: customHeartTintColor.green, blue: customHeartTintColor.blue, alpha: 1)
            } else {
                if let index = viewedSlidesFavoritesCachedArray.firstIndex(of: selectedProductForFavoritesFromWidget.id) {
                    viewedSlidesFavoritesCachedArray.remove(at: index)
                }
                UserDefaults.standard.setValue(viewedSlidesFavoritesCachedArray, for: UserDefaults.Key(productFavoritesId))
                
                sdkRemoveFromFavorites(productId: selectedProductForFavoritesFromWidget.id)
                
                var heartClearIcon = UIImage(named: "iconLikeHeartDark", in: frameworkBundle, compatibleWith: nil)
                if SdkConfiguration.isDarkMode {
                    heartClearIcon = UIImage(named: "iconLikeHeartLight", in: frameworkBundle, compatibleWith: nil)
                }
                let heartClearImageRender = heartClearIcon?.withRenderingMode(.alwaysTemplate)
                let heartClearImageView = UIImageView(image: heartClearImageRender)
                
                cell.recommendationsFavoritesButton.setImage(heartClearImageView.image, for: .normal)
                
                var customHeartTintColor = SdkConfiguration.recommendations.widgetFavoritesIconColor.hexToRGB()
                if SdkConfiguration.isDarkMode {
                    customHeartTintColor = SdkConfiguration.recommendations.widgetFavoritesIconColorDarkMode.hexToRGB()
                }
                cell.recommendationsFavoritesButton.tintColor = UIColor(red: customHeartTintColor.red, green: customHeartTintColor.green, blue: customHeartTintColor.blue, alpha: 1)
            }
            
            print("\nUser did tap Add/Remove 'Favorites' from Recommendations widget\nUse 'recommendationsDelegate' for interactions\nProduct id: \(selectedProductForFavoritesFromWidget.id)")
            print("Favorite product name: \(selectedProductForFavoritesFromWidget.name)")
            print("Favorite product brand: \(selectedProductForFavoritesFromWidget.brand)")
            print("Favorite product model: \(selectedProductForFavoritesFromWidget.model)")
            print("Favorite product imageUrl: \(selectedProductForFavoritesFromWidget.imageUrl)")
            print("Favorite product resizedImageUrl: \(selectedProductForFavoritesFromWidget.resizedImageUrl)")
            print("Favorite product url: \(selectedProductForFavoritesFromWidget.url)")
            print("Favorite product deeplinkIos: \(selectedProductForFavoritesFromWidget.deeplinkIos)")
            print("Favorite product price: \(selectedProductForFavoritesFromWidget.price)")
            print("Favorite product priceFormatted: \(String(describing: selectedProductForFavoritesFromWidget.priceFormatted))")
            print("Favorite product priceFull: \(selectedProductForFavoritesFromWidget.priceFull)")
            print("Favorite product priceFullFormatted: \(String(describing: selectedProductForFavoritesFromWidget.priceFullFormatted))")
            print("Favorite product currency: \(selectedProductForFavoritesFromWidget.currency)\n")
            
            recommendationsDelegate?.addToFavoritesProductData(product: selectedProductForFavoritesFromWidget)
        }
    }
    
    public func configureCartButton(cell: RecommendationsWidgetViewCell, itemIdExistInCart: Bool) {
        if !itemIdExistInCart {
            let addTxtStr = SdkConfiguration.recommendations.widgetAddToCartButtonText
            if SdkConfiguration.recommendations.widgetFontName != nil {
                var fontAddToCartProvidedBySdk = UIFont(name: SdkConfiguration.recommendations.widgetFontName!, size: 17.0)
                cell.recommendationsCartButton.titleLabel?.font = fontAddToCartProvidedBySdk
                
                if SdkConfiguration.recommendations.widgetAddToCartButtonFontSize != nil {
                    fontAddToCartProvidedBySdk = UIFont(name: SdkConfiguration.recommendations.widgetFontName!, size: SdkConfiguration.recommendations.widgetAddToCartButtonFontSize!)
                    cell.recommendationsCartButton.titleLabel?.font = fontAddToCartProvidedBySdk
                }
            } else {
                cell.recommendationsCartButton.titleLabel?.font = .systemFont(ofSize: 17.0, weight: .semibold)
                
                if SdkConfiguration.recommendations.widgetAddToCartButtonFontSize != nil {
                    cell.recommendationsCartButton.titleLabel?.font = .systemFont(ofSize: SdkConfiguration.recommendations.widgetAddToCartButtonFontSize!, weight: .semibold)
                }
            }
            cell.recommendationsCartButton.setTitle(addTxtStr, for: .normal)
        } else {
            let removeTxtStr = SdkConfiguration.recommendations.widgetRemoveFromCartButtonText
            if SdkConfiguration.recommendations.widgetFontName != nil {
                var fontRemoveFromCartProvidedBySdk = UIFont(name: SdkConfiguration.recommendations.widgetFontName!, size: 17.0)
                cell.recommendationsCartButton.titleLabel?.font = fontRemoveFromCartProvidedBySdk
                
                if SdkConfiguration.recommendations.widgetRemoveFromCartButtonFontSize != nil {
                    fontRemoveFromCartProvidedBySdk = UIFont(name: SdkConfiguration.recommendations.widgetFontName!, size: SdkConfiguration.recommendations.widgetRemoveFromCartButtonFontSize!)
                    cell.recommendationsCartButton.titleLabel?.font = fontRemoveFromCartProvidedBySdk
                }
            } else {
                cell.recommendationsCartButton.titleLabel?.font = .systemFont(ofSize: 17.0, weight: .semibold)
                
                if SdkConfiguration.recommendations.widgetRemoveFromCartButtonFontSize != nil {
                    cell.recommendationsCartButton.titleLabel?.font = .systemFont(ofSize: SdkConfiguration.recommendations.widgetRemoveFromCartButtonFontSize!, weight: .semibold)
                }
            }
            cell.recommendationsCartButton.setTitle(removeTxtStr, for: .normal)
        }
    }
    
    public func configureFavoritesButton(cell: RecommendationsWidgetViewCell, itemIdExistInFavorites: Bool) {
        var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        frameworkBundle = Bundle.module
#endif
        if !itemIdExistInFavorites {
            var heartClearIcon = UIImage(named: "iconLikeHeartDark", in: frameworkBundle, compatibleWith: nil)
            if SdkConfiguration.isDarkMode {
                heartClearIcon = UIImage(named: "iconLikeHeartLight", in: frameworkBundle, compatibleWith: nil)
            }
            let heartClearImageRender = heartClearIcon?.withRenderingMode(.alwaysTemplate)
            let heartClearImageView = UIImageView(image: heartClearImageRender)
            
            cell.recommendationsFavoritesButton.setImage(heartClearImageView.image, for: .normal)
            
            var customHeartTintColor = SdkConfiguration.recommendations.widgetFavoritesIconColor.hexToRGB()
            if SdkConfiguration.isDarkMode {
                customHeartTintColor = SdkConfiguration.recommendations.widgetFavoritesIconColorDarkMode.hexToRGB()
            }
            cell.recommendationsFavoritesButton.tintColor = UIColor(red: customHeartTintColor.red, green: customHeartTintColor.green, blue: customHeartTintColor.blue, alpha: 1)
        } else {
            var heartFillIcon = UIImage(named: "iconLikeHeartFillDark", in: frameworkBundle, compatibleWith: nil)
            if SdkConfiguration.isDarkMode {
                heartFillIcon = UIImage(named: "iconLikeHeartFillLight", in: frameworkBundle, compatibleWith: nil)
            }
            let heartFillImageRender = heartFillIcon?.withRenderingMode(.alwaysTemplate)
            let heartFillImageView = UIImageView(image: heartFillImageRender)
            
            cell.recommendationsFavoritesButton.setImage(heartFillImageView.image, for: .normal)
            
            var customHeartTintColor = SdkConfiguration.recommendations.widgetFavoritesIconColor.hexToRGB()
            if SdkConfiguration.isDarkMode {
                customHeartTintColor = SdkConfiguration.recommendations.widgetFavoritesIconColorDarkMode.hexToRGB()
            }
            cell.recommendationsFavoritesButton.tintColor = UIColor(red: customHeartTintColor.red, green: customHeartTintColor.green, blue: customHeartTintColor.blue, alpha: 1)
        }
    }
    
    public func sdkAddToCart(productId: String) {
        sdk?.track(event: .productAddedToCart(id: productId)) { trackResponse in
            switch trackResponse {
            case .success(_):
                print("Product id \(productId) added to 'Cart' success")
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
    
    public func sdkRemoveFromCart(productId: String) {
        sdk?.track(event: .productRemovedFromCart(id: productId)) { trackResponse in
            switch trackResponse {
            case .success(_):
                print("Product id \(productId) removed from 'Cart' success")
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
    
    public func sdkAddToFavorites(productId: String) {
        sdk?.track(event: .productAddedToFavorites(id: productId)) { trackResponse in
            switch trackResponse {
            case .success(_):
                print("Product id \(productId) added to 'Favorites' success")
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
    
    public func sdkRemoveFromFavorites(productId: String) {
        sdk?.track(event: .productRemovedFromFavorites(id: productId)) { trackResponse in
            switch trackResponse {
            case .success(_):
                print("Product id \(productId) removed from 'Favorites' success")
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
    
    public override func traitCollectionDidChange (_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        let userInterfaceStyle = traitCollection.userInterfaceStyle
        if UIApplication.shared.applicationState == .inactive {
            switch userInterfaceStyle {
            case .unspecified:
                self.reloadRecommendationsCollectionSubviews()
            case .light:
                self.reloadRecommendationsCollectionSubviews()
            case .dark:
                self.reloadRecommendationsCollectionSubviews()
            @unknown default:
                break
            }
        }
    }
    
    public func reloadRecommendationsCollectionSubviews() {
        self.setupWidgetBgColor()
        UICollectionView.performWithoutAnimation {
            self.layoutIfNeeded()
            self.reloadData()
        }
    }
    
    public func openWidgetUrl(link: String) {
        if let linkUrl = URL(string: link) {
            self.parentViewController?.presentInternalSdkWebKit(webUrl: linkUrl)
        }
    }
    
    func formatValue(_ value: Double) -> String {
        return String(format: "%.2f", value)
    }
    
    private func strikeThrough(str: String) -> NSAttributedString {
        let attributeString = NSMutableAttributedString(string: str)
        attributeString.addAttribute(NSAttributedString.Key.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSMakeRange(0, attributeString.length))
        return attributeString
    }
    
    private class func formatValue(_ value: Double) -> Int {
        return Int(value) * 2
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedRecommendationProductFroCell = cells[indexPath.row]
        recommendationsDelegate?.didTapOnProduct(product: selectedRecommendationProductFroCell)
        
        openWidgetUrl(link: selectedRecommendationProductFroCell.url)
        
        print("\nUser did tap cell from Recommendations Widget\nUse 'recommendationsDelegate' for interactions\nProduct id: \(selectedRecommendationProductFroCell.id)\n")
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: RecommendationsConstants.recommendationsCollectionItemWidth, height: frame.height * 0.9)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
