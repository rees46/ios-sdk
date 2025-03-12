import UIKit

class TopDialog: UIViewController {
    
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
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
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
        setupContentView()
        setupImageContainer()
        setupButtons()
        layoutUI()
        
        if positiveButtonText == nil && negativeButtonText == nil {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissDialog))
            tapGesture.cancelsTouchesInView = false
            view.addGestureRecognizer(tapGesture)
        }
    }
    
    private func setupContentView() {
        contentView.backgroundColor = AppColors.Background.contentView
        contentView.layer.cornerRadius = AppDimensions.Padding.medium
        contentView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
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
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
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
                imageContainer.heightAnchor.constraint(equalToConstant: AppDimensions.Size.bottomSheetHeight)
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
        if acceptButton.isHidden && declineButton.isHidden {
            NSLayoutConstraint.activate([
                contentContainer.topAnchor.constraint(equalTo: imageContainer.isHidden ? contentView.topAnchor : imageContainer.bottomAnchor),
                contentContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                contentContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                contentContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                
                messageLabel.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -AppDimensions.Padding.medium)
            ])
        } else {
            NSLayoutConstraint.activate([
                contentContainer.topAnchor.constraint(equalTo: imageContainer.isHidden ? contentView.topAnchor : imageContainer.bottomAnchor),
                contentContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                contentContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                contentContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppDimensions.Padding.medium)
            ])
        }
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
        if acceptButton.isHidden && declineButton.isHidden {
            NSLayoutConstraint.activate([
                messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppDimensions.Padding.small),
                messageLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: AppDimensions.Padding.medium),
                messageLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -AppDimensions.Padding.medium),
                messageLabel.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -AppDimensions.Padding.medium)
            ])
        } else {
            NSLayoutConstraint.activate([
                messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppDimensions.Padding.small),
                messageLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: AppDimensions.Padding.medium),
                messageLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -AppDimensions.Padding.medium)
            ])
        }
    }
    
    private func setButtonConstraints() {
        if !declineButton.isHidden && !acceptButton.isHidden {
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
        } else if !acceptButton.isHidden {
            NSLayoutConstraint.activate([
                acceptButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: AppDimensions.Padding.medium),
                acceptButton.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: AppDimensions.Padding.medium),
                acceptButton.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -AppDimensions.Padding.medium),
                acceptButton.heightAnchor.constraint(equalToConstant: AppDimensions.Height.popUpButton),
                acceptButton.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -AppDimensions.Padding.medium)
            ])
        } else if !declineButton.isHidden {
            NSLayoutConstraint.activate([
                declineButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: AppDimensions.Padding.medium),
                declineButton.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: AppDimensions.Padding.medium),
                declineButton.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -AppDimensions.Padding.medium),
                declineButton.heightAnchor.constraint(equalToConstant: AppDimensions.Height.popUpButton),
                declineButton.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -AppDimensions.Padding.medium)
            ])
        }
    }
    
    @objc private func onAcceptButtonTapped() {
        onPositiveButtonClick?()
        dismiss(animated: false, completion: nil)
    }
    
    @objc private func onDeclineButtonTapped() {
        onNegativeButtonClick?()
        dismiss(animated: false, completion: nil)
    }
    
    @objc private func dismissDialog() {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.frame.origin.y = -self.view.frame.height
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
        })
    }
}
