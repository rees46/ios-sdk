import UIKit

protocol CheckBoxDelegate: AnyObject {
    func checkBoxCell(didChangeState isChecked: Bool, for color: String)
}
