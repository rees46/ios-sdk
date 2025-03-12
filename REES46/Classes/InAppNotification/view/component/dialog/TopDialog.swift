import UIKit

class TopDialog: UIViewController {
    
    private let backgroundImageView = DialogImageVeiw()
    private let contentView = UIView()
    private let contentContainer = UIStackView()
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
        contentContainer.axis = .vertical
        contentContainer.alignment = .fill
        contentContainer.spacing = AppDimensions.Padding.medium
        contentContainer.distribution = .fill
        contentContainer.addArrangedSubview(titleLabel)
        contentContainer.addArrangedSubview(messageLabel)
        
        if !declineButton.isHidden && !acceptButton.isHidden {
            let buttonStack = UIStackView(arrangedSubviews: [declineButton, acceptButton])
            buttonStack.axis = .horizontal
            buttonStack.spacing = AppDimensions.Padding.small
            buttonStack.alignment = .fill
            buttonStack.distribution = .fillEqually
            contentContainer.addArrangedSubview(buttonStack)
        } else if !acceptButton.isHidden {
            contentContainer.addArrangedSubview(acceptButton)
        } else if !declineButton.isHidden {
            contentContainer.addArrangedSubview(declineButton)
        }
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
    
    @objc private func onAcceptButtonTapped() {
        onPositiveButtonClick?()
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func onDeclineButtonTapped() {
        onNegativeButtonClick?()
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
