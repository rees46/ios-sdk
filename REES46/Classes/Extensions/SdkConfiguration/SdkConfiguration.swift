import UIKit.UIFont
import Foundation

public protocol SdkConfigurationProtocol: AnyObject {
    //
}

//public typealias SdkConfiguration = SdkConfiguration
public typealias sdkFontPath = URL
public typealias sdkFontName = String
public typealias sdkFontExtension = String
public typealias sdkFontClass = (url: sdkFontPath, name: sdkFontName)

open class SdkConfiguration: SdkConfigurationProtocol {

    public static let stories: SdkConfiguration = SdkConfiguration()
    
    open var name: String?
    
    public init() {}

    public private(set) static var fontFamily: SdkFontFamily!
    
    lazy var _fontNames = originalFontNames
    public var fontNames: [String] { return _fontNames }
    public var allLoadedFonts: [sdkFontClass] = []
    public var arg: String = ""
    
    public var originalFontNames = [
        "Open Sans",
        "Open Sans Bold",
        "Open Sans Bold Italic",
        "Open Sans Extra Bold",
        "Open Sans Extra Bold Italic",
        "Open Sans Italic",
        "Open Sans Light",
        "Open Sans Semi Bold",
        "Open Sans Semi Bold Italic",
        "Open SansLight Italic",
    ]
    
    public func overrideSystemFont(fontName: String) {
        overrideSystemFont(fontFamily: SdkFontFamily(regular: fontName))
    }
    
    public func overrideSystemFont(fontFamily: SdkFontFamily) {
        SdkConfiguration.fontFamily = fontFamily
        SdkConfiguration.exchangeOriginalUIFontMethodsWithCustomMethods()
    }
    
    public class func customFont(name: String, size: CGFloat) -> UIFont {
        let sizeWithOffset = size
        guard let sFont = UIFont(name: name, size: sizeWithOffset) else {
            UIFont.familyNames.forEach({ familyName in
                let fontNames = UIFont.fontNames(forFamilyName: familyName)
                print(familyName, fontNames)
            })
            print("SDK! ERROR!", name)
            fatalError("SDK Font not found: \(name)")
        }
        return sFont
    }
    
    public func registerFont(fileName: String) {
        //sdk.configuration().stories?.registerFont(fileName: "Roboto-Italic.ttf")
        var parsedFont: (sdkFontName, sdkFontExtension)?

        if fileName.contains(SdkSupportedFontExtensions.trueType.rawValue) || fileName.contains(SdkSupportedFontExtensions.openType.rawValue) {
            parsedFont = SdkConfiguration.fontExt(fromName: fileName)
        } else {
            let tmpName = fileName + "." + SdkSupportedFontExtensions.trueType.rawValue
            parsedFont = SdkConfiguration.fontExt(fromName: tmpName)
        }

        if let parsedFont = parsedFont {

            let pathForResourceString = Bundle.main.path(forResource: parsedFont.0, ofType: parsedFont.1)
            if pathForResourceString != nil {
                let fontData = NSData(contentsOfFile: pathForResourceString!)
                let dataProvider = CGDataProvider(data: fontData!)
                let fontRef = CGFont(dataProvider!)
                var errorRef: Unmanaged<CFError>? = nil

                if (CTFontManagerRegisterGraphicsFont(fontRef!, &errorRef) == false) {
                    print("SDK Error registering font")
                } else {
                    print("SDK Success registering font")
                }
            }
        }
    }
    
    public func registerFont(fileName: String, fileExtension: String) {
        //sdk.configuration().stories.registerFont(fileName: "Roboto-Italic", fileExtension: "ttf")
        let pathForResourceString = Bundle.main.path(forResource: fileName, ofType: fileExtension)
        if pathForResourceString != nil {
            let fontData = NSData(contentsOfFile: pathForResourceString!)
            let dataProvider = CGDataProvider(data: fontData!)
            let fontRef = CGFont(dataProvider!)
            var errorRef: Unmanaged<CFError>? = nil

            if (CTFontManagerRegisterGraphicsFont(fontRef!, &errorRef) == false) {
                print("SDK Error registering font")
            } else {
                print("SDK Success registering font")
            }
        }
    }
    
