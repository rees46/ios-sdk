import UIKit

public class NotificationWidget: InAppNotificationProtocol {
    
    private var parentViewController: UIViewController
    private var snackbar: UIView?
    
    public init(parentViewController: UIViewController) {
        self.parentViewController = parentViewController
    }
    
    public func showAlert(
        titleText: String,
        messageText: String,
        imageUrl: String,
        positiveButtonText: String,
        negativeButtonText: String,
        onPositiveButtonClick: @escaping () -> Void,
        onNegativeButtonClick: @escaping () -> Void
    ) {
        let customDialog = AlertDialog()
        customDialog.titleText = titleText
        customDialog.messageText = messageText
        customDialog.imageUrl = imageUrl
        customDialog.positiveButtonText = positiveButtonText
        customDialog.negativeButtonText = negativeButtonText
        customDialog.onPositiveButtonClick = onPositiveButtonClick
        customDialog.onNegativeButtonClick = onNegativeButtonClick

        customDialog.modalPresentationStyle = .overFullScreen
        parentViewController.present(customDialog, animated: true, completion: nil)
    }

    public func showBottomSheet(
        titleText: String,
        messageText: String,
        imageUrl: String,
        positiveButtonText: String,
        negativeButtonText: String?,
        onPositiveButtonClick: @escaping () -> Void,
        onNegativeButtonClick: @escaping () -> Void
    ) {
        let bottomSheet = BottomSheetDialog()
        
        bottomSheet.titleText = titleText
        bottomSheet.messageText = messageText
        bottomSheet.imageUrl = imageUrl
        bottomSheet.positiveButtonText = positiveButtonText
        bottomSheet.negativeButtonText = negativeButtonText
        bottomSheet.onPositiveButtonClick = onPositiveButtonClick
        bottomSheet.onNegativeButtonClick = onNegativeButtonClick

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
