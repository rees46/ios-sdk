import UIKit

public class SlideViewController: UIViewController, SlideView {
    
    var imageView: UIImageView!
    var loadingIndicator: UIActivityIndicatorView!
    var reloadButton: UIButton!
    var errorLabel: UILabel!
    var loadTimer: Timer?
    var autoReloadTimer: Timer?
    var currentURL: URL?
    private var reloadTimer: Timer?
    private let imageLoader: ImageLoadingProtocol
    
    struct Constants {
        static let imageURL = URL(string: "https://example.com/image.jpg")!
        static let loadingTimeout: TimeInterval = 15
        static let reloadIconName = "iconReload"
        static let messageKey = "error_message_failed_to_load"
        static let errorMessageComment = "Error message for failed data loading"
    }
    
    init(imageLoader: ImageLoadingProtocol) {
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadImage(from: Constants.imageURL)
        loadTimer = Timer.scheduledTimer(timeInterval: Constants.loadingTimeout, target: self, selector: #selector(checkLoadingTimeout), userInfo: nil, repeats: false)
    }
    
    func setupUI() {
        imageView = UIImageView(frame: view.bounds)
        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)
        
        if #available(iOS 13.0, *) {
            loadingIndicator = UIActivityIndicatorView(style: .large)
        }
        loadingIndicator.center = view.center
        view.addSubview(loadingIndicator)
        
        reloadButton = UIButton(type: .system)
        reloadButton.setImage(UIImage(named: Constants.reloadIconName), for: .normal)
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
    
    func hideLoadingIndicator() {
        loadingIndicator.stopAnimating()
    }
    
    func showImage(_ image: UIImage) {
        hideLoadingIndicator()
        imageView.image = image
    }
    
    func showError() {
        hideLoadingIndicator()
        errorLabel.text = NSLocalizedString(Constants.messageKey, comment: Constants.errorMessageComment)
        
        errorLabel.isHidden = false
        reloadButton.isHidden = false
        
        autoReloadTimer = Timer.scheduledTimer(timeInterval: Constants.loadingTimeout, target: self, selector: #selector(reloadData), userInfo: nil, repeats: false)
    }
    
    func showReloadButton() {
        hideLoadingIndicator()
        reloadButton.isHidden = false
    }
    
    @objc func reloadData() {
        if let url = currentURL {
            loadImage(from: url)
        }
    }
    
    @objc func checkLoadingTimeout() {
        if imageView.image == nil {
            showReloadButton()
        }
    }
    
    func loadImage(from url: URL) {
        currentURL = url
        showLoadingIndicator()
        startLoadingTimeout()
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.loadTimer?.invalidate()
                
                if let error = error {
                    self.showError()
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    self.showError()
                    return
                }
                
                guard let data = data, let image = UIImage(data: data) else {
                    self.showError()
                    return
                }
                
                self.showImage(image)
            }
        }
        task.resume()
    }
    
    private func startLoadingTimeout() {
        reloadTimer = Timer.scheduledTimer(withTimeInterval: Constants.loadingTimeout, repeats: false) { [weak self] _ in
            self?.showReloadButton()
        }
    }
}
