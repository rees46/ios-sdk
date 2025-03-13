import UIKit

class AlertDialog: UIViewController {
    
    private let backgroundImageView = DialogImageVeiw()
    private let contentView = UIView()
    private let contentContainer = UIView()
    private let imageContainer = UIView()
    private let closeButton = DialogButtonClose()
    private let titleLabel: DialogText
    private let messageLabel: DialogText
    private let confirmButton: DialogActionButton
    private let dismissButton: DialogActionButton
    
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
        view.backgroundColor = AppColors.Background.alertDimmed
        setupContentView()
        setupImageContainer()
        setupButtons()
        layoutUI()

        if(confirmButtonText == nil && dismissButtonText == nil) {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissDialog))
            tapGesture.cancelsTouchesInView = false
            view.addGestureRecognizer(tapGesture)
        }
    }
    
    private func setupContentView() {
        contentView.backgroundColor = AppColors.Background.contentView
        contentView.layer.cornerRadius = AppDimensions.Padding.medium
        contentView.clipsToBounds = true
        view.addSubview(contentView)
    }
    
    private func setupImageContainer() {
        contentView.addSubview(imageContainer)
        imageContainer.addSubview(backgroundImageView)
        imageContainer.addSubview(closeButton)
    }
    
    private func setupButtons() {
        contentContainer.backgroundColor = AppColors.Background.contentView
        contentContainer.layer.cornerRadius = AppDimensions.Padding.medium
        contentContainer.clipsToBounds = true
        
        contentContainer.addSubview(titleLabel)
        contentContainer.addSubview(messageLabel)
        contentContainer.addSubview(confirmButton)
        contentContainer.addSubview(dismissButton)
        contentView.addSubview(contentContainer)
        
        confirmButton.addTarget(self, action: #selector(onAcceptButtonTapped), for: .touchUpInside)
        dismissButton.addTarget(self, action: #selector(onDeclineButtonTapped), for: .touchUpInside)
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
        
        applyContraints()
    }
    
    
    
    @objc private func onAcceptButtonTapped() {
        onConfirmButtonClick?()
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func onDeclineButtonTapped() {
        onDismissButtonClick?()
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func dismissDialog() {
        dismiss(animated: true, completion: nil)
    }
}

extension AlertDialog {
    func applyContraints() {
        setContentViewConstraints()
        setImageContainerConstraints()
        setBackgroundImageViewConstraints()
        setContentContainerConstraints()
        setCloseButtonConstraints()
        setTitleLabelConstraints()
        setMessageLabelConstraints()
        setButtonConstraints(buttonState: determineState())
    }
    
    private func setContentViewConstraints() {
        NSLayoutConstraint.activate([
            contentView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppDimensions.Padding.large),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppDimensions.Padding.large)
        ])
    }
    
    private func setImageContainerConstraints() {
        if imageUrl.isEmpty {
            NSLayoutConstraint.activate([
                imageContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
                imageContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                imageContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                imageContainer.heightAnchor.constraint(equalToConstant: 0)
            ])
        } else {
            NSLayoutConstraint.activate([
                imageContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
                imageContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                imageContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                imageContainer.heightAnchor.constraint(equalToConstant: AppDimensions.Size.alertPopUpHeight)
            ])
        }
    }
    
    private func setBackgroundImageViewConstraints() {
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor)
        ])
    }
    
    private func setContentContainerConstraints() {
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: imageContainer.isHidden ? contentView.topAnchor : imageContainer.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            contentContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: AppDimensions.Size.alertPopUpHeight)
        ])
    }
    
    private func setCloseButtonConstraints() {
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: imageContainer.topAnchor, constant: AppDimensions.Padding.small),
            closeButton.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor, constant: -AppDimensions.Padding.small),
            closeButton.widthAnchor.constraint(equalToConstant: AppDimensions.Size.closeButtonSize),
            closeButton.heightAnchor.constraint(equalToConstant: AppDimensions.Size.closeButtonSize)
        ])
    }
    
    private func setTitleLabelConstraints() {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: AppDimensions.Padding.medium),
            titleLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: AppDimensions.Padding.medium),
            titleLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -AppDimensions.Padding.medium)
        ])
    }
    
    private func setMessageLabelConstraints() {
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppDimensions.Padding.small),
            messageLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: AppDimensions.Padding.medium),
            messageLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -AppDimensions.Padding.medium)
        ])
    }
    
    private func setButtonConstraints(buttonState: ButtonState) {
        let commonConstraints = { [self] (button: UIButton, topAnchor: NSLayoutYAxisAnchor, bottomAnchor: NSLayoutYAxisAnchor?) in
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: topAnchor, constant: AppDimensions.Padding.medium),
                button.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: AppDimensions.Padding.medium),
                button.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -AppDimensions.Padding.medium),
                button.heightAnchor.constraint(equalToConstant: AppDimensions.Height.popUpButton)
            ])
            
            if let bottomAnchor = bottomAnchor {
                button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -AppDimensions.Padding.medium).isActive = true
            }
        }
        
        switch(buttonState) {
            case .noButtons:
                messageLabel.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -AppDimensions.Padding.medium).isActive = true
            case .onlyAccept:
                commonConstraints(dismissButton, messageLabel.bottomAnchor, contentContainer.bottomAnchor)
            case .onlyDecline:
                commonConstraints(confirmButton, messageLabel.bottomAnchor, contentContainer.bottomAnchor)
            case .bothButtons:
                NSLayoutConstraint.activate([
                    dismissButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: AppDimensions.Padding.medium),
                    dismissButton.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: AppDimensions.Padding.medium),
                    dismissButton.trailingAnchor.constraint(equalTo: contentContainer.centerXAnchor, constant: -AppDimensions.Padding.small),
                    dismissButton.heightAnchor.constraint(equalToConstant: AppDimensions.Height.popUpButton),
                
                    confirmButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: AppDimensions.Padding.medium),
                    confirmButton.leadingAnchor.constraint(equalTo: contentContainer.centerXAnchor, constant: AppDimensions.Padding.small),
                    confirmButton.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -AppDimensions.Padding.medium),
                    confirmButton.heightAnchor.constraint(equalToConstant: AppDimensions.Height.popUpButton),
                    confirmButton.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -AppDimensions.Padding.medium)
                ])
        }
    }
    
    private func determineState() -> ButtonState {
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
}
