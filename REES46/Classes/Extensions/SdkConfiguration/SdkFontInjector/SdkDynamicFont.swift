import UIKit

public enum SdkDynamicFont: String, SdkFontPackage {
    
    //SDK SAMPLE FONT INNTERGATION IN ASSEMBLER
    case regular = "Museo"
    case bold = "Museo-Bold"

    public var fontPath: String {
        return ""
    }
    
    public var fontExtension: FontExtension {
        return .ttf
    }
    
}
