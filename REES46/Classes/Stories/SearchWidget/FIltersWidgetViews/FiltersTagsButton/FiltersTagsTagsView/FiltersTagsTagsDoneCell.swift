import UIKit

open class FiltersWidgetTagsDoneCell: UITableViewCell {
    
    var delegate : FiltersWidgetDoneDelegate?

    open override func awakeFromNib() {
        super.awakeFromNib()
    }

    open override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    @objc func doneAction() {
        self.delegate?.didDoneTapped()
    }
}

protocol FiltersWidgetDoneDelegate {
    func didDoneTapped()
}
