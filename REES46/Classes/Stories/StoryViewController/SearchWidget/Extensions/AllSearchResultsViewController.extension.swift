import UIKit

extension AllSearchResultsViewController: UICollectionViewDataSource, UICollectionViewDelegate, RecommendationsWidgetViewCellDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return searchResults?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RecommendationsWidgetViewCell.reuseRecommCellId, for: indexPath) as! RecommendationsWidgetViewCell
        
        guard let result = searchResults?[indexPath.item] else { return cell }
        
        cell.recommendationsProductNameLabel.text = result.name
        cell.recommendationsPriceLabel.text = formatPrice(result.price, currencySymbol: result.currency)
        cell.recommendationsImageView.loadImage(from: result.image)
        cell.recommendationsDiscountLabel.text = "Cashback 20%"
        cell.recommendationsCreditLabel.text = "0-0-12"
        
        let ratingForStars = result.rating
        if ratingForStars == 0 {
            cell.recommendationsRatingStars.isHidden = true
            cell.recommendationsRatingStarsNoReviewsLabel.isHidden = false
            cell.recommendationsRatingStarsNoReviewsLabel.text = SdkConfiguration.recommendations.widgetNoReviewsDefaultText
        } else {
            cell.recommendationsRatingStars.isHidden = false
            cell.recommendationsRatingStarsNoReviewsLabel.isHidden = true
        }
        
        cell.widgetCellDelegate = self
        cell.recommendationsCartButton.isHidden = false
        cell.recommendationsFavoritesButton.isHidden = false
        
        let productId = result.id
        configureCartButton(cell: cell, productId: productId)
        configureFavoritesButton(cell: cell, productId: productId)
        
        return cell
    }
    
    private func formatPrice(_ price: Double, currencySymbol: String) -> String {
        let priceString = String(format: "%.2f", price)
        return priceString.formattedCurrency(withSymbol: currencySymbol)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Обработка выбора ячейки
    }
    
    func didTapWidgetAddToCartButtonInside(cell: RecommendationsWidgetViewCell, position: CGPoint) {
        guard let indexPath = resultsListView.collectionView.indexPath(for: cell) else { return }
        let productId = searchResults?[indexPath.item].id ?? ""
        toggleCartItem(for: productId, in: cell)
    }
    
    func didTapWidgetAddToFavoritesButtonInside(cell: RecommendationsWidgetViewCell, position: CGPoint) {
        guard let indexPath = resultsListView.collectionView.indexPath(for: cell) else { return }
        let productId = searchResults?[indexPath.item].id ?? ""
        toggleFavoritesItem(for: productId, in: cell)
    }
    
    private func toggleCartItem(for productId: String, in cell: RecommendationsWidgetViewCell) {
        let cartKey = "cart.product.\(productId)"
        var cartItems = UserDefaults.standard.stringArray(forKey: cartKey) ?? []
        
        if cartItems.contains(productId) {
            cartItems.removeAll { $0 == productId }
            UserDefaults.standard.setValue(cartItems, forKey: cartKey)
            cell.recommendationsCartButton.setTitle(SdkConfiguration.recommendations.widgetAddToCartButtonText, for: .normal)
        } else {
            cartItems.append(productId)
            UserDefaults.standard.setValue(cartItems, forKey: cartKey)
            cell.recommendationsCartButton.setTitle(SdkConfiguration.recommendations.widgetRemoveFromCartButtonText, for: .normal)
        }
        configureCartButtonAppearance(cell: cell, isInCart: cartItems.contains(productId))
    }
    
    private func toggleFavoritesItem(for productId: String, in cell: RecommendationsWidgetViewCell) {
        let favoritesKey = "favorites.product.\(productId)"
        var favoritesItems = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        
        if favoritesItems.contains(productId) {
            favoritesItems.removeAll { $0 == productId }
            UserDefaults.standard.setValue(favoritesItems, forKey: favoritesKey)
            cell.recommendationsFavoritesButton.setImage(UIImage(named: "iconLikeHeart"), for: .normal)
        } else {
            favoritesItems.append(productId)
            UserDefaults.standard.setValue(favoritesItems, forKey: favoritesKey)
            cell.recommendationsFavoritesButton.setImage(UIImage(named: "iconLikeHeartFill"), for: .normal)
        }
    }
    
    private func configureCartButton(cell: RecommendationsWidgetViewCell, productId: String) {
        let cartKey = "cart.product.\(productId)"
        let cartItems = UserDefaults.standard.stringArray(forKey: cartKey) ?? []
        let isInCart = cartItems.contains(productId)
        
        let buttonText = isInCart ? SdkConfiguration.recommendations.widgetRemoveFromCartButtonText : SdkConfiguration.recommendations.widgetAddToCartButtonText
        cell.recommendationsCartButton.setTitle(buttonText, for: .normal)
        
        configureCartButtonAppearance(cell: cell, isInCart: isInCart)
    }

    private func configureCartButtonAppearance(cell: RecommendationsWidgetViewCell, isInCart: Bool) {
        let textColor: UIColor
        let backgroundColor: UIColor
        let font: UIFont
        
        if SdkConfiguration.isDarkMode {
            textColor = UIColor(hex: SdkConfiguration.recommendations.widgetCartButtonTextColorDarkMode)
            backgroundColor = UIColor(hex: SdkConfiguration.recommendations.widgetCartButtonBackgroundColorDarkMode)
        } else {
            textColor = UIColor(hex: SdkConfiguration.recommendations.widgetCartButtonTextColor)
            backgroundColor = UIColor(hex: SdkConfiguration.recommendations.widgetCartButtonBackgroundColor)
        }
        
        cell.recommendationsCartButton.setTitleColor(textColor, for: .normal)
        cell.recommendationsCartButton.backgroundColor = backgroundColor
        
        let fontSize = SdkConfiguration.recommendations.widgetAddToCartButtonFontSize ?? 17.0
        if let fontName = SdkConfiguration.recommendations.widgetFontName {
            font = UIFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize, weight: .semibold)
        } else {
            font = .systemFont(ofSize: fontSize, weight: .semibold)
        }
        cell.recommendationsCartButton.titleLabel?.font = font
    }
    
    private func configureFavoritesButton(cell: RecommendationsWidgetViewCell, productId: String) {
        let favoritesKey = "favorites.product.\(productId)"
        var favoritesItems = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []

        let isProductFavorited = favoritesItems.contains(productId)
        
        var frameworkBundle = Bundle(for: type(of: self))
    #if SWIFT_PACKAGE
        frameworkBundle = Bundle.module
    #endif
        
        if isProductFavorited {
            if let index = favoritesItems.firstIndex(of: productId) {
                favoritesItems.remove(at: index)
            }
            UserDefaults.standard.setValue(favoritesItems, forKey: favoritesKey)
            
            sdkRemoveFromFavorites(productId: productId)
            
            var heartClearIcon = UIImage(named: "iconLikeHeartDark", in: frameworkBundle, compatibleWith: nil)
            if SdkConfiguration.isDarkMode {
                heartClearIcon = UIImage(named: "iconLikeHeartLight", in: frameworkBundle, compatibleWith: nil)
            }
            let heartClearImageRender = heartClearIcon?.withRenderingMode(.alwaysTemplate)
            cell.recommendationsFavoritesButton.setImage(heartClearImageRender, for: .normal)
            
            var customHeartTintColor = SdkConfiguration.recommendations.widgetFavoritesIconColor.hexToRGB()
            if SdkConfiguration.isDarkMode {
                customHeartTintColor = SdkConfiguration.recommendations.widgetFavoritesIconColorDarkMode.hexToRGB()
            }
            cell.recommendationsFavoritesButton.tintColor = UIColor(red: customHeartTintColor.red, green: customHeartTintColor.green, blue: customHeartTintColor.blue, alpha: 1)
            
        } else {
            favoritesItems.append(productId)
            UserDefaults.standard.setValue(favoritesItems, forKey: favoritesKey)
            
            sdkAddToFavorites(productId: productId)
            
            var heartFillIcon = UIImage(named: "iconLikeHeartFillDark", in: frameworkBundle, compatibleWith: nil)
            if SdkConfiguration.isDarkMode {
                heartFillIcon = UIImage(named: "iconLikeHeartFillLight", in: frameworkBundle, compatibleWith: nil)
            }
            let heartFillImageRender = heartFillIcon?.withRenderingMode(.alwaysTemplate)
            cell.recommendationsFavoritesButton.setImage(heartFillImageRender, for: .normal)
            
            var customHeartTintColor = SdkConfiguration.recommendations.widgetFavoritesIconColor.hexToRGB()
            if SdkConfiguration.isDarkMode {
                customHeartTintColor = SdkConfiguration.recommendations.widgetFavoritesIconColorDarkMode.hexToRGB()
            }
            cell.recommendationsFavoritesButton.tintColor = UIColor(red: customHeartTintColor.red, green: customHeartTintColor.green, blue: customHeartTintColor.blue, alpha: 1)
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
}
