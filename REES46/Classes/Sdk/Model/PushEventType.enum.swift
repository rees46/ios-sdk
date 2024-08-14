import Foundation
import UIKit

public enum PushEventType: String {
    case web = "web"
    case category = "category"
    case product = "product"
    case carousel = "carousel"
    case custom = "custom"
    
    static func findType(value: String) -> PushEventType? {
        switch value {
        case PushEventType.web.rawValue:
            return .web
        case PushEventType.category.rawValue:
            return .category
        case PushEventType.product.rawValue:
            return .product
        case PushEventType.carousel.rawValue:
            return .carousel
        case PushEventType.custom.rawValue:
            return .custom
        default:
            return nil
        }
    }
}
