import Foundation
import UIKit

public class SlidePresenter {
    
    weak var view: SlideView?
    private var currentURL: URL?
    private var reloadTimer: Timer?
    private let imageLoader: ImageLoadingProtocol
    
    init(imageLoader: ImageLoadingProtocol) {
        self.imageLoader = imageLoader
    }
    
    func loadImage(from url: URL) {
        currentURL = url
        view?.showLoadingIndicator()
        startLoadingTimeout()
        
        imageLoader.loadImage(from: url) { [weak self] result in
            guard let self = self else { return }
            self.reloadTimer?.invalidate()
            
            switch result {
            case .success(let image):
                self.view?.showImage(image)
            case .failure(let error):
                self.view?.showError()
                self.view?.showReloadButton()
            }
        }
    }
    
    private func startLoadingTimeout() {
        reloadTimer = Timer.scheduledTimer(withTimeInterval: SlideViewController.Constants.loadingTimeout, repeats: false) { [weak self] _ in
            self?.view?.showReloadButton()
        }
    }
    
    func reloadImage() {
        if let url = currentURL {
            loadImage(from: url)
        }
    }
}
