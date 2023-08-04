import UIKit

extension UIFont {
    public convenience init?(font: UIFont.TextStyle, size: CGFloat) {
        let fontIdentifier: String = font.rawValue
        self.init(name: fontIdentifier, size: size)
    }

    @available(iOS 11.0, *)
    public static func scaled(font: UIFont.TextStyle, textStyle: UIFont.TextStyle = .body) -> UIFont? {
        let defaultSize = UIFont.preferredFont(forTextStyle: textStyle).pointSize
        guard let font = UIFont(font: font, size: defaultSize) else { return nil }
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
    }
}
