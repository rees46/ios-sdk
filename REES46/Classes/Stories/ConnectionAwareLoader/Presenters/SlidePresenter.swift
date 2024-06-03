import Foundation
import UIKit

class SlidePresenter {
    private let imageLoader: ImageLoading
    weak var view: SlideView?

    init(imageLoader: ImageLoading) {
        self.imageLoader = imageLoader
    }

    func loadImage(from url: URL) {
        view?.showLoadingIndicator()
        imageLoader.loadImage(from: url) { [weak self] result in
            switch result {
            case .success(let image):
                self?.view?.showImage(image)
            case .failure(let error):
                self?.view?.showError(message: error.localizedDescription)
            }
        }
    }
}
