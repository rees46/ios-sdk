import UIKit

open class FiltersCheckboxTreeStyle<T: FiltersCheckboxItem> {
    
    public struct Images {
        public var checkboxOn: UIImage?
        public var checkboxOff: UIImage?
        public var checkboxMixed: UIImage?
        public var groupArrow: UIImage?
    }

    public struct ItemViewStyle {
        public var levelBoxSize: CGSize = .init(width: 29, height: 29)
        public var elementsSpacing: CGFloat = 19
        public var minHeight: CGFloat = 38
        public var titleFont: UIFont = .systemFont(ofSize: 17, weight: .regular)
        public var subtitleFont: UIFont = .systemFont(ofSize: 14, weight: .regular)
        public var titleColor: UIColor = .black
        public var subtitleColor: UIColor = .darkGray
        public var disabledStateColor: UIColor = .lightGray
    }
    
    public var isCollapseAvailable: Bool = true

    public var isCollapseAnimated: Bool = true
    
    public var collapseAnimationDuration: TimeInterval = 0.3
    
    public var itemViewStyle = ItemViewStyle()
    
    public var images = Images()
    
    open func getCheckboxItemView() -> FiltersCheckboxItemView<T> {
        return FiltersCheckboxItemView(style: self)
    }
    
    public init() {
        setupDefaultImages()
    }
    
    func setupDefaultImages() {
        var frameworkBundle = Bundle(for: FiltersCheckboxTreeStyle.self)
#if SWIFT_PACKAGE
        frameworkBundle = Bundle.module
#endif
        
        images.checkboxOn = UIImage(named: "icCheckboxFilledOn", in: frameworkBundle, compatibleWith: nil)
        images.checkboxOff = UIImage(named: "icCheckboxFilledOff", in: frameworkBundle, compatibleWith: nil)
        images.checkboxMixed = UIImage(named: "icCheckboxFilledMixed", in: frameworkBundle, compatibleWith: nil)
        images.groupArrow = UIImage(named: "angleDownBlack", in: frameworkBundle, compatibleWith: nil)
    }
}
