import Foundation

public protocol InAppNotificationProtocol {
    
    func showAlert(
        titleText: String,
        messageText: String,
        imageUrl: String,
        confirmButtonText: String?,
        dismissButtonText: String?,
        onConfirmButtonClick: @escaping () -> Void
    )
    
    func showBottomSheet(
        titleText: String,
        messageText: String,
        imageUrl: String,
        confirmButtonText: String?,
        dismissButtonText: String?,
        onConfirmButtonClick: @escaping () -> Void
    )
    
    func showFullScreenAlert(
        titleText: String,
        messageText: String,
        imageUrl: String,
        confirmButtonText: String,
        dismissButtonText: String,
        onConfirmButtonClick: @escaping () -> Void
    )
    
    func showTopDialog(
        titleText: String,
        messageText: String,
        imageUrl: String,
        confirmButtonText: String?,
        dismissButtonText: String?,
        onConfirmButtonClick: @escaping () -> Void
    )
    
    func showSnackbar(
        message: String,
        buttonAcceptText: String,
        buttonDeclineText: String,
        buttonAcceptAction: @escaping () -> Void,
        buttonDeclineAction: @escaping () -> Void
    )
}
