import UIKit
import Foundation

public class SdkGlobalHelper {

    public class var sharedInstance: SdkGlobalHelper {
        struct Static {
            static let instance: SdkGlobalHelper = SdkGlobalHelper()
        }
        return Static.instance
    }
    
    init() {
    }
    
    public struct ScreenSize {
        static let SCREEN_WIDTH = UIScreen.main.bounds.size.width
        static let SCREEN_HEIGHT = UIScreen.main.bounds.size.height
        static let SCREEN_MAX_LENGTH = max(ScreenSize.SCREEN_WIDTH, ScreenSize.SCREEN_HEIGHT)
        static let SCREEN_MIN_LENGTH = min(ScreenSize.SCREEN_WIDTH, ScreenSize.SCREEN_HEIGHT)
    }
    
    public struct DeviceType {
        public static let IS_IPHONE_5 = UIDevice.current.userInterfaceIdiom == .phone && ScreenSize.SCREEN_MAX_LENGTH == 568.0
        public static let IS_IPHONE_SE = UIDevice.current.userInterfaceIdiom == .phone && ScreenSize.SCREEN_MAX_LENGTH == 667.0
        public static let IS_IPHONE_8_PLUS = UIDevice.current.userInterfaceIdiom == .phone && ScreenSize.SCREEN_MAX_LENGTH == 736.0
        public static let IS_IPHONE_XS = UIDevice.current.userInterfaceIdiom == .phone && ScreenSize.SCREEN_MAX_LENGTH == 812.0
        public static let IS_IPHONE_XS_MAX = UIDevice.current.userInterfaceIdiom == .phone && ScreenSize.SCREEN_MAX_LENGTH == 896.0
        public static let IS_IPHONE_14 = UIDevice.current.userInterfaceIdiom == .phone && ScreenSize.SCREEN_MAX_LENGTH == 844.0
        public static let IS_IPHONE_14_PRO = UIDevice.current.userInterfaceIdiom == .phone && ScreenSize.SCREEN_MAX_LENGTH == 852.0
        public static let IS_IPHONE_14_PLUS = UIDevice.current.userInterfaceIdiom == .phone && ScreenSize.SCREEN_MAX_LENGTH == 926.0
        public static let IS_IPHONE_14_PRO_MAX = UIDevice.current.userInterfaceIdiom == .phone && ScreenSize.SCREEN_MAX_LENGTH == 932.0
    }
    
    public func getSdkDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    public func willDeviceHaveDynamicIsland() -> Bool {
        if let simulatorModelIdentifier = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] {
            let nameSimulator = simulatorModelIdentifier
            return nameSimulator == "iPhone15,2" || nameSimulator == "iPhone15,3" || nameSimulator == "iPhone15,4" || nameSimulator == "iPhone15,5" || nameSimulator == "iPhone16,1" || nameSimulator == "iPhone16,2"  ? true : false
        }
        
        var sysinfo = utsname()
        uname(&sysinfo)
        let name =  String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)!.trimmingCharacters(in: .controlCharacters)
        return name == "iPhone15,2" || name == "iPhone15,3" || name == "iPhone15,4" || name == "iPhone15,5" || name == "iPhone16,1" || name == "iPhone16,2" ? true : false
    }
    
    public func saveVideoParamsToDictionary(parentSlideId: String, paramsDictionary: [String:String]) {
       var stringValuesToSave: [String:String] = [:]
        
       for key in paramsDictionary.keys {
          let valueToStore = paramsDictionary[key]!
          let keyVideoStr: String = key
          let durationVideoStr: String = valueToStore

          stringValuesToSave[keyVideoStr] = durationVideoStr
       }
       UserDefaults.standard.setValue(stringValuesToSave, forKeyPath: parentSlideId)
    }
    
    func retrieveVideoCachedParamsDictionary(parentSlideId: String) -> [String:String] {
        let savedDownloadedVideosValues: [String:String] = UserDefaults.standard.object(forKey: parentSlideId) as? [String : String] ?? [String:String]()
        
        var convertedDurationsDictionary:[String:String] = [:]
        for key in savedDownloadedVideosValues.keys {
            let keyVideoStr: String = key
            let durationVideoStr: String = savedDownloadedVideosValues[key]!
            convertedDurationsDictionary[keyVideoStr] = durationVideoStr
        }
        
        return convertedDurationsDictionary
    }
}


