import Foundation
import UIKit

public protocol StoriesCommunicationProtocol: AnyObject {
    func receiveIosLink(text: String)
    func receiveSelectedProductData(products: StoriesElement)
    func receiveSelectedCarouselProductData(products: StoriesProduct)
    func receiveSelectedPromocodeProductData(promoCodeSlide: StoriesPromoCodeElement)

    /// Asked before the SDK opens a link tapped inside stories: a slide button
    /// deeplink or link, a promocode deeplink, or a carousel product.
    ///
    /// Implement it and return `false` to keep the SDK from opening the url when the
    /// host routes it on its own — the story is dismissed either way, so the screen
    /// the host navigates to is not covered by the viewer.
    ///
    /// - Parameter url: the url the SDK is about to open.
    /// - Returns: `true` if the url should be opened by the SDK itself. Defaults to `true`.
    func shouldOpenLinkBySdk(url: String) -> Bool
}

public extension StoriesCommunicationProtocol {
    func shouldOpenLinkBySdk(url: String) -> Bool { true }
}

public protocol StoriesViewLinkProtocol: AnyObject {
    func linkIosExternalUse(url: String)
    func sendStructSelectedStorySlide(storySlide: StoriesElement)
    func structOfSelectedCarouselProduct(product: StoriesProduct)
    func sendStructSelectedPromocodeSlide(promoCodeSlide: StoriesPromoCodeElement)
    func reloadStoriesCollectionSubviews()
    func updateBgColor()
    func shouldOpenLinkBySdk(url: String) -> Bool
}

public extension StoriesViewLinkProtocol {
    func shouldOpenLinkBySdk(url: String) -> Bool { true }
}

public class StoriesView: UIView, UINavigationControllerDelegate {

    /// Height the block takes while it has something to show — the row height of the preview
    /// collection layout.
    public static let defaultHeight: CGFloat = 135

    public var onStoriesLoadComplete: ((Bool) -> Void)?

    /// Called when the block collapses because a load brought nothing to show (`true`), and when a
    /// later load brings stories and it expands again (`false`).
    ///
    /// The view collapses itself, so a host needs this only to give back space it reserved around
    /// the block — or when it lays the block out by frame or pins its height with a required
    /// constraint, neither of which the SDK overrides.
    public var onStoriesCollapse: ((Bool) -> Void)?

    /// `false` once a load came back with nothing to show — a block turned off in the dashboard
    /// brings no stories, and a failed request brings nothing either. The view then hides itself and
    /// reports a zero intrinsic height so it stops taking up space on the host screen. Stays `true`
    /// while the block is loading, which keeps the placeholder row visible.
    public private(set) var hasStories: Bool = true

    let cellId = "StoriesCollectionViewPreviewCell"
    
    private var collectionView: UICollectionView = {
        let testFrame = CGRect(x: 0, y: 0, width: 300, height: StoriesView.defaultHeight)
        let layout = UICollectionViewFlowLayout()
        //layout.horizontalAlignment = .left
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        layout.scrollDirection = .horizontal
        
        layout.itemSize = CGSize(width: SdkConfiguration.stories.iconSize, height: StoriesView.defaultHeight)
        layout.sectionInset = UIEdgeInsets(top: 0, left: SdkConfiguration.stories.iconMarginX, bottom: 0, right: SdkConfiguration.stories.iconMarginX)
        
        let collectionView = UICollectionView(frame: testFrame, collectionViewLayout: layout)
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        return collectionView
    }()
    
    private var stories: [Story]?
    private var settings: StoriesSettings?
    private var sdk: PersonalizationSDK?

    /// Subscription from the `configure(shopId:...)` overload; torn down when the view goes away or is
    /// reconfigured, so the `awaitInstance` callback is not held.
    private var sdkAwaitCancellable: Cancellable?

    public weak var communicationDelegate: StoriesCommunicationProtocol?
    
    private var mainVC: UIViewController?
    private var code: String = ""
    
    private var isInDownloadMode: Bool = true

