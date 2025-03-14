import UIKit

class BaseDialog: UIViewController {
    
    let backgroundImageView = DialogImageVeiw()
    let contentView = UIView()
    let contentContainer = UIView()
    let imageContainer = UIView()
    let closeButton = DialogButtonClose()
    let titleLabel: DialogText
    let messageLabel: DialogText
    let confirmButton: DialogActionButton
    let dismissButton: DialogActionButton
    
    var titleText: String = ""
    var messageText: String = ""
    var imageUrl: String = ""
    var confirmButtonText: String?
    var dismissButtonText: String?
    var confirmButtonColor: UIColor = AppColors.Background.buttonPositive
    var dismissButtonColor: UIColor = AppColors.Background.buttonNegative
    
    var onConfirmButtonClick: (() -> Void)?
    var onDismissButtonClick: (() -> Void)?
    
    init() {
        titleLabel = DialogText(text: "", fontSize: AppDimensions.FontSize.large, isBold: true)
        messageLabel = DialogText(text: "", fontSize: AppDimensions.FontSize.medium)
        confirmButton = DialogActionButton(title: "", backgroundColor: confirmButtonColor)
        dismissButton = DialogActionButton(title: "", backgroundColor: dismissButtonColor)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = titleText
        messageLabel.text = messageText
        
        if let confirmText = confirmButtonText, !confirmText.isEmpty {
            confirmButton.setTitle(confirmText, for: .normal)
            confirmButton.backgroundColor = confirmButtonColor
        } else {
            confirmButton.isHidden = true
        }
        
        if let dismissText = dismissButtonText, !dismissText.isEmpty {
            dismissButton.setTitle(dismissText, for: .normal)
            dismissButton.backgroundColor = dismissButtonColor
        } else {
            dismissButton.isHidden = true
        }
        
        setupUI()
        backgroundImageView.loadImage(from: imageUrl)
    }
    
    private func setupUI() {
        let state = determineButtonState()
        setupContentView()
        setupImageContainer()
        setupButtons()
        layoutUI()
        applyConstraints(buttonState: state)
        addDismissTapGesture(hasButtons: state.self == .noButtons)
    }
    
    func setupContentView() {
        contentView.backgroundColor = AppColors.Background.contentView
        contentView.clipsToBounds = true
        view.addSubview(contentView)
    }
    
    private func setupImageContainer() {
        contentView.addSubview(imageContainer)
        imageContainer.addSubview(backgroundImageView)
        imageContainer.addSubview(closeButton)
        imageContainer.isHidden = imageUrl.isEmpty
    }
    
    private func setupButtons() {
        contentContainer.backgroundColor = AppColors.Background.contentView
        contentContainer.clipsToBounds = true
        
        contentContainer.addSubview(titleLabel)
        contentContainer.addSubview(messageLabel)
        contentContainer.addSubview(confirmButton)
        contentContainer.addSubview(dismissButton)
        contentView.addSubview(contentContainer)
        
        confirmButton.addTarget(self, action: #selector(onConfirmButtonTapped), for: .touchUpInside)
        dismissButton.addTarget(self, action: #selector(onDismissButtonTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(dismissDialog), for: .touchUpInside)
    }
    
    private func layoutUI() {
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        imageContainer.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func determineButtonState() -> ButtonState {
        if confirmButton.isHidden && dismissButton.isHidden {
            return .noButtons
        } else if confirmButton.isHidden {
            return .onlyDecline
        } else if dismissButton.isHidden {
            return .onlyAccept
        } else {
            return .bothButtons
        }
    }
    
    private func addDismissTapGesture(hasButtons: Bool) {
        if(hasButtons) {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissDialog))
            view.addGestureRecognizer(tapGesture)
        }
    }
    
    internal func setContentViewConstraints() {
        fatalError("Must be overridden in subclass")
    }
    
    internal func setContentContainerConstraints() {
        fatalError("Must be overridden in subclass")
    }
    
    @objc internal func dismissDialog() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func onConfirmButtonTapped() {
        onConfirmButtonClick?()
        dismiss(animated: true, completion: nil)
    }
    
    @objc func onDismissButtonTapped() {
        onDismissButtonClick?()
        dismissDialog()
    }
}
