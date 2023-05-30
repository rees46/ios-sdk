import UIKit

enum UcpAbortReason : Int {
    case unknown
    case unableToLoad
    case invalidURL
    case tagNotFound
    case levelNotFound
    case domainNotFound
}

public class Ucp: NSObject {
    
    public static var instance: Ucp!
    
    public class func shared() -> Ucp {
        self.instance = (self.instance ?? Ucp())
        
        return self.instance
    }
    
    public class func urlBy(
        tag: String,
        replacements: NSDictionary? = nil,
        hasDomain: Bool = false,
        bundle: Bundle = .main
    ) -> URL? {
        if let url = urlStringBy(tag: tag, replacements: replacements, hasDomain: hasDomain, bundle: bundle) {
            return URL(string: url)
        }
        
        return nil
    }
    
    public class func urlStringBy(
        tag: String,
        replacements: NSDictionary? = nil,
        hasDomain: Bool = false,
        bundle: Bundle = .main
    ) -> String? {
        return Ucp.shared().urlStringBy(tag: tag, replacements: replacements, hasDomain: hasDomain, bundle: bundle)
    }
    
    private func urlStringBy(
        tag: String,
        replacements: NSDictionary?,
        hasDomain: Bool,
        bundle: Bundle = .main
    ) -> String? {
        
        guard let endpoints: NSDictionary = SdkProvider.shared().getBy(tag: "endpoints", bundle: bundle) else {
            abortFor(reason: .tagNotFound, details: "Tag not found: \(tag)")
            return nil
        }
        
        guard var urlString: String = endpoints.getBy(path: tag) else {
            abortFor(reason: .tagNotFound, details: "Tag not found: \(tag)")
            return nil
        }
        
        if hasDomain {
            guard let domain: String = SdkProvider.shared().getBy(tag: "domain", bundle: bundle) else {
                abortFor(reason: .domainNotFound, details: "Domain not found")
                return nil
            }
            
            urlString = String(format: "%@%@", domain, urlString)
        }
        
        if let keys = replacements?.allKeys {
            for key in keys {
                let pathKey = "{\(key)}"
                let pathValue = replacements?.object(forKey: key) as! String
                urlString = urlString.replacingOccurrences(of: pathKey, with: pathValue)
            }
        }
            
        urlString = urlString.replacingOccurrences(of: "${bundle}", with: bundle.bundleURL.absoluteString)
        
        guard let url = NSURL(string: urlString) else {
            abortFor(reason: .invalidURL, details: "Unable to convert URL: \(urlString)")
            return nil
        }
        
        return url.absoluteString
    }
    
    private func abortFor(reason: UcpAbortReason, details: String) -> Void {
        let exceptionName: NSExceptionName!
        switch (reason) {
        case .unableToLoad:     exceptionName = NSExceptionName(rawValue: "Ucp Error: Unable To Load")
        case .levelNotFound:    exceptionName = NSExceptionName(rawValue: "Ucp Error: Level Not Found")
        case .tagNotFound:      exceptionName = NSExceptionName(rawValue: "Ucp Error: Tag Not Found")
        case .invalidURL:       exceptionName = NSExceptionName(rawValue: "Ucp Error: Invalid URL")
        case .domainNotFound:   exceptionName = NSExceptionName(rawValue: "Ucp Error: Invalid Domain")
        default:                exceptionName = NSExceptionName(rawValue: "CP Error: Unknown error")
        }
        NSException(name: exceptionName, reason: details, userInfo: nil).raise()
    }
    
}
