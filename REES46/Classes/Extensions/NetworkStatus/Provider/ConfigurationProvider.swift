import UIKit

enum SdkProviderAbortReason : Int {
    case unknown
    case unableToLoad
    case levelNotFound
    case tagNotFound
}

public protocol SdkProviderProtocol {
    func getBy<T>(tag: String) -> T?
}

public class SdkProvider: NSObject, SdkProviderProtocol {
    
    public static var instance: SdkProvider!
    
    var configurations: NSDictionary?
    var schemeName: String?
    

    public class func shared() -> SdkProvider {
        self.instance = (self.instance ?? SdkProvider())
        
        if (self.instance.configurations == nil) {
            self.instance.getConfigurations()
        }
        
        return self.instance
    }
    
    public func getBy<T>(tag: String) -> T? {
        
        guard let value: T = configurations?.getBy(path: tag) else {
            abortFor(reason: .tagNotFound, details: "Not found: \(tag)")
            return nil
        }
        
        return value
    }
    

    func abortFor(reason: SdkProviderAbortReason, details: String) -> Void {
        let exceptionName: NSExceptionName!
        switch (reason) {
        case .unableToLoad:     exceptionName = NSExceptionName(rawValue: "SdkProvider Error: Unable To Load")
        case .levelNotFound:    exceptionName = NSExceptionName(rawValue: "SdkProvider Error: Level Not Found")
        case .tagNotFound:      exceptionName = NSExceptionName(rawValue: "SdkProvider Error: Tag Not Found")
        default:                exceptionName = NSExceptionName(rawValue: "SdkProvider Error: Unknown error")
        }
        NSException(name: exceptionName, reason: details, userInfo: nil).raise()
    }
    
    
    private func getConfigurations() {
        
        guard let data = openSdkPlist() else {
            return abortFor(reason: .unableToLoad, details: "NetSetup.plist not found!")
        }
        
        if let info = Bundle.main.infoDictionary, let scheme = info["Scheme"] as? String {
            if let schemeConfigurations = data.object(forKey: scheme.replacingOccurrences(of: "\"", with: "")) as? NSDictionary {
                configurations = schemeConfigurations
                schemeName = String(describing: scheme)
            }  else {
                abortFor(reason: .levelNotFound, details: "Scheme level not found: \(schemeName ?? "not scheme")")
            }
        }
        
    }
    
    private func openSdkPlist() -> NSDictionary? {
        var allData: NSDictionary? = nil
        if let path = Bundle.main.path(forResource: "NetSetup", ofType: "plist") {
            let fileURL = URL(fileURLWithPath: path, isDirectory: false)
            allData =  NSDictionary(contentsOf: fileURL)
        }
        return allData
    }
}

public extension NSDictionary {
    
    func getBy<T>(path: String) -> T? {
        let firstPart = path.contains(".") ? String(path[..<path.range(of: ".")!.lowerBound]) : path
        let secondPart = path.contains(".") ? String(path[path.range(of: ".")!.upperBound...]) : ""
        if let dictionary = self.object(forKey: firstPart) as? NSDictionary, secondPart != "" {
            return dictionary.getBy(path: secondPart)
        } else {
            return self.object(forKey: firstPart) as? T
        }
    }
}
