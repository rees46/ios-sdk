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
    var onConfirmButtonClick: () -> Void
    
    private var hasConfirmButton: Bool { confirmButtonText != nil }
    private var hasDismissButton: Bool { dismissButtonText != nil }
    
    init(
        titleText: String,
        messageText: String,
        imageUrl: String,
        confirmButtonText: String?,
        dismissButtonText: String?,
        onConfirmButtonClick: @escaping () -> Void
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
}
