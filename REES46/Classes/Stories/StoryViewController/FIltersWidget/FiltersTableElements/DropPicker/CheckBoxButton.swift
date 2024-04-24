import UIKit

class CheckBoxButton: UIButton {
    
    let checkedImage = UIImage(named: "icCheckboxFilledOn")! as UIImage
    let uncheckedImage = UIImage(named: "icCheckboxFilledOff")! as UIImage
    
    var isChecked: Bool = false {
        didSet{
            if isChecked == true {
                self.setImage(uncheckedImage, for: .normal)
            } else {
                self.setImage(checkedImage, for: .normal)
            }
        }
    }
    
    override func awakeFromNib() {
        self.isUserInteractionEnabled = true
        self.addTarget(self, action: #selector(CheckBoxButton.buttonClicked), for: .touchUpInside)
                self.isChecked = false 
    }
    
    @objc func buttonClicked(sender: UIButton) {
        if sender == self {
            if isChecked == true {
                isChecked = false
            } else {
                isChecked = true
            }
        }
    }
}