    /// Zero height while the block is empty. Optional priority, so a host that pins its own required
    /// height keeps winning and can collapse the block itself from `onStoriesCollapse`.
    private lazy var emptyStateHeightConstraint: NSLayoutConstraint = {
        let constraint = heightAnchor.constraint(equalToConstant: 0)
        constraint.priority = UILayoutPriority(999)
        return constraint
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        self.addSubview(collectionView)
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint(item: collectionView, attribute: NSLayoutConstraint.Attribute.left, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self, attribute: NSLayoutConstraint.Attribute.left, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: collectionView, attribute: NSLayoutConstraint.Attribute.right, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self, attribute: NSLayoutConstraint.Attribute.right, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: collectionView, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: collectionView, attribute: NSLayoutConstraint.Attribute.bottom, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: 1, constant: 0).isActive = true
        configureView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc
    func willEnterForeground() {
        //
    }
    
    @objc
    func didEnterBackground() {
        //
    }
    
    /// Lets a host drop the block into a stack view without pinning a height: the row sizes itself,
    /// and reports nothing to occupy once a load comes back empty.
    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: hasStories ? StoriesView.defaultHeight : 0)
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        let userInterfaceStyle = traitCollection.userInterfaceStyle
        if UIApplication.shared.applicationState == .inactive {
            switch userInterfaceStyle {
            case .unspecified:
                DispatchQueue.main.async {
                    self.collectionView.backgroundColor = SdkConfiguration.stories.storiesBlockBackgroundColorChanged_Light
                    self.reloadStoriesCollectionSubviews()
                    self.updateBgColor()
                }
            case .light:
                DispatchQueue.main.async {
                    self.collectionView.backgroundColor = SdkConfiguration.stories.storiesBlockBackgroundColorChanged_Light
                    self.reloadStoriesCollectionSubviews()
                    self.updateBgColor()
                }
            case .dark:
                DispatchQueue.main.async {
                    self.collectionView.backgroundColor = SdkConfiguration.stories.storiesBlockBackgroundColorChanged_Dark
                    self.reloadStoriesCollectionSubviews()
                    self.updateBgColor()
                }
            @unknown default:
                break
            }
        } else {
            DispatchQueue.main.async {
                self.updateBgColor()
            }
        }
    }
    
    private func configureView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(StoriesCollectionViewPreviewCell.self, forCellWithReuseIdentifier: StoriesCollectionViewPreviewCell.cellId)
        self.setBgColor()
        
        UserDefaults.standard.set(false, forKey: "MuteSoundSetting")
    }
    
    public func configure(sdk: PersonalizationSDK, mainVC: UIViewController, code: String) {
        self.sdk = sdk
        self.mainVC = mainVC
        self.code = code
        loadStoriesData()
    }

    /**
     Multi-instance overload (R3): resolves the SDK instance for `shopId` from the `Rees46` registry
     instead of taking one directly, so the host does not have to hold and thread the SDK. With no
     `shopId` the single default instance is used. The resolution is reactive — if the shop is not
     initialized yet, the view loads as soon as it registers.

     An ambiguous request (no `shopId` while several shops are registered) resolves to nothing and the
     view stays empty — pass an explicit `shopId` in a multi-shop app. Reconfiguring cancels any
     previous pending resolution.
     */
    public func configure(shopId: String? = nil, mainVC: UIViewController, code: String) {
        self.mainVC = mainVC
        self.code = code
        sdkAwaitCancellable?.cancel()
        sdkAwaitCancellable = Rees46.awaitInstance(for: shopId) { [weak self] sdk in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.sdk = sdk
                self.loadStoriesData()
            }
        }
    }

    deinit {
        sdkAwaitCancellable?.cancel()
    }

    private func setBgColor() {
        if SdkConfiguration.isDarkMode {
            DispatchQueue.main.async {
                self.collectionView.backgroundColor = SdkConfiguration.stories.storiesBlockBackgroundColorChanged_Dark
                self.reloadStoriesCollectionSubviews()
            }
        } else {
            DispatchQueue.main.async {
                self.collectionView.backgroundColor = SdkConfiguration.stories.storiesBlockBackgroundColorChanged_Light
                self.reloadStoriesCollectionSubviews()
            }
        }
    }
    
    private func setBgColor(color: String) {
        let hex = color.hexToRGB()
        DispatchQueue.main.async {
            self.collectionView.backgroundColor = UIColor(red: hex.red, green: hex.green, blue: hex.blue, alpha: 0)
        }
    }
    
    private func loadStoriesData() {
        reopenIfCollapsed()
        sdk?.getStories(code: code) { result in
            switch result {
            case let .success(response):
                // The list and the settings belong to the collection view, which reads them on the
                // main queue — this callback arrives on the session queue, so they are handed over
                // there rather than assigned from here.
                DispatchQueue.main.async {
                    self.stories = response.stories
                    self.settings = response.settings
                    self.isInDownloadMode = false
                    self.collectionView.reloadData()
                    self.updateEmptyState(hasStories: !response.stories.isEmpty)
                    print("StoriesView: Stories successfully loaded")
                    self.onStoriesLoadComplete?(true)
                }
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error:", customError)
                default:
                    print("Error:", error.description)
                }
                DispatchQueue.main.async {
                    // Nothing to show either, so the block collapses the same way an empty one does
                    // instead of leaving a row of placeholders that never resolve.
                    self.stories = []
                    self.isInDownloadMode = false
                    self.collectionView.reloadData()
                    self.updateEmptyState(hasStories: false)
                    print("StoriesView: Stories load failed")
                    self.onStoriesLoadComplete?(false)
                }
            }
        }
    }

    /// A collapsed block goes back to its placeholder row for the duration of a reload, so a retry
    /// after an empty or failed load can bring it back. A block that has stories on screen keeps them
    /// until the new list arrives — reloading is not a reason to blank it.
    private func reopenIfCollapsed() {
        let reopen = { [weak self] in
            guard let self = self, !self.hasStories else { return }
            self.stories = nil
            self.isInDownloadMode = true
            self.collectionView.reloadData()
            self.updateEmptyState(hasStories: true)
        }

        // `configure(shopId:)` and the SwiftUI wrapper already call in on the main queue; a host
        // calling `configure(sdk:)` from a background thread is sent there rather than touching UIKit
        // off the main queue.
        if Thread.isMainThread {
            reopen()
        } else {
            DispatchQueue.main.async(execute: reopen)
        }
    }
    
    /// Collapses the block when a load brings nothing to show — no stories (a block switched off in
    /// the dashboard) or a failed request both otherwise leave an empty row on the host screen — and
    /// restores it when a later load brings stories.
    ///
    /// Hiding is what makes a stack view hand the row's space back; the constraint and the intrinsic
    /// size cover hosts that lay the block out with constraints of their own.
    private func updateEmptyState(hasStories: Bool) {
        guard self.hasStories != hasStories else { return }
        self.hasStories = hasStories
        isHidden = !hasStories
        // A frame-based host lays the view out through the autoresizing mask, where an added
        // constraint would fight the generated ones — it gets `isHidden` and the callback only.
        if !translatesAutoresizingMaskIntoConstraints {
            emptyStateHeightConstraint.isActive = !hasStories
        }
        invalidateIntrinsicContentSize()
        superview?.setNeedsLayout()
        onStoriesCollapse?(!hasStories)
    }

    public func pauseStoryNow() {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ExternalActionStoryPause"), object: nil)
    }
    
    public func playStoryNow() {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ExternalActionStoryPlay"), object: nil)
    }
}


