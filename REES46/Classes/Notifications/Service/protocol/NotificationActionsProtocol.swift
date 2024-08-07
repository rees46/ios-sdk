import Foundation
import UserNotifications
import UIKit

public protocol NotificationActionsProtocol: AnyObject {
    func openCategory(categoryId: String)
    func openProduct(productId: String)
    func openWeb(url: String)
    func openCustom(url: String)
}
