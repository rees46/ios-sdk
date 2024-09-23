import UIKit

public protocol InAppNotificationProtocol {
    func showAlert(
        title: String,
        message: String,
        buttonText: String,
        buttonAction: @escaping () -> Void
    )
}

class NotificationWidget: InAppNotificationProtocol {
    
    private var parentViewController: UIViewController

    init(parentViewController: UIViewController) {
        self.parentViewController = parentViewController
    }
    
    func showAlert(
        title: String,
        message: String,
        buttonText: String,
        buttonAction: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: buttonText, style: .default) { _ in
            buttonAction()
        }
        alert.addAction(action)
        parentViewController.present(alert, animated: true, completion: nil)
    }
    
}
