import UIKit.UIFont
import Foundation

public protocol SdkConfigurationProtocol: AnyObject {}

public typealias sdkFontPath = URL
public typealias sdkFontName = String
public typealias sdkFontExtension = String
public typealias sdkFontClass = (url: sdkFontPath, name: sdkFontName)

open class SdkConfiguration: SdkConfigurationProtocol, StoryViewControllerProtocol {
    public func reloadStoriesCollectionSubviews() {}
    
    public static let stories: SdkConfiguration = SdkConfiguration()
    
    public init() {}
    public private(set) static var fontFamily: SdkFontFamily!
    lazy var _fontNames = originalFontNames
    public var fontNames: [String] { return _fontNames }
    public var allLoadedFonts: [sdkFontClass] = []

    public func registerFont(fileName: String, fileExtension: String) {
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
    
    public func setStoriesBlock(fontName: String? = nil, fontSize: CGFloat? = nil, textColor: String? = nil, backgroundColor: String? = nil, darkModeTextColor: String? = nil, darkModeBackgroundColor: String? = nil) {
        
        let uiBlockTextColorLight = UIColor(hexString: textColor ?? UIColor.sdkDefaultBlackColor.toHexString())
        let uiBlockBackgroundColorLight = UIColor(hexString: backgroundColor ?? UIColor.white.toHexString())
        let uiBlockTextColorDark = UIColor(hexString: darkModeTextColor ?? UIColor.white.toHexString())
        let uiBlockBackgroundColorDark = UIColor(hexString: darkModeBackgroundColor ?? UIColor.black.toHexString())
        
        storiesBlockTextColorChanged_Light = uiBlockTextColorLight
        storiesBlockTextColorChanged_Dark = uiBlockTextColorDark
        
        storiesBlockBackgroundColorChanged_Light = uiBlockBackgroundColorLight
        storiesBlockBackgroundColorChanged_Dark = uiBlockBackgroundColorDark
        
        var fontBySdk = UIFont(name: storiesBlockFontNameConstant, size: storiesBlockMinimumFontSizeConstant)
        if fontName != nil {
            if fontName == storiesBlockFontNameConstant {
                storiesBlockFontNameChanged = storiesBlockFontNameConstant
            } else {
                storiesBlockFontNameChanged = fontName
            }
            //var testFont = UIFont(name: fontName!, size: 14.0)
            fontBySdk = UIFont(name: storiesBlockFontNameChanged!, size: storiesBlockMinimumFontSizeChanged ?? 14.0)
        
            SdkStyle.shared.register(fonts: normalFonts(), for: FontSizes.normal)
            SdkStyle.shared.register(fonts: largeFonts(), for: FontSizes.large)
            SdkStyle.shared.switchFontSize(to: FontSizes.normal)
            
//            _ = {
//                $0.isUserInteractionEnabled = true
//                $0.textColor = storiesBlockTextColorChanged
//                $0.font = UIFont(name: storiesBlockFontNameChanged!, size: storiesBlockMinimumFontSizeChanged ?? 14.0)
//            }(UILabel.appearance())
            
            if fontSize != nil {
                if fontSize == storiesBlockMinimumFontSizeConstant {
                    storiesBlockMinimumFontSizeChanged = storiesBlockMinimumFontSizeConstant
                } else {
                    storiesBlockMinimumFontSizeChanged = fontSize
                    fontBySdk = UIFont(name: storiesBlockFontNameChanged!, size: storiesBlockMinimumFontSizeChanged ?? 14.0)
                }
            } else {
                storiesBlockMinimumFontSizeChanged = 0.0
            }
        } else {
            if fontSize != nil {
                if fontSize == storiesBlockMinimumFontSizeConstant {
                    storiesBlockMinimumFontSizeChanged = storiesBlockMinimumFontSizeConstant
                } else {
                    storiesBlockMinimumFontSizeChanged = fontSize
                    fontBySdk = UIFont(name: storiesBlockFontNameConstant, size: storiesBlockMinimumFontSizeChanged ?? 14.0)
                }
            } else {
                storiesBlockMinimumFontSizeChanged = 0.0
            }
        }
        
        if (fontBySdk == nil) {
            fontBySdk = .systemFont(ofSize: 14.0)
        }
        
        SdkStyle.shared.register(colorScheme:
                                    lightSdkStyleApperance(storiesBlockSelectFontName: fontBySdk!,
                                                           storiesBlockSelectFontSize: storiesBlockMinimumFontSizeChanged!,
                                                           storiesBlockFontColor: uiBlockTextColorLight,
                                                           storiesBlockBackgroundColor: uiBlockBackgroundColorLight,
                                                           
                                                           defaultButtonSelectFontName: fontBySdk!,
                                                           defaultButtonSelectFontSize: storiesBlockMinimumFontSizeChanged!,
                                                           defaultButtonFontColor: .white,
                                                           defaultButtonBackgroundColor: .black,
                                                           
                                                           productsButtonSelectFontName: fontBySdk!,
                                                           productsButtonSelectFontSize: storiesBlockMinimumFontSizeChanged!,
                                                           productsButtonFontColor: .black,
                                                           productsButtonBackgroundColor: .white
                                                          ),
                                 for: SdkStyleApperanceTypes.storiesBlockLight)
        
        SdkStyle.shared.register(colorScheme:
                                    darkSdkStyleApperance(storiesBlockSelectFontName: fontBySdk!,
                                                          storiesBlockSelectFontSize: storiesBlockMinimumFontSizeChanged!,
                                                          storiesBlockFontColor: uiBlockTextColorDark,
                                                          storiesBlockBackgroundColor: uiBlockBackgroundColorDark,
                                                          
                                                          defaultButtonSelectFontName: fontBySdk!,
                                                          defaultButtonSelectFontSize: storiesBlockMinimumFontSizeChanged!,
                                                          defaultButtonFontColor: .black,
                                                          defaultButtonBackgroundColor: .white,
                                                          
                                                          productsButtonSelectFontName: fontBySdk!,
                                                          productsButtonSelectFontSize: storiesBlockMinimumFontSizeChanged!,
                                                          productsButtonFontColor: .black,
                                                          productsButtonBackgroundColor: .white
                                                          ),
                                 for: SdkStyleApperanceTypes.storiesBlockDark)

        
        if #available(iOS 13.0, *) {
            if SdkConfiguration.isDarkMode {
                SdkStyle.shared.switchApppearance(to: SdkStyleApperanceTypes.storiesBlockDark, animated: false)
            } else {
                SdkStyle.shared.switchApppearance(to: SdkStyleApperanceTypes.storiesBlockLight, animated: false)
            }
        } else {
            //
        }
    }
    
