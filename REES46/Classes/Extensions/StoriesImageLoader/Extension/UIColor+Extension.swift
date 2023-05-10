import UIKit

extension String {
    func hexToRGB() -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        var hexFormatted: String = self.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if hexFormatted.hasPrefix("#") {
            hexFormatted = String(hexFormatted.dropFirst())
        }
        
        if hexFormatted.count != 6 {
            return (0, 0, 0)
        }
        
        var rgb: UInt64 = 0
        Scanner(string: hexFormatted).scanHexInt64(&rgb)
        
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        
        return (red, green, blue)
    }

}
