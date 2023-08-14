import Foundation
import UIKit

public enum UIFontDescriptorUsage: String {
    
    case ultraLight = "CTFontUltraLightUsage"
    case thin       = "CTFontThinUsage"
    case light      = "CTFontLightUsage"
    case regular    = "CTFontRegularUsage"
    case oblique    = "CTFontObliqueUsage"
    case medium     = "CTFontMediumUsage"
    case demi       = "CTFontDemiUsage"
    case emphasized = "CTFontEmphasizedUsage"
    case bold       = "CTFontBoldUsage"
    case heavy      = "CTFontHeavyUsage"
    case black      = "CTFontBlackUsage"
    
}

public extension UIFontDescriptor.AttributeName {
    static let usage = UIFontDescriptor.AttributeName(rawValue: "NSCTFontUIUsageAttribute")
}
