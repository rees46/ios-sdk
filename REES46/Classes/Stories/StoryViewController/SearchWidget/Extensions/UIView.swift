import Foundation
import UIKit

extension UIView {
    var viewController: UIViewController? {
        var view: UIView? = self
        while let next = view?.next {
            if let viewController = next as? UIViewController {
                return viewController
            }
            view = next as? UIView
        }
        return nil
    }
}
