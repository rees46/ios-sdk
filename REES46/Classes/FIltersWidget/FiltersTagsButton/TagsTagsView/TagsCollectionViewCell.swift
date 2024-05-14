import UIKit

class TagsCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var menuLabel: UILabel!
    var menu = FiltersTagsMenu(filterId: -88, title: "Menu", titleFiltersValues: ["String"], selected: false)
    
    var menuString = String()
    override func awakeFromNib() {
    }
    
    override func layoutSubviews() {
        updateView()
    }
    
    func updateView(){
        menuLabel.text = menuString
        if menu.selected {
            selectedCollectionStyle()
        } else {
           unselectedCollectionStyle()
        }
    }
    
    func selectedCollectionStyle() {
        layer.borderWidth = 0
        layer.backgroundColor = UIColor.sdkDefaultBordoColor.cgColor
        layer.cornerRadius = layer.bounds.height/2
        menuLabel.textColor = UIColor.white
    }
    
    func unselectedCollectionStyle() {
        layer.borderColor = UIColor.sdkDefaultBordoColor.cgColor
        layer.backgroundColor = UIColor.tranparent.cgColor
        layer.borderWidth = 1
        layer.cornerRadius = layer.bounds.height/2
        menuLabel.textColor = UIColor.primary
    }
    
    var isHeightCalculated: Bool = false

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
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
