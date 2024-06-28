import UIKit

protocol SlideView: AnyObject {
    func showLoadingIndicator()
    func hideLoadingIndicator()
    func showImage(_ image: UIImage)
    func showError()
    func showReloadButton()
}
