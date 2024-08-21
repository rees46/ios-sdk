import UIKit

extension AllSearchResultsViewController: UICollectionViewDataSource, UICollectionViewDelegate, RecommendationsWidgetViewCellDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return searchResults?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RecommendationsWidgetViewCell.reuseRecommCellId, for: indexPath) as! RecommendationsWidgetViewCell
        
        guard let result = searchResults?[indexPath.item] else { return cell }
        
        configureCell(cell, with: result)
        
        return cell
    }
    
    private func configureCell(_ cell: RecommendationsWidgetViewCell, with result: SearchResult) {
        cell.recommendationsProductNameLabel.text = result.name
        cell.recommendationsPriceLabel.text = formatPrice(result.price, currencySymbol: result.currency)
        cell.recommendationsImageView.loadImage(from: result.image)
        cell.recommendationsDiscountLabel.text = "Cashback 20%"
        cell.recommendationsCreditLabel.text = "0-0-12"
        
        configureRating(for: cell, with: result.rating)
        
        cell.widgetCellDelegate = self
        cell.recommendationsCartButton.isHidden = false
        cell.recommendationsFavoritesButton.isHidden = false
        
        configureCartButton(cell: cell, productId: result.id)
        configureFavoritesButton(cell: cell, productId: result.id)
    }
    
    private func configureRating(for cell: RecommendationsWidgetViewCell, with rating: Int) {
        if rating == 0 {
            cell.recommendationsRatingStars.isHidden = true
            cell.recommendationsRatingStarsNoReviewsLabel.isHidden = false
            cell.recommendationsRatingStarsNoReviewsLabel.text = SdkConfiguration.recommendations.widgetNoReviewsDefaultText
        } else {
            cell.recommendationsRatingStars.isHidden = false
            cell.recommendationsRatingStarsNoReviewsLabel.isHidden = true
        }
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
            removeProductFromCart(cartItems, productId: productId, cartKey: cartKey, cell: cell)
        } else {
            addProductToCart(cartItems, productId: productId, cartKey: cartKey, cell: cell)
        }
    }
    
    private func removeProductFromCart(_ cartItems: [String], productId: String, cartKey: String, cell: RecommendationsWidgetViewCell) {
        var updatedCartItems = cartItems
        updatedCartItems.removeAll { $0 == productId }
        UserDefaults.standard.setValue(updatedCartItems, forKey: cartKey)
        cell.recommendationsCartButton.setTitle(SdkConfiguration.recommendations.widgetAddToCartButtonText, for: .normal)
        configureCartButtonAppearance(cell: cell, isInCart: false)
    }
    
    private func addProductToCart(_ cartItems: [String], productId: String, cartKey: String, cell: RecommendationsWidgetViewCell) {
        var updatedCartItems = cartItems
        updatedCartItems.append(productId)
        UserDefaults.standard.setValue(updatedCartItems, forKey: cartKey)
        cell.recommendationsCartButton.setTitle(SdkConfiguration.recommendations.widgetRemoveFromCartButtonText, for: .normal)
        configureCartButtonAppearance(cell: cell, isInCart: true)
    }
    
    private func toggleFavoritesItem(for productId: String, in cell: RecommendationsWidgetViewCell) {
        let favoritesKey = "favorites.product.\(productId)"
        var favoritesItems = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        
        if favoritesItems.contains(productId) {
            removeProductFromFavorites(favoritesItems, productId: productId, favoritesKey: favoritesKey, cell: cell)
        } else {
            addProductToFavorites(favoritesItems, productId: productId, favoritesKey: favoritesKey, cell: cell)
        }
    }
    
    private func removeProductFromFavorites(_ favoritesItems: [String], productId: String, favoritesKey: String, cell: RecommendationsWidgetViewCell) {
        var updatedFavoritesItems = favoritesItems
        updatedFavoritesItems.removeAll { $0 == productId }
        UserDefaults.standard.setValue(updatedFavoritesItems, forKey: favoritesKey)
        cell.recommendationsFavoritesButton.setImage(UIImage(named: "iconLikeHeartDark"), for: .normal)
    }
    
    private func addProductToFavorites(_ favoritesItems: [String], productId: String, favoritesKey: String, cell: RecommendationsWidgetViewCell) {
        var updatedFavoritesItems = favoritesItems
        updatedFavoritesItems.append(productId)
        UserDefaults.standard.setValue(updatedFavoritesItems, forKey: favoritesKey)
        cell.recommendationsFavoritesButton.setImage(UIImage(named: "iconLikeHeartFillDark"), for: .normal)
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
        font = UIFont(name: SdkConfiguration.recommendations.widgetFontName ?? "Helvetica", size: fontSize) ?? .systemFont(ofSize: fontSize, weight: .semibold)
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
            removeProductFromFavorites(favoritesItems, productId: productId, favoritesKey: favoritesKey, cell: cell)
            configureFavoritesButtonAppearance(cell: cell, isFavorited: true, frameworkBundle: frameworkBundle)
        } else {
            addProductToFavorites(favoritesItems, productId: productId, favoritesKey: favoritesKey, cell: cell)
            configureFavoritesButtonAppearance(cell: cell, isFavorited: false, frameworkBundle: frameworkBundle)
        }
    }
    private func configureFavoritesButtonAppearance(cell: RecommendationsWidgetViewCell, isFavorited: Bool, frameworkBundle: Bundle) {
        let iconName = isFavorited ? "iconLikeHeartFillDark" : "iconLikeHeartDark"
        let iconNameDarkMode = isFavorited ? "iconLikeHeartFillLight" : "iconLikeHeartLight"
        
        let iconNameToUse = SdkConfiguration.isDarkMode ? iconNameDarkMode : iconName
        let heartIcon = UIImage(named: iconNameToUse, in: frameworkBundle, compatibleWith: nil)?.withRenderingMode(.alwaysTemplate)
        cell.recommendationsFavoritesButton.setImage(heartIcon, for: .normal)
        
        let customHeartTintColor = SdkConfiguration.isDarkMode ? SdkConfiguration.recommendations.widgetFavoritesIconColorDarkMode.hexToRGB() : SdkConfiguration.recommendations.widgetFavoritesIconColor.hexToRGB()
        cell.recommendationsFavoritesButton.tintColor = UIColor(red: customHeartTintColor.red, green: customHeartTintColor.green, blue: customHeartTintColor.blue, alpha: 1)
    }
    
    public func sdkAddToFavorites(productId: String) {
        sdk?.track(event: .productAddedToFavorites(id: productId)) { trackResponse in
            switch trackResponse {
            case .success(_):
                print("Product id \(productId) added to 'Favorites' success")
            case let .failure(error):
                print("Error:", error)
            }
        }
    }
    
    public func sdkRemoveFromFavorites(productId: String) {
        sdk?.track(event: .productRemovedFromFavorites(id: productId)) { trackResponse in
            switch trackResponse {
            case .success(_):
                print("Product id \(productId) removed from 'Favorites' success")
            case let .failure(error):
                print("Error:", error)
            }
        }
    }
}
