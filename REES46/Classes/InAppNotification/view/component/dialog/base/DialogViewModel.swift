import UIKit

public class DialogViewModel {
    var titleText: String
    var messageText: String
    var imageUrl: String
    var confirmButtonText: String?
    var dismissButtonText: String?
    var buttonState: ButtonState {
        determineButtonState()
    }
    var isImageContainerHidden: Bool
    var hasButtons: Bool {
        buttonState == .noButtons
    }
    var onConfirmButtonClick: (() -> Void)?
    
    private var hasConfirmButton: Bool { confirmButtonText != nil }
    private var hasDismissButton: Bool { dismissButtonText != nil }
    
    var image: UIImage? = nil
    
    init(
        titleText: String,
        messageText: String,
        imageUrl: String,
        confirmButtonText: String?,
        dismissButtonText: String?,
        onConfirmButtonClick: (() -> Void)?
    ) {
        self.titleText = titleText
        self.messageText = messageText
        self.imageUrl = imageUrl
        self.confirmButtonText = confirmButtonText
        self.dismissButtonText = dismissButtonText
        self.isImageContainerHidden = imageUrl.isEmpty
        self.onConfirmButtonClick = onConfirmButtonClick
    }
    
    func determineButtonState() -> ButtonState {
        switch (hasConfirmButton, hasDismissButton) {
            case (false, false): return .noButtons
            case (false, true): return .onlyDismiss
            case (true, false): return .onlyConfirm
            case (true, true): return .bothButtons
        }
    }
    
    func loadImage(onImageLoaded: @escaping (UIImage) -> Void) {
        guard let url = URL(string: imageUrl) else { return }
        
        DefaultImageLoader().loadImage(from: url) { result in
            switch result {
                case .success(let image):
                    onImageLoaded(image)
                case .failure(let error):
                    self.isImageContainerHidden = true
            }
        }
    }
}
