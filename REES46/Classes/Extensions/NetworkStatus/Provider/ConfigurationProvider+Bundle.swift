import Foundation

public extension SdkProvider {

    func getBy<T>(tag: String, bundle: Bundle) -> T? {
        let configuration = getConfigurations(for: bundle)
        guard let value: T = configuration?.getBy(path: tag) else {
            abortFor(reason: .tagNotFound, details: "Tag not found: \(tag)")
            return nil
        }
        return value
    }
}

private extension SdkProvider {
    func getConfigurations(for bundle: Bundle) -> NSDictionary? {
        guard let data = openSdkPlist(with: bundle) else {
            abortFor(reason: .unableToLoad, details: "NetSetup.plist not found!")
            return nil
        }
        
        if let info = Bundle.main.infoDictionary, let scheme = info["Scheme"] as? String {
            if let schemeConfigurations = data.object(forKey: scheme.replacingOccurrences(of: "\"", with: "")) as? NSDictionary {
                return schemeConfigurations
            }  else {
                abortFor(reason: .levelNotFound, details: "Scheme  not found: \(schemeName ?? "not scheme")")
            }
        }
        return nil
    }
    
    func openSdkPlist(with bundle: Bundle) -> NSDictionary? {
        var allData: NSDictionary? = nil
        if let path = bundle.path(forResource: "NetSetup", ofType: "plist") {
            let fileURL = URL(fileURLWithPath: path, isDirectory: false)
            allData = NSDictionary(contentsOf: fileURL)
        }
        return allData
    }
}
