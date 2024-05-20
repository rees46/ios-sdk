import UIKit

public class FiltersTagsCollectionView: UICollectionView {
    
    var isDynamicSizeRequired = false
    
    open override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    open override var intrinsicContentSize: CGSize {
        return contentSize
    }
}
