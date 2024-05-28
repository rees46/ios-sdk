import UIKit
import Foundation

protocol TBAppearanceConfigurable {
    var textColor: UIColor { get }
    var cornerRadius: CGFloat { get }
    var clipsToBounds: Bool { get }
    var backgroundColor: UIColor { get }
    var yOffset: CGFloat { get }
}

public struct TBAppearanceConfiguration: TBAppearanceConfigurable {
    let yOffset: CGFloat
    let textColor: UIColor
    let backgroundColor: UIColor
    let cornerRadius: CGFloat
    let clipsToBounds: Bool
    
    init(from textBlockObject: StoriesElement, clipsToBounds: Bool = true) {
        self.yOffset = textBlockObject.yOffset ?? 0
        self.textColor = textBlockObject.textColor != nil
        ? UIColor(hexString: textBlockObject.textColor!)
        : .black
        
        self.backgroundColor = textBlockObject.textBackgroundColor != nil
        ? UIColor(hexString: textBlockObject.textBackgroundColor!).withOpacity(from: textBlockObject.textBackgroundColorOpacity ?? "")
        : UIColor.clear
        
        self.cornerRadius = CGFloat(textBlockObject.cornerRadius)
        self.clipsToBounds = clipsToBounds
    }
}
