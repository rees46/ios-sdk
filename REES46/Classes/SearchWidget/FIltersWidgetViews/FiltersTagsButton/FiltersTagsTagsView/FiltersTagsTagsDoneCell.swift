import UIKit

class FiltersWidgetTagsDoneCell: UITableViewCell {
    
    var delegate : FiltersWidgetDoneDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    @IBAction func doneAction(_ sender: Any) {
        self.delegate?.didDoneTapped()
    }
}

protocol FiltersWidgetDoneDelegate {
    func didDoneTapped()
}
