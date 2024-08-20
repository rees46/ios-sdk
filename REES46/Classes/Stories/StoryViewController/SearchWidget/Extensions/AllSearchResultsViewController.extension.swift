import UIKit

extension AllSearchResultsViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return searchResults?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RecommendationsWidgetViewCell.reuseRecommCellId, for: indexPath) as! RecommendationsWidgetViewCell
        
        if let result = searchResults?[indexPath.item] {
            cell.recommendationsProductNameLabel.text = result.name
            cell.recommendationsPriceLabel.text = formatPrice(result.price, currencySymbol: result.currency)
            cell.recommendationsImageView.loadImage(from: result.image)
            cell.recommendationsDiscountLabel.text = "Cashback 20%" // Sample, coming soon
            cell.recommendationsCreditLabel.text = "0-0-12" // Sample, coming soon
        }
        
        return cell
    }
    
    private func formatPrice(_ price: Double, currencySymbol: String) -> String {
        let priceString = String(format: "%.2f", price)
        return priceString.formattedCurrency(withSymbol: currencySymbol)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Customize view here
    }
}
