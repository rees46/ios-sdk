import UIKit
import REES46

/// "Legacy UI" tab — the same stories block wired the classic UIKit way: a `StoriesView`,
/// a `StoriesCommunicationProtocol` delegate and a manual `configure(sdk:mainVC:code:)`.
///
/// Kept next to `SwiftUIStoriesScreen` so both integration styles can be compared side by side.
final class LegacyStoriesViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let storiesView = StoriesView(frame: .zero)
    private let statusLabel = UILabel()
    private let eventsLabel = UILabel()
    private let showStoriesButton = DemoShopButton(type: .system)

    private var events: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupLayout()
        setupStories()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configureStories),
            name: globalSDKNotificationNameMainInit,
            object: nil
        )
        configureStories()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: globalSDKNotificationNameMainInit, object: nil)
    }

    // MARK: - Setup

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])

        contentStack.addArrangedSubview(title("StoriesView (UIKit)"))

        storiesView.translatesAutoresizingMaskIntoConstraints = false
        storiesView.heightAnchor.constraint(equalToConstant: 135).isActive = true
        contentStack.addArrangedSubview(storiesView)

        statusLabel.text = "Waiting for the SDK to initialise…"
        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        contentStack.addArrangedSubview(statusLabel)

        showStoriesButton.setTitle("Open stories programmatically", for: .normal)
        showStoriesButton.setTitleColor(.white, for: .normal)
        showStoriesButton.addTarget(self, action: #selector(openStories), for: .touchUpInside)
        showStoriesButton.heightAnchor.constraint(equalToConstant: 42).isActive = true
        contentStack.addArrangedSubview(showStoriesButton)

        contentStack.addArrangedSubview(title("Delegate callbacks"))

        eventsLabel.text = "Tap a story to see delegate callbacks here"
        eventsLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        eventsLabel.textColor = .secondaryLabel
        eventsLabel.numberOfLines = 0
        contentStack.addArrangedSubview(eventsLabel)
    }

    private func setupStories() {
        storiesView.communicationDelegate = self
        storiesView.onStoriesLoadComplete = { [weak self] isLoaded in
            DispatchQueue.main.async {
                self?.statusLabel.text = isLoaded ? "Stories loaded" : "Stories failed to load"
            }
        }
    }

    private func title(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .headline)
        label.numberOfLines = 0
        return label
    }

    // MARK: - Actions

    @objc
    private func configureStories() {
        // The SDK posts its init notification from a background thread and NotificationCenter
        // delivers synchronously, so this can arrive off the main thread.
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.configureStories() }
            return
        }

        guard let sdk = globalSDK else { return }
        statusLabel.text = "Loading stories…"
        storiesView.configure(sdk: sdk, mainVC: self, code: AppEnvironments.storiesCode)
    }

    @objc
    private func openStories() {
        storiesView.showStories()
    }

    private func log(_ message: String) {
        events.insert(message, at: 0)
        if events.count > 20 {
            events.removeLast()
        }
        eventsLabel.text = events.joined(separator: "\n")
    }
}

// MARK: - StoriesCommunicationProtocol

extension LegacyStoriesViewController: StoriesCommunicationProtocol {

    func receiveIosLink(text: String) {
        log("receiveIosLink: \(text)")
    }

    func receiveSelectedProductData(products: StoriesElement) {
        log("receiveSelectedProductData: \(products.deeplinkIos ?? products.link ?? "no link")")
    }

    func receiveSelectedCarouselProductData(products: StoriesProduct) {
        log("receiveSelectedCarouselProductData: \(products.deeplinkIos)")
    }

    func receiveSelectedPromocodeProductData(promoCodeSlide: StoriesPromoCodeElement) {
        log("receiveSelectedPromocodeProductData (StoriesPromoCodeElement exposes no public fields)")
    }
}
