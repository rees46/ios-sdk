import UIKit

class CustomAlertDialog: UIViewController {

    private let backgroundImageView = UIImageView()
    private let contentView = UIView()
    private let contentContainer = UIView()
    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let acceptButton = UIButton(type: .system)
    private let declineButton = UIButton(type: .system)
    
    var titleText: String = ""
    var messageText: String = ""
    var imageUrl: String = ""
    var positiveButtonText: String = ""
    var negativeButtonText: String = ""
    var positiveButtonColor: UIColor = .systemBlue
    var negativeButtonColor: UIColor = .gray
    
    var onPositiveButtonClick: (() -> Void)?
    var onNegativeButtonClick: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadImage()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        setupContentView()
        setupBackgroundImageView()
        setupContentContainer()
        setupCloseButton()
        setupTitleLabel()
        setupMessageLabel()
        setupButtons()
        layoutUI()
    }
    
    private func setupContentView() {
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = AppDimensions.Padding.medium
        contentView.clipsToBounds = true
        view.addSubview(contentView)
    }
    
    private func setupBackgroundImageView() {
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        contentView.addSubview(backgroundImageView)
    }
    
    private func setupContentContainer() {
        contentContainer.backgroundColor = .white
        contentContainer.layer.cornerRadius = AppDimensions.Padding.medium
        contentContainer.clipsToBounds = true
        contentView.addSubview(contentContainer)
    }
    
    private func setupCloseButton() {
        closeButton.tintColor = .white
        closeButton.alpha = 1.0
        closeButton.backgroundColor = .clear
        closeButton.addTarget(self, action: #selector(dismissDialog), for: .touchUpInside)
        
        let crossLayer = CAShapeLayer()
        let crossPath = UIBezierPath()
        
        crossPath.move(to: CGPoint(x: 0, y: 0))
        crossPath.addLine(to: CGPoint(
            x: AppDimensions.Padding.large,
            y: AppDimensions.Padding.large)
        )
        
        crossPath.move(to: CGPoint(
            x: AppDimensions.Padding.large,
            y: 0)
        )
        crossPath.addLine(to: CGPoint(
            x: 0,
            y: AppDimensions.Padding.large)
        )
        
        crossLayer.path = crossPath.cgPath
        crossLayer.strokeColor = UIColor.black.cgColor
        crossLayer.lineWidth = 2.0
        
        closeButton.layer.addSublayer(crossLayer)
        contentContainer.addSubview(closeButton)
    }
    
    private func setupTitleLabel() {
        titleLabel.text = titleText
        titleLabel.font = UIFont.boldSystemFont(ofSize: AppDimensions.FontSize.large)
        titleLabel.textColor = .black
        contentContainer.addSubview(titleLabel)
    }
    
    private func setupMessageLabel() {
        messageLabel.text = messageText
        messageLabel.font = UIFont.systemFont(ofSize: AppDimensions.FontSize.medium)
        messageLabel.numberOfLines = 0
        messageLabel.textColor = .black
        contentContainer.addSubview(messageLabel)
    }
    
    private func setupButtons() {
        // Accept Button
        acceptButton.setTitle(positiveButtonText, for: .normal)
        acceptButton.backgroundColor = positiveButtonColor
        acceptButton.setTitleColor(.white, for: .normal)
        acceptButton.layer.cornerRadius = AppDimensions.Padding.small
        acceptButton.addTarget(self, action: #selector(onAcceptButtonTapped), for: .touchUpInside)
        contentContainer.addSubview(acceptButton)
        
        // Decline Button
        declineButton.setTitle(negativeButtonText, for: .normal)
        declineButton.backgroundColor = negativeButtonColor
        declineButton.setTitleColor(.white, for: .normal)
        declineButton.layer.cornerRadius = AppDimensions.Padding.small
        declineButton.addTarget(self, action: #selector(onDeclineButtonTapped), for: .touchUpInside)
        contentContainer.addSubview(declineButton)
    }
    
    private func layoutUI() {
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        acceptButton.translatesAutoresizingMaskIntoConstraints = false
        declineButton.translatesAutoresizingMaskIntoConstraints = false
        
        setContentViewConstraints()
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
    
    private func setBackgroundImageViewConstraints() {
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundImageView.heightAnchor.constraint(equalToConstant: AppDimensions.Size.alertPopUpHeight)
        ])
    }
    
    private func setContentContainerConstraints() {
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: backgroundImageView.bottomAnchor, constant: -AppDimensions.Padding.large),
            contentContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            contentContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: AppDimensions.Size.alertPopUpHeight)
        ])
    }
    
    private func setCloseButtonConstraints() {
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: AppDimensions.Padding.small),
            closeButton.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -AppDimensions.Padding.small),
            closeButton.widthAnchor.constraint(equalToConstant: AppDimensions.Padding.large),
            closeButton.heightAnchor.constraint(equalToConstant: AppDimensions.Padding.large)
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
        NSLayoutConstraint.activate([
            // Decline Button
            declineButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: AppDimensions.Padding.medium),
            declineButton.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: AppDimensions.Padding.medium),
            declineButton.trailingAnchor.constraint(equalTo: contentContainer.centerXAnchor, constant: -AppDimensions.Padding.small),
            declineButton.heightAnchor.constraint(equalToConstant: AppDimensions.Height.popUpButton),
            
            // Accept Button
            acceptButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: AppDimensions.Padding.medium),
            acceptButton.leadingAnchor.constraint(equalTo: contentContainer.centerXAnchor, constant: AppDimensions.Padding.small),
            acceptButton.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -AppDimensions.Padding.medium),
            acceptButton.heightAnchor.constraint(equalToConstant: AppDimensions.Height.popUpButton),
            acceptButton.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -AppDimensions.Padding.medium)
        ])
    }
    
    private func loadImage() {
        guard let url = URL(string: imageUrl) else {
            print("Invalid image URL")
            return
        }
        DispatchQueue.global().async {
            do {
                let data = try Data(contentsOf: url)
                let image = UIImage(data: data)
                DispatchQueue.main.async {
                    self.backgroundImageView.image = image
                }
            } catch {
                print("Failed to load image: \(error.localizedDescription)")
            }
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
