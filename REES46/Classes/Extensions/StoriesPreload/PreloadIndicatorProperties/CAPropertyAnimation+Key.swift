import UIKit

extension CAPropertyAnimation {
    enum Key: String {
        var path: String {
            return rawValue
        }

        case flatStart = "strokeStart"
        case flatEnd = "strokeEnd"
        case flatColor = "strokeColor"
        case rotationZ = "transform.rotation.z"
        case scale = "transform.scale"
    }

    convenience init(key: Key) {
        self.init(keyPath: key.path)
    }
}
