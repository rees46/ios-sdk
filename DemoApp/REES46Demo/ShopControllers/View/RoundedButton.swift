import UIKit

class RoundedButton: UIButton {

    override func draw(_ rect: CGRect) {
        layer.cornerRadius = 5
        clipsToBounds = true
    }

}
