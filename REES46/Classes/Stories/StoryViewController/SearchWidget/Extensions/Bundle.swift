import Foundation

extension Bundle {
    func getLocalizedString(forKey key: String, tableName: String? = nil, value: String? = nil, comment: String = "") -> String {
        return NSLocalizedString(key, tableName: tableName, bundle: self, value: value ?? "", comment: comment)
    }
}
