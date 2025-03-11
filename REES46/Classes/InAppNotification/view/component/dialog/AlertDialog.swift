import UIKit

class AlertDialog: UIViewController {
    
    private let backgroundImageView = DialogImageVeiw()
    private let contentView = UIView()
    private let contentContainer = UIView()
    private let imageContainer = UIView()
    private let closeButton = DialogButtonClose()
    private let titleLabel: DialogText
    private let messageLabel: DialogText
    private let acceptButton: DialogActionButton
    private let declineButton: DialogActionButton
    
    var titleText: String = ""
    var messageText: String = ""
    var imageUrl: String = ""
    var positiveButtonText: String?
    var negativeButtonText: String?
    var positiveButtonColor: UIColor = AppColors.Background.buttonPositive
    var negativeButtonColor: UIColor = AppColors.Background.buttonNegative
    
    var onPositiveButtonClick: (() -> Void)?
    var onNegativeButtonClick: (() -> Void)?
    
    init() {
        titleLabel = DialogText(text: "", fontSize: AppDimensions.FontSize.large, isBold: true)
        messageLabel = DialogText(text: "", fontSize: AppDimensions.FontSize.medium)
        acceptButton = DialogActionButton(title: "", backgroundColor: positiveButtonColor)
        declineButton = DialogActionButton(title: "", backgroundColor: negativeButtonColor)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = titleText
        messageLabel.text = messageText
        
        if let positiveText = positiveButtonText, !positiveText.isEmpty {
            acceptButton.setTitle(positiveText, for: .normal)
            acceptButton.backgroundColor = positiveButtonColor
        } else {
            acceptButton.isHidden = true
        }
        
        if let negativeText = negativeButtonText, !negativeText.isEmpty {
            declineButton.setTitle(negativeText, for: .normal)
            declineButton.backgroundColor = negativeButtonColor
        } else {
            declineButton.isHidden = true
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

        if(positiveButtonText == nil && negativeButtonText == nil) {
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
        contentContainer.addSubview(acceptButton)
        contentContainer.addSubview(declineButton)
        contentView.addSubview(contentContainer)
        
        acceptButton.addTarget(self, action: #selector(onAcceptButtonTapped), for: .touchUpInside)
        declineButton.addTarget(self, action: #selector(onDeclineButtonTapped), for: .touchUpInside)
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
        acceptButton.translatesAutoresizingMaskIntoConstraints = false
        declineButton.translatesAutoresizingMaskIntoConstraints = false
        
        setContentViewConstraints()
        setImageContainerConstraints()
        setBackgroundImageViewConstraints()
        setContentContainerConstraints()
        setCloseButtonConstraints()
        setTitleLabelConstraints()
        setMessageLabelConstraints()
        setButtonConstraints()
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
    
    private func setButtonConstraints() {
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
        
        if acceptButton.isHidden && declineButton.isHidden {
            messageLabel.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -AppDimensions.Padding.medium).isActive = true
        } else if acceptButton.isHidden {
            commonConstraints(declineButton, messageLabel.bottomAnchor, contentContainer.bottomAnchor)
        } else if declineButton.isHidden {
            commonConstraints(acceptButton, messageLabel.bottomAnchor, contentContainer.bottomAnchor)
        } else {
            NSLayoutConstraint.activate([
                declineButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: AppDimensions.Padding.medium),
                declineButton.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: AppDimensions.Padding.medium),
                declineButton.trailingAnchor.constraint(equalTo: contentContainer.centerXAnchor, constant: -AppDimensions.Padding.small),
                declineButton.heightAnchor.constraint(equalToConstant: AppDimensions.Height.popUpButton),
                
                acceptButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: AppDimensions.Padding.medium),
                acceptButton.leadingAnchor.constraint(equalTo: contentContainer.centerXAnchor, constant: AppDimensions.Padding.small),
                acceptButton.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -AppDimensions.Padding.medium),
                acceptButton.heightAnchor.constraint(equalToConstant: AppDimensions.Height.popUpButton),
                acceptButton.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -AppDimensions.Padding.medium)
            ])
        }
    }
    
    @objc private func onAcceptButtonTapped() {
        onPositiveButtonClick?()
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func onDeclineButtonTapped() {
        onNegativeButtonClick?()
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func dismissDialog() {
        dismiss(animated: true, completion: nil)
    }
}