    public func setSlideDefaultButton(fontName: String? = nil, fontSize: CGFloat? = nil, textColor: String? = nil, backgroundColor: String? = nil, darkModeTextColor: String? = nil, darkModeBackgroundColor: String? = nil) {
        
        let slideDefaultButtonTextColorLight = UIColor(hexString: textColor ?? UIColor.sdkDefaultBlackColor.toHexString())
        //let slideDefaultButtonBackgroundColorLight = UIColor(hexString: backgroundColor ?? UIColor.white.toHexString())
        let slideDefaultButtonTextColorDark = UIColor(hexString: darkModeTextColor ?? UIColor.white.toHexString())
        //let slideDefaultButtonBackgroundColorDark = UIColor(hexString: darkModeBackgroundColor ?? UIColor.black.toHexString())
        
        let defaultTextColor = UIColor.hexStringFromColor(color: slideDefaultButtonTextColorConstant_Light)
        let convertedTextColor = textColor?.hexToRGB() ?? defaultTextColor.hexToRGB()
        if textColor != nil {
            slideDefaultButtonTextColorChanged_Light = UIColor(red: convertedTextColor.red, green: convertedTextColor.green, blue: convertedTextColor.blue, alpha: 1)
        } else {
            slideDefaultButtonTextColorChanged_Light = nil
        }
        
        let defaultTextColorDark = UIColor.hexStringFromColor(color: slideDefaultButtonTextColorConstant_Dark)
        let convertedTextColorDark = darkModeTextColor?.hexToRGB() ?? defaultTextColorDark.hexToRGB()
        if textColor != nil {
            slideDefaultButtonTextColorChanged_Dark = UIColor(red: convertedTextColorDark.red, green: convertedTextColorDark.green, blue: convertedTextColorDark.blue, alpha: 1)
        } else {
            slideDefaultButtonTextColorChanged_Dark = nil
        }
        
        let defaultBackgroundColorLight = UIColor.hexStringFromColor(color: slideDefaultButtonBackgroundColorConstant_Light)
        let convertedDefaultButtonBackgroundColorLight = backgroundColor?.hexToRGB() ?? defaultBackgroundColorLight.hexToRGB()
        if backgroundColor != nil {
            slideDefaultButtonBackgroundColorChanged_Light = UIColor(red: convertedDefaultButtonBackgroundColorLight.red, green: convertedDefaultButtonBackgroundColorLight.green, blue: convertedDefaultButtonBackgroundColorLight.blue, alpha: 1)
        } else {
            slideDefaultButtonBackgroundColorChanged_Light = nil
        }
        
        let defaultBackgroundColorDark = UIColor.hexStringFromColor(color: slideDefaultButtonBackgroundColorConstant_Dark)
        let convertedDefaultButtonBackgroundColorDark = darkModeBackgroundColor?.hexToRGB() ?? defaultBackgroundColorDark.hexToRGB()
        if darkModeBackgroundColor != nil {
            slideDefaultButtonBackgroundColorChanged_Dark = UIColor(red: convertedDefaultButtonBackgroundColorDark.red, green: convertedDefaultButtonBackgroundColorDark.green, blue: convertedDefaultButtonBackgroundColorDark.blue, alpha: 1)
        } else {
            slideDefaultButtonBackgroundColorChanged_Dark = nil
        }
        
        var slideButtonFontBySdk = UIFont(name: slideDefaultButtonFontNameConstant, size: slideDefaultButtonFontSizeConstant)
        if fontName != nil {
            if fontName == slideDefaultButtonFontNameConstant {
                slideDefaultButtonFontNameChanged = slideDefaultButtonFontNameConstant
            } else {
                slideDefaultButtonFontNameChanged = fontName
            }
            slideButtonFontBySdk = UIFont(name: slideDefaultButtonFontNameChanged!, size: slideDefaultButtonFontSizeChanged ?? 14.0)
            
            if fontSize != nil {
                if fontSize == slideDefaultButtonFontSizeConstant {
                    slideDefaultButtonFontSizeChanged = slideDefaultButtonFontSizeConstant
                } else {
                    slideDefaultButtonFontSizeChanged = fontSize
                    slideButtonFontBySdk = UIFont(name: slideDefaultButtonFontNameChanged!, size: fontSize ?? 14.0)
                }
            } else {
                slideDefaultButtonFontSizeChanged = 0.0
            }
        } else {
            if fontSize != nil {
                if fontSize == slideDefaultButtonFontSizeConstant {
                    slideDefaultButtonFontSizeChanged = slideDefaultButtonFontSizeConstant
                } else {
                    slideDefaultButtonFontSizeChanged = fontSize
                    slideButtonFontBySdk = UIFont(name: slideDefaultButtonFontNameConstant, size: slideDefaultButtonFontSizeChanged ?? 14.0)
                }
            } else {
                slideDefaultButtonFontSizeChanged = 0.0
            }
        }
        
        let storedStoriesBlockSelectFontName = SdkStyle.shared.currentColorScheme?.storiesBlockSelectFontName
        let storedStoriesBlockFontColor = SdkStyle.shared.currentColorScheme?.storiesBlockFontColor
        let storedStoriesBlockBackgroundColor = SdkStyle.shared.currentColorScheme?.storiesBlockBackgroundColor
        
        if (slideButtonFontBySdk == nil) {
            slideButtonFontBySdk = .systemFont(ofSize: 16.0)
        }
        
        SdkStyle.shared.register(colorScheme:
                                    lightSdkStyleApperance(storiesBlockSelectFontName: storedStoriesBlockSelectFontName!,
                                                           storiesBlockSelectFontSize: storiesBlockMinimumFontSizeChanged!,
                                                           storiesBlockFontColor: storedStoriesBlockFontColor!,
                                                           storiesBlockBackgroundColor: storedStoriesBlockBackgroundColor!,
                                                           
                                                           defaultButtonSelectFontName: slideButtonFontBySdk!,
                                                           defaultButtonSelectFontSize: slideDefaultButtonFontSizeChanged!,
                                                           defaultButtonFontColor: slideDefaultButtonTextColorLight,
                                                           defaultButtonBackgroundColor: slideDefaultButtonBackgroundColorChanged_Light ?? .white,
                                                           
                                                           productsButtonSelectFontName: slideButtonFontBySdk!,
                                                           productsButtonSelectFontSize: slideDefaultButtonFontSizeChanged!,
                                                           productsButtonFontColor: .black,
                                                           productsButtonBackgroundColor: .white
                                                          ),
                                 for: SdkStyleApperanceTypes.storiesBlockLight)
        
        SdkStyle.shared.register(colorScheme:
                                    darkSdkStyleApperance(storiesBlockSelectFontName: storedStoriesBlockSelectFontName!,
                                                          storiesBlockSelectFontSize: storiesBlockMinimumFontSizeChanged!,
                                                          storiesBlockFontColor: storedStoriesBlockFontColor!,
                                                          storiesBlockBackgroundColor: storedStoriesBlockBackgroundColor!,
                                                          
                                                          defaultButtonSelectFontName: slideButtonFontBySdk!,
                                                          defaultButtonSelectFontSize: slideDefaultButtonFontSizeChanged!,
                                                          defaultButtonFontColor: slideDefaultButtonTextColorDark,
                                                          defaultButtonBackgroundColor: slideDefaultButtonBackgroundColorChanged_Dark ?? .white,
                                                          
                                                          productsButtonSelectFontName: slideButtonFontBySdk!,
                                                          productsButtonSelectFontSize: 12.0,
                                                          productsButtonFontColor: .black,
                                                          productsButtonBackgroundColor: .white
                                                          ),
                                 for: SdkStyleApperanceTypes.storiesBlockDark)

        
        if #available(iOS 13.0, *) {
            if SdkConfiguration.isDarkMode {
                SdkStyle.shared.switchApppearance(to: SdkStyleApperanceTypes.storiesBlockDark, animated: false)
            } else {
                SdkStyle.shared.switchApppearance(to: SdkStyleApperanceTypes.storiesBlockLight, animated: false)
            }
        } else {
            //
        }
    }
    
    public func setSlideProductsButton(fontName: String? = nil, fontSize: CGFloat? = nil, textColor: String? = nil, backgroundColor: String? = nil, darkModeTextColor: String? = nil, darkModeBackgroundColor: String? = nil) {
        
        if fontName != nil {
            if fontName == slideProductsButtonFontNameConstant {
                slideProductsButtonFontNameChanged = nil
            } else {
                slideProductsButtonFontNameChanged = fontName
            }
        }
        
        let defaultTextColor = UIColor.hexStringFromColor(color: slideProductsButtonTextColorConstant_Light)
        let convertedTextColor = textColor?.hexToRGB() ?? defaultTextColor.hexToRGB()
        slideProductsButtonTextColorChanged_Light = UIColor(red: convertedTextColor.red, green: convertedTextColor.green, blue: convertedTextColor.blue, alpha: 1)
        
        let defaultTextColorDark = UIColor.hexStringFromColor(color: slideProductsButtonTextColorConstant_Dark)
        let convertedTextColorDark = darkModeTextColor?.hexToRGB() ?? defaultTextColorDark.hexToRGB()
        slideProductsButtonTextColorChanged_Dark = UIColor(red: convertedTextColorDark.red, green: convertedTextColorDark.green, blue: convertedTextColorDark.blue, alpha: 1)
        
        let defaultBackgroundColor = UIColor.hexStringFromColor(color: slideProductsButtonBackgroundColorConstant_Light)
        let convertedBackgroundColor = backgroundColor?.hexToRGB() ?? defaultBackgroundColor.hexToRGB()
        if backgroundColor != nil {
            slideProductsButtonBackgroundColorChanged_Light = UIColor(red: convertedBackgroundColor.red, green: convertedBackgroundColor.green, blue: convertedBackgroundColor.blue, alpha: 1)
        } else {
            slideProductsButtonBackgroundColorChanged_Light = nil
        }
        
        let defaultBackgroundColorDark = UIColor.hexStringFromColor(color: slideProductsButtonBackgroundColorConstant_Dark)
        let convertedBackgroundColorDark = darkModeBackgroundColor?.hexToRGB() ?? defaultBackgroundColorDark.hexToRGB()
        if backgroundColor != nil {
            slideProductsButtonBackgroundColorChanged_Dark = UIColor(red: convertedBackgroundColorDark.red, green: convertedBackgroundColorDark.green, blue: convertedBackgroundColorDark.blue, alpha: 1)
        } else {
            slideProductsButtonBackgroundColorChanged_Dark = nil
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
    
    public enum InstalledCustomFonts: String, SdkApperanceViewScheme {
        case storiesBlockTextFont
        case defaultButtonTextFont
        case productsButtonTextFont
    }

    public struct normalFonts: SdkStyleCustomFonts {
        public var customFonts = [InstalledCustomFonts.storiesBlockTextFont.SdkApperanceViewScheme()    : UIFont.systemFont(ofSize: 17),
                                 InstalledCustomFonts.defaultButtonTextFont.SdkApperanceViewScheme() : UIFont.systemFont(ofSize: 12),
                                 InstalledCustomFonts.productsButtonTextFont.SdkApperanceViewScheme()   : UIFont.systemFont(ofSize: 22) ]
    }

    public struct largeFonts: SdkStyleCustomFonts {
        public var customFonts = [InstalledCustomFonts.storiesBlockTextFont.SdkApperanceViewScheme()    : UIFont.systemFont(ofSize: 20),
                                InstalledCustomFonts.defaultButtonTextFont.SdkApperanceViewScheme() : UIFont.systemFont(ofSize: 15),
                                InstalledCustomFonts.productsButtonTextFont.SdkApperanceViewScheme()   : UIFont.systemFont(ofSize: 27) ]
    }

    public enum FontSizes: String, SdkApperanceViewScheme {
        case normal
        case large
    }
    
    public struct storiesBlockLightSdkStyleApperance: sdkElement_storiesBlockColorScheme {
        public var storiesBlockBackgroundColor = UIColor.blue
        public var storiesBlockFontColor = UIColor.green
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

    public struct lightSdkStyleApperance: SdkStyleColorScheme, SdkStyleViewColorScheme, SdkStyleLabelColorScheme, SdkStyleButtonColorScheme, SdkStyleTableViewColorScheme, SdkStyleCustomColorScheme {
        
        public var storiesBlockSelectFontName: UIFont
        public var storiesBlockSelectFontSize: CGFloat
        public var storiesBlockFontColor: UIColor
        public var storiesBlockBackgroundColor: UIColor
        
        public var defaultButtonSelectFontName: UIFont
        public var defaultButtonSelectFontSize: CGFloat
        public var defaultButtonFontColor: UIColor
        public var defaultButtonBackgroundColor: UIColor
        
        public var productsButtonSelectFontName: UIFont
        public var productsButtonSelectFontSize: CGFloat
        public var productsButtonFontColor: UIColor
        public var productsButtonBackgroundColor: UIColor
        
        
        public let storiesBack = UIColor.lightGray
        public let viewControllerBackground = UIColor.white
        public let navigationBarStyle = UIBarStyle.default
        public let navigationBarBackgroundColor =  UIColor.white
        public let navigationBarTextColor = UIColor.black
        public let viewBackgroundColor = UIColor.magenta
        public let labelTextColor = UIColor.black
        public let buttonTintColor = UIColor.blue

        public let tableViewBackgroundColor = UIColor.lightGray
        public var tableViewSeparatorColor = UIColor.gray
        public let headerBackgroundColor = UIColor.white
        public let headerTextColorColor = UIColor.black
        public let cellBackgroundColor = UIColor.white
        public let cellTextColorColor = UIColor.black
        public let cellSubTextColorColor = UIColor.darkGray

        public let customColors = [CustomTableCellColors.cellBackground.SdkApperanceViewScheme() : UIColor.magenta,
                            CustomTableCellColors.cellTextColor.SdkApperanceViewScheme() : UIColor.purple ]
    }

    public struct darkSdkStyleApperance: SdkStyleColorScheme, SdkStyleViewColorScheme, SdkStyleLabelColorScheme, SdkStyleButtonColorScheme, SdkStyleTableViewColorScheme, SdkStyleCustomColorScheme {
        
        public var storiesBlockSelectFontName: UIFont
        public var storiesBlockSelectFontSize: CGFloat
        public var storiesBlockFontColor: UIColor
        public var storiesBlockBackgroundColor: UIColor
        
        public var defaultButtonSelectFontName: UIFont
        public var defaultButtonSelectFontSize: CGFloat
        public var defaultButtonFontColor: UIColor
        public var defaultButtonBackgroundColor: UIColor
        
        public var productsButtonSelectFontName: UIFont
        public var productsButtonSelectFontSize: CGFloat
        public var productsButtonFontColor: UIColor
        public var productsButtonBackgroundColor: UIColor
        
        
        public let viewControllerBackground = UIColor.black
        public let navigationBarStyle = UIBarStyle.black
        public let navigationBarBackgroundColor =  UIColor.black
        public let navigationBarTextColor = UIColor.white
        public let viewBackgroundColor = UIColor.yellow
        public let labelTextColor = UIColor.white
        public let buttonTintColor = UIColor.blue

        public let tableViewBackgroundColor = UIColor.darkGray
        public var tableViewSeparatorColor = UIColor.gray
        public let headerBackgroundColor = UIColor.black
        public let headerTextColorColor = UIColor.white
        public let cellBackgroundColor = UIColor.black
        public let cellTextColorColor = UIColor.white
        public let cellSubTextColorColor = UIColor.lightGray

        public let customColors = [CustomTableCellColors.cellBackground.SdkApperanceViewScheme() : UIColor.purple,
                            CustomTableCellColors.cellTextColor.SdkApperanceViewScheme() : UIColor.magenta ]
    }

    public struct customSdkStyleApperance: SdkStyleColorScheme, SdkStyleViewColorScheme, SdkStyleLabelColorScheme, SdkStyleButtonColorScheme, SdkStyleTableViewColorScheme, SdkStyleCustomColorScheme {
        
        public var storiesBlockSelectFontName: UIFont
        public var storiesBlockSelectFontSize: CGFloat
        public var storiesBlockFontColor: UIColor
        public var storiesBlockBackgroundColor: UIColor
        
        public var defaultButtonSelectFontName: UIFont
        public var defaultButtonSelectFontSize: CGFloat
        public var defaultButtonFontColor: UIColor
        public var defaultButtonBackgroundColor: UIColor
        
        public var productsButtonSelectFontName: UIFont
        public var productsButtonSelectFontSize: CGFloat
        public var productsButtonFontColor: UIColor
        public var productsButtonBackgroundColor: UIColor
        
        
        public let storiesBack = UIColor.lightGray
        public var viewControllerBackground = UIColor.blue
        public let navigationBarStyle = UIBarStyle.black
        public let navigationBarBackgroundColor =  UIColor.blue
        public let navigationBarTextColor = UIColor.white
        public let viewBackgroundColor = UIColor.black
        public let labelTextColor = UIColor.white
        public let buttonTintColor = UIColor.blue

        public let tableViewBackgroundColor = UIColor.lightGray
        public var tableViewSeparatorColor = UIColor.gray
        public let headerBackgroundColor = UIColor.white
        public let headerTextColorColor = UIColor.black
        public let cellBackgroundColor = UIColor.white
        public let cellTextColorColor = UIColor.black
        public let cellSubTextColorColor = UIColor.darkGray

        public let customColors = [CustomTableCellColors.cellBackground.SdkApperanceViewScheme() : UIColor.magenta,
                            CustomTableCellColors.cellTextColor.SdkApperanceViewScheme() : UIColor.purple ]
    }

    public enum SdkStyleApperanceTypes: String, SdkApperanceViewScheme {
        case storiesBlockLight
        case storiesBlockDark
        case slideDefaultButtonLight
        case slideDefaultButtonDark
        case slideProductsButtonLight
        case slideProductsButtonDark
        case productsCardLight
        case productsCardDark
        case custom
    }
    
    @available(iOS 13.0, *)
    public static var isDarkMode: Bool {
        return UITraitCollection.current.userInterfaceStyle == .dark
    }
    
    public func availableFonts() -> [String: [String]] {
        var fonts: [String: [String]] = [:]
        
        UIFont.familyNames.forEach({ familyName in
            let fontNames = UIFont.fontNames(forFamilyName: familyName)
            fonts[familyName] = fontNames
        })
        return fonts
    }
    
    public func getInstalledFontsFrom(bundle: Bundle = .main,
        completion: (([String]) -> Void)? = nil) {
        getInstalledFontsFrom(at: bundle.bundleURL, completion: completion)
    }

    public func getInstalledFontsFrom(at url: URL?,
        completion: (([String]) -> Void)? = nil
    ) {
        guard let url = url else { completion?([])
            return
        }

        var loadedForSDKFonts: [sdkFontClass] = []
        loadedForSDKFonts += SdkConfiguration.loadFonts(at: url)
        loadedForSDKFonts += SdkConfiguration.loadFontsFromBundles(at: url)

        let alreadyLoaded = allLoadedFonts.map { $0.url }
        let justLoaded = loadedForSDKFonts.map { $0.url }
        for i in 0 ..< justLoaded.count {
            let justLoadedUrl = justLoaded[i]
            if alreadyLoaded.firstIndex(of: justLoadedUrl) == nil {
                allLoadedFonts.append(loadedForSDKFonts[i])
            }
        }

        completion?(loadedForSDKFonts.map { $0.name })
    }
    
    public enum CustomTableCellColors: String, SdkApperanceViewScheme {
        case cellBackground
        case cellTextColor
    }
    
    public var storiesBlockFontNameChanged: String?
    public var storiesBlockFontNameConstant: String {
        get { return ".SFUI-Regular" }
        set { storiesBlockFontNameChanged = newValue }
    }
    
    public var storiesBlockMinimumFontSizeChanged: CGFloat?
    public var storiesBlockMinimumFontSizeConstant: CGFloat {
        get { return 7.0 }
        set { storiesBlockMinimumFontSizeChanged = newValue }
    }
    
    public var storiesBlockTextColorChanged_Light: UIColor?
    public var storiesBlockTextColorConstant_Light: UIColor {
        get { return .black }
        set { storiesBlockTextColorChanged_Light = newValue }
    }
    
    public var storiesBlockTextColorChanged_Dark: UIColor?
    public var storiesBlockTextColorConstant_Dark: UIColor {
        get { return .black }
        set { storiesBlockTextColorChanged_Dark = newValue }
    }
    
    public var storiesBlockBackgroundColorChanged_Light: UIColor?
    public var storiesBlockBackgroundColorConstant_Light: UIColor {
        get { return .white }
        set { storiesBlockBackgroundColorChanged_Light = newValue }
    }
    
    public var storiesBlockBackgroundColorChanged_Dark: UIColor?
    public var storiesBlockBackgroundColorConstant_Dark: UIColor {
        get { return .black }
        set { storiesBlockBackgroundColorChanged_Dark = newValue }
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
    
    public var slideDefaultButtonTextColorChanged_Light: UIColor?
    public var slideDefaultButtonTextColorConstant_Light: UIColor {
        get { return .black }
        set { slideDefaultButtonTextColorChanged_Light = newValue }
    }
    
    public var slideDefaultButtonTextColorChanged_Dark: UIColor?
    public var slideDefaultButtonTextColorConstant_Dark: UIColor {
        get { return .black }
        set { slideDefaultButtonTextColorChanged_Dark = newValue }
    }
    
    public var slideDefaultButtonBackgroundColorChanged_Light: UIColor?
    public var slideDefaultButtonBackgroundColorConstant_Light: UIColor {
        get { return .white }
        set { slideDefaultButtonBackgroundColorChanged_Light = newValue }
    }
    
    public var slideDefaultButtonBackgroundColorChanged_Dark: UIColor?
    public var slideDefaultButtonBackgroundColorConstant_Dark: UIColor {
        get { return .white }
        set { slideDefaultButtonBackgroundColorChanged_Dark = newValue }
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
    
    public var slideProductsButtonTextColorChanged_Light: UIColor?
    public var slideProductsButtonTextColorConstant_Light: UIColor {
        get { return .black }
        set { slideProductsButtonTextColorChanged_Light = newValue }
    }
    
    public var slideProductsButtonTextColorChanged_Dark: UIColor?
    public var slideProductsButtonTextColorConstant_Dark: UIColor {
        get { return .black }
        set { slideProductsButtonTextColorChanged_Dark = newValue }
    }
    
    public var slideProductsButtonBackgroundColorChanged_Light: UIColor?
    public var slideProductsButtonBackgroundColorConstant_Light: UIColor {
        get { return .white }
        set { slideProductsButtonBackgroundColorChanged_Light = newValue }
    }
    
    public var slideProductsButtonBackgroundColorChanged_Dark: UIColor?
    public var slideProductsButtonBackgroundColorConstant_Dark: UIColor {
        get { return .white }
        set { slideProductsButtonBackgroundColorChanged_Dark = newValue }
    }
    
    public var slideProductsHideButtonFontNameChanged: String?
    public var slideProductsHideButtonFontNameConstant: String {
        get { return ".SFUI-Regular" }
        set { slideProductsButtonFontNameChanged = newValue }
    }
    
    public var bootRegisteredFontChanged: UIFont?
    public var bootRegisteredFontConstant: UIFont {
        get { return .systemFont(ofSize: 14.0) }
        set { bootRegisteredFontChanged = newValue }
    }
    
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
}

//DEPRECATED

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


//public enum SdkStyleApperanceTypes: String, SdkApperanceViewScheme {
//    case light
//    case dark
//    case blue
//}

enum CustomFonts: String, SdkApperanceViewScheme {
    case storiesBlockTextFont
    case defaultButtonTextFont
    case productsButtonTextFont
}

public struct normalFonts: SdkStyleCustomFonts {
    public var customFonts = [CustomFonts.storiesBlockTextFont.SdkApperanceViewScheme()    : UIFont.systemFont(ofSize: 17),
                       CustomFonts.defaultButtonTextFont.SdkApperanceViewScheme() : UIFont.systemFont(ofSize: 12),
                       CustomFonts.productsButtonTextFont.SdkApperanceViewScheme()   : UIFont.systemFont(ofSize: 22) ]
}

struct largeFonts: SdkStyleCustomFonts {
    let ss = sdkElement_storiesBlockColorScheme.self
    public var customFonts = [CustomFonts.storiesBlockTextFont.SdkApperanceViewScheme()    : UIFont.systemFont(ofSize: 20),
                       CustomFonts.defaultButtonTextFont.SdkApperanceViewScheme() : UIFont.systemFont(ofSize: 15),
                       CustomFonts.productsButtonTextFont.SdkApperanceViewScheme()   : UIFont.systemFont(ofSize: 27) ]
}

enum FontSizes: String, SdkApperanceViewScheme {
    case normal
    case large
}

extension UIColor {
    convenience init(hexString: String, alpha: CGFloat = 1.0) {
        let hexString: String = hexString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let scanner = Scanner(string: hexString)
        if (hexString.hasPrefix("#")) {
            scanner.scanLocation = 1
        }
        var color: UInt32 = 0
        scanner.scanHexInt32(&color)
        let mask = 0x000000FF
        let r = Int(color >> 16) & mask
        let g = Int(color >> 8) & mask
        let b = Int(color) & mask
        let red   = CGFloat(r) / 255.0
        let green = CGFloat(g) / 255.0
        let blue  = CGFloat(b) / 255.0
        self.init(red:red, green:green, blue:blue, alpha:alpha)
    }
    func toHexString() -> String {
        var r:CGFloat = 0
        var g:CGFloat = 0
        var b:CGFloat = 0
        var a:CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb:Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format:"#%06x", rgb)
    }
}
