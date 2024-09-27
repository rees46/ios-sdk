import UIKit

public class FullScreenAlertViewController: UIViewController {

    private var titleText: String
    private var messageText: String
    private var acceptButtonText: String
    private var declineButtonText: String
    private var imageURL: URL
    private var acceptAction: () -> Void
    private var declineAction: () -> Void

    private let backgroundImageView = UIImageView()

    public init(
        title: String,
        message: String,
        imageURL: URL,
        acceptButtonText: String,
        declineButtonText: String,
        acceptAction: @escaping () -> Void,
        declineAction: @escaping () -> Void
    ) {
        self.titleText = title
        self.messageText = message
        self.acceptButtonText = acceptButtonText
        self.declineButtonText = declineButtonText
        self.imageURL = imageURL
        self.acceptAction = acceptAction
        self.declineAction = declineAction
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        loadBackgroundImage()
    }

    private func setupUI() {
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundImageView)
        
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        let dimmingView = UIView()
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dimmingView)

        NSLayoutConstraint.activate([
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        let titleLabel = UILabel()
        titleLabel.text = titleText
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)

        let messageLabel = UILabel()
        messageLabel.text = messageText
        messageLabel.font = UIFont.systemFont(ofSize: 18)
        messageLabel.textColor = .white
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        view.addSubview(messageLabel)

        let acceptButton = UIButton(type: .system)
        acceptButton.setTitle(acceptButtonText, for: .normal)
        acceptButton.setTitleColor(.white, for: .normal)
        acceptButton.backgroundColor = .systemGreen
        acceptButton.layer.cornerRadius = 10
        acceptButton.translatesAutoresizingMaskIntoConstraints = false
        acceptButton.addTarget(self, action: #selector(acceptButtonTapped), for: .touchUpInside)
        view.addSubview(acceptButton)

        let declineButton = UIButton(type: .system)
        declineButton.setTitle(declineButtonText, for: .normal)
        declineButton.setTitleColor(.white, for: .normal)
        declineButton.backgroundColor = .systemRed
        declineButton.layer.cornerRadius = 10
        declineButton.translatesAutoresizingMaskIntoConstraints = false
        declineButton.addTarget(self, action: #selector(declineButtonTapped), for: .touchUpInside)
        view.addSubview(declineButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            acceptButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            acceptButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            acceptButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            acceptButton.heightAnchor.constraint(equalToConstant: 50),

            declineButton.bottomAnchor.constraint(equalTo: acceptButton.topAnchor, constant: -10),
            declineButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            declineButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            declineButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func loadBackgroundImage() {
        URLSession.shared.dataTask(with: imageURL) { [weak self] data, response, error in
            guard let self = self, let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self.backgroundImageView.image = image
            }
        }.resume()
    }

    @objc private func acceptButtonTapped() {
        dismiss(animated: true) {
            self.acceptAction()
        }
    }

    @objc private func declineButtonTapped() {
        dismiss(animated: true) {
            self.declineAction()
        }
    }
}
