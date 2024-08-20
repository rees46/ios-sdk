import UIKit

extension AllSearchResultsViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return searchResults?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RecommendationsWidgetViewCell.reuseRecommCellId, for: indexPath) as! RecommendationsWidgetViewCell
        
        if let result = searchResults?[indexPath.item] {
            cell.recommendationsProductNameLabel.text = result.name
            cell.recommendationsPriceLabel.text = "\(result.price)"
            cell.recommendationsImageView.loadImage(from: result.image)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Customize view here
    }
}
