import UIKit.UIFont
import Foundation

public protocol SdkConfigurationProtocol: AnyObject {}

public typealias sdkFontPath = URL
public typealias sdkFontName = String
public typealias sdkFontExtension = String
public typealias sdkFontClass = (url: sdkFontPath, name: sdkFontName)

open class SdkConfiguration: SdkConfigurationProtocol {

    public static let stories: SdkConfiguration = SdkConfiguration()
    
    public static let recommendations: SdkConfiguration = SdkConfiguration()
    
    //public static let search: SdkConfiguration = SdkConfiguration()
    
    public init() {}
    
    public var allLoadedFonts: [sdkFontClass] = []
    
    //Sdk main stories block default settings
    var iconSize: CGFloat = 76
    var iconBorderWidth: CGFloat = 2.3
    var iconMarginX: CGFloat = 18
    var iconMarginBottom: CGFloat = 8
    var iconNotViewedBorderColor: String = ""
    var iconNotViewedBorderColorDarkMode: String = ""
    var iconViewedBorderColor: String = ""
    var iconViewedBorderColorDarkMode: String = ""
    var iconViewedTransparency: CGFloat = 1.0
    var iconPlaceholderColor: String = "#d6d6d6"
    var iconPlaceholderColorDarkMode: String = "#d6d6d6"
    var iconAnimatedLoaderColor: String = "#5ec169"
    var labelWidth: CGFloat = 76
    var pinColor: String = ""
    var pinColorDarkMode: String = ""
    var closeIconColor: String = "#ffffff"
    var iconDisplayFormatSquare = false //default square icon false
    
    var defaultIconNotViewedBorderColor: String = "#fd7c50"
    var defaultIconViewedBorderColor: String = "#fdc2a1"
    var defaultIconViewedTransparency: CGFloat = 1.0
    var defaultIconPinColor: String = "#fd7c50"
    
    public var storiesBlockNumberOfLines: Int = 0
    public var storiesBlockCharWrapping = false
    //public var storiesBlockCharWrapping = false
    
    public var storiesBlockCharCountWrap: Int = 10
    public var defaultShowProductsButtonText: String = "See all products"
    public var defaultHideProductsButtonText: String = "Hide products"
    
    var defaultButtonCornerRadius: CGFloat = -1
    var productsButtonCornerRadius: CGFloat = -1
    
    //Sdk Promocode default settings
    public var defaultCopyToClipboardMessageText: String = "Copied"
    public var defaultCopyToClipboardMessageWidth: CGFloat = 150
    
    //Sdk Recommendations Widget settings
    public var fontNameWidget: String? = nil
    public var backgroundColorWidget: String = "#ffffff"
    public var backgroundColorDarkMode: String = "#000000"
    public var cellBackgroundColor: String = "#ffffff"
    public var cellBackgroundColorDarkMode: String = "#000000"
    public var borderWidth: CGFloat = 1
    public var borderColor: String = "#d3d3d3"
    public var borderColorDarkMode: String = "#d3d3d3"
    public var borderTransparent: CGFloat = 0.5
    public var cornerRadius: CGFloat = 9
    public var starsColor: String = "#ff9500"
    public var cartButtonTextColor: String = "#ffffff"
    public var cartButtonTextColorDarkMode: String = "#000000"
    public var cartButtonBackgroundColor: String = "#000000"
    public var cartButtonBackgroundColorDarkMode: String = "#ffffff"
    public var addToCartButtonText: String = "Add to cart"
    public var removeFromCartButtonText: String = "Remove from cart"
    public var addToCartButtonFontSize: CGFloat? = 17.0
    public var removeFromCartButtonFontSize: CGFloat? = 14.0
    public var favoritesIconColor: String = "#000000"
    public var favoritesIconColorDarkMode: String = "#ffffff"
    public var cartButtonNeedOpenWebUrl = false
    public var preloadIndicatorColor: String = "#000000"
    public var defaultMessageNoReviews: String = "No reviews"
    
    //Sdk Stories Block collection cell indicator
    public var storiesBlockPreloadIndicatorDisabled = false
    
    //Sdk Stories Slide default indicator
    public var storiesSlideReloadIndicatorDisabled = false
    public var storiesSlideReloadIndicatorBackgroundColor: String = "#ffffff"
    public var storiesSlideReloadIndicatorSize: CGFloat = 76.0
    public var storiesSlideReloadIndicatorBorderLineWidth: CGFloat = 3
    public var storiesSlideReloadIndicatorSegmentCount = Int(Double(Int.random(in: 10..<11)))
    public var storiesSlideReloadIndicatorAnimationDuration: Double = 1
    public var storiesSlideReloadIndicatorRotationDuration: Double = 17
    
    //Sdk Stories Slide reload settings
    public var storiesSlideReloadManually = false
    public var storiesSlideReloadTimeoutInterval: TimeInterval = 10
    
    //Sdk Stories Slide popup settings
    public var storiesSlideReloadPopupMessageError: String = "Failed to retrieve data. Please check your connection and try again"
    public var storiesSlideReloadPopupMessageFontSize: CGFloat = 17
    public var storiesSlideReloadPopupMessageFontWeight: UIFont.Weight = .medium
    public var storiesSlideReloadPopupPositionY: CGFloat = 120
    public var storiesSlideReloadPopupMessageDisplayTime: TimeInterval = 2.5
    
    //Sdk reachability popup postion settings
    public enum storiesSlideReloadPopupPosition: String, SdkPopupAlertViewScheme {
        case top
        case centerCustom
        case bottom
    }
    
