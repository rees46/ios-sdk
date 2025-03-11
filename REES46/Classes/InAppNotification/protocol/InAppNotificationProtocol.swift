import Foundation

public protocol InAppNotificationProtocol {
    
    func showAlert(
        titleText: String,
        messageText: String,
        imageUrl: String,
        positiveButtonText: String?,
        negativeButtonText: String?,
        onPositiveButtonClick: @escaping () -> Void
    )
    
    func showBottomSheet(
        titleText: String,
        messageText: String,
        imageUrl: String,
        positiveButtonText: String?,
        negativeButtonText: String?,
        onPositiveButtonClick: @escaping () -> Void
    )
    
    func showFullScreenAlert(
        titleText: String,
        messageText: String,
        imageUrl: String,
        positiveButtonText: String,
        negativeButtonText: String,
        onPositiveButtonClick: @escaping () -> Void
    )
    
    func showSnackbar(
        message: String,
        buttonAcceptText: String,
        buttonDeclineText: String,
        buttonAcceptAction: @escaping () -> Void,
        buttonDeclineAction: @escaping () -> Void
    )
}
