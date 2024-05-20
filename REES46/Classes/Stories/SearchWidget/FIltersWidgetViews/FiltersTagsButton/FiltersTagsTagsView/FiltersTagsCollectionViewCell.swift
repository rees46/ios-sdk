import UIKit

open class FiltersTagsCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var tagLabel: UILabel!
    
    var tagsFiltersData = FiltersDataMenuList(filterId: -88, title: "Menu", titleFiltersValues: ["String"], selected: false)
    
    var tagString = String()
    
    open override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    open override func layoutSubviews() {
        updateView()
    }
    
    func updateView(){
        tagLabel.text = tagString
        if tagsFiltersData.selected {
            selectedCollectionStyle()
        } else {
           unselectedCollectionStyle()
        }
    }
    
    func selectedCollectionStyle() {
        layer.borderWidth = 0
        layer.backgroundColor = UIColor.sdkDefaultBordoColor.cgColor
        layer.cornerRadius = layer.bounds.height/2
        tagLabel.textColor = UIColor.white
    }
    
    func unselectedCollectionStyle() {
        layer.borderColor = UIColor.sdkDefaultBordoColor.cgColor
        layer.backgroundColor = UIColor.tagsPrimaryTransparentColor.cgColor
        layer.borderWidth = 1
        layer.cornerRadius = layer.bounds.height/2
        tagLabel.textColor = UIColor.tagsPrimaryColor
    }
    
    var isHeightCalculated: Bool = false

    open override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        if !isHeightCalculated {
            setNeedsLayout()
            layoutIfNeeded()
            let size = contentView.systemLayoutSizeFitting(layoutAttributes.size)
            var newFrame = layoutAttributes.frame
            newFrame.size.width = CGFloat(ceilf(Float(size.width)))
            layoutAttributes.frame = newFrame
            //isHeightCalculated = false
        }
        return layoutAttributes
    }
}
