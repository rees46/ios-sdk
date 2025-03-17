import UIKit

class DialogStyle {

    static func applyBottomDialogStyle(to contentView: UIView) {
        contentView.layer.cornerRadius = AppDimensions.Padding.medium
        contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }
    
    static func applyTopDialogStyle(to contentView: UIView) {
        contentView.layer.cornerRadius = AppDimensions.Padding.medium
        contentView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    }
    
    static func applyBackgroundStyle(to view: UIView) {
        view.backgroundColor = UIColor.black.withAlphaComponent(AppDimensions.Alpha.background)
    }
}