    public func setStoriesBlock(fontName: String? = nil, fontSize: CGFloat? = nil, textColor: String? = nil, backgroundColor: String? = nil) {
        
        if fontName != nil {
            if fontName == storiesBlockFontNameConstant {
                storiesBlockFontNameChanged = storiesBlockFontNameConstant
            } else {
                storiesBlockFontNameChanged = fontName
            }
        } else {
            storiesBlockFontNameChanged = nil
        }
        
        if fontSize != nil {
            if fontSize == storiesBlockFontSizeConstant {
                storiesBlockFontSizeChanged = storiesBlockFontSizeConstant
            } else {
                storiesBlockFontSizeChanged = fontSize
            }
        } else {
            storiesBlockFontSizeChanged = storiesBlockFontSizeConstant
        }
        
        let defaultTextColor = UIColor.hexStringFromColor(color: storiesBlockTextColorConstant)
        if textColor != nil {
            let convertedTextColor = textColor?.hexToRGB() ?? defaultTextColor.hexToRGB()
            storiesBlockTextColorChanged = UIColor(red: convertedTextColor.red, green: convertedTextColor.green, blue: convertedTextColor.blue, alpha: 1)
        } else {
            let convertedTextColor = defaultTextColor.hexToRGB()
            storiesBlockTextColorChanged = UIColor(red: convertedTextColor.red, green: convertedTextColor.green, blue: convertedTextColor.blue, alpha: 1)
        }
        
        let defaultBackgroundColor = UIColor.hexStringFromColor(color: storiesBlockBackgroundColorConstant)
        let convertedBackgroundColor = backgroundColor?.hexToRGB() ?? defaultBackgroundColor.hexToRGB()
        storiesBlockBackgroundColorChanged = UIColor(red: convertedBackgroundColor.red, green: convertedBackgroundColor.green, blue: convertedBackgroundColor.blue, alpha: 1)
        
        if storiesBlockFontNameChanged != nil {
            _ = {
                $0.isUserInteractionEnabled = true
                $0.textColor = storiesBlockTextColorChanged
                $0.font = UIFont(name: storiesBlockFontNameChanged!, size: storiesBlockFontSizeChanged ?? 14.0)
            }(UILabel.appearance())
        } else {
            _ = {
                $0.isUserInteractionEnabled = true
                $0.textColor = storiesBlockTextColorChanged
                
                if fontSize != nil {
                    $0.font = .systemFont(ofSize: storiesBlockFontSizeChanged ?? 14.0)
                } else {
                    $0.font = .systemFont(ofSize: 14.0)
                }
            }(UILabel.appearance())
        }
        
        _ = {
            $0.backgroundColor = storiesBlockBackgroundColorChanged
        }(UICollectionView.appearance())
    }
    
    public func setSlideDefaultButton(fontName: String? = nil, fontSize: CGFloat? = nil, textColor: String? = nil, backgroundColor: String? = nil) {
        
        if fontName != nil {
            if fontName == slideDefaultButtonFontNameConstant {
                slideDefaultButtonFontNameChanged = nil
            } else {
                slideDefaultButtonFontNameChanged = fontName
            }
        }
        
        let convertedFontSize = fontSize ?? slideDefaultButtonFontSizeConstant
        if fontSize != nil {
            slideDefaultButtonFontSizeChanged = convertedFontSize
        } else {
            slideDefaultButtonFontSizeChanged = nil
        }
        
        let defaultTextColor = UIColor.hexStringFromColor(color: slideDefaultButtonTextColorConstant)
        let convertedTextColor = textColor?.hexToRGB() ?? defaultTextColor.hexToRGB()
        if textColor != nil {
            slideDefaultButtonTextColorChanged = UIColor(red: convertedTextColor.red, green: convertedTextColor.green, blue: convertedTextColor.blue, alpha: 1)
        } else {
            slideDefaultButtonTextColorChanged = nil
        }
        
        let defaultBackgroundColor = UIColor.hexStringFromColor(color: slideDefaultButtonBackgroundColorConstant)
        let convertedBackgroundColor = backgroundColor?.hexToRGB() ?? defaultBackgroundColor.hexToRGB()
        if backgroundColor != nil {
            slideDefaultButtonBackgroundColorChanged = UIColor(red: convertedBackgroundColor.red, green: convertedBackgroundColor.green, blue: convertedBackgroundColor.blue, alpha: 1)
        } else {
            slideDefaultButtonBackgroundColorChanged = nil
        }
    }
    
