import UIKit

private let area = CGSize(width: 44, height: 44)

extension UIButton {
    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.isHidden || !self.isUserInteractionEnabled || self.alpha < 0.01 {
            return nil
        }
        
        let buttonSize = self.bounds.size
        let widthToAdd = max(area.width - buttonSize.width, 0)
        let heightToAdd = max(area.height - buttonSize.height, 0)
        let largerFrame = self.bounds.insetBy(dx: -widthToAdd / 2, dy: -heightToAdd / 2)
        
        return (largerFrame.contains(point)) ? self : nil
    }
}
