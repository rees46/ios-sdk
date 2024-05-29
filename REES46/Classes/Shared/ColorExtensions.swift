import Foundation
import UIKit


extension UIColor {
    public func withBrightness(brightness: CGFloat) -> UIColor {
        var H: CGFloat = 0, S: CGFloat = 0, B: CGFloat = 0, A: CGFloat = 0
        if getHue(&H, saturation: &S, brightness: &B, alpha: &A) {
            B += (brightness - 1.0)
            B = max(min(B, 1.0), 0.0)
            return UIColor(hue: H, saturation: S, brightness: B, alpha: A)
        }
        return self
    }
    
    public func withOpacity(from opacityString: String) -> UIColor {
        guard let opacityValue = extractOpacity(from: opacityString) else {
            return self
        }
        let colorWithOpacity = self.withAlphaComponent(opacityValue)
        
        return colorWithOpacity
    }
    
    private func extractOpacity(from opacityString: String) -> CGFloat? {
        let percentageString = opacityString.trimmingCharacters(in: CharacterSet(charactersIn: "%"))
        if let percentage = Double(percentageString) {
            return CGFloat(percentage) / 100.0
        }
        return nil
    }
}
