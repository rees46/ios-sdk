import UIKit

public class sdkConfiguration {
    public static var stories = sdkConfiguration()
    
    private init() {
    }
    
    public func registerFont(fileName: String, fileExtension: String) {
//        let mainBundle = Bundle.main
//#if SWIFT_PACKAGE
//        mainBundle = Bundle.module
//#endif
        
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
            storiesBlockFontNameChanged = storiesBlockFontNameConstant
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
        
        _ = {
            $0.isUserInteractionEnabled = true
            $0.textColor = storiesBlockTextColorChanged
            $0.font = UIFont(name: storiesBlockFontNameChanged!, size: storiesBlockFontSizeChanged ?? 14.0)
        }(UILabel.appearance())
        
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
        slideDefaultButtonFontSizeChanged = convertedFontSize
        
        let defaultTextColor = UIColor.hexStringFromColor(color: slideDefaultButtonTextColorConstant)
        let convertedTextColor = textColor?.hexToRGB() ?? defaultTextColor.hexToRGB()
        slideDefaultButtonTextColorChanged = UIColor(red: convertedTextColor.red, green: convertedTextColor.green, blue: convertedTextColor.blue, alpha: 1)
        
        let defaultBackgroundColor = UIColor.hexStringFromColor(color: slideDefaultButtonBackgroundColorConstant)
        let convertedBackgroundColor = backgroundColor?.hexToRGB() ?? defaultBackgroundColor.hexToRGB()
        slideDefaultButtonBackgroundColorChanged = UIColor(red: convertedBackgroundColor.red, green: convertedBackgroundColor.green, blue: convertedBackgroundColor.blue, alpha: 1)
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
        slideProductsButtonBackgroundColorChanged = UIColor(red: convertedBackgroundColor.red, green: convertedBackgroundColor.green, blue: convertedBackgroundColor.blue, alpha: 1)
        
        let convertedFontSize = fontSize ?? slideProductsButtonFontSizeConstant
        slideProductsButtonFontSizeChanged = convertedFontSize
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
        //get { return .systemFont(ofSize: 14.0) }
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
    
    public func availableSystemFonts(familyName: String) -> [String] {
        let fonts = availableFonts()
        return fonts[familyName] ?? []
    }
    
    public func standartAppearance() {
        let boldFont = ".SFUI-Bold"
        let regularFont = ".SFUI-Regular"
        let lightFont = ".SFUI-Light"
        
        let sdkUIAppDefaultsNavBar = UINavigationBar.appearance()
        //let sdkUIAppDefaultsImageView = UIImageView.appearance()
        
        let sdkUIAppDefaultsLabel = UILabel.appearance()
        let sdkUIAppDefaultsTextField = UITextField.appearance()
        let sdkUIAppDefaultsTextView = UITextView.appearance()
        let sdkUIAppDefaultsPlaceholder = UILabel.appearance(whenContainedInInstancesOf: [UITextField.self])
        let sdkUIAppDefaultsButtonLabel = UILabel.appearance(whenContainedInInstancesOf: [UIButton.self])
        let sdkUIAppDefaultsButton = UIButton.appearance()
        
        let sdkUIAppDefaultsWebView = UIWebView.appearance()
        let sdkUIAppDefaultsTableView = UITableView.appearance()
        let sdkUIAppDefaultsTableCell = UITableViewCell.appearance()
        let sdkUIAppDefaultsSectionHeader = UITableViewHeaderFooterView.appearance()
        
        let sdkUIAppDefaultsScrollView = UIScrollView.appearance()
        //let sdkUIAppDefaultsCollectionCell = UICollectionViewCell.appearance()
        //let sdkUIAppDefaultsCollectionView = UICollectionView.appearance()

    
        sdkUIAppDefaultsNavBar.tintColor = UIColor.black
        sdkUIAppDefaultsNavBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.blue, NSAttributedString.Key.font: UIFont(name: boldFont, size: 19)!]
        sdkUIAppDefaultsNavBar.backgroundColor = UIColor.white
        
        sdkUIAppDefaultsLabel.font = UIFont(name: boldFont, size: 14.0)
        sdkUIAppDefaultsLabel.textColor = UIColor.blue
        
        sdkUIAppDefaultsTextView.font = UIFont(name: regularFont, size: 15.0)
        sdkUIAppDefaultsTextView.textColor = UIColor.black
        sdkUIAppDefaultsTextView.backgroundColor = UIColor.white
        
        sdkUIAppDefaultsTextField.backgroundColor = UIColor.red
        sdkUIAppDefaultsTextField.textColor = UIColor.blue
        sdkUIAppDefaultsTextField.font = UIFont(name: boldFont, size: 12.0)

        sdkUIAppDefaultsPlaceholder.font = UIFont(name: lightFont, size: 12.0)
        sdkUIAppDefaultsPlaceholder.backgroundColor = sdkUIAppDefaultsTextField.backgroundColor
        sdkUIAppDefaultsPlaceholder.textColor = UIColor.gray
        
        sdkUIAppDefaultsButtonLabel.font = UIFont(name: boldFont, size: 14.0)
        sdkUIAppDefaultsButton.titleLabel?.font = .systemFont(ofSize: 7, weight: .regular)
        sdkUIAppDefaultsButton.titleEdgeInsets = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        
        sdkUIAppDefaultsButtonLabel.allowsDefaultTighteningForTruncation = true
        sdkUIAppDefaultsButton.tintColor = UIColor.red
        
        sdkUIAppDefaultsWebView.scalesPageToFit = true
        sdkUIAppDefaultsWebView.scrollView.bounces = true
        sdkUIAppDefaultsWebView.layer.cornerRadius = 3.0
        sdkUIAppDefaultsWebView.layer.borderWidth = 1.0
        
        sdkUIAppDefaultsTableView.backgroundColor = UIColor.white
        sdkUIAppDefaultsTableCell.backgroundColor = UIColor.blue
        sdkUIAppDefaultsSectionHeader.tintColor = UIColor.yellow
        
        sdkUIAppDefaultsScrollView.bounces = true
        sdkUIAppDefaultsScrollView.backgroundColor = UIColor.orange
        sdkUIAppDefaultsScrollView.backgroundColor = UIColor.purple
        
    }
    
//    func hexStringFromColor(color: UIColor) -> String {
//        let components = color.cgColor.components
//
//        if components?.count == 2 {
//            let r: CGFloat = components?[0] ?? 0.0
//            let g: CGFloat = components?[0] ?? 0.0
//            let b: CGFloat = components?[0] ?? 0.0
//
//            let hexString = String.init(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
//            print(hexString)
//            return hexString
//        } else {
//            let r: CGFloat = components?[0] ?? 0.0
//            let g: CGFloat = components?[1] ?? 0.0
//            let b: CGFloat = components?[2] ?? 0.0
//
//            let hexString = String.init(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
//            //print(hexString)
//            return hexString
//        }
//     }
    
    func isEqualToStringCompare(find: String) -> Bool {
        return String(format: String.init()) == find
    }
    
}

