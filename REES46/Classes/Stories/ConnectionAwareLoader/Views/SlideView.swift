import UIKit

protocol SlideView: AnyObject {
    func showLoadingIndicator()
    func showImage(_ image: UIImage)
    func showError(message: String)
}