    public func setSlideProductsButton(fontName: String? = nil, fontSize: CGFloat? = nil, textColor: String? = nil, backgroundColor: String? = nil) {
        
        if fontName != nil {
            if fontName == slideProductsButtonFontNameConstant {
                slideProductsButtonFontNameChanged = nil
            } else {
                slideProductsButtonFontNameChanged = fontName
            }
        }
        
        let defaultTextColor = UIColor.hexStringFromColor(color: slideProductsButtonTextColorConstant)
        let convertedTextColor = textColor?.hexToRGB() ?? defaultTextColor.hexToRGB()
        slideProductsButtonTextColorChanged = UIColor(red: convertedTextColor.red, green: convertedTextColor.green, blue: convertedTextColor.blue, alpha: 1)
        
        let defaultBackgroundColor = UIColor.hexStringFromColor(color: slideProductsButtonBackgroundColorConstant)
        let convertedBackgroundColor = backgroundColor?.hexToRGB() ?? defaultBackgroundColor.hexToRGB()
        if backgroundColor != nil {
            slideProductsButtonBackgroundColorChanged = UIColor(red: convertedBackgroundColor.red, green: convertedBackgroundColor.green, blue: convertedBackgroundColor.blue, alpha: 1)
        } else {
            slideProductsButtonBackgroundColorChanged = nil
        }
        
        let convertedFontSize = fontSize ?? slideProductsButtonFontSizeConstant
        if fontSize != nil {
            slideProductsButtonFontSizeChanged = convertedFontSize
        } else {
            slideProductsButtonFontSizeChanged = nil
        }
    }
    
    public func setProductsCard(fontName: String? = nil) {
        if fontName != nil {
            if fontName == slideProductsHideButtonFontNameConstant {
                slideProductsHideButtonFontNameChanged = nil
            } else {
                slideProductsHideButtonFontNameChanged = fontName
            }
        }
    }
    
    public var storiesBlockTextColorChanged: UIColor?
    public var storiesBlockTextColorConstant: UIColor {
        get { return .black }
        set { storiesBlockTextColorChanged = newValue }
    }
    
    public var storiesBlockBackgroundColorChanged: UIColor?
    public var storiesBlockBackgroundColorConstant: UIColor {
        get { return .white }
        set { storiesBlockBackgroundColorChanged = newValue }
    }
    
    public var storiesBlockFontNameChanged: String?
    public var storiesBlockFontNameConstant: String {
        get { return ".SFUI-Regular" }
        set { storiesBlockFontNameChanged = newValue }
    }
    
    public var storiesBlockFontSizeChanged: CGFloat?
    public var storiesBlockFontSizeConstant: CGFloat {
        get { return 14.0 }
        set { storiesBlockFontSizeChanged = newValue }
    }
    
    public var slideDefaultButtonFontNameChanged: String?
    public var slideDefaultButtonFontNameConstant: String {
        get { return ".SFUI-Regular" }
        set { slideDefaultButtonFontNameChanged = newValue }
    }
    
    public var slideDefaultButtonFontSizeChanged: CGFloat?
    public var slideDefaultButtonFontSizeConstant: CGFloat {
        get { return 14.0 }
        set { slideDefaultButtonFontSizeChanged = newValue }
    }
    
