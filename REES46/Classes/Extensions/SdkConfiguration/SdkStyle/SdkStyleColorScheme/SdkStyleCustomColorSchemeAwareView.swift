import UIKit

public protocol SdkStyleCustomColorSchemeAwareView {
    func applyCustomColorScheme(_ colorScheme: SdkStyleCustomColorScheme)

    var shouldDowncastCustomColorScheme: Bool { get }
}

extension SdkStyleCustomColorSchemeAwareView {
    public var shouldDowncastCustomColorScheme: Bool {
        return false
    }
}

