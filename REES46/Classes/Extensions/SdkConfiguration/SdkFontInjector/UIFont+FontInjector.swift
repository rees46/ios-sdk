import UIKit

public enum SdkFontTextStyleImplement: Int {
    
    case largeTitleDefault = 0
    case largeTitle
    case mediumTitle
    case smallTitle
    case headline
    case body
    case callout
    case subheadline
    case footnote
    case caption1
    case caption2
    
    internal var systemSdkFontTextStyleImplement: UIFont.TextStyle? {
        return [SdkFontTextStyleImplement.largeTitle: UIFont.TextStyle.title1,
                SdkFontTextStyleImplement.mediumTitle: UIFont.TextStyle.title2,
                SdkFontTextStyleImplement.smallTitle: UIFont.TextStyle.title3,
                SdkFontTextStyleImplement.headline: UIFont.TextStyle.headline,
                SdkFontTextStyleImplement.body: UIFont.TextStyle.body,
                SdkFontTextStyleImplement.callout: UIFont.TextStyle.callout,
                SdkFontTextStyleImplement.subheadline: UIFont.TextStyle.subheadline,
                SdkFontTextStyleImplement.footnote: UIFont.TextStyle.footnote,
                SdkFontTextStyleImplement.caption1: UIFont.TextStyle.caption1,
                SdkFontTextStyleImplement.caption2: UIFont.TextStyle.caption2][self]
    }
    
    public var dynamicPointSize: CGFloat {
        if let systemSdkFontTextStyleImplement = systemSdkFontTextStyleImplement {
            return UIFont.preferredFont(forTextStyle: systemSdkFontTextStyleImplement).pointSize
        } else if self == .largeTitle {
            let titleFontSize = UIFont.preferredFont(forTextStyle: .title1).pointSize
            if let title1SizingMapper = [38, 43, 48, 53, 58].firstIndex(of: titleFontSize) {
                return [44, 48, 52, 56, 60][title1SizingMapper]
            }
            return 52
        }
        return 16
    }
    
}


extension UIFont {
    class func dynamicFont<T: SdkFontPackage>(style: SdkFontTextStyleImplement,
                                                  weight: UIFont.Weight = .regular,
                                                  ofFont font: T.Type? = nil) -> UIFont {
        return UIFont.staicFont(ofSize: style.dynamicPointSize, weight: weight)
    }
    
    internal class func staicFont(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        if let font = SdkFontInjector.font(ofSize: size, weight: weight) {
            return font
        }
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
    
}
