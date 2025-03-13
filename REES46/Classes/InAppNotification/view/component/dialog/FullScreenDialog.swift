import Foundation
import UIKit

class FullScreenDialog: UIViewController {
    
    private let backgroundImageView = DialogImageVeiw()
    private let contentView = UIView()
    private let contentContainer = UIView()
    private let imageContainer = UIView()
    private let closeButton = DialogButtonClose()
    private let titleLabel: DialogText
    private let messageLabel: DialogText
    private let confirmButton: DialogActionButton
    private let dismissButton: DialogActionButton
    private let spacerView = UIView()
    
    var titleText: String = ""
    var messageText: String = ""
    var imageUrl: String = ""
    var confirmButtonText: String = ""
    var dismissButtonText: String = ""
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
        confirmButton.setTitle(confirmButtonText, for: .normal)
        dismissButton.setTitle(dismissButtonText, for: .normal)
        confirmButton.backgroundColor = confirmButtonColor
        dismissButton.backgroundColor = dismissButtonColor
        
        setupUI()
        backgroundImageView.loadImage(from: imageUrl)
    }
    
    private func setupUI() {
        view.backgroundColor = AppColors.Background.alertDimmed
        setupContentView()
        setupImageContainer()
        setupButtons()
        layoutUI()
    }
    
    private func setupContentView() {
        contentView.backgroundColor = AppColors.Background.contentView
        view.addSubview(contentView)
    }
    
    private func setupImageContainer() {
        contentView.addSubview(imageContainer)
        imageContainer.addSubview(backgroundImageView)
        imageContainer.addSubview(closeButton)
    }
    
    private func setupButtons() {
        contentContainer.backgroundColor = AppColors.Background.contentView
        
        contentContainer.addSubview(titleLabel)
        contentContainer.addSubview(messageLabel)
        contentContainer.addSubview(spacerView)
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
        spacerView.translatesAutoresizingMaskIntoConstraints = false
        
        setContentViewConstraints()
        setImageContainerConstraints()
        setBackgroundImageViewConstraints()
        setContentContainerConstraints()
        setCloseButtonConstraints()
        setTitleLabelConstraints()
        setMessageLabelConstraints()
        setSpacerConstraints()
        setButtonConstraints()
    }
    
    private func setContentViewConstraints() {
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setImageContainerConstraints() {
        NSLayoutConstraint.activate([
            imageContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageContainer.heightAnchor.constraint(equalToConstant: AppDimensions.Size.fullScreenImageHeight)
        ])
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
            contentContainer.topAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
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
    
    private func setSpacerConstraints() {
        NSLayoutConstraint.activate([
            spacerView.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: AppDimensions.Padding.medium),
            spacerView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            spacerView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            spacerView.bottomAnchor.constraint(equalTo: confirmButton.topAnchor),
            spacerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        ])
    }
    
    private func setButtonConstraints() {
        NSLayoutConstraint.activate([
            // Dismiss Button
            dismissButton.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: AppDimensions.Padding.medium),
            dismissButton.trailingAnchor.constraint(equalTo: contentContainer.centerXAnchor, constant: -AppDimensions.Padding.small),
            dismissButton.heightAnchor.constraint(equalToConstant: AppDimensions.Height.popUpButton),
            dismissButton.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -AppDimensions.Padding.large),
            
            // Confirm Button
            confirmButton.leadingAnchor.constraint(equalTo: contentContainer.centerXAnchor, constant: AppDimensions.Padding.small),
            confirmButton.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -AppDimensions.Padding.medium),
            confirmButton.heightAnchor.constraint(equalToConstant: AppDimensions.Height.popUpButton),
            confirmButton.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -AppDimensions.Padding.large)
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
        dismiss(animated: true, completion: nil)
    }
}
