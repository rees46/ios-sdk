import UIKit

class SlideViewController: UIViewController, SlideView {

    var presenter: SlidePresenter!
    var imageView: UIImageView!
    var loadingIndicator: UIActivityIndicatorView!
    var reloadButton: UIButton!
    var errorLabel: UILabel!
    var loadTimer: Timer?
    var autoReloadTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.loadImage(from: URL(string: "https://example.com/image.jpg")!)
    }

    func setupUI() {
        imageView = UIImageView(frame: view.bounds)
        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)

        if #available(iOS 13.0, *) {
            loadingIndicator = UIActivityIndicatorView(style: .large)
        } else {
            // Fallback on earlier versions
        }
        loadingIndicator.center = view.center
        view.addSubview(loadingIndicator)

        reloadButton = UIButton(type: .system)
        reloadButton.setImage(UIImage(named: "iconReload"), for: .normal)
        reloadButton.frame = CGRect(x: (view.bounds.width - 50) / 2, y: view.bounds.height / 2 - 25, width: 50, height: 50)
        reloadButton.addTarget(self, action: #selector(reloadData), for: .touchUpInside)
        reloadButton.isHidden = true
        view.addSubview(reloadButton)

        errorLabel = UILabel(frame: CGRect(x: 20, y: view.bounds.height / 2 + 50, width: view.bounds.width - 40, height: 50))
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        view.addSubview(errorLabel)
    }

    func showLoadingIndicator() {
        loadingIndicator.startAnimating()
        reloadButton.isHidden = true
        errorLabel.isHidden = true
    }

    func showImage(_ image: UIImage) {
        loadingIndicator.stopAnimating()
        imageView.image = image
    }

    func showError(message: String) {
        loadingIndicator.stopAnimating()
        errorLabel.text = message
        errorLabel.isHidden = false
        reloadButton.isHidden = false

        autoReloadTimer = Timer.scheduledTimer(timeInterval: 15, target: self, selector: #selector(reloadData), userInfo: nil, repeats: false)
    }

    @objc func reloadData() {
        presenter.loadImage(from: URL(string: "https://example.com/image.jpg")!)
    }
}
