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

            switch position {
                case .centered:
                    showAlert(
                        titleText: title ?? baseTitle,
                        messageText: subTitle ?? baseSubTitle,
                        imageUrl: imageUrl ?? "",
                        confirmButtonText: confirmText,
                        dismissButtonText: buttonDismissText,
                        onConfirmButtonClick: confirmAction
                    )
                case .bottom:
                    showBottomDialog(
                        titleText: title ?? baseTitle,
                        messageText: subTitle ?? baseSubTitle,
                        imageUrl: imageUrl ?? "",
                        confirmButtonText: confirmText,
                        dismissButtonText: buttonDismissText,
                        onConfirmButtonClick: confirmAction
                    )
                case .top:
                    showTopDialog(
                        titleText: title ?? baseTitle,
                        messageText: subTitle ?? baseSubTitle,
                        imageUrl: imageUrl ?? "",
                        confirmButtonText: confirmText,
                        dismissButtonText: buttonDismissText,
                        onConfirmButtonClick: confirmAction
                    )
            }
        }
    }
    
    public func showAlert(
        titleText: String,
        messageText: String,
        imageUrl: String = "",
        confirmButtonText: String? = nil,
        dismissButtonText: String? = nil,
        onConfirmButtonClick: (() -> Void)? = nil
    ) {
        let viewModel = DialogViewModel(
            titleText: titleText,
            messageText: messageText,
            imageUrl: imageUrl,
            confirmButtonText: confirmButtonText,
            dismissButtonText: dismissButtonText,
            onConfirmButtonClick: onConfirmButtonClick
        )
        let dialog = AlertDialog(viewModel: viewModel)
        dialog.modalPresentationStyle = .overFullScreen
        parentViewController.present(dialog, animated: true, completion: nil)
    }
    
    public func showBottomDialog(
        titleText: String,
        messageText: String,
        imageUrl: String = "",
        confirmButtonText: String? = nil,
        dismissButtonText: String? = nil,
        onConfirmButtonClick: (() -> Void)? = nil
    ) {
        let viewModel = DialogViewModel(
            titleText: titleText,
            messageText: messageText,
            imageUrl: imageUrl,
            confirmButtonText: confirmButtonText,
            dismissButtonText: dismissButtonText,
            onConfirmButtonClick: onConfirmButtonClick
        )
        let dialog = BottomDialog(viewModel: viewModel)
        parentViewController.present(dialog, animated: true, completion: nil)
    }
    
    public func showTopDialog(
        titleText: String,
        messageText: String,
        imageUrl: String = "",
        confirmButtonText: String? = nil,
        dismissButtonText: String? = nil,
        onConfirmButtonClick: (() -> Void)? = nil
    ) {
        let viewModel = DialogViewModel(
            titleText: titleText,
            messageText: messageText,
            imageUrl: imageUrl,
            confirmButtonText: confirmButtonText,
            dismissButtonText: dismissButtonText,
            onConfirmButtonClick: onConfirmButtonClick
        )
        let dialog = TopDialog(viewModel: viewModel)
        dialog.modalPresentationStyle = .overFullScreen
        parentViewController.present(dialog, animated: true, completion: nil)
    }
    
    private func handleConfirmButtonClick(link: String?) {
        if let urlString = link, let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                self.logLinkOpeningResult(success: success, urlString: urlString)
            }
        } else {
            self.logLinkOpeningResult(success: false, urlString: link)
        }
    }

    private func logLinkOpeningResult(success: Bool, urlString: String?) {
        if success {
            print("Link opened: \(urlString ?? "unknown")")
        } else {
            print("Unable to open link: \(urlString ?? "unknown")")
        }
    }
    
    private func navigateToPushSettings() {
        if let appSettingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(appSettingsURL, options: [:], completionHandler: nil)
        }
    }
}
