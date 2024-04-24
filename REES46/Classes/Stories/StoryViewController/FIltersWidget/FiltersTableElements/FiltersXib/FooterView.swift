import UIKit

protocol FooterViewDelegate: AnyObject {
    func headerFooterViewArrowInSection(header: FooterView, section: Int)
}

class FooterView: UITableViewHeaderFooterView {

//    var item: ItemBaseModel? {
//        didSet {
//            guard let item = item else {
//                return
//            }
//            
//            titleLabel?.text = item.sectionTitle
//            setCollapsed(collapsed: item.isCollapsed)
//        }
//    }
    
    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var arrowImage: UIImageView?
    
    var section: Int = 0
    
    weak var delegate: FooterViewDelegate?
    
    static var nib:UINib {
        return UINib(nibName: identifier, bundle: nil)
    }
    
    static var identifier: String {
        return String(describing: self)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapHeader)))
    }
    
    @objc private func didTapHeader() {
        
        delegate?.headerFooterViewArrowInSection(header: self, section: section)
    }

    func setCollapsed(collapsed: Bool) {
        arrowImage?.rotate(collapsed ? 0.0 : .pi)
    }
}
