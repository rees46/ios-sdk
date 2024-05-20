import UIKit

public enum SdkDynamicFont: String, SdkFontPackage {
    
    case regular = "Inter"

    public var fontPath: String {
        return ""
    }
    
    public var fontExtension: FontExtension {
        return .ttf
    }
    
}
