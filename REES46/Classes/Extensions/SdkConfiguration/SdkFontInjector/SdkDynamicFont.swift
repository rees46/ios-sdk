import UIKit

public enum SdkDynamicFont: String, SdkFontPackage {
    
    //SAMPLE
    case regular = "Museo"
    case bold = "Museo-Bold"
    
    public var fontPath: String {
        return ""
    }
    
    public var fontExtension: FontExtension {
        return .otf
    }
    
}
