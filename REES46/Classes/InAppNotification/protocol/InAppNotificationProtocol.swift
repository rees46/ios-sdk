import Foundation

public protocol InAppNotificationProtocol {
    
    func showAlert(
        title: String,
        message: String,
        buttonText: String,
        buttonAction: @escaping () -> Void
    )
    
    func showBottomSheet(
        title: String,
        message: String,
        buttonAcceptText: String,
        buttonDeclineText: String,
        buttonAcceptAction: @escaping () -> Void,
        buttonDeclineAction: @escaping () -> Void
    )
    
    func showFullScreenAlert(
        title: String,
        message: String,
        imageURL: URL,
        buttonAcceptText: String,
        buttonDeclineText: String,
        buttonAcceptAction: @escaping () -> Void,
        buttonDeclineAction: @escaping () -> Void
    )
    
    func showSnackbar(
        message: String,
        buttonAcceptText: String,
        buttonDeclineText: String,
        buttonAcceptAction: @escaping () -> Void,
        buttonDeclineAction: @escaping () -> Void
    )
}