    public var slideDefaultButtonTextColorChanged: UIColor?
    public var slideDefaultButtonTextColorConstant: UIColor {
        get { return .black }
        set { slideDefaultButtonTextColorChanged = newValue }
    }
    
    public var slideDefaultButtonBackgroundColorChanged: UIColor?
    public var slideDefaultButtonBackgroundColorConstant: UIColor {
        get { return .white }
        set { slideDefaultButtonBackgroundColorChanged = newValue }
    }
    
    public var slideProductsButtonFontNameChanged: String?
    public var slideProductsButtonFontNameConstant: String {
        get { return ".SFUI-Regular" }
        set { slideProductsButtonFontNameChanged = newValue }
    }
    
    public var slideProductsButtonFontSizeChanged: CGFloat?
    public var slideProductsButtonFontSizeConstant: CGFloat {
        get { return 14.0 }
        set { slideProductsButtonFontSizeChanged = newValue }
    }
    
    public var slideProductsButtonTextColorChanged: UIColor?
    public var slideProductsButtonTextColorConstant: UIColor {
        get { return .black }
        set { slideProductsButtonTextColorChanged = newValue }
    }
    
    public var slideProductsButtonBackgroundColorChanged: UIColor?
    public var slideProductsButtonBackgroundColorConstant: UIColor {
        get { return .white }
        set { slideProductsButtonBackgroundColorChanged = newValue }
    }
    
    public var slideProductsHideButtonFontNameChanged: String?
    public var slideProductsHideButtonFontNameConstant: String {
        get { return ".SFUI-Regular" }
        //get { return .systemFont(ofSize: 14.0) }
        set { slideProductsButtonFontNameChanged = newValue }
    }
    
    public var bootRegisteredFontChanged: UIFont?
    public var bootRegisteredFontConstant: UIFont {
        get { return .systemFont(ofSize: 14.0) }
        set { bootRegisteredFontChanged = newValue }
    }
    
    public func availableFonts() -> [String: [String]] {
        var fonts: [String: [String]] = [:]
        
        UIFont.familyNames.forEach({ familyName in
            let fontNames = UIFont.fontNames(forFamilyName: familyName)
            fonts[familyName] = fontNames
        })
        return fonts
    }
    
    public func getInstalledFontsFrom(
        bundle: Bundle = .main,
        completion: (([String]) -> Void)? = nil
    ) {
        getInstalledFontsFrom(at: bundle.bundleURL, completion: completion)
    }

    public func getInstalledFontsFrom(
        at url: URL?,
        completion: (([String]) -> Void)? = nil
    ) {
        guard let url = url else { completion?([])
            return
        }

        var loadedFonts: [sdkFontClass] = []
        loadedFonts += SdkConfiguration.loadFonts(at: url)
        loadedFonts += SdkConfiguration.loadFontsFromBundles(at: url)

        let alreadyLoaded = allLoadedFonts.map { $0.url }
        let justLoaded = loadedFonts.map { $0.url }
        for i in 0 ..< justLoaded.count {
            let justLoadedUrl = justLoaded[i]
            if alreadyLoaded.firstIndex(of: justLoadedUrl) == nil {
                allLoadedFonts.append(loadedFonts[i])
            }
        }

        completion?(loadedFonts.map { $0.name })
    }
}


private extension SdkConfiguration {
    
    @objc class func customSystemFont(ofSize size: CGFloat) -> UIFont {
        return customFont(name: SdkConfiguration.fontFamily.regular, size: size)
    }
    
    @objc class func customBoldSystemFont(ofSize size: CGFloat) -> UIFont {
        return customFont(name: SdkConfiguration.fontFamily.bold, size: size)
    }
    