extension StoriesView: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // Placeholders only until a list arrives: `stories` is assigned off the main queue, ahead of
        // `isInDownloadMode`, so counting 4 here once it is set asks for cells the list cannot fill —
        // an empty block (this is the shape of a block switched off in the dashboard) crashed on the
        // subscript in `cellForItemAt`.
        guard let stories = stories else {
            return isInDownloadMode ? 4 : 0
        }
        return stories.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        if (SdkConfiguration.stories.labelWidth > SdkConfiguration.stories.iconSize) {
            return SdkConfiguration.stories.labelWidth / 2 + SdkConfiguration.stories.iconMarginX * 2
        } else {
            return 18
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StoriesCollectionViewPreviewCell.cellId, for: indexPath) as? StoriesCollectionViewPreviewCell else {return UICollectionViewCell()}
        
        if let currentStory = story(at: indexPath.row) {
            
            let storyId = currentStory.id

            var allStoriesMainArray: [String] = []
            for (index, _) in currentStory.slides.enumerated() {
                //print("Story has \(index + 1): \(currentStory.slides[(index)].id)")
                allStoriesMainArray.append(currentStory.slides[(index)].id)
            }

            let viewedSlidesStoriesCachedArray: [String] = sdk?.localState?.viewedSlides(storyId: storyId) ?? []
            if (viewedSlidesStoriesCachedArray.count == allStoriesMainArray.count) {
                cell.configureCell(settings: settings, viewed: currentStory.viewed, viewedLocalKey: true, storyId: currentStory.id)
                cell.configure(story: currentStory)
            } else {
                cell.configureCell(settings: settings, viewed: currentStory.viewed, viewedLocalKey: false, storyId: currentStory.id)
                cell.configure(story: currentStory)
            }
        } else {
            if (isInDownloadMode && stories == nil) {
                cell.storyBackCircle.alpha = 0.0
                
                var placeholderColor = SdkConfiguration.stories.iconPlaceholderColor.hexToRGB()
                
                if SdkConfiguration.isDarkMode {
                    placeholderColor = SdkConfiguration.stories.iconPlaceholderColorDarkMode.hexToRGB()
                }
                
                cell.storyBackCircle.backgroundColor = UIColor(red: placeholderColor.red, green: placeholderColor.green, blue: placeholderColor.blue, alpha: 1.0)
                UIView.animate(withDuration: 5.0, animations: {
                    cell.storyBackCircle.alpha = 1.0
                })
            }
        }
        
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        showStoriesByUserClick(at: indexPath.row)
    }
    
    public func showStories() {
        guard let firstStory = stories?.first else {
            return
        }
        
        guard let index = stories?.firstIndex(where: { $0.id == firstStory.id }) else {
            return
        }
        
        showStories(at: index, for: firstStory)
    }
    private func showStoriesByUserClick(at index: Int) {
        guard let story = story(at: index) else {
            return
        }
        
        showStories(at: index, for: story)
    }

    /// The loaded list and the cells the collection asks for can disagree for a moment (see
    /// `numberOfItemsInSection`), so every read of it goes through a bounds check.
    private func story(at index: Int) -> Story? {
        guard let stories = stories, stories.indices.contains(index) else {
            return nil
        }
        return stories[index]
    }
    
    private func showStories(at index: Int, for story: Story) {
        let storyVC = StoryViewController()
        storyVC.sdkLinkDelegate = self
        storyVC.sdk = sdk
        storyVC.stories = stories ?? []

        var allSlidesIDs: [String] = []
        for slide in story.slides {
            allSlidesIDs.append(slide.id)
        }

        let viewedSlidesCachedIDs: [String] = sdk?.localState?.viewedSlides(storyId: story.id) ?? []
        
        if let lastViewedSlideID = viewedSlidesCachedIDs.last,
           let defaultIndex = allSlidesIDs.firstIndex(of: lastViewedSlideID) {
            let nextIndex = defaultIndex + 1
            storyVC.currentPosition = IndexPath(row: nextIndex, section: index)
            storyVC.startWithIndexPath = IndexPath(row: nextIndex, section: index)
        } else {
            storyVC.currentPosition = IndexPath(row: story.startPosition, section: index)
            storyVC.startWithIndexPath = IndexPath(row: story.startPosition, section: index)
        }
        
        storyVC.modalPresentationStyle = .fullScreen
        mainVC?.present(storyVC, animated: true)
    }
}


