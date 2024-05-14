import UIKit

class SearchWidgetCellRoundedButton: UIButton {
    override func draw(_ rect: CGRect) {
        layer.cornerRadius = 5
        clipsToBounds = true
    }
}
