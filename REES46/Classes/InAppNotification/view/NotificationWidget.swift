import UIKit

public class NotificationWidget: InAppNotificationProtocol {
    private var parentViewController: UIViewController
    private var snackbar: UIView?
    private var popup: Popup?
    
    public init(
        parentViewController: UIViewController,
        popup: Popup? = nil
    ) {
        self.parentViewController = parentViewController
        self.popup = popup
        
        if let popup = popup {
            showPopup(popup)
        }
    }
    
    private func showPopup(_ popup: Popup) {
        let position: Popup.Position = Popup.Position(rawValue: popup.position) ?? .centered
        let baseTitle: String = NSLocalizedString("alert_dialog_title", comment:  "")
        let baseSubTitle: String = NSLocalizedString("alert_dialog_message", comment:  "")
        
        var buttonConfirmText: String?
        var buttonDismissText: String?
        var confirmLink: String?
        var buttonPushPermissions: String?
        
        if let actions = popup.getParsedPopupActions() {
            buttonConfirmText = actions.link?.button_text
            buttonDismissText = actions.close?.button_text
            buttonPushPermissions = actions.system_mobile_push_subscribe?.button_text
            confirmLink = actions.link?.link_ios ?? actions.link?.link_android ?? actions.link?.link_web
        }
        
        let (header, text) = popup.extractTitleAndSubtitle()
        
        let imageUrl = popup.components?.image
        let title = popup.components?.header ?? header
        let subTitle = popup.components?.text ?? text
        
        if title != nil && subTitle != nil {
            
            let confirmAction: () -> Void
            let confirmText: String?
            
            if let pushPermissionsText = buttonPushPermissions {
                confirmText = pushPermissionsText
                confirmAction = { [weak self] in
                    self?.navigateToPushSettings()
                }
            } else {
                confirmText = buttonConfirmText
                confirmAction = { [weak self] in
                    self?.handleConfirmButtonClick(link: confirmLink)
                }
            }
            
            let viewModel = DialogViewModel(
                titleText: title ?? baseTitle,
                messageText: subTitle ?? baseSubTitle,
                imageUrl: imageUrl ?? "",
                confirmButtonText: confirmText,
                dismissButtonText: buttonDismissText,
                onConfirmButtonClick: confirmAction
            )
            
            switch position {
                case .centered:
                    showAlert(viewModel: viewModel)
                case .bottom:
                    showBottomDialog(viewModel: viewModel)
                case .top:
                    showTopDialog(viewModel: viewModel)
            }
        }
    }
    
    
    public func showAlert(viewModel: DialogViewModel) {
        let dialog = AlertDialog(viewModel: viewModel)
        dialog.modalPresentationStyle = .overFullScreen
        parentViewController.present(dialog, animated: true, completion: nil)
    }
    
    public func showBottomDialog(viewModel: DialogViewModel) {
        let dialog = BottomDialog(viewModel: viewModel)
        parentViewController.present(dialog, animated: true, completion: nil)
    }
    
    public func showTopDialog(viewModel: DialogViewModel) {
        let dialog = TopDialog(viewModel: viewModel)
        dialog.modalPresentationStyle = .overFullScreen
        parentViewController.present(dialog, animated: true, completion: nil)
    }
    
    public func showFullScreenAlert(
        titleText: String,
        messageText: String,
        imageUrl: String,
        confirmButtonText: String,
        dismissButtonText: String,
        onConfirmButtonClick: @escaping () -> Void
    ) {
        let dialog = FullScreenDialog()
        dialog.titleText = titleText
        dialog.messageText = messageText
        dialog.imageUrl = imageUrl
        dialog.confirmButtonText = confirmButtonText
        dialog.dismissButtonText = dismissButtonText
        dialog.onConfirmButtonClick = {
            onConfirmButtonClick()
            dialog.dismiss(animated: true)
        }
        dialog.onDismissButtonClick = {
            dialog.dismiss(animated: true)
        }
        
        parentViewController.present(dialog, animated: true, completion: nil)
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
    
    private func handleConfirmButtonClick(link: String?) {
        if let urlString = link, let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    print("Link opened: \(urlString)")
                } else {
                    print("Unable to open link: \(urlString)")
                }
            }
        } else {
            print("Link missing or invalid")
        }
    }
    
    private func navigateToPushSettings() {
        if let appSettingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(appSettingsURL, options: [:], completionHandler: nil)
        }
    }
}
