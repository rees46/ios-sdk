import UIKit

public class NotificationWidget: InAppNotificationProtocol {
    
    private var parentViewController: UIViewController
    private var snackbar: UIView?
    
    public init(parentViewController: UIViewController) {
        self.parentViewController = parentViewController
    }
    
    public func showAlert(
        from parentViewController: UIViewController,
        title: String,
        message: String,
        buttonText: String,
        buttonAction: @escaping () -> Void
    ) {
        let customDialog = CustomAlertDialog()
        customDialog.titleText = "Pizza ipsum dolor meat lovers buffalo."
        customDialog.messageText = "Pizza ipsum dolor meat lovers buffalo. Cheese ranch Philly red marinara ricotta lovers steak NY beef."
        customDialog.imageUrl = "https://mir-s3-cdn-cf.behance.net/projects/404/01d316151239201.Y3JvcCwzMzA0LDI1ODUsMzQzLDA.png"
        customDialog.positiveButtonText = "Accept"
        customDialog.negativeButtonText = "Decline"
        customDialog.onPositiveButtonClick = {
            print("Positive button clicked")
        }
        customDialog.onNegativeButtonClick = {
            print("Negative button clicked")
        }

        customDialog.modalPresentationStyle = .overFullScreen
        parentViewController.present(customDialog, animated: true, completion: nil)
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

    public func showFullScreenAlert(
        title: String,
        message: String,
        imageURL: URL,
        buttonAcceptText: String,
        buttonDeclineText: String,
        buttonAcceptAction: @escaping () -> Void,
        buttonDeclineAction: @escaping () -> Void
    ) {
        let fullScreenAlert = FullScreenAlertViewController(
            title: title,
            message: message,
            imageURL: imageURL,
            acceptButtonText: buttonAcceptText,
            declineButtonText: buttonDeclineText,
            acceptAction: buttonAcceptAction,
            declineAction: buttonDeclineAction
        )

        parentViewController.present(fullScreenAlert, animated: true, completion: nil)
    }

    public func showSnackbar(
        message: String,
        buttonAcceptText: String,
        buttonDeclineText: String,
        buttonAcceptAction: @escaping () -> Void,
        buttonDeclineAction: @escaping () -> Void
    ) {
        let snackbar = UIView()
        snackbar.backgroundColor = .darkGray
        snackbar.layer.cornerRadius = AppDimensions.Size.medium
        snackbar.translatesAutoresizingMaskIntoConstraints = false
        self.snackbar = snackbar

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textColor = .white
        messageLabel.font = UIFont.systemFont(ofSize: AppDimensions.FontSize.medium)
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        snackbar.addSubview(messageLabel)

        let acceptButton = UIButton(type: .system)
        acceptButton.setTitle(buttonAcceptText, for: .normal)
        acceptButton.setTitleColor(.green, for: .normal)
        acceptButton.translatesAutoresizingMaskIntoConstraints = false
        acceptButton.addTarget(self, action: #selector(acceptButtonTapped), for: .touchUpInside)
        snackbar.addSubview(acceptButton)

        let declineButton = UIButton(type: .system)
        declineButton.setTitle(buttonDeclineText, for: .normal)
        declineButton.setTitleColor(.red, for: .normal)
        declineButton.translatesAutoresizingMaskIntoConstraints = false
        declineButton.addTarget(self, action: #selector(declineButtonTapped), for: .touchUpInside)
        snackbar.addSubview(declineButton)

        parentViewController.view.addSubview(snackbar)

        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: snackbar.leadingAnchor, constant: AppDimensions.Padding.medium),
            messageLabel.centerYAnchor.constraint(equalTo: snackbar.centerYAnchor),

            declineButton.trailingAnchor.constraint(equalTo: snackbar.trailingAnchor, constant: -AppDimensions.Padding.medium),
            declineButton.centerYAnchor.constraint(equalTo: snackbar.centerYAnchor),
            declineButton.leadingAnchor.constraint(equalTo: acceptButton.trailingAnchor, constant: AppDimensions.Padding.small),

            acceptButton.trailingAnchor.constraint(equalTo: declineButton.leadingAnchor, constant: -AppDimensions.Padding.small),
            acceptButton.centerYAnchor.constraint(equalTo: snackbar.centerYAnchor),

            snackbar.leadingAnchor.constraint(equalTo: parentViewController.view.leadingAnchor, constant: AppDimensions.Padding.large),
            snackbar.trailingAnchor.constraint(equalTo: parentViewController.view.trailingAnchor, constant: -AppDimensions.Padding.large),
            snackbar.bottomAnchor.constraint(equalTo: parentViewController.view.bottomAnchor, constant: -AppDimensions.Padding.large),
            snackbar.heightAnchor.constraint(equalToConstant: AppDimensions.Height.snackbar)
        ])

        snackbar.transform = CGAffineTransform(translationX: 0, y: AppDimensions.Animation.snackbarTranslationY)
        UIView.animate(withDuration: AppDimensions.Animation.duration) {
            snackbar.transform = .identity
        }
    }

    @objc private func acceptButtonTapped() {
        guard let snackbar = snackbar else { return }
        dismissSnackbar(snackbar)
    }

    @objc private func declineButtonTapped() {
        guard let snackbar = snackbar else { return }
        dismissSnackbar(snackbar)
    }

    private func dismissSnackbar(_ snackbar: UIView) {
        UIView.animate(withDuration: AppDimensions.Animation.duration, animations: {
            snackbar.transform = CGAffineTransform(translationX: 0, y: AppDimensions.Animation.snackbarTranslationY)
        }) { _ in
            snackbar.removeFromSuperview()
            self.snackbar = nil
        }
    }
}