import UIKit

protocol HeaderViewDelegate: AnyObject {
    func headerExpandArrowInSection(header: HeaderView, section: Int)
}

class HeaderView: UITableViewHeaderFooterView {

    @IBOutlet weak var titleLabel: UILabel?
    
    var section: Int = 0
    
    weak var delegate: HeaderViewDelegate?
    
    static var nib:UINib {
        return UINib(nibName: identifier, bundle: nil)
    }
    
    static var identifier: String {
        return String(describing: self)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if #available(iOS 13.0, *) {
            self.contentView.backgroundColor = UIColor(red: 252/255, green: 252/255, blue: 252/255, alpha: 1)
        } else {
            // TODO Implementation
        }
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapHeader)))
    }
    
    @objc private func didTapHeader() {
        delegate?.headerExpandArrowInSection(header: self, section: section)
    }

}

extension UIView {
    func rotate(_ toValue: CGFloat, duration: CFTimeInterval = 0.2) {
        let animation = CABasicAnimation(keyPath: "transform.rotation")
        
        animation.toValue = toValue
        animation.duration = duration
        animation.isRemovedOnCompletion = false
        animation.fillMode = CAMediaTimingFillMode.forwards
        
        self.layer.add(animation, forKey: nil)
    }
}
