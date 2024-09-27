import UIKit

public class NotificationWidget: InAppNotificationProtocol {

    private var parentViewController: UIViewController

    public init(parentViewController: UIViewController) {
        self.parentViewController = parentViewController
    }

    public func showAlert(
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

    public func showBottomSheet(
        title: String,
        message: String,
        buttonAcceptText: String,
        buttonDeclineText: String,
        buttonAcceptAction: @escaping () -> Void,
        buttonDeclineAction: @escaping () -> Void
    ) {
        let bottomSheet = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)

        let acceptAction = UIAlertAction(title: buttonAcceptText, style: .default) { _ in
            buttonAcceptAction()
        }
        let declineAction = UIAlertAction(title: buttonDeclineText, style: .destructive) { _ in
            buttonDeclineAction()
        }

        bottomSheet.addAction(acceptAction)
        bottomSheet.addAction(declineAction)

        if let popoverController = bottomSheet.popoverPresentationController {
            popoverController.sourceView = parentViewController.view
            popoverController.sourceRect = CGRect(
                x: parentViewController.view.bounds.midX,
                y: parentViewController.view.bounds.midY,
                width: 0, height: 0
            )
            popoverController.permittedArrowDirections = []
        }

        parentViewController.present(bottomSheet, animated: true, completion: nil)
    }
}
