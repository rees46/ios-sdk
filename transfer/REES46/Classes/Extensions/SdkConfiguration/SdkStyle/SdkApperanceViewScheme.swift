import Foundation

public protocol SdkApperanceViewScheme {
    func SdkApperanceViewScheme() -> String
}


extension RawRepresentable where RawValue == String {
    public func SdkApperanceViewScheme() -> String {
        let str = String(describing: type(of: self)) + rawValue
        return str
    }
}
