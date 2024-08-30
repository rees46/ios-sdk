extension Bundle {
    private static var frameworkBundle: Bundle {
        return Bundle(for: BundleToken.self)
    }
    
    static func getLocalizedString(forKey key: String, tableName: String? = nil, value: String? = nil, comment: String = "") -> String {
        return NSLocalizedString(key, tableName: tableName, bundle: frameworkBundle, value: value ?? "", comment: comment)
    }
}

private final class BundleToken {}