extension DispatchQueue {
    private static var _onceTracker = [String]()
    
    class func onceTechService(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        block: () -> Void
    ) {
        let token = "\(file):\(function):\(line)"
        onceTechService(token: token, block: block)
    }
    
    class func onceTechService(
        token: String,
        block: () -> Void
    ) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        guard !_onceTracker.contains(token) else {
            return
        }
        
        _onceTracker.append(token)
        block()
    }
}


extension UIImage {
    func withRoundedCorners(radius: CGFloat? = nil) -> UIImage? {
        let maxRadius = min(size.width, size.height) / 2
        let cornerRadius: CGFloat
        
        if let radius = radius, radius > 0 && radius <= maxRadius {
            cornerRadius = radius
        } else {
            cornerRadius = maxRadius
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        
        let rect = CGRect(origin: .zero, size: size)
        UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()
        draw(in: rect)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}


extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
 
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }

    convenience init(rgb: Int) {
        self.init(
            red: (rgb >> 16) & 0xFF,
            green: (rgb >> 8) & 0xFF,
            blue: rgb & 0xFF
        )
    }
}


extension UIColor {
    public class func hexStringFromColor(color: UIColor) -> String {
        let components = color.cgColor.components
        
        if components?.count == 2 {
            let r: CGFloat = components?[0] ?? 0.0
            let g: CGFloat = components?[0] ?? 0.0
            let b: CGFloat = components?[0] ?? 0.0

            let hexString = String.init(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
            //print(hexString)
            return hexString
        } else {
            let r: CGFloat = components?[0] ?? 0.0
            let g: CGFloat = components?[1] ?? 0.0
            let b: CGFloat = components?[2] ?? 0.0

            let hexString = String.init(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
            //print(hexString)
            return hexString
        }
    }
    
    public var rgba: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return (red, green, blue, alpha)
    }
    
    
    public static let sdkDefaultWhiteColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.9)
    public static let sdkDefaultBlackColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.9)
    public static let sdkDefaultOrangeColor = UIColor(red: 252/255, green: 107/255, blue: 63/255, alpha: 1.0)
    public static let sdkDefaultBlueColor = UIColor(red: 23/255, green: 170/255, blue: 223/255, alpha: 1.0)
    public static let sdkDefaultYellowColor = UIColor(red: 251/255, green: 184/255, blue: 0/255, alpha: 1.0)
    public static let sdkDefaultGreenColor = UIColor(red: 94/255, green: 193/255, blue: 105/255, alpha: 1.0)
}


extension String {
    func localizeUI(withComment comment: String? = nil) -> String {
        return NSLocalizedString(self, comment: comment ?? "")
    }
}


extension Int {
    static func parseIntSymbols(from string: String) -> Int? {
        Int(string.components(separatedBy: CharacterSet.decimalDigits.inverted).joined())
    }
}


extension Error {
    var errorCode:Int? {
        return (self as NSError).code
    }
}


extension UIView {
    func fixInView(_ container: UIView!) {
        translatesAutoresizingMaskIntoConstraints = false
        frame = container.frame
        container.addSubview(self)
        NSLayoutConstraint(item: self, attribute: .leading, relatedBy: .equal, toItem: container, attribute: .leading, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .trailing, relatedBy: .equal, toItem: container, attribute: .trailing, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .top, relatedBy: .equal, toItem: container, attribute: .top, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: container, attribute: .bottom, multiplier: 1.0, constant: 0).isActive = true
    }
}


extension NSObject {
    func safeRemoveObserver(_ observer: NSObject, forKeyPath keyPath: String) {
        switch self.observationInfo {
        case .some:
            self.removeObserver(observer, forKeyPath: keyPath)
        default: break
            //debugPrint("SDK Error deleting Observer does not exist")
        }
    }
}
