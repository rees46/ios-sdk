import Foundation
import UIKit

public struct SdkImageReloader<Base> {

    let base: Base
    init(_ base: Base) {
        self.base = base
    }
}

public protocol SdkImageReloaderCompatible {
    associatedtype CompatibleType
    var load: SdkImageReloader<CompatibleType> { get }
}


extension SdkImageReloaderCompatible {

    public var load: SdkImageReloader<Self> {
        return SdkImageReloader(self)
    }
}


extension UIImageView: SdkImageReloaderCompatible {}
