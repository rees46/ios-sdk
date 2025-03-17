import Foundation

public protocol InAppNotificationProtocol {
    
    func showAlert(
        titleText: String,
        messageText: String,
        imageUrl: String,
        confirmButtonText: String?,
        dismissButtonText: String?,
        onConfirmButtonClick: (() -> Void)?
    )
    
    func showBottomDialog(
        titleText: String,
        messageText: String,
        imageUrl: String,
        confirmButtonText: String?,
        dismissButtonText: String?,
        onConfirmButtonClick: (() -> Void)?
    )
    
    func showTopDialog(
        titleText: String,
        messageText: String,
        imageUrl: String,
        confirmButtonText: String?,
        dismissButtonText: String?,
        onConfirmButtonClick: (() -> Void)?
    )
}
