import UIKit

protocol FiltersWidgetResetDelegate: AnyObject {
    func dismissNow()
}

open class FiltersWidgetResetCell: UITableViewCell {
    
    weak var delegate: FiltersWidgetResetDelegate?
    
    static var nib:UINib {
        return UINib(nibName: identifier, bundle: nil)
    }
    
    static var identifier: String {
        return String(describing: self)
    }
    
    @IBAction func searchDataItemSelected(_ sender: Any?) {
        //delegate?.dismissNow()
    }
    
    @IBAction func cancelDataItemSelected(_ sender: Any?) {
        delegate?.dismissNow()
    }
    
    public override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}

@IBDesignable open class FiltersResetButton: UIButton {
    open override func layoutSubviews() {
        super.layoutSubviews()
        updateButtonCornerRadius()
    }

    @IBInspectable var rounded: Bool = false {
        didSet {
            updateButtonCornerRadius()
        }
    }

    func updateButtonCornerRadius() {
        layer.backgroundColor = UIColor.white.cgColor
        layer.masksToBounds = true
        layer.borderWidth = 2.0
        layer.borderColor = UIColor.black.cgColor
        layer.cornerRadius = 8
    }
}

@IBDesignable open class FiltersSelectedShowButton: UIButton {
    open override func layoutSubviews() {
        super.layoutSubviews()
        updateButtonCornerRadius()
    }

    @IBInspectable var rounded: Bool = false {
        didSet {
            updateButtonCornerRadius()
        }
    }

    func updateButtonCornerRadius() {
        layer.backgroundColor = UIColor.black.cgColor
        layer.masksToBounds = true
        layer.borderWidth = 2.0
        layer.borderColor = UIColor.white.cgColor
        layer.cornerRadius = 8
    }
}
