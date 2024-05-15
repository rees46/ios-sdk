import UIKit

protocol FiltersWidgetFooterViewDelegate: AnyObject {
    func headerFooterViewArrowInSection(header: FiltersWidgetFooterView, section: Int)
}

open class FiltersWidgetFooterView: UITableViewHeaderFooterView {
    
    @IBOutlet weak var titleLabel: UILabel?
    
    @IBOutlet weak var arrowImage: UIImageView?
    
    var section: Int = 0
    
    weak var delegate: FiltersWidgetFooterViewDelegate?
    
    public override func awakeFromNib() {
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
