import UIKit

extension AllSearchResultsViewController: UICollectionViewDataSource, UICollectionViewDelegate, RecommendationsWidgetViewCellDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return searchResults?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RecommendationsWidgetViewCell.reuseRecommCellId, for: indexPath) as! RecommendationsWidgetViewCell
        
        if let result = searchResults?[indexPath.item] {
            cell.recommendationsProductNameLabel.text = result.name
            cell.recommendationsPriceLabel.text = formatPrice(result.price, currencySymbol: result.currency)
            cell.recommendationsImageView.loadImage(from: result.image)
            cell.recommendationsDiscountLabel.text = "Cashback 20%"
            cell.recommendationsCreditLabel.text = "0-0-12"
        }
        
        let ratingForStars = searchResults?[indexPath.item].rating
        if ratingForStars == 0 {
            cell.recommendationsRatingStars.isHidden = true
            cell.recommendationsRatingStarsNoReviewsLabel.isHidden = false
            cell.recommendationsRatingStarsNoReviewsLabel.text = SdkConfiguration.recommendations.widgetNoReviewsDefaultText
        } else {
            cell.recommendationsRatingStars.isHidden = false
            cell.recommendationsRatingStarsNoReviewsLabel.isHidden = true
            cell.recommendationsRatingStarsNoReviewsLabel.text = ""
        }
        
        cell.widgetCellDelegate = self
        
        cell.recommendationsCartButton.isHidden = false
        cell.recommendationsFavoritesButton.isHidden = false
        
        let product = searchResults?[indexPath.item]
        let productId = product?.id ?? ""
        
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
        let product = searchResults?[indexPath.item]
        let productId = product?.id ?? ""
        
        toggleCartItem(for: productId, in: cell)
    }
    
    func didTapWidgetAddToFavoritesButtonInside(cell: RecommendationsWidgetViewCell, position: CGPoint) {
        guard let indexPath = resultsListView.collectionView.indexPath(for: cell) else { return }
        let product = searchResults?[indexPath.item]
        let productId = product?.id ?? ""
        
        toggleFavoritesItem(for: productId, in: cell)
    }
    
    private func toggleCartItem(for productId: String, in cell: RecommendationsWidgetViewCell) {
        let cartKey = "cart.product.\(productId)"
        var cartItems = UserDefaults.standard.stringArray(forKey: cartKey) ?? []
        print("PRODUCT ID toggleCartItem \(productId)")
        
        if cartItems.contains(productId) {
            cartItems.removeAll { $0 == productId }
            UserDefaults.standard.setValue(cartItems, forKey: cartKey)
            cell.recommendationsCartButton.setTitle("Add to cart", for: .normal)
            //            sdk?.track(event: .productRemovedFromCart(id: productId))
        } else {
            cartItems.append(productId)
            UserDefaults.standard.setValue(cartItems, forKey: cartKey)
            cell.recommendationsCartButton.setTitle("Remove to cart", for: .normal)
            //            sdk?.track(event: .productAddedToCart(id: productId))
        }
    }
    
    private func toggleFavoritesItem(for productId: String, in cell: RecommendationsWidgetViewCell) {
        let favoritesKey = "favorites.product.\(productId)"
        var favoritesItems = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        
        if favoritesItems.contains(productId) {
            favoritesItems.removeAll { $0 == productId }
            UserDefaults.standard.setValue(favoritesItems, forKey: favoritesKey)
            cell.recommendationsFavoritesButton.setImage(UIImage(named: "iconLikeHeart"), for: .normal)
            //            sdk?.track(event: .productRemovedFromFavorites(id: productId))
        } else {
            favoritesItems.append(productId)
            UserDefaults.standard.setValue(favoritesItems, forKey: favoritesKey)
            cell.recommendationsFavoritesButton.setImage(UIImage(named: "iconLikeHeartFill"), for: .normal)
            //            sdk?.track(event: .productAddedToFavorites(id: productId))
        }
    }
    
    private func configureCartButton(cell: RecommendationsWidgetViewCell, productId: String) {
        let cartKey = "cart.product.\(productId)"
        let cartItems = UserDefaults.standard.stringArray(forKey: cartKey) ?? []
        
        if cartItems.contains(productId) {
            cell.recommendationsCartButton.setTitle("Remove from cart", for: .normal)
            
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
        } else {
            cell.recommendationsCartButton.setTitle("Add to cart", for: .normal)
            
            let widgetCartButtonTextColor = SdkConfiguration.recommendations.widgetCartButtonTextColor.hexToRGB()
            let tColor = UIColor(red: widgetCartButtonTextColor.red, green: widgetCartButtonTextColor.green, blue: widgetCartButtonTextColor.blue, alpha: 1)
            cell.recommendationsCartButton.setTitleColor(tColor, for: .normal)
            
            let widgetCartButtonBackgroundColor = SdkConfiguration.recommendations.widgetCartButtonBackgroundColor.hexToRGB()
            let bgColor = UIColor(red: widgetCartButtonBackgroundColor.red, green: widgetCartButtonBackgroundColor.green, blue: widgetCartButtonBackgroundColor.blue, alpha: 1)
            cell.recommendationsCartButton.backgroundColor = bgColor
        }
    }
    
    private func configureFavoritesButton(cell: RecommendationsWidgetViewCell, productId: String) {
        let favoritesKey = "favorites.product.\(productId)"
        let favoritesItems = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        
        if favoritesItems.contains(productId) {
            cell.recommendationsFavoritesButton.setImage(UIImage(named: "iconLikeHeartFill"), for: .normal)
        } else {
            cell.recommendationsFavoritesButton.setImage(UIImage(named: "iconLikeHeart"), for: .normal)
        }
    }
}
