import Foundation
extension Bundle {
    private static var frameworkBundle: Bundle {
#if SWIFT_PACKAGE
        return Bundle.module
#else
        return Bundle(for: BundleToken.self)
#endif
    }
    
    static func getLocalizedString(forKey key: String, tableName: String? = nil, value: String? = nil, comment: String = "") -> String {
        return NSLocalizedString(key, tableName: tableName, bundle: frameworkBundle, value: value ?? "", comment: comment)
    }
}

private final class BundleToken {}
