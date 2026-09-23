import Foundation
import UIKit

/// The popup shown when the server sends no position, or one this SDK does not know:
/// the image on top, the text under it and the buttons at the bottom of the screen.
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
    private let buttonStackView = UIStackView()

    let viewModel: DialogViewModel

    var confirmButtonColor: UIColor = AppColors.Background.buttonPositive
    var dismissButtonColor: UIColor = AppColors.Background.buttonNegative

    init(viewModel: DialogViewModel) {
        self.viewModel = viewModel
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

        titleLabel.text = viewModel.titleText
        messageLabel.text = viewModel.messageText

        setupUI()
        viewModel.loadImage(onImageLoaded: { [weak self] image in
            self?.backgroundImageView.image = image
        })
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
        imageContainer.clipsToBounds = true
        imageContainer.isHidden = viewModel.isImageContainerHidden
        contentView.addSubview(imageContainer)
        imageContainer.addSubview(backgroundImageView)
    }

    private func setupButtons() {
        contentContainer.backgroundColor = AppColors.Background.contentView

        let state = viewModel.buttonState
        confirmButton.setTitle(viewModel.confirmButtonText, for: .normal)
        confirmButton.backgroundColor = confirmButtonColor
        confirmButton.isHidden = state != .onlyConfirm && state != .bothButtons
        dismissButton.setTitle(viewModel.dismissButtonText, for: .normal)
        dismissButton.backgroundColor = dismissButtonColor
        dismissButton.isHidden = state != .onlyDismiss && state != .bothButtons

        // A hidden button leaves the stack, so a single one takes the full width.
        buttonStackView.axis = .horizontal
        buttonStackView.spacing = AppDimensions.Padding.medium
        buttonStackView.distribution = .fillEqually
        buttonStackView.addArrangedSubview(dismissButton)
        buttonStackView.addArrangedSubview(confirmButton)
        buttonStackView.isHidden = state == .noButtons

        contentContainer.addSubview(titleLabel)
        contentContainer.addSubview(messageLabel)
        contentContainer.addSubview(buttonStackView)
        contentView.addSubview(contentContainer)
        // The close button sits on the content view, not in the image container: without an
        // image the container is collapsed and would not pass touches to it.
        contentView.addSubview(closeButton)

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
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false

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
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setImageContainerConstraints() {
        let height = viewModel.isImageContainerHidden ? 0 : AppDimensions.Size.fullScreenImageHeight
        NSLayoutConstraint.activate([
            imageContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageContainer.heightAnchor.constraint(equalToConstant: height)
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
        // Without an image the text starts below the status bar, not under it.
        let top = viewModel.isImageContainerHidden ? contentView.safeTopAnchor : imageContainer.bottomAnchor
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: top),
            contentContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func setCloseButtonConstraints() {
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: contentView.safeTopAnchor, constant: AppDimensions.Padding.small),
            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppDimensions.Padding.small),
            closeButton.widthAnchor.constraint(equalToConstant: AppDimensions.Size.closeButtonSize),
            closeButton.heightAnchor.constraint(equalToConstant: AppDimensions.Size.closeButtonSize)
        ])
    }

    private func setTitleLabelConstraints() {
        // Without an image the close button is over the text, so the title stops short of it.
        let trailing = viewModel.isImageContainerHidden
            ? titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -AppDimensions.Padding.small)
            : titleLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -AppDimensions.Padding.medium)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: AppDimensions.Padding.medium),
            titleLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: AppDimensions.Padding.medium),
            trailing
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
        let bottom = contentContainer.safeBottomAnchor
        guard viewModel.buttonState != .noButtons else {
            NSLayoutConstraint.activate([
                messageLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottom, constant: -AppDimensions.Padding.medium)
            ])
            return
        }
        // The buttons stay at the bottom of the screen; the text keeps its place under the image.
        NSLayoutConstraint.activate([
            buttonStackView.topAnchor.constraint(greaterThanOrEqualTo: messageLabel.bottomAnchor, constant: AppDimensions.Padding.medium),
            buttonStackView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: AppDimensions.Padding.medium),
            buttonStackView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -AppDimensions.Padding.medium),
            buttonStackView.bottomAnchor.constraint(equalTo: bottom, constant: -AppDimensions.Padding.medium),
            buttonStackView.heightAnchor.constraint(equalToConstant: AppDimensions.Height.popUpButton)
        ])
    }

    @objc private func onConfirmButtonTapped() {
        viewModel.onConfirmButtonClick?()
        dismissDialog()
    }

    @objc private func onDismissButtonTapped() {
        dismissDialog()
    }

    /// Every way out reports the dismissal: the popup presenter waits for it to show the next popup.
    @objc private func dismissDialog() {
        let onDismiss = viewModel.onDismiss
        dismiss(animated: true, completion: {
            onDismiss?()
        })
    }
}
