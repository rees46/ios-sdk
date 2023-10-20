import UIKit

public protocol SdkStyleCustomFonts {
    var customFonts: [String : UIFont] { get set }
}


extension SdkStyleCustomFonts {
    public subscript(key: SdkApperanceViewScheme) -> UIFont {
        get {
            return customFonts[key.SdkApperanceViewScheme()] ?? UIFont.systemFont(ofSize: UIFont.systemFontSize)
        }
        set {
            
        }
        
    }
}
