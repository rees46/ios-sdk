import UIKit

class FiltersTagsCollectionView: UICollectionView {
    var isDynamicSizeRequired = false
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    override var intrinsicContentSize: CGSize {
        return contentSize
    }
}
