import UIKit

public protocol SdkStyleCustomColorScheme {
    var customColors: [String : UIColor] { get }
}


extension SdkStyleCustomColorScheme {
    public subscript(key: SdkApperanceViewScheme) -> UIColor {
        get {
            return customColors[key.SdkApperanceViewScheme()] ?? UIColor.black
        }
    }
}
