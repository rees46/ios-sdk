import UIKit

public protocol FiltersWidgetResetDelegate: AnyObject {
    func searchSelectedFiltersDataItemSelected()
    func cancelSelectedFiltersDataItemSelected()
}

public class FiltersWidgetResetCell: UITableViewCell {
    weak var delegate: FiltersWidgetResetDelegate?
    
    public override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    @objc public func searchDataItemSelected() {
        delegate?.searchSelectedFiltersDataItemSelected()
    }
    
    @objc public func cancelDataItemSelected() {
        delegate?.cancelSelectedFiltersDataItemSelected()
    }
}

@IBDesignable class FiltersResetButton: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()
        updateResetButtonCornerRadius()
    }
    
    @IBInspectable var rounded: Bool = false {
        didSet {
            updateResetButtonCornerRadius()
        }
    }
    
    func updateResetButtonCornerRadius() {
        layer.backgroundColor = UIColor.white.cgColor
        layer.masksToBounds = true
        layer.borderWidth = 2.0
        layer.borderColor = UIColor.black.cgColor
        layer.cornerRadius = 8
    }
}

@IBDesignable class FiltersSelectedShowButton: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()
        updateShowButtonCornerRadius()
    }
    
    @IBInspectable var rounded: Bool = false {
        didSet {
            updateShowButtonCornerRadius()
        }
    }
    
    func updateShowButtonCornerRadius() {
        layer.backgroundColor = UIColor.black.cgColor
        layer.masksToBounds = true
        layer.borderWidth = 2.0
        layer.borderColor = UIColor.white.cgColor
        layer.cornerRadius = 8
    }
}
