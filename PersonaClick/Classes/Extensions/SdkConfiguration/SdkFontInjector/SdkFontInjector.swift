import UIKit

public protocol SdkFontPackage: Hashable, RawRepresentable {
    static func dynamicFont(textStyle: SdkFontTextStyleImplement, weight: UIFont.Weight) -> UIFont
    static func font(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont
}

public enum FontExtension: String {
    case ttf = ".ttf"
    case otf = ".otf"
    case fnt = ".fnt"
}

open class SdkFontInjector: NSObject {
    
    public static let manager: SdkFontInjector = SdkFontInjector()
    
    public static var lastestRegisterFontFamilyName: String?
    public static var registeredFont: [String: [UIFont.Weight : String]] = [:]
    
    static internal func font(ofSize size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont? {
        guard let registeredFontName = lastestRegisterFontFamilyName,
              let fonts = registeredFont[registeredFontName],
              fonts.values.count > 0 else {
            return nil
        }
        let postScriptedName = fonts[weight] ?? fonts[.regular] ?? Array(fonts.values)[0]
        return UIFont(name: postScriptedName, size: size)
    }
    
    public enum sdkSupportedFontExtensions: String {
        case trueType = "ttf"
        case openType = "otf"

        init?(_ ver: String?) {
            if sdkSupportedFontExtensions.trueType.rawValue == ver {
                self = .trueType
            } else if sdkSupportedFontExtensions.openType.rawValue == ver {
                self = .openType
            } else {
                return nil
            }
        }
    }
    
    public func registerFontNameWithExtension(fileName: String, fileExtension: String) {
        var parsedFont: (sdkFontName, sdkFontExtension)?

        if fileName.contains(sdkSupportedFontExtensions.trueType.rawValue) || fileName.contains(sdkSupportedFontExtensions.openType.rawValue) {
            parsedFont = SdkConfiguration.fontExt(fromName: fileName)
        } else {
            var tmpName = fileName + "." + sdkSupportedFontExtensions.trueType.rawValue
            parsedFont = SdkConfiguration.fontExt(fromName: tmpName)
            if parsedFont == nil {
                tmpName = fileName + "." + sdkSupportedFontExtensions.openType.rawValue
                parsedFont = SdkConfiguration.fontExt(fromName: tmpName)
            }
        }

        if parsedFont != nil {
            let pathForResourceString = Bundle.main.path(forResource: fileName, ofType: fileExtension)
            if pathForResourceString != nil {
                let fontData = NSData(contentsOfFile: pathForResourceString!)
                let dataProvider = CGDataProvider(data: fontData!)
                let fontRef = CGFont(dataProvider!)
                var errorRef: Unmanaged<CFError>? = nil

                if (CTFontManagerRegisterGraphicsFont(fontRef!, &errorRef) == false) {
                    print("SDK Error registering font")
                } else {
                    let fontName = fontRef!.postScriptName as String?
                    let fontWeightName = "\(String(describing: fontName))".split(separator: ".").last
                    for fontWeight in UIFont.Weight.all {
                        if let key = fontWeight.key, key == fontWeightName! {
                            if SdkFontInjector.registeredFont[fontName!] == nil {
                                SdkFontInjector.registeredFont[fontName!] = [:]
                            }
                        }
                        //SdkFontInjector.registeredFont[fontName!]?[fontWeight] = fontName
                    }
                    SdkFontInjector.registeredFont[fontName!]?[UIFont.Weight.regular] = fontName
                    print("SDK Success registering font")
                    SdkFontInjector.lastestRegisterFontFamilyName = fontName
                }
            }
        }
    }
}


extension SdkFontPackage {
    public static func dynamicFont(textStyle: SdkFontTextStyleImplement, weight: UIFont.Weight = .regular) -> UIFont {
        return UIFont.dynamicFont(style: textStyle, weight: weight, ofFont: Self.self)
    }
    
    public static func font(ofSize size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        return UIFont.staicFont(ofSize: size, weight: weight)
    }
}


extension SdkFontPackage where Self.RawValue == String {
    var fileName: String {
        return rawValue
    }
    
    static var familyName: String {
        return "\(self)"
    }
}


extension UIFont.Weight {
    static var mappingKeys: [UIFont.Weight: String] {
        return [.ultraLight: "ultraLight",
                .thin: "thin",
                .light: "light",
                .regular: "regular",
                .medium: "medium",
                .semibold: "semibold",
                .bold: "bold",
                .heavy: "heavy",
                .black: "black"]
    }
    
    static var all: [UIFont.Weight] {
        return Array(mappingKeys.keys)
    }
    
    var key: String? {
        return UIFont.Weight.mappingKeys[self]
    }
    
}