extension StoriesView: StoriesViewLinkProtocol {
    public func sendStructSelectedStorySlide(storySlide: StoriesElement) {
        self.communicationDelegate?.receiveSelectedProductData(products: storySlide)
        print("\nSDK Received story slide button tap links for external use:")
        printSlideObject(objElementClass: storySlide)
    }
    
    public func structOfSelectedCarouselProduct(product: StoriesProduct) {
        self.communicationDelegate?.receiveSelectedCarouselProductData(products: product)
        print("\nSDK Received carousel selected product link for external use:")
        printCarouselObject(objProductClass: product)
    }
    
    public func sendStructSelectedPromocodeSlide(promoCodeSlide: StoriesPromoCodeElement) {
        self.communicationDelegate?.receiveSelectedPromocodeProductData(promoCodeSlide: promoCodeSlide)
        print("\nSDK Received promocode slide button tap links for external use:")
        printPromoObject(objPromoClass: promoCodeSlide)
    }
    
    public func linkIosExternalUse(url: String) {
        self.communicationDelegate?.receiveIosLink(text: url)
        print("\nSDK Received linkIos for external use: \(url)\n\n")
    }

    public func shouldOpenLinkBySdk(url: String) -> Bool {
        self.communicationDelegate?.shouldOpenLinkBySdk(url: url) ?? true
    }
    
    public func reloadStoriesCollectionSubviews() {
        UICollectionView.performWithoutAnimation {
            self.collectionView.layoutIfNeeded()
            self.collectionView.reloadData()
        }
    }
    
    public func updateBgColor() {
        DispatchQueue.main.async {
            self.collectionView.reloadItems(at: self.collectionView.indexPathsForVisibleItems)
            self.setBgColor()
        }
    }
    
    public func printSlideObject(objElementClass: StoriesElement) {
        print("Deeplink iOS: \(objElementClass.deeplinkIos ?? "")")
        print("Link iOS: \(objElementClass.linkIos ?? "")")
        print("Link Web: \(objElementClass.link ?? "")")
    }
    
    public func printCarouselObject(objProductClass: StoriesProduct) {
        print("ProductName: \(objProductClass.name)")
        print("ProductUrl: \(objProductClass.url)")
        print("ProductCategory: \(objProductClass.category.name)")
        print("ProductCategoryUrl: \(objProductClass.category.url)")
        print("ProductPrice: \(objProductClass.price)")
        print("ProductPriceFormatted: \(objProductClass.price_formatted)")
        print("ProductPicture: \(objProductClass.picture)\n\n")
    }
    
    public func printPromoObject(objPromoClass: StoriesPromoCodeElement) {
        print("Deeplink iOS: \(objPromoClass.deeplinkIos )")
        print("Link Web: \(objPromoClass.url )")
    }
}

class CustomCollectionViewCell: UICollectionViewCell {
    override var isSelected: Bool {
        didSet {
            contentView.backgroundColor = isSelected ? .red : .white
        }
    }
}


extension UIViewController {
    func embedInNavigationController() -> UINavigationController {
        return UINavigationController(rootViewController: self)
    }
}
