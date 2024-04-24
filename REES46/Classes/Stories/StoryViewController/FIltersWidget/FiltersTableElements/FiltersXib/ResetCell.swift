import UIKit

protocol AboutViewDelegate: AnyObject {
    //func sNow()
    func dismissNow()
}

class ResetCell: UITableViewCell {

    @IBOutlet weak var aboutLabel: UILabel?
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var checkBox: CheckBoxButton!
    
    weak var delegate: AboutViewDelegate?
    
//    var item: ItemBaseModel? {
//        didSet {
//            guard  item is ItemAbout else {
//                return
//            }
//            
////            aboutLabel?.text = item.about
//        }
//    }
    
    static var nib:UINib {
        return UINib(nibName: identifier, bundle: nil)
    }
    
    static var identifier: String {
        return String(describing: self)
    }
    
    @IBAction func searchDataItemSelected(_ sender: Any?) {
        //delegate?.sNow()
        
    }
    
    @IBAction func cancelDataItemSelected(_ sender: Any?) {
        delegate?.dismissNow()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}


@IBDesignable class ResetFiltersButton: UIButton {
    override func layoutSubviews() {
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
        //layer.cornerRadius = frame.size.height / 2
    }
}



@IBDesignable class ShowFiltersButton: UIButton {
    override func layoutSubviews() {
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
        //layer.cornerRadius = frame.size.height / 2
    }
}