    public func registerFont(fileName: String, fileExtension: String) {
        let pathForResourceString = Bundle.main.path(forResource: fileName,
                                                     ofType: fileExtension)
        guard pathForResourceString != nil else {
            print("SDK: Failed locate custom font \(fileName) in App Bundle")
            return
        }
        
        if pathForResourceString != nil {
            let fontData = NSData(contentsOfFile: pathForResourceString!)
            let dataProvider = CGDataProvider(data: fontData!)
            let fontRef = CGFont(dataProvider!)
            var errorRef: Unmanaged<CFError>? = nil

            if (CTFontManagerRegisterGraphicsFont(fontRef!, &errorRef) == false) {
                print("SDK: Error registering custom font")
            } else {
                print("SDK: Success registering custom font")
            }
        }
        
        SdkFontInjector.manager.registerFontNameWithExtension(fileName: fileName, fileExtension: fileExtension)
    }
    
    public func registerFont(fileNameWithoutExtension: String) {
        var parsedFont: (sdkFontName, sdkFontExtension)?

        if fileNameWithoutExtension.contains(SdkFontInjector.sdkSupportedFontExtensions.trueType.rawValue) || fileNameWithoutExtension.contains(SdkFontInjector.sdkSupportedFontExtensions.openType.rawValue) {
            parsedFont = SdkConfiguration.fontExt(fromName: fileNameWithoutExtension)
        } else {
            var tmpName = fileNameWithoutExtension + "." + SdkFontInjector.sdkSupportedFontExtensions.trueType.rawValue
            parsedFont = SdkConfiguration.fontExt(fromName: tmpName)
            if parsedFont == nil {
                tmpName = fileNameWithoutExtension + "." + SdkFontInjector.sdkSupportedFontExtensions.openType.rawValue
                parsedFont = SdkConfiguration.fontExt(fromName: tmpName)
            }
        }

        if let parsedFont = parsedFont {
            let pathForResourceString = Bundle.main.path(forResource: parsedFont.0, ofType: parsedFont.1)
            if pathForResourceString != nil {
                let fontData = NSData(contentsOfFile: pathForResourceString!)
                let dataProvider = CGDataProvider(data: fontData!)
                let fontRef = CGFont(dataProvider!)
                var errorRef: Unmanaged<CFError>? = nil

                if (CTFontManagerRegisterGraphicsFont(fontRef!, &errorRef) == false) {
                    print("SDK: Error registering font")
                } else {
                    print("SDK: Success registering font")
                }
            }
        }
    }
    
