import UIKit

protocol NibView {}

extension NibView where Self: UIView {
    static func instanceFromNib() -> Self? {
        let nibName = String(describing: self)
        return Bundle.main.loadNibNamed(nibName, owner: self, options: nil)?.first as? Self
    }
}
