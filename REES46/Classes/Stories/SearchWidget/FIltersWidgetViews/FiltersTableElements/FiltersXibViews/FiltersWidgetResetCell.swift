import UIKit

protocol FiltersWidgetResetDelegate: AnyObject {
    func dismissNow()
}

public class FiltersWidgetResetCell: UITableViewCell {
    
    @IBOutlet private weak var searchDataButton: UIButton!
    @IBOutlet private weak var resetDataButton: UIButton!
    
    weak var delegate: FiltersWidgetResetDelegate?
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        searchDataButton.addTarget(self, action: #selector(searchDataItemSelected), for: .touchUpInside)
        resetDataButton.addTarget(self, action: #selector(cancelDataItemSelected), for: .touchUpInside)
    }
    
    @objc public func searchDataItemSelected() {
        delegate?.dismissNow()
    }
    
    @objc public func cancelDataItemSelected() {
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