    public func setStoriesBlock(fontName: String? = nil,
                                fontSize: CGFloat? = nil,
                                textColor: String? = nil,
                                textColorDarkMode: String? = nil,
                                backgroundColor: String? = nil,
                                backgroundColorDarkMode: String? = nil,
                                iconSize: CGFloat? = nil,
                                iconBorderWidth: CGFloat? = nil,
                                iconMarginX: CGFloat? = nil,
                                iconMarginBottom: CGFloat? = nil,
                                iconNotViewedBorderColor: String? = nil,
                                iconNotViewedBorderColorDarkMode: String? = nil,
                                iconViewedBorderColor: String? = nil,
                                iconViewedBorderColorDarkMode: String? = nil,
                                iconViewedTransparency: CGFloat? = nil,
                                iconAnimatedLoaderColor: String? = nil,
                                iconPlaceholderColor: String? = nil,
                                iconPlaceholderColorDarkMode: String? = nil,
                                iconDisplayFormatSquare: Bool? = false,
                                labelWidth: CGFloat? = nil,
                                pinColor: String? = nil,
                                pinColorDarkMode: String? = nil,
                                closeIconColor: String? = nil) {
        
        let uiBlockTextColorLight = UIColor(hexString: textColor ?? UIColor.sdkDefaultBlackColor.toHexString())
        let uiBlockBackgroundColorLight = UIColor(hexString: backgroundColor ?? UIColor.white.toHexString())
        let uiBlockTextColorDark = UIColor(hexString: textColorDarkMode ?? UIColor.white.toHexString())
        let uiBlockBackgroundColorDark = UIColor(hexString: backgroundColorDarkMode ?? UIColor.black.toHexString())
        
        storiesBlockTextColorChanged_Light = uiBlockTextColorLight
        storiesBlockTextColorChanged_Dark = uiBlockTextColorDark
        
        storiesBlockBackgroundColorChanged_Light = uiBlockBackgroundColorLight
        storiesBlockBackgroundColorChanged_Dark = uiBlockBackgroundColorDark
        
        var fontProvidedBySdk = UIFont(name: storiesBlockFontNameConstant, size: storiesBlockMinimumFontSizeConstant)

        if fontName != nil {
            if fontName == storiesBlockFontNameConstant {
                storiesBlockFontNameChanged = storiesBlockFontNameConstant
            } else {
                storiesBlockFontNameChanged = fontName
            }
            
            fontProvidedBySdk = UIFont(name: storiesBlockFontNameChanged!, size: storiesBlockMinimumFontSizeChanged ?? 14.0)
            
            if fontSize != nil {
                if fontSize == storiesBlockMinimumFontSizeConstant {
                    storiesBlockMinimumFontSizeChanged = storiesBlockMinimumFontSizeConstant
                } else {
                    storiesBlockMinimumFontSizeChanged = fontSize
                    fontProvidedBySdk = UIFont(name: storiesBlockFontNameChanged!, size: storiesBlockMinimumFontSizeChanged ?? 14.0)
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
                    fontProvidedBySdk = UIFont(name: storiesBlockFontNameConstant, size: storiesBlockMinimumFontSizeChanged ?? 14.0)
                }
            } else {
                storiesBlockMinimumFontSizeChanged = 0.0
            }
        }
        
        if (fontProvidedBySdk == nil) {
            fontProvidedBySdk = .systemFont(ofSize: 14.0)
        }
        
        SdkStyle.shared.register(colorScheme: lightSdkStyleApperance(storiesBlockSelectFontName: fontProvidedBySdk!,
                                                                     storiesBlockSelectFontSize: storiesBlockMinimumFontSizeChanged!,
                                                                     storiesBlockFontColor: uiBlockTextColorLight,
                                                                     storiesBlockBackgroundColor: uiBlockBackgroundColorLight,
                                                                     defaultButtonSelectFontName: fontProvidedBySdk!,
                                                                     defaultButtonSelectFontSize: storiesBlockMinimumFontSizeChanged!,
                                                                     defaultButtonFontColor: .white,
                                                                     defaultButtonBackgroundColor: .black,
                                                                     productsButtonSelectFontName: fontProvidedBySdk!,
                                                                     productsButtonSelectFontSize: storiesBlockMinimumFontSizeChanged!,
                                                                     productsButtonFontColor: .black,
                                                                     productsButtonBackgroundColor: .white),
                                 for: SdkStyleApperanceTypes.storiesBlockLight)
        
        SdkStyle.shared.register(colorScheme: darkSdkStyleApperance(storiesBlockSelectFontName: fontProvidedBySdk!,
                                                                    storiesBlockSelectFontSize: storiesBlockMinimumFontSizeChanged!,
                                                                    storiesBlockFontColor: uiBlockTextColorDark,
                                                                    storiesBlockBackgroundColor: uiBlockBackgroundColorDark,
                                                                    defaultButtonSelectFontName: fontProvidedBySdk!,
                                                                    defaultButtonSelectFontSize: storiesBlockMinimumFontSizeChanged!,
                                                                    defaultButtonFontColor: .black,
                                                                    defaultButtonBackgroundColor: .white,
                                                                    productsButtonSelectFontName: fontProvidedBySdk!,
                                                                    productsButtonSelectFontSize: storiesBlockMinimumFontSizeChanged!,
                                                                    productsButtonFontColor: .black,
                                                                    productsButtonBackgroundColor: .white),
                                 for: SdkStyleApperanceTypes.storiesBlockDark)

        if iconSize != nil {
            self.iconSize = iconSize!
        }
        if iconBorderWidth != nil {
            self.iconBorderWidth = iconBorderWidth!
        }
        if iconMarginX != nil {
            self.iconMarginX = iconMarginX!
        }
        if iconMarginBottom != nil {
            self.iconMarginBottom = iconMarginBottom!
        }
        if iconNotViewedBorderColor != nil {
            self.iconNotViewedBorderColor = iconNotViewedBorderColor!
        }
        if iconNotViewedBorderColorDarkMode != nil {
            self.iconNotViewedBorderColorDarkMode = iconNotViewedBorderColorDarkMode!
        }
        if iconViewedBorderColor != nil {
            self.iconViewedBorderColor = iconViewedBorderColor!
        }
        if iconViewedBorderColorDarkMode != nil {
            self.iconViewedBorderColorDarkMode = iconViewedBorderColorDarkMode!
        }
        if iconViewedTransparency != nil {
            self.iconViewedTransparency = iconViewedTransparency!
        }
        if iconAnimatedLoaderColor != nil {
            self.iconAnimatedLoaderColor = iconAnimatedLoaderColor!
        }
        if iconPlaceholderColor != nil {
            self.iconPlaceholderColor = iconPlaceholderColor!
        }
        if iconPlaceholderColorDarkMode != nil {
            self.iconPlaceholderColorDarkMode = iconPlaceholderColorDarkMode!
        }
        if labelWidth != nil {
            self.labelWidth = labelWidth!
        }
        if pinColor != nil {
            self.pinColor = pinColor!
        }
        if pinColorDarkMode != nil {
            self.pinColorDarkMode = pinColorDarkMode!
        }
        if closeIconColor != nil {
            self.closeIconColor = closeIconColor!
        }
        
        if iconDisplayFormatSquare != nil {
            self.iconDisplayFormatSquare = iconDisplayFormatSquare ?? false
        }
        
        if SdkConfiguration.isDarkMode {
            SdkStyle.shared.switchApppearance(to: SdkStyleApperanceTypes.storiesBlockDark, animated: false)
        } else {
            SdkStyle.shared.switchApppearance(to: SdkStyleApperanceTypes.storiesBlockLight, animated: false)
        }
    }
    
