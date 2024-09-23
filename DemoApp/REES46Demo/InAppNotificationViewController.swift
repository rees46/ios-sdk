import Foundation

class InAppNotificationViewController: UIViewController, InAppNotificationProtocol {

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

        self.present(alert, animated: true, completion: nil)
    }
}
