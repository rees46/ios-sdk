import Foundation

public protocol InAppNotificationProtocol {
    
    func showAlert(viewModel: DialogViewModel)
    
    func showBottomDialog(viewModel: DialogViewModel)
    
    func showFullScreenAlert(
        titleText: String,
        messageText: String,
        imageUrl: String,
        confirmButtonText: String,
        dismissButtonText: String,
        onConfirmButtonClick: @escaping () -> Void
    )
    
    func showTopDialog(viewModel: DialogViewModel)
    
    func showSnackbar(
        message: String,
        buttonAcceptText: String,
        buttonDeclineText: String,
        buttonAcceptAction: @escaping () -> Void,
        buttonDeclineAction: @escaping () -> Void
    )
}