    @objc class func customSystemFont(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        switch weight {
            case .ultraLight: return customFont(name: SdkConfiguration.fontFamily.ultraLight, size: size)
            case .thin:       return customFont(name: SdkConfiguration.fontFamily.thin,       size: size)
            case .light:      return customFont(name: SdkConfiguration.fontFamily.light,      size: size)
            case .regular:    return customFont(name: SdkConfiguration.fontFamily.regular,    size: size)
            case .medium:     return customFont(name: SdkConfiguration.fontFamily.medium,     size: size)
            case .semibold:   return customFont(name: SdkConfiguration.fontFamily.semibold,   size: size)
            case .bold:       return customFont(name: SdkConfiguration.fontFamily.bold,       size: size)
            case .heavy:      return customFont(name: SdkConfiguration.fontFamily.heavy,      size: size)
            case .black:      return customFont(name: SdkConfiguration.fontFamily.black,      size: size)
            default:          return customFont(name: SdkConfiguration.fontFamily.regular,    size: size)
        }
    }
    
    @objc class func customItalicSystemFont(ofSize size: CGFloat) -> UIFont {
        return customFont(name: SdkConfiguration.fontFamily.oblique, size: size)
    }
    
    class func loadFonts(at url: URL) -> [sdkFontClass] {
        var loadedFonts: [sdkFontClass] = []

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            let alreadyLoaded = SdkConfiguration.stories.allLoadedFonts.map { $0.url }
                for font in fonts(contents) {
                    if let idx = alreadyLoaded.firstIndex(of: font.url) {
                        loadedFonts.append(SdkConfiguration.stories.allLoadedFonts[idx])
                    } else if let lf = loadFont(font) {
                        loadedFonts.append(lf)
                    }
                }
        } catch let error as NSError {
            print("SDK There was an error loading fonts. Path: \(url). Error: \(error)")
        }
        return loadedFonts
    }

    class func loadFontsFromBundles(at url: URL) -> [sdkFontClass] {
        var loadedFonts: [sdkFontClass] = []

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            for item in contents {
                guard item.absoluteString.contains(".bundle") else {continue}
                    loadedFonts += loadFonts(at: item)
                }
            } catch let error as NSError {
                print("SDK There was an error accessing bundle with url. Path: \(url). Error: \(error) ")
            }
        return loadedFonts
    }

    class func loadFont(_ font: sdkFontClass) -> sdkFontClass? {
        let fileURL: sdkFontPath = font.url
        let name = font.name
        var nowLoadedFontName: String?
        var sdkRef: CGFont?
        var error: Unmanaged<CFError>?

        if let data = try? Data(contentsOf: fileURL) as CFData,
           let sdkDataProvider = CGDataProvider(data: data) {
            workaroundDeadlock()

            sdkRef = CGFont(sdkDataProvider)

            if CTFontManagerRegisterGraphicsFont(sdkRef!, &error) {
                if let postScriptName = sdkRef?.postScriptName {
                    print("SDK Successfully loaded custom font: '\(postScriptName)'.")
                    nowLoadedFontName = String(postScriptName)
                }
            } else if let error = error?.takeRetainedValue() {
                let errorDescription = CFErrorCopyDescription(error)
                print("SDK Already installed custom font '\(name)': \(String(describing: errorDescription))")
            }
        } else {
            guard let error = error?.takeRetainedValue() else {
                print("SDK Failed to load font '\(name)'.")
                return nil
            }
            let errorDescription = CFErrorCopyDescription(error)
            print("SDK Failed to load font '\(name)': \(String(describing: errorDescription))")
        }

        if let sdkLfn = nowLoadedFontName {
            return (fileURL, sdkLfn)
        }
        return nil
    }

    class func workaroundDeadlock() {
        _ = UIFont.systemFont(ofSize: 7)
    }
    
    final class func fontExt(fromName name: String) -> (sdkFontName, sdkFontExtension) {
        let components = name.split{$0 == "."}.map { String($0) }
        return (components[0], components[1])
    }
}


private extension SdkConfiguration {
    
