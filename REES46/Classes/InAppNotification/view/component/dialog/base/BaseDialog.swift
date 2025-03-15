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
    
    let viewModel: DialogViewModel
    
    var confirmButtonColor: UIColor = AppColors.Background.buttonPositive
    var dismissButtonColor: UIColor = AppColors.Background.buttonNegative
    
    init(
        viewModel: DialogViewModel
    ) {
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
        backgroundImageView.loadImage(from: viewModel.imageUrl)
    }
    
    private func setupUI() {
        let state = viewModel.determineButtonState()
        
        configureButtons(for: state)
        setupContentView()
        setupImageContainer()
        setupButtons()
        layoutUI()
        applyConstraints(buttonState: state, isImageContainerHidden: viewModel.isImageContainerHidden)
        addDismissTapGesture(hasButtons: viewModel.hasButtons)
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
        imageContainer.isHidden = viewModel.isImageContainerHidden
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
    
    
    private func configureButtons(for state: ButtonState) {
        switch state {
            case .onlyConfirm:
                confirmButton.setTitle(viewModel.confirmButtonText, for: .normal)
                confirmButton.backgroundColor = confirmButtonColor
                dismissButton.isHidden = true
            case .onlyDismiss:
                dismissButton.setTitle(viewModel.dismissButtonText, for: .normal)
                dismissButton.backgroundColor = dismissButtonColor
                confirmButton.isHidden = true
            case .noButtons:
                confirmButton.isHidden = true
                dismissButton.isHidden = true
            case .bothButtons:
                confirmButton.setTitle(viewModel.confirmButtonText, for: .normal)
                confirmButton.backgroundColor = confirmButtonColor
                dismissButton.setTitle(viewModel.dismissButtonText, for: .normal)
                dismissButton.backgroundColor = dismissButtonColor
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
        viewModel.onConfirmButtonClick()
        dismiss(animated: true, completion: nil)
    }
    
    @objc func onDismissButtonTapped() {
        dismissDialog()
    }
}
