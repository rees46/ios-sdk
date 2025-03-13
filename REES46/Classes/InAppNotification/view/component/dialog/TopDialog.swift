import UIKit

class TopDialog: UIViewController {
    
    private let backgroundImageView = DialogImageVeiw()
    private let contentView = UIView()
    private let contentContainer = UIStackView()
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
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
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
        setupContentView()
        setupImageContainer()
        setupButtons()
        layoutUI()
        
        if confirmButtonText == nil && dismissButtonText == nil {
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
        contentContainer.axis = .vertical
        contentContainer.alignment = .fill
        contentContainer.spacing = AppDimensions.Padding.medium
        contentContainer.distribution = .fill
        contentContainer.addArrangedSubview(titleLabel)
        contentContainer.addArrangedSubview(messageLabel)
        
        if !dismissButton.isHidden && !confirmButton.isHidden {
            let buttonStack = UIStackView(arrangedSubviews: [dismissButton, confirmButton])
            buttonStack.axis = .horizontal
            buttonStack.spacing = AppDimensions.Padding.small
            buttonStack.alignment = .fill
            buttonStack.distribution = .fillEqually
            contentContainer.addArrangedSubview(buttonStack)
        } else if !confirmButton.isHidden {
            contentContainer.addArrangedSubview(confirmButton)
        } else if !dismissButton.isHidden {
            contentContainer.addArrangedSubview(dismissButton)
        }
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
        
        setContentViewConstraints()
        setImageContainerConstraints()
        setBackgroundImageViewConstraints()
        setContentContainerConstraints()
        setCloseButtonConstraints()
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
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: imageContainer.isHidden ? contentView.topAnchor : imageContainer.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        contentContainer.layoutMargins = UIEdgeInsets(top: AppDimensions.Padding.medium, left: AppDimensions.Padding.medium, bottom: AppDimensions.Padding.medium, right: AppDimensions.Padding.medium)
                contentContainer.isLayoutMarginsRelativeArrangement = true
    }
    
    private func setCloseButtonConstraints() {
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: imageContainer.topAnchor, constant: AppDimensions.Padding.small),
            closeButton.leadingAnchor.constraint(greaterThanOrEqualTo: imageContainer.leadingAnchor, constant: AppDimensions.Padding.small),
            closeButton.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor, constant: AppDimensions.Padding.small),
            closeButton.widthAnchor.constraint(equalToConstant: AppDimensions.Size.closeButtonSize),
            closeButton.heightAnchor.constraint(equalToConstant: AppDimensions.Size.closeButtonSize)
        ])
    }
    
    @objc private func onConfirmButtonTapped() {
        onConfirmButtonClick?()
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func onDismissButtonTapped() {
        onDismissButtonClick?()
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func dismissDialog() {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.frame.origin.y = -self.view.frame.height
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
        })
    }
}
