import UIKit

class DoneTableViewCell: UITableViewCell {
    
    var delegate : DoneDelegate?

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

protocol DoneDelegate {
    func didDoneTapped()
}