    class func exchangeOriginalUIFontMethodsWithCustomMethods() {
        func exchangeOriginalUIFontMethodsWithCustomMethods() {
            
            SdkFontInstaller.exchange(
                classMethod: #selector(UIFont.systemFont(ofSize:)), of: UIFont.self,
                with: #selector(SdkConfiguration.customSystemFont(ofSize:)), of: SdkFontInstaller.self
            )
            
            SdkFontInstaller.exchange(
                classMethod: #selector(UIFont.boldSystemFont(ofSize:)), of: UIFont.self,
                with: #selector(SdkConfiguration.customBoldSystemFont(ofSize:)), of: SdkFontInstaller.self
            )
            
            SdkFontInstaller.exchange(
                classMethod: #selector(UIFont.systemFont(ofSize:weight:)), of: UIFont.self,
                with: #selector(SdkConfiguration.customSystemFont(ofSize:weight:)), of: SdkFontInstaller.self
            )
            
            SdkFontInstaller.exchange(
                classMethod: #selector(UIFont.italicSystemFont(ofSize:)), of: UIFont.self,
                with: #selector(SdkConfiguration.customItalicSystemFont(ofSize:)), of: SdkFontInstaller.self
            )
            
            SdkFontInstaller.exchange(
                instanceMethod: #selector(UIFontDescriptor.init(coder:)), of: UIFont.self,
                with: #selector(UIFont.init(customCoder:)), of: UIFont.self
            )
        }
    }
    
}

@objc
public extension UIFont {
    @objc convenience init?(customCoder aDecoder: NSCoder) {
        guard let fontDescriptor = aDecoder.decodeObject(forKey: "UIFontDescriptor") as? UIFontDescriptor else {
            self.init(coder: aDecoder)
            return
        }
        
        guard let fontUIUsageAttribute = fontDescriptor.fontAttributes[.usage] as? String else {
            self.init(coder: aDecoder)
            return
        }

        var fontFamily: SdkFontFamily {
            return SdkConfiguration.fontFamily
        }

        var fontName: String {
            guard let fontDescriptorUsage = UIFontDescriptorUsage(rawValue: fontUIUsageAttribute) else {
                print("SDK Undefined usage attribute: \(fontUIUsageAttribute)")
                return fontFamily.regular
            }
            
            switch fontDescriptorUsage {
                case .ultraLight:    return fontFamily.ultraLight
                case .thin:          return fontFamily.thin
                case .light:         return fontFamily.light
                case .regular:       return fontFamily.regular
                case .oblique:       return fontFamily.oblique
                case .medium:        return fontFamily.medium
                case .demi:          return fontFamily.semibold
                case .emphasized:    return fontFamily.emphasized
                case .bold:          return fontFamily.bold
                case .heavy:         return fontFamily.heavy
                case .black:         return fontFamily.black
            }
        }

        self.init(name: fontName, size: fontDescriptor.pointSize)
    }
}
            
         
public enum SdkSupportedFontExtensions: String {
    case trueType = "ttf"
    case openType = "otf"

    init?(_ ver: String?) {
        if SdkSupportedFontExtensions.trueType.rawValue == ver {
            self = .trueType
        } else if SdkSupportedFontExtensions.openType.rawValue == ver {
            self = .openType
        } else {
            return nil
        }
    }
}


extension SdkConfiguration {
    class func fonts(_ contents: [URL]) -> [sdkFontClass] {
        var fonts = [sdkFontClass]()
        for fontUrl in contents {
            if let fontName = font(fontUrl) {
                fonts.append((fontUrl, fontName))
            }
        }
        return fonts
    }

    class func font(_ fontUrl: URL) -> sdkFontName? {
        let name = fontUrl.lastPathComponent
        let comps = name.components(separatedBy: ".")
        if comps.count < 2 { return nil }
        let fname = comps[0 ..< comps.count - 1].joined(separator: ".")
        return SdkSupportedFontExtensions(comps.last!) != nil ? fname : nil
    }
}
