import Foundation

public protocol InAppNotificationProtocol {
    func showAlert(
        title: String,
        message: String,
        buttonText: String,
        buttonAction: @escaping () -> Void
    )
}