    public func setSlideDefaultButton(fontName: String? = nil,
                                      fontSize: CGFloat? = nil,
                                      textColor: String? = nil,
                                      backgroundColor: String? = nil,
                                      textColorDarkMode: String? = nil,
                                      backgroundColorDarkMode: String? = nil,
                                      cornerRadius: CGFloat? = nil) {
        
        let slideDefaultButtonTextColorLight = UIColor(hexString: textColor ?? UIColor.sdkDefaultBlackColor.toHexString())
        let slideDefaultButtonTextColorDark = UIColor(hexString: textColorDarkMode ?? UIColor.white.toHexString())
        
        let defaultTextColor = UIColor.hexStringFromColor(color: slideDefaultButtonTextColorConstant_Light)
        let convertedTextColor = textColor?.hexToRGB() ?? defaultTextColor.hexToRGB()
        if textColor != nil {
            slideDefaultButtonTextColorChanged_Light = UIColor(red: convertedTextColor.red, green: convertedTextColor.green, blue: convertedTextColor.blue, alpha: 1)
        } else {
            slideDefaultButtonTextColorChanged_Light = nil
            slideDefaultButtonTextColorConstant_Light = UIColor(red: convertedTextColor.red, green: convertedTextColor.green, blue: convertedTextColor.blue, alpha: 1)
        }
        
        let defaultTextColorDark = UIColor.hexStringFromColor(color: slideDefaultButtonTextColorConstant_Dark)
        let convertedTextColorDark = textColorDarkMode?.hexToRGB() ?? defaultTextColorDark.hexToRGB()
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
        let convertedDefaultButtonBackgroundColorDark = backgroundColorDarkMode?.hexToRGB() ?? defaultBackgroundColorDark.hexToRGB()
        if backgroundColorDarkMode != nil {
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
        
        var storedStoriesBlockSelectFontName = SdkStyle.shared.currentColorScheme?.storiesBlockSelectFontName
        if storedStoriesBlockSelectFontName == nil {
            storedStoriesBlockSelectFontName = .systemFont(ofSize: 15.0, weight: .semibold)
        }
        let storedStoriesBlockFontColor = SdkStyle.shared.currentColorScheme?.storiesBlockFontColor ?? .black
        let storedStoriesBlockBackgroundColor = SdkStyle.shared.currentColorScheme?.storiesBlockBackgroundColor ?? .white
        
        if (slideButtonFontBySdk == nil) {
            slideButtonFontBySdk = .systemFont(ofSize: 16.0)
        }
        if (storiesBlockMinimumFontSizeChanged == nil) {
            storiesBlockMinimumFontSizeChanged = 14.0
        }
        
        if cornerRadius != nil {
            self.defaultButtonCornerRadius = cornerRadius!
        }
        
        SdkStyle.shared.register(colorScheme:
                                    lightSdkStyleApperance(storiesBlockSelectFontName: storedStoriesBlockSelectFontName!,
                                                           storiesBlockSelectFontSize: storiesBlockMinimumFontSizeChanged!,
                                                           storiesBlockFontColor: storedStoriesBlockFontColor,
                                                           storiesBlockBackgroundColor: storedStoriesBlockBackgroundColor,
                                                           
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
                                                          storiesBlockFontColor: storedStoriesBlockFontColor,
                                                          storiesBlockBackgroundColor: storedStoriesBlockBackgroundColor,
                                                          
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

        
        if SdkConfiguration.isDarkMode {
            SdkStyle.shared.switchApppearance(to: SdkStyleApperanceTypes.storiesBlockDark, animated: false)
        } else {
            SdkStyle.shared.switchApppearance(to: SdkStyleApperanceTypes.storiesBlockLight, animated: false)
        }
    }
    
    public func setSlideProductsButton(fontName: String? = nil,
                                       fontSize: CGFloat? = nil,
                                       textColor: String? = nil,
                                       backgroundColor: String? = nil,
                                       textColorDarkMode: String? = nil,
                                       backgroundColorDarkMode: String? = nil,
                                       cornerRadius: CGFloat? = nil) {
        
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
        let convertedTextColorDark = textColorDarkMode?.hexToRGB() ?? defaultTextColorDark.hexToRGB()
        slideProductsButtonTextColorChanged_Dark = UIColor(red: convertedTextColorDark.red, green: convertedTextColorDark.green, blue: convertedTextColorDark.blue, alpha: 1)
        
        let defaultBackgroundColor = UIColor.hexStringFromColor(color: slideProductsButtonBackgroundColorConstant_Light)
        let convertedBackgroundColor = backgroundColor?.hexToRGB() ?? defaultBackgroundColor.hexToRGB()
        if backgroundColor != nil {
            slideProductsButtonBackgroundColorChanged_Light = UIColor(red: convertedBackgroundColor.red, green: convertedBackgroundColor.green, blue: convertedBackgroundColor.blue, alpha: 1)
        } else {
            slideProductsButtonBackgroundColorChanged_Light = nil
        }
        
        let defaultBackgroundColorDark = UIColor.hexStringFromColor(color: slideProductsButtonBackgroundColorConstant_Dark)
        let convertedBackgroundColorDark = backgroundColorDarkMode?.hexToRGB() ?? defaultBackgroundColorDark.hexToRGB()
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
        
        if cornerRadius != nil {
            self.productsButtonCornerRadius = cornerRadius!
        }
    }
    
    public func setProductsCard(fontName: String? = nil,
                                showProductsButtonText: String? = "See all products",
                                hideProductsButtonText: String? = "Hide products") {
        if fontName != nil {
            if fontName == slideProductsHideButtonFontNameConstant {
                slideProductsHideButtonFontNameChanged = nil
            } else {
                slideProductsHideButtonFontNameChanged = fontName
            }
        }
        defaultShowProductsButtonText = showProductsButtonText!
        defaultHideProductsButtonText = hideProductsButtonText!
    }
    
    //    public func setWidget(wfontName: String? = nil,
    //                          wbackgroundColor: String? = nil,
    //                          backgroundColorDarkMode: String? = nil,
    //                          cellBackgroundColor: String? = nil,
    //                          cellBackgroundColorDarkMode: String? = nil,
    //                          borderWidth: CGFloat? = nil,
    //                          borderColor: String? = nil,
    //                          colorDarkMode: String? = nil,
    //                          borderTransparent: CGFloat? = nil,
    //                          cornerRadius: CGFloat? = nil,
    //                          starsColor: String? = nil,
    //                          addToCartButtonText: String? = nil,
    //                          removeFromCartButtonText: String? = nil,
    //                          addToCartButtonFontSize: CGFloat? = nil,
    //                          removeFromCartButtonFontSize: CGFloat? = nil,
    //                          cartButtonTextColor: String? = nil,
    //                          cartButtonTextColorDarkMode: String? = nil,
    //                          cartButtonBackgroundColor: String? = nil,
    //                          cartButtonBackgroundColorDarkMode: String? = nil,
    //                          cartButtonNeedOpenWebUrl: Bool? = false,
    //                          favoritesIconColor: String? = nil,
    //                          favoritesIconColorDarkMode: String? = nil,
    //                          preloadIndicatorColor: String? = nil,
    //                          defaultMessageNoReview: String? = "No reviews") {
    //
    //        if fontNameWidget != nil {
    //            self.wfontName = fontNameWidget!
    //        }
    //        if wbackgroundColor != nil {
    //            self.wbackgroundColor = wbackgroundColor!
    //        }
    //        if backgroundColorDarkMode != nil {
    //            self.backgroundColorDarkMode = backgroundColorDarkMode!
    //        }
    //        if cellBackgroundColor != nil {
    //            self.cellBackgroundColor = cellBackgroundColor!
    //        }
    //        if cellBackgroundColorDarkMode != nil {
    //            self.cellBackgroundColorDarkMode = cellBackgroundColorDarkMode!
    //        }
    //        if borderWidth != nil {
    //            self.borderWidth = borderWidth!
    //        }
    //        if borderColor != nil {
    //            self.borderColor = borderColor!
    //        }
    //        if colorDarkMode != nil {
    //            self.colorDarkMode = colorDarkMode!
    //        }
    //        if borderTransparent != nil {
    //            self.borderTransparent = borderTransparent!
    //        }
    //        if cornerRadius != nil {
    //            self.cornerRadius = cornerRadius!
    //        }
    //        if starsColor != nil {
    //            self.starsColor = starsColor!
    //        }
    //        if addToCartButtonText != nil {
    //            self.addToCartButtonText = addToCartButtonText!
    //        }
    //        if removeFromCartButtonText != nil {
    //            self.removeFromCartButtonText = removeFromCartButtonText!
    //        }
    //        if addToCartButtonFontSize != nil {
    //            self.addToCartButtonFontSize = addToCartButtonFontSize!
    //        }
    //        if removeFromCartButtonFontSize != nil {
    //            self.removeFromCartButtonFontSize = removeFromCartButtonFontSize!
    //        }
    //        if cartButtonTextColor != nil {
    //            self.cartButtonTextColor = cartButtonTextColor!
    //        }
    //        if cartButtonTextColorDarkMode != nil {
    //            self.cartButtonTextColorDarkMode = cartButtonTextColorDarkMode!
    //        }
    //        if cartButtonBackgroundColor != nil {
    //            self.cartButtonBackgroundColor = cartButtonBackgroundColor!
    //        }
    //        if cartButtonBackgroundColorDarkMode != nil {
    //            self.cartButtonBackgroundColorDarkMode = cartButtonBackgroundColorDarkMode!
    //        }
    //        if cartButtonNeedOpenWebUrl != nil {
    //            self.cartButtonNeedOpenWebUrl = cartButtonNeedOpenWebUrl!
    //        }
    //        if favoritesIconColor != nil {
    //            self.favoritesIconColor = favoritesIconColor!
    //        }
    //        if favoritesIconColorDarkMode != nil {
    //            self.favoritesIconColorDarkMode = favoritesIconColorDarkMode!
    //        }
    //        if preloadIndicatorColor != nil {
    //            self.preloadIndicatorColor = preloadIndicatorColor!
    //        }
    //        if defaultMessageNoReviews != nil {
    //            self.defaultMessageNoReviews = defaultMessageNoReviews!
    //        }
    //    }
    
    
    public func setWidget(fontNameWidget: String? = nil,
                          backgroundColorWidget: String? = nil,
                          backgroundColorDarkMode: String? = nil,
                          cellBackgroundColor: String? = nil,
                          cellBackgroundColorDarkMode: String? = nil,
                          borderWidth: CGFloat? = nil,
                          borderColor: String? = nil,
                          borderColorDarkMode: String? = nil,
                          borderTransparent: CGFloat? = nil,
                          cornerRadius: CGFloat? = nil,
                          starsColor: String? = nil,
                          addToCartButtonText: String? = nil,
                          removeFromCartButtonText: String? = nil,
                          addToCartButtonFontSize: CGFloat? = nil,
                          removeFromCartButtonFontSize: CGFloat? = nil,
                          cartButtonTextColor: String? = nil,
                          cartButtonTextColorDarkMode: String? = nil,
                          cartButtonBackgroundColor: String? = nil,
                          cartButtonBackgroundColorDarkMode: String? = nil,
                          cartButtonNeedOpenWebUrl: Bool? = false,
                          favoritesIconColor: String? = nil,
                          favoritesIconColorDarkMode: String? = nil,
                          preloadIndicatorColor: String? = nil,
                          defaultMessageNoReviews: String? = "No reviews") {
        
        if fontNameWidget != nil {
            self.fontNameWidget = fontNameWidget!
        }
        if backgroundColorWidget != nil {
            self.backgroundColorWidget = backgroundColorWidget!
        }
        if backgroundColorDarkMode != nil {
            self.backgroundColorDarkMode = backgroundColorDarkMode!
        }
        if cellBackgroundColor != nil {
            self.cellBackgroundColor = cellBackgroundColor!
        }
        if cellBackgroundColorDarkMode != nil {
            self.cellBackgroundColorDarkMode = cellBackgroundColorDarkMode!
        }
        if borderWidth != nil {
            self.borderWidth = borderWidth!
        }
        if borderColor != nil {
            self.borderColor = borderColor!
        }
        if borderColorDarkMode != nil {
            self.borderColorDarkMode = borderColorDarkMode!
        }
        if borderTransparent != nil {
            self.borderTransparent = borderTransparent!
        }
        if cornerRadius != nil {
            self.cornerRadius = cornerRadius!
        }
        if starsColor != nil {
            self.starsColor = starsColor!
        }
        if addToCartButtonText != nil {
            self.addToCartButtonText = addToCartButtonText!
        }
        if removeFromCartButtonText != nil {
            self.removeFromCartButtonText = removeFromCartButtonText!
        }
        if addToCartButtonFontSize != nil {
            self.addToCartButtonFontSize = addToCartButtonFontSize!
        }
        if removeFromCartButtonFontSize != nil {
            self.removeFromCartButtonFontSize = removeFromCartButtonFontSize!
        }
        if cartButtonTextColor != nil {
            self.cartButtonTextColor = cartButtonTextColor!
        }
        if cartButtonTextColorDarkMode != nil {
            self.cartButtonTextColorDarkMode = cartButtonTextColorDarkMode!
        }
        if cartButtonBackgroundColor != nil {
            self.cartButtonBackgroundColor = cartButtonBackgroundColor!
        }
        if cartButtonBackgroundColorDarkMode != nil {
            self.cartButtonBackgroundColorDarkMode = cartButtonBackgroundColorDarkMode!
        }
        if cartButtonNeedOpenWebUrl != nil {
            self.cartButtonNeedOpenWebUrl = cartButtonNeedOpenWebUrl!
        }
        if favoritesIconColor != nil {
            self.favoritesIconColor = favoritesIconColor!
        }
        if favoritesIconColorDarkMode != nil {
            self.favoritesIconColorDarkMode = favoritesIconColorDarkMode!
        }
        if preloadIndicatorColor != nil {
            self.preloadIndicatorColor = preloadIndicatorColor!
        }
        if defaultMessageNoReviews != nil {
            self.defaultMessageNoReviews = defaultMessageNoReviews!
        }
    }
    
    public var promoCodeSlideFontNameChanged: String?
    public var promoCodeSlideFontNameConstant: String {
        get {
            return "San Francisco (System Font)"
        }
        set {
            promoCodeSlideFontNameChanged = newValue
        }
    }
    
    public var promoCodeSlideFontSizeChanged: CGFloat?
    public var promoCodeSlideFontSizeConstant: CGFloat {
        get {
            return 14.0
        }
        set {
            promoCodeSlideFontSizeChanged = newValue
        }
    }
    
    public var promoProductTitleTextColorLightMode: UIColor?
    public var promoCodeSlideFontColorConstant_Light: UIColor {
        get {
            return .white
        }
        set {
            promoProductTitleTextColorLightMode = newValue
        }
    }
    
    public var promoProductTitleTextColorDarkMode: UIColor?
    public var promoCodeSlideFontColorConstant_Dark: UIColor {
        get {
            return .white
        }
        set {
            promoProductTitleTextColorDarkMode = newValue
        }
    }
    
    public var bannerOldPriceSectionFontColor: UIColor?
    public var bannerOldPriceSectionFontColorConstant: UIColor {
        get {
            return .white
        }
        set {
            bannerOldPriceSectionFontColor = newValue
        }
    }
    
    public var bannerPriceSectionFontColor: UIColor?
    public var bannerPriceSectionFontColorConstant: UIColor {
        get {
            return .white
        }
        set {
            bannerPriceSectionFontColor = newValue
        }
    }
    
    public var bannerPromocodeSectionFontColor: UIColor?
    public var bannerPromocodeSectionFontColorConstant: UIColor {
        get {
            return .white
        }
        set {
            bannerPromocodeSectionFontColor = newValue
        }
    }
    
    public var bannerPriceSectionBackgroundColor: UIColor?
    public var bannerPriceSectionBackgroundConstant: UIColor {
        get {
            return .orange
        }
        set {
            bannerPriceSectionBackgroundColor = newValue
        }
    }
    
    public var bannerPromocodeSectionBackgroundColor: UIColor?
    public var bannerPromocodeSectionBackgroundColorConstant: UIColor {
        get {
            return .orange
        }
        set {
            bannerPromocodeSectionBackgroundColor = newValue
        }
    }
    
    public var bannerDiscountSectionBackgroundColor: UIColor?
    public var bannerDiscountSectionBackgroundConstant: UIColor {
        get {
            return .yellow
        }
        set {
            bannerDiscountSectionBackgroundColor = newValue
        }
    }
    
    public func setPromocodeCard(productBannerFontName: String? = nil,
                                 productTitleFontSize: CGFloat? = nil,
                                 productTitleTextColor: String? = nil,
                                 productTitleTextColorDarkMode: String? = nil,
                                 productBannerOldPriceSectionFontColor: String? = nil,
                                 productBannerPriceSectionFontColor: String? = nil,
                                 productBannerPriceSectionBackgroundColor: String? = nil,
                                 productBannerPromocodeSectionFontColor: String? = nil,
                                 productBannerPromocodeSectionBackgroundColor: String? = nil,
                                 productBannerDiscountSectionBackgroundColor: String? = nil,
                                 productBannerPromocodeCopyToClipboardMessage: String? = "Copied") {
        
        if productBannerFontName != nil {
            if productBannerFontName == promoCodeSlideFontNameConstant {
                promoCodeSlideFontNameChanged = nil
            } else {
                promoCodeSlideFontNameChanged = productBannerFontName
            }
        }
        
        let convertedFontSize = productTitleFontSize ?? promoCodeSlideFontSizeConstant
        if productTitleFontSize != nil {
            promoCodeSlideFontSizeChanged = convertedFontSize
        } else {
            promoCodeSlideFontSizeConstant = 16.0
        }
        
        let uipromoProductTitleTextColorLightMode = UIColor(hexString: productTitleTextColor ?? UIColor.white.toHexString())
        let uipromoProductTitleTextColorDarkMode = UIColor(hexString: productTitleTextColorDarkMode ?? UIColor.white.toHexString())
        
        promoProductTitleTextColorLightMode = uipromoProductTitleTextColorLightMode
        promoProductTitleTextColorDarkMode = uipromoProductTitleTextColorDarkMode
        
        let uiOldProductBannerPriceSectionFontColor = UIColor(hexString: productBannerOldPriceSectionFontColor ?? UIColor.sdkDefaultWhiteColor.toHexString())
        
        let uiProductBannerPriceSectionFontColor = UIColor(hexString: productBannerPriceSectionFontColor ?? UIColor.sdkDefaultWhiteColor.toHexString())
        let uiProductBannerPromocodeSectionFontColor = UIColor(hexString: productBannerPromocodeSectionFontColor ?? UIColor.sdkDefaultWhiteColor.toHexString())
        let uiProductBannerPriceSectionBackgroundColor = UIColor(hexString: productBannerPriceSectionBackgroundColor ?? UIColor.sdkDefaultOrangeColor.toHexString())
        let uiProductBannerPromocodeSectionBackgroundColor = UIColor(hexString: productBannerPromocodeSectionBackgroundColor ?? UIColor.sdkDefaultBlueColor.toHexString())
        
        bannerOldPriceSectionFontColor = uiOldProductBannerPriceSectionFontColor
        bannerPriceSectionFontColor = uiProductBannerPriceSectionFontColor
        bannerPromocodeSectionFontColor = uiProductBannerPromocodeSectionFontColor
        
        bannerPriceSectionBackgroundColor = uiProductBannerPriceSectionBackgroundColor
        bannerPromocodeSectionBackgroundColor = uiProductBannerPromocodeSectionBackgroundColor
        
        let uiDiscountBannerSectionBackgroundColor = UIColor(hexString: productBannerDiscountSectionBackgroundColor ?? UIColor.sdkDefaultYellowColor.toHexString())
        bannerDiscountSectionBackgroundColor = uiDiscountBannerSectionBackgroundColor
        
        defaultCopyToClipboardMessageText = productBannerPromocodeCopyToClipboardMessage!
        //defaultCopyToClipboardMessageWidth = copyToClipboardWidth!
    }
    
    final class func fontExt(fromName name: String) -> (sdkFontName, sdkFontExtension) {
        let components = name.split{$0 == "."}.map { String($0) }
        return (components[0], components[1])
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
                                   CustomTableCellColors.cellTextColor.SdkApperanceViewScheme() : UIColor.purple]
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
                                   CustomTableCellColors.cellTextColor.SdkApperanceViewScheme() : UIColor.purple]
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
    
    public static var isDarkMode: Bool {
        if #available(iOS 13.0, *) {
            return UITraitCollection.current.userInterfaceStyle == .dark
        } else {
            return false
        }
    }
    
    public func getInstalledFontsFrom(bundle: Bundle = .main,
                                      completion: (([String]) -> Void)? = nil) {
        getInstalledFontsFrom(at: bundle.bundleURL, completion: completion)
    }
    
    public func getInstalledFontsFrom(at url: URL?,
                                      completion: (([String]) -> Void)? = nil) {
        
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
        get {
            return "San Francisco (System Font)"
        }
        set {
            storiesBlockFontNameChanged = newValue
        }
    }
    
    public var storiesBlockMinimumFontSizeChanged: CGFloat?
    public var storiesBlockMinimumFontSizeConstant: CGFloat {
        get {
            return 7.0
        }
        set {
            storiesBlockMinimumFontSizeChanged = newValue
        }
    }
    
    public var storiesBlockTextColorChanged_Light: UIColor?
    public var storiesBlockTextColorConstant_Light: UIColor {
        get {
            return .black
        }
        set {
            storiesBlockTextColorChanged_Light = newValue
        }
    }
    
    public var storiesBlockTextColorChanged_Dark: UIColor?
    public var storiesBlockTextColorConstant_Dark: UIColor {
        get {
            return .black
        }
        set {
            storiesBlockTextColorChanged_Dark = newValue
        }
    }
    
    public var storiesBlockBackgroundColorChanged_Light: UIColor?
    public var storiesBlockBackgroundColorConstant_Light: UIColor {
        get {
            return .white
        }
        set {
            storiesBlockBackgroundColorChanged_Light = newValue
        }
    }
    
    public var storiesBlockBackgroundColorChanged_Dark: UIColor?
    public var storiesBlockBackgroundColorConstant_Dark: UIColor {
        get {
            return .black
        }
        set {
            storiesBlockBackgroundColorChanged_Dark = newValue
        }
    }
    
    public var slideDefaultButtonFontNameChanged: String?
    public var slideDefaultButtonFontNameConstant: String {
        get {
            return "San Francisco (System Font)"
        }
        set {
            slideDefaultButtonFontNameChanged = newValue
        }
    }
    
    public var slideDefaultButtonFontSizeChanged: CGFloat?
    public var slideDefaultButtonFontSizeConstant: CGFloat {
        get {
            return 14.0
        }
        set {
            slideDefaultButtonFontSizeChanged = newValue
        }
    }
    
    public var slideDefaultButtonTextColorChanged_Light: UIColor?
    public var slideDefaultButtonTextColorConstant_Light: UIColor {
        get {
            return .black
        }
        set {
            slideDefaultButtonTextColorChanged_Light = newValue
        }
    }
    
    public var slideDefaultButtonTextColorChanged_Dark: UIColor?
    public var slideDefaultButtonTextColorConstant_Dark: UIColor {
        get {
            return .black
        }
        set {
            slideDefaultButtonTextColorChanged_Dark = newValue
        }
    }
    
    public var slideDefaultButtonBackgroundColorChanged_Light: UIColor?
    public var slideDefaultButtonBackgroundColorConstant_Light: UIColor {
        get {
            return .white
        }
        set {
            slideDefaultButtonBackgroundColorChanged_Light = newValue
        }
    }
    
    public var slideDefaultButtonBackgroundColorChanged_Dark: UIColor?
    public var slideDefaultButtonBackgroundColorConstant_Dark: UIColor {
        get {
            return .white
        }
        set {
            slideDefaultButtonBackgroundColorChanged_Dark = newValue
        }
    }
    
    public var slideProductsButtonFontNameChanged: String?
    public var slideProductsButtonFontNameConstant: String {
        get {
            return "San Francisco (System Font)" }
        set {
            slideProductsButtonFontNameChanged = newValue }
    }
    
    public var slideProductsButtonFontSizeChanged: CGFloat?
    public var slideProductsButtonFontSizeConstant: CGFloat {
        get {
            return 14.0
        }
        set {
            slideProductsButtonFontSizeChanged = newValue
        }
    }
    
    public var slideProductsButtonTextColorChanged_Light: UIColor?
    public var slideProductsButtonTextColorConstant_Light: UIColor {
        get {
            return .black
        }
        set {
            slideProductsButtonTextColorChanged_Light = newValue
        }
    }
    
    public var slideProductsButtonTextColorChanged_Dark: UIColor?
    public var slideProductsButtonTextColorConstant_Dark: UIColor {
        get {
            return .black
        }
        set {
            slideProductsButtonTextColorChanged_Dark = newValue
        }
    }
    
    public var slideProductsButtonBackgroundColorChanged_Light: UIColor?
    public var slideProductsButtonBackgroundColorConstant_Light: UIColor {
        get {
            return .white
        }
        set {
            slideProductsButtonBackgroundColorChanged_Light = newValue
        }
    }
    
    public var slideProductsButtonBackgroundColorChanged_Dark: UIColor?
    public var slideProductsButtonBackgroundColorConstant_Dark: UIColor {
        get {
            return .white
        }
        set {
            slideProductsButtonBackgroundColorChanged_Dark = newValue
        }
    }
    
    public var slideProductsHideButtonFontNameChanged: String?
    public var slideProductsHideButtonFontNameConstant: String {
        get {
            return "San Francisco (System Font)"
        }
        set {
            slideProductsButtonFontNameChanged = newValue
        }
    }
    
    public var bootRegisteredFontChanged: UIFont?
    public var bootRegisteredFontConstant: UIFont {
        get {
            return .systemFont(ofSize: 14.0)
        }
        set {
            bootRegisteredFontChanged = newValue
        }
    }
    
    public class func customFont(name: String, size: CGFloat) -> UIFont {
        let sizeWithOffset = size
        guard let sFont = UIFont(name: name, size: sizeWithOffset) else {
            UIFont.familyNames.forEach({ familyName in
                let fontNames = UIFont.fontNames(forFamilyName: familyName)
                print(familyName, fontNames)
            })
            print("SDK: Error Font not found: \(name)")
            return UIFont.systemFont(ofSize: 15.0)
        }
        return sFont
    }
}


private extension SdkConfiguration {
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
            print("SDK: There was an error loading fonts. Path: \(url). Error: \(error)")
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
                print("SDK: There was an error accessing bundle with url. Path: \(url). Error: \(error) ")
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
                    print("SDK: Successfully loaded custom font: '\(postScriptName)'.")
                    nowLoadedFontName = String(postScriptName)
                }
            } else if let error = error?.takeRetainedValue() {
                let errorDescription = CFErrorCopyDescription(error)
                print("SDK: Already installed custom font '\(name)': \(String(describing: errorDescription))")
            }
        } else {
            guard let error = error?.takeRetainedValue() else {
                print("SDK: Failed to load font '\(name)'.")
                return nil
            }
            let errorDescription = CFErrorCopyDescription(error)
            print("SDK: Failed to load font '\(name)': \(String(describing: errorDescription))")
        }

        if let sdkLfn = nowLoadedFontName {
            return (fileURL, sdkLfn)
        }
        return nil
    }

    class func workaroundDeadlock() {
        _ = UIFont.systemFont(ofSize: 7)
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
        if comps.count < 2 {
            return nil
        }
        
        let fname = comps[0 ..< comps.count - 1].joined(separator: ".")
        return SdkFontInjector.sdkSupportedFontExtensions(comps.last!) != nil ? fname : nil
    }
}

extension UIColor {
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt32()
        Scanner(string: hex).scanHexInt32(&int)
        let a, r, g, b: UInt32
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
    
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
        
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    func toHexString() -> String {
        var r:CGFloat = 0
        var g:CGFloat = 0
        var b:CGFloat = 0
        var a:CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format:"#%06x", rgb)
    }
}
