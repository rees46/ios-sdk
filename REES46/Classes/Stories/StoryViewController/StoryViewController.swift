import UIKit
import AVFoundation

public protocol StoryViewControllerProtocol: AnyObject {
    func reloadStoriesCollectionSubviews()
}

public protocol CarouselCollectionViewCellDelegate: AnyObject {
    func closeProductsCarousel()
    func sendStructSelectedCarouselProduct(product: StoriesProduct)
}

public class NavigationStackController: UINavigationController {
    
    open weak var stackDelegate: UINavigationControllerDelegate?
    
    public override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func canBeMadeHeadViewController(viewController: UIViewController) -> Bool {
        return viewController.isKind(of: StoryViewController.self)
    }
    
    func resetNavigationStackWithLatestViewControllerAsHead() {
        if viewControllers.count > 1 {
            viewControllers.removeFirst((viewControllers.count - 1))
        }
    }
}

class StoryViewController: UINavigationController, UINavigationControllerDelegate, UIGestureRecognizerDelegate, CarouselCollectionViewCellDelegate {
    private var collectionView: UICollectionView = {
        let frame = CGRect(x: 0, y: 0, width: 300, height: 100)
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 100, height: 130)
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        let collectionView = UICollectionView(frame: frame, collectionViewLayout: layout)
        collectionView.isPagingEnabled = true
        collectionView.isScrollEnabled = false
        collectionView.backgroundColor = .black
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.isPrefetchingEnabled = false
        return collectionView
    }()
    
    public var closeButton: UIButton = {
        let closeButton = UIButton()
        return closeButton
    }()
    
    private var pageIndicator: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.distribution = .fillEqually
        view.spacing = 8
        return view
    }()
    
    public var stories: [Story] = []
    
    public var startWithIndexPath: IndexPath? = .init(item: 1, section: 0)
    public var currentPosition: IndexPath = IndexPath()
    
    private var timer = Timer()
    
    private var storyTime = 8
    
    private var timeLeft: TimeInterval = 8
    private var endTime: Date?
    
    private var currentProgressView: UIProgressView?
    private var currentDuration: Float = 0
    
    private var lastContentStoryOffset = CGPoint.zero
    private var needSaveStoryLocal = true
    
    public var sdk: PersonalizationSDK?
    public var sdkLinkDelegate: StoriesViewLinkProtocol?
    
    private let carouselProductsSlideTintBlurView = UIView()
    private var carouselProductsSlideCollectionView = CarouselCollectionView()
    
    private let storiesSlideReloadIndicator = StoriesSlideReloadIndicator()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        commonInit()
        setupGestureRecognizerOnCollection()
        
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(pauseTimer), name: .init(rawValue: "ExternalActionStoryPause"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(continueTimer), name: .init(rawValue: "ExternalActionStoryPlay"), object: nil)
        UserDefaults.standard.set(false, forKey: "CarouselTimerStopMemorySetting")
        UserDefaults.standard.set(false, forKey: "LastTapButtonMemorySdkSetting")
    }
    
    @objc
    func willEnterForeground() {
        let ds: Bool = UserDefaults.standard.bool(forKey: "CarouselTimerStopMemorySetting")
        if !ds {
            let sIdDetect: String = UserDefaults.standard.string(forKey: "LastViewedSlideMemorySetting") ?? ""
            NotificationCenter.default.post(name: .init(rawValue: "PlayVideoLongTap"), object: nil, userInfo: ["slideID": sIdDetect])
            continueTimer()
        }
    }
    
    @objc
    func didEnterBackground() {
        let sIdDetect: String = UserDefaults.standard.string(forKey: "LastViewedSlideMemorySetting") ?? ""
        NotificationCenter.default.post(name: .init(rawValue: "PauseVideoLongTap"), object: nil, userInfo: ["slideID": sIdDetect])
        pauseTimer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer.invalidate()
    }
    
    func applicationWillResignActive(notification: NSNotification) {
        viewWillDisappear(true)
    }
    
    func applicationWillEnterBackground(notification: NSNotification) {
        viewWillAppear(true)
    }
    
    public override func traitCollectionDidChange (_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        let userInterfaceStyle = traitCollection.userInterfaceStyle
        if UIApplication.shared.applicationState == .inactive {
            switch userInterfaceStyle {
            case .unspecified:
                let storySlideId = stories[currentPosition.section].id
                let cachedSlideId = "cached.slide." + storySlideId
                let userInfo = ["url": cachedSlideId] as [String: Any]
                NotificationCenter.default.post(name:Notification.Name(cachedSlideId), object: userInfo)
                self.sdkLinkDelegate?.reloadStoriesCollectionSubviews()
                self.sdkLinkDelegate?.updateBgColor()
                self.collectionView.reloadData()
            case .light:
                let storySlideId = stories[currentPosition.section].id
                let cachedSlideId = "cached.slide." + storySlideId
                let userInfo = ["url": cachedSlideId] as [String: Any]
                NotificationCenter.default.post(name:Notification.Name(cachedSlideId), object: userInfo)
                self.sdkLinkDelegate?.reloadStoriesCollectionSubviews()
                self.sdkLinkDelegate?.updateBgColor()
                self.collectionView.reloadData()
            case .dark:
                let storySlideId = stories[currentPosition.section].id
                let cachedSlideId = "cached.slide." + storySlideId
                let userInfo = ["url": cachedSlideId] as [String: Any]
                NotificationCenter.default.post(name:Notification.Name(cachedSlideId), object: userInfo)
                self.sdkLinkDelegate?.reloadStoriesCollectionSubviews()
                self.sdkLinkDelegate?.updateBgColor()
                self.collectionView.reloadData()
            @unknown default:
                break
            }
        }
    }
    
    private func commonInit() {
        view.addSubview(collectionView)
        view.addSubview(closeButton)
        view.addSubview(pageIndicator)
        
        storiesSlideReloadIndicator.contentMode = .scaleToFill
        storiesSlideReloadIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        let customIndicatorColor = SdkConfiguration.stories.storiesSlideReloadIndicatorBackgroundColor.hexToRGB()
        storiesSlideReloadIndicator.strokeColor = UIColor(red: customIndicatorColor.red, green: customIndicatorColor.green, blue: customIndicatorColor.blue, alpha: 1)
        
        storiesSlideReloadIndicator.lineWidth = SdkConfiguration.stories.storiesSlideReloadIndicatorBorderLineWidth
        storiesSlideReloadIndicator.numSegments = SdkConfiguration.stories.storiesSlideReloadIndicatorSegmentCount
        storiesSlideReloadIndicator.animationDuration = SdkConfiguration.stories.storiesSlideReloadIndicatorAnimationDuration
        storiesSlideReloadIndicator.rotationDuration = SdkConfiguration.stories.storiesSlideReloadIndicatorRotationDuration
        storiesSlideReloadIndicator.alpha = 0.0
        view.addSubview(storiesSlideReloadIndicator)
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint(item: collectionView, attribute: NSLayoutConstraint.Attribute.left, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.left, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: collectionView, attribute: NSLayoutConstraint.Attribute.right, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.right, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: collectionView, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: collectionView, attribute: NSLayoutConstraint.Attribute.bottom, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: 1, constant: 0).isActive = true
        
        pageIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint(item: pageIndicator,
                           attribute: NSLayoutConstraint.Attribute.left,
                           relatedBy: NSLayoutConstraint.Relation.equal,
                           toItem: view, attribute: NSLayoutConstraint.Attribute.left,
                           multiplier: 1,
                           constant: 11).isActive = true
        NSLayoutConstraint(item: pageIndicator,
                           attribute: NSLayoutConstraint.Attribute.right,
                           relatedBy: NSLayoutConstraint.Relation.equal,
                           toItem: view, attribute: NSLayoutConstraint.Attribute.right,
                           multiplier: 1,
                           constant: -11).isActive = true
        NSLayoutConstraint(item: pageIndicator,
                           attribute: NSLayoutConstraint.Attribute.height,
                           relatedBy: NSLayoutConstraint.Relation.equal,
                           toItem: nil,
                           attribute: NSLayoutConstraint.Attribute.notAnAttribute,
                           multiplier: 1,
                           constant: 4).isActive = true
        if SdkGlobalHelper.sharedInstance.willDeviceHaveDynamicIsland() {
            NSLayoutConstraint(item: pageIndicator,
                               attribute: NSLayoutConstraint.Attribute.top,
                               relatedBy: NSLayoutConstraint.Relation.equal,
                               toItem: view,
                               attribute: NSLayoutConstraint.Attribute.top,
                               multiplier: 1,
                               constant: 62).isActive = true }
        else {
            NSLayoutConstraint(item: pageIndicator,
                               attribute: NSLayoutConstraint.Attribute.top,
                               relatedBy: NSLayoutConstraint.Relation.equal,
                               toItem: view,
                               attribute: NSLayoutConstraint.Attribute.top,
                               multiplier: 1,
                               constant: 40).isActive = true
        }
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        if SdkGlobalHelper.sharedInstance.willDeviceHaveDynamicIsland() {
            NSLayoutConstraint(item: closeButton, attribute: NSLayoutConstraint.Attribute.right, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.right, multiplier: 1, constant: -10).isActive = true
            NSLayoutConstraint(item: closeButton, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: pageIndicator, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: 1, constant: 26).isActive = true
            NSLayoutConstraint(item: closeButton, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 30).isActive = true
            NSLayoutConstraint(item: closeButton, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 30).isActive = true
        } else {
            NSLayoutConstraint(item: closeButton, attribute: NSLayoutConstraint.Attribute.right, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.right, multiplier: 1, constant: -10).isActive = true
            NSLayoutConstraint(item: closeButton, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: pageIndicator, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: 1, constant: 5).isActive = true
            NSLayoutConstraint(item: closeButton, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 30).isActive = true
            NSLayoutConstraint(item: closeButton, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 30).isActive = true
        }
        
        if SdkConfiguration.stories.storiesSlideReloadIndicatorDisabled {
            //Disable implementation
        } else {
            storiesSlideReloadIndicator.translatesAutoresizingMaskIntoConstraints = false
            storiesSlideReloadIndicator.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor).isActive = true
            storiesSlideReloadIndicator.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor).isActive = true
        }
        
        configureView()
        closeButton.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)
    }
    
    @objc
    private func didSingleTapOnScreen(_ gestureRecognizer: UITapGestureRecognizer) {
        let tapLocation = gestureRecognizer.location(in: self.view)
        let halfWidth = self.view.bounds.width / 2.0
        if tapLocation.x < halfWidth {
            handleLeftTap()
        } else {
            handleRightTap()
        }
    }
    
    private func handleRightTap() {
        needSaveStoryLocal = false
        
        guard currentPosition.section < stories.count else {
            print("Section index out of range")
            return
        }
        
        let storyId = stories[currentPosition.section].id
        let storyName = "viewed.slide." + storyId
        
        guard currentPosition.row < stories[currentPosition.section].slides.count else {
            print("Row index out of range")
            return
        }
        
        let slideId = stories[currentPosition.section].slides[currentPosition.row].id
        
        var viewedSlidesStoriesCachedArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(storyName)) as? [String] ?? []
        let viewedStorySlideIdExists = viewedSlidesStoriesCachedArray.contains(where: {
            $0.range(of: slideId) != nil
        })
        
        if !viewedStorySlideIdExists {
            viewedSlidesStoriesCachedArray.append(slideId)
            UserDefaults.standard.setValue(viewedSlidesStoriesCachedArray, for: UserDefaults.Key(storyName))
            needSaveStoryLocal = true
        }
        
        if currentPosition.row < stories[currentPosition.section].slides.count - 1 {
            currentPosition.row += 1
            collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
            
            DispatchQueue.main.async {
                self.updateSlides()
            }
        } else if currentPosition.section >= stories.count - 1 {
            self.dismiss(animated: true)
        } else if currentPosition.section < stories.count - 1 {
            
            currentPosition.row = 0
            
            guard currentPosition.section + 1 < stories.count else {
                print("Section index out of range")
                return
            }
            
            let storyId = stories[currentPosition.section + 1].id
            let storyName = "viewed.slide." + storyId
            
            guard currentPosition.row < stories[currentPosition.section + 1].slides.count else {
                print("Row index out of range")
                return
            }
            
            let slideId = stories[currentPosition.section + 1].slides[currentPosition.row].id
            
            var allStoriesMainArray: [String] = []
            for (index, _) in stories[currentPosition.section + 1].slides.enumerated() {
                allStoriesMainArray.append(stories[currentPosition.section + 1].slides[index].id)
            }
            
            let viewedSlidesStoriesCachedArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(storyName)) as? [String] ?? []
            let viewedStorySlideIdExists = viewedSlidesStoriesCachedArray.contains(where: {
                $0.range(of: slideId) != nil
            })
            
            if viewedStorySlideIdExists {
                let lastViewedSlideIndexValue = viewedSlidesStoriesCachedArray.last
                var currentDefaultIndex = 0
                for name in allStoriesMainArray {
                    if name == lastViewedSlideIndexValue {
                        break
                    }
                    currentDefaultIndex += 1
                }
                
                if (currentDefaultIndex + 1 < stories[currentPosition.section + 1].slides.count) {
                    currentPosition.section += 1
                    currentPosition.row = currentDefaultIndex + 1
                    collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                } else if (currentDefaultIndex + 1 == stories[currentPosition.section + 1].slides.count) {
                    currentPosition.section += 1
                    currentPosition.row = currentDefaultIndex
                    collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                } else {
                    currentPosition.section += 1
                    currentPosition.row = 0
                    
                    scrollToFirstRow()
                    collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                }
            } else {
                currentPosition.section += 1
                currentPosition.row = 0
                
                scrollToFirstRow()
                collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
            }
            
            DispatchQueue.main.async {
                self.updateSlides()
            }
        }
    }
    
    private func handleLeftTap() {
        if currentPosition.row > 0 {
            currentPosition.row -= 1
            collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
            DispatchQueue.main.async {
                self.updateSlides()
            }
        } else if currentPosition.section == 0 {
            self.dismiss(animated: true)
        } else if currentPosition.section >= 1 {
            
            currentPosition.row = 0
            
            let storyId = stories[currentPosition.section - 1].id
            let storyName = "viewed.slide." + storyId
            let slideId = stories[currentPosition.section - 1].slides[currentPosition.row].id
            
            var allStoriesMainArray: [String] = []
            for (index, _) in stories[currentPosition.section - 1].slides.enumerated() {
                allStoriesMainArray.append(stories[currentPosition.section - 1].slides[(index)].id)
            }
            
            let viewedSlidesStoriesCachedArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(storyName)) as? [String] ?? []
            let viewedStorySlideIdExists = viewedSlidesStoriesCachedArray.contains(where: {
                $0.range(of: slideId) != nil
            })
            
            if viewedStorySlideIdExists {
                let lastViewedSlideIndexValue = viewedSlidesStoriesCachedArray.last
                var currentDefaultIndex = 0
                for name in allStoriesMainArray {
                    if name == lastViewedSlideIndexValue {
                        break
                    }
                    currentDefaultIndex += 1
                }
                
                if (currentDefaultIndex + 1 < stories[currentPosition.section - 1].slides.count) {
                    if currentDefaultIndex == 0 {
                        currentPosition.section -= 1
                        currentPosition.row = currentDefaultIndex
                        collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                    } else {
                        if (currentDefaultIndex + 1 <= stories[currentPosition.section - 1].slides.count) {
                            currentPosition.section -= 1
                            currentPosition.row = currentDefaultIndex + 1
                            collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                        } else {
                            currentPosition.section -= 1
                            currentPosition.row = currentDefaultIndex
                            collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                        }
                    }
                } else {
                    currentPosition.section -= 1
                    currentPosition.row = 0
                    
                    scrollToFirstRow()
                    collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                }
            } else {
                currentPosition.section -= 1
                currentPosition.row = 0
                
                scrollToFirstRow()
                collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
            }
            
            DispatchQueue.main.async {
                self.updateSlides()
            }
        }
    }
    
    @objc
    func didSwipeLeft() {
        if currentPosition.section >= stories.count - 1{
            dismiss(animated: true)
        } else {
            needSaveStoryLocal = false
            currentPosition.row = 0
            
            let storyId = stories[currentPosition.section + 1].id
            let storyName = "viewed.slide." + storyId
            let slideId = stories[currentPosition.section + 1].slides[currentPosition.row].id
            
            var allStoriesMainArray: [String] = []
            for (index, _) in stories[currentPosition.section + 1].slides.enumerated() {
                allStoriesMainArray.append(stories[currentPosition.section + 1].slides[(index)].id)
            }
            
            let viewedSlidesStoriesCachedArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(storyName)) as? [String] ?? []
            let viewedStorySlideIdExists = viewedSlidesStoriesCachedArray.contains(where: {
                $0.range(of: slideId) != nil
            })
            
            if viewedStorySlideIdExists {
                let lastViewedSlideIndexValue = viewedSlidesStoriesCachedArray.last
                var currentDefaultIndex = 0
                for name in allStoriesMainArray {
                    if name == lastViewedSlideIndexValue {
                        break
                    }
                    currentDefaultIndex += 1
                }
                
                if (currentDefaultIndex + 1 < stories[currentPosition.section + 1].slides.count) {
                    currentPosition.section += 1
                    currentPosition.row = currentDefaultIndex + 1
                    collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                } else if (currentDefaultIndex + 1 == stories[currentPosition.section + 1].slides.count) {
                    currentPosition.section += 1
                    currentPosition.row = 0 //currentDefaultIndex
                    collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                } else {
                    currentPosition.section += 1
                    currentPosition.row = 0
                    
                    scrollToFirstRow()
                    collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                }
            } else {
                needSaveStoryLocal = false
                currentPosition.section += 1
                currentPosition.row = 0
                scrollToFirstRow()
                collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
            }
            
            DispatchQueue.main.async {
                self.updateSlides()
            }
        }
    }
    
    private func scrollToFirstRow() {
        let sectionFrame = collectionView.layoutAttributesForItem(at: IndexPath(item: 0, section: currentPosition.section))?.frame ?? .zero
        collectionView.setContentOffset(CGPoint(x: sectionFrame.origin.x - collectionView.contentInset.left, y: 0), animated: false)
    }
    
    @objc
    func didSwipeRight() {
        if currentPosition.section > 0 {
            currentPosition.row = 0
            
            let storyId = stories[currentPosition.section - 1].id
            let storyName = "viewed.slide." + storyId
            let slideId = stories[currentPosition.section - 1].slides[currentPosition.row].id
            
            var allStoriesMainArray: [String] = []
            for (index, _) in stories[currentPosition.section - 1].slides.enumerated() {
                allStoriesMainArray.append(stories[currentPosition.section - 1].slides[(index)].id)
            }
            
            let viewedSlidesStoriesCachedArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(storyName)) as? [String] ?? []
            let viewedStorySlideIdExists = viewedSlidesStoriesCachedArray.contains(where: {
                $0.range(of: slideId) != nil
            })
            
            if viewedStorySlideIdExists {
                let lastViewedSlideIndexValue = viewedSlidesStoriesCachedArray.last
                var currentDefaultIndex = 0
                for name in allStoriesMainArray {
                    if name == lastViewedSlideIndexValue {
                        break
                    }
                    currentDefaultIndex += 1
                }
                
                if (currentDefaultIndex + 1 < stories[currentPosition.section - 1].slides.count) {
                    if (currentDefaultIndex + 1 <= stories[currentPosition.section - 1].slides.count) {
                        currentPosition.section -= 1
                        currentPosition.row = currentDefaultIndex + 1
                        collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                    } else {
                        currentPosition.section -= 1
                        currentPosition.row = currentDefaultIndex
                        collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                    }
                } else {
                    currentPosition.section -= 1
                    currentPosition.row = 0
                    
                    scrollToFirstRow()
                    collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                }
            } else {
                currentPosition.section -= 1
                currentPosition.row = 0
                
                scrollToFirstRow()
                collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
            }
            
            DispatchQueue.main.async {
                self.updateSlides()
            }
        } else {
            dismiss(animated: true)
        }
    }
    
    private func configureView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        
        var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        frameworkBundle = Bundle.module
#endif
        let image = UIImage(named: "iconStoryClose", in: frameworkBundle, compatibleWith: nil)
        let imageRender = image?.withRenderingMode(.alwaysTemplate)
        let imageView = UIImageView(image: imageRender)
        closeButton.setImage(imageView.image, for: .normal)
        
        let customTintColor = SdkConfiguration.stories.closeIconColor.hexToRGB()
        closeButton.tintColor = UIColor(red: customTintColor.red, green: customTintColor.green, blue: customTintColor.blue, alpha: 1)
        collectionView.register(StoryCollectionViewCell.self, forCellWithReuseIdentifier: StoryCollectionViewCell.cellId)
        
        updateSlides()
    }
    
    private func updateSlides() {
        // Check if stories array is not empty and currentPosition indices are valid
        guard !stories.isEmpty else {
            print("Error: Stories array is empty")
            return
        }
        
        guard stories.indices.contains(currentPosition.section) else {
            print("Error: Section index \(currentPosition.section) is out of range")
            return
        }
        
        let story = stories[currentPosition.section]
        
        guard story.slides.indices.contains(currentPosition.row) else {
            print("Error: Row index \(currentPosition.row) is out of range for section \(currentPosition.section)")
            return
        }
        
        let storySlideMedia = story.slides[currentPosition.row]
        storyTime = storySlideMedia.duration
        
        if storySlideMedia.type == .video {
            let videoDurationInCache = SdkGlobalHelper.sharedInstance.retrieveVideoCachedParamsDictionary(parentSlideId: storySlideMedia.id)
            if let videoDurationSeconds = videoDurationInCache[storySlideMedia.id] {
                storyTime = Int(videoDurationSeconds) ?? storySlideMedia.duration
            } else {
                // Handle case where video duration cannot be retrieved
            }
        }
        
        timeLeft = TimeInterval(storyTime)
        
        // Clear existing arranged subviews
        for view in pageIndicator.arrangedSubviews {
            pageIndicator.removeArrangedSubview(view)
        }
        
        // Update page indicators
        let slides = story.slides
        for (index, _) in slides.enumerated() {
            let progressView = UIProgressView()
            progressView.tintColor = .white
            if index == currentPosition.row {
                progressView.progress = 0
                startProgress(progressView: progressView)
            } else if index < currentPosition.row {
                progressView.progress = 1
            } else {
                progressView.progress = 0
            }
            pageIndicator.addArrangedSubview(progressView)
        }
    }
    
    private func startProgress(progressView: UIProgressView) {
        endTime = Date().addingTimeInterval(timeLeft)
        let duration: Float = Float(timeLeft)
        currentProgressView = progressView
        currentDuration = duration
        
        let superviewSlideId = stories[currentPosition.section].slides[currentPosition.row].id
        let cachedSlideMediaId = "cached.slide." + superviewSlideId
        
        let imagesForStoriesDownloadedArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(cachedSlideMediaId)) as? [String] ?? []
        let imageStoryIdDownloaded = imagesForStoriesDownloadedArray.contains(where: {
            $0.range(of: cachedSlideMediaId) != nil
        })
        
        if imageStoryIdDownloaded {
            if SdkConfiguration.stories.storiesSlideReloadIndicatorDisabled {
                //Implementation
            } else {
                UIView.animate(withDuration: 0.3, animations: {
                    self.storiesSlideReloadIndicator.alpha = 0.0
                })
            }
            
            timer.invalidate()
            timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(updateTime), userInfo: nil, repeats: true)
        } else {
            timer.invalidate()
            
            if SdkConfiguration.stories.storiesSlideReloadIndicatorDisabled {
                UIView.animate(withDuration: 0.5, animations: {
                    self.storiesSlideReloadIndicator.alpha = 0.0
                })
            } else {
                UIView.animate(withDuration: 0.5, animations: {
                    self.storiesSlideReloadIndicator.alpha = 1.0
                })
            }
            
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name(cachedSlideMediaId), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.updateVisibleCells(notification:)),
                                                   name: Notification.Name(cachedSlideMediaId), object: nil)
        }
    }
    
    @objc
    func updateVisibleCells(notification: NSNotification) {
        DispatchQueue.main.async {
            if let visibleCell = self.collectionView.indexPathsForVisibleItems.first {
                UIView.animate(withDuration: 0.5, animations: {
                    self.storiesSlideReloadIndicator.alpha = 0.0
                })
                self.currentPosition = visibleCell
                self.collectionView.reloadItems(at: self.collectionView.indexPathsForVisibleItems)
                DispatchQueue.main.async {
                    self.updateSlides()
                }
            }
        }
    }
    
    @objc
    func updateTime() {
        if timeLeft > 0 {
            timeLeft = endTime?.timeIntervalSinceNow ?? 0
            currentProgressView?.progress = 1 - Float(timeLeft) / currentDuration
        } else {
            currentProgressView?.progress = 0
            timer.invalidate()
            needSaveStoryLocal = true
            if currentPosition.row < stories[currentPosition.section].slides.count - 1 {
                currentPosition.row += 1
                collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                DispatchQueue.main.async {
                    self.updateSlides()
                }
            } else if currentPosition.section >= stories.count - 1 {
                self.dismiss(animated: true)
            } else if currentPosition.section < stories.count - 1 {
                
                currentPosition.row = 0
                
                let storyId = stories[currentPosition.section + 1].id
                let storyName = "viewed.slide." + storyId
                let slideId = stories[currentPosition.section + 1].slides[currentPosition.row].id
                
                var allStoriesMainArray: [String] = []
                for (index, _) in stories[currentPosition.section + 1].slides.enumerated() {
                    allStoriesMainArray.append(stories[currentPosition.section + 1].slides[(index)].id)
                }
                
                let viewedSlidesStoriesCachedArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(storyName)) as? [String] ?? []
                let viewedStorySlideIdExists = viewedSlidesStoriesCachedArray.contains(where: {
                    $0.range(of: slideId) != nil
                })
                
                if viewedStorySlideIdExists {
                    let lastViewedSlideIndexValue = viewedSlidesStoriesCachedArray.last
                    var currentDefaultIndex = 0
                    for name in allStoriesMainArray {
                        if name == lastViewedSlideIndexValue {
                            break
                        }
                        currentDefaultIndex += 1
                    }
                    
                    if (currentDefaultIndex + 1 < stories[currentPosition.section + 1].slides.count) {
                        currentPosition.section += 1
                        currentPosition.row = currentDefaultIndex + 1
                        collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                    } else if (currentDefaultIndex + 1 == stories[currentPosition.section + 1].slides.count) {
                        currentPosition.section += 1
                        currentPosition.row = currentDefaultIndex
                        collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                    } else {
                        currentPosition.section += 1
                        currentPosition.row = 0
                        
                        scrollToFirstRow()
                        collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                    }
                } else {
                    currentPosition.section += 1
                    currentPosition.row = 0
                    collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                }
                
                DispatchQueue.main.async {
                    self.updateSlides()
                }
            }
        }
    }
    
    private func saveStorySlideWatching(index: IndexPath) {
        let storyId = stories[index.section].id
        let storyName = "viewed.slide." + storyId
        let slideId = stories[index.section].slides[index.row].id
        
        var viewedSlidesStoriesCachedArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(storyName)) as? [String] ?? []
        let viewedStorySlideIdExists = viewedSlidesStoriesCachedArray.contains(where: {
            $0.range(of: slideId) != nil
        })
        
        if !viewedStorySlideIdExists {
            viewedSlidesStoriesCachedArray.append(slideId)
            UserDefaults.standard.setValue(viewedSlidesStoriesCachedArray, for: UserDefaults.Key(storyName))
        }
    }
    
    public func openUrl(link: String) {
#if DEBUG
        print("Opening product in device browser")
#endif
        
        if let linkUrl = URL(string: link) {
            pauseTimer()
            
            let carouselOpenedBoolKey: Bool = UserDefaults.standard.bool(forKey: "CarouselTimerStopMemorySetting")
            if !carouselOpenedBoolKey {
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "WebKitClosedContinueTimerSetting"), object: nil)
                NotificationCenter.default.addObserver(self, selector: #selector(continueTimer), name: Notification.Name("WebKitClosedContinueTimerSetting"), object: nil)
            }
            
            UIApplication.shared.open(linkUrl, options: [:], completionHandler: nil)
            
            let sIdDetect: String = UserDefaults.standard.string(forKey: "LastViewedSlideMemorySetting") ?? ""
            NotificationCenter.default.post(name: .init(rawValue: "PauseVideoLongTap"), object: nil, userInfo: ["slideID": sIdDetect])
            
            dismiss(animated: true)
        }
    }
    
    @objc
    private func pauseTimer() {
        timer.invalidate()
    }
    
    @objc
    private func continueTimer() {
        endTime = Date().addingTimeInterval(timeLeft)
        timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(updateTime), userInfo: nil, repeats: true)
    }
    
    private func trackViewSlide(index: IndexPath) {
        let storyId = stories[index.section].id
        let slideId = stories[index.section].slides[index.row].id
        sdk?.track(event: .slideView(storyId: storyId, slideId: slideId), recommendedBy: nil, completion: { result in
        })
    }
    
    private func trackClickSlide(index: IndexPath) {
        let storyId = stories[index.section].id
        let slideId = stories[index.section].slides[index.row].id
        sdk?.track(event: .slideClick(storyId: storyId, slideId: slideId), recommendedBy: nil, completion: { result in
        })
    }
    
    private func setupGestureRecognizerOnCollection() {
        let longPressedGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(gestureRecognizer:)))
        longPressedGesture.isEnabled = true
        longPressedGesture.minimumPressDuration = 0.20
        longPressedGesture.allowableMovement = 50
        longPressedGesture.delaysTouchesBegan = true
        longPressedGesture.cancelsTouchesInView = false

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(didSingleTapOnScreen(_:)))
        singleTap.cancelsTouchesInView = false

        collectionView.gestureRecognizers = [] 
        collectionView.addGestureRecognizer(longPressedGesture)
        collectionView.addGestureRecognizer(singleTap)

        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(didSwipeLeft))
        leftSwipe.direction = .left
        leftSwipe.require(toFail: longPressedGesture)
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(didSwipeRight))
        rightSwipe.direction = .right
        rightSwipe.require(toFail: longPressedGesture)
        let downSwipe = UISwipeGestureRecognizer(target: self, action: #selector(didSwipeDown))
        downSwipe.direction = .down
        downSwipe.require(toFail: longPressedGesture)

        collectionView.addGestureRecognizer(leftSwipe)
        collectionView.addGestureRecognizer(rightSwipe)
        collectionView.addGestureRecognizer(downSwipe)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    @objc
    private func handleLongPress(gestureRecognizer: UILongPressGestureRecognizer) {
        let positionNumber = gestureRecognizer.location(in: collectionView)
        if gestureRecognizer.state == .ended {
            if let indexPath = collectionView.indexPathForItem(at: positionNumber) {
                let slide = stories[indexPath.section].slides[indexPath.row]
                NotificationCenter.default.post(name: .init(rawValue: "PlayVideoLongTap"), object: nil, userInfo: ["slideID": slide.id])
                continueTimer()
            }
            return
        }
        if (gestureRecognizer.state != .began) {
            if let indexPath = collectionView.indexPathForItem(at: positionNumber) {
                let slide = stories[indexPath.section].slides[indexPath.row]
                NotificationCenter.default.post(name: .init(rawValue: "PauseVideoLongTap"), object: nil, userInfo: ["slideID": slide.id])
                pauseTimer()
            }
            return
        } else {
            if let indexPath = collectionView.indexPathForItem(at: positionNumber) {
                let slide = stories[indexPath.section].slides[indexPath.row]
                NotificationCenter.default.post(name: .init(rawValue: "PauseVideoLongTap"), object: nil, userInfo: ["slideID": slide.id])
                pauseTimer()
            }
        }
    }
    
    class CustomFlowLayout: UICollectionViewFlowLayout {
        var currentScrollDirection = ""
        func currentScroll(direction: String) {
            currentScrollDirection = direction
        }
    }
    
    public func openProductsCarouselView(withProducts: [StoriesProduct], hideLabel: String) {
        pauseTimer()
        view.backgroundColor = .clear
        
        carouselProductsSlideTintBlurView.backgroundColor = UIColor(white: 0, alpha: 0.8)
        carouselProductsSlideTintBlurView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
        carouselProductsSlideCollectionView.hideLabel = hideLabel
        view.addSubview(carouselProductsSlideTintBlurView)
        
        view.addSubview(self.carouselProductsSlideCollectionView)
        
        self.carouselProductsSlideCollectionView.center = CGPoint(x: self.view.center.x, y: self.view.center.y + self.view.frame.size.height)
        self.view.addSubview(self.carouselProductsSlideCollectionView)
        self.view.bringSubviewToFront(self.carouselProductsSlideCollectionView)
        
        UIView.animate(withDuration: 0.6, delay: 0.0,
                       usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0,
                       options: .allowAnimatedContent, animations: {
            self.carouselProductsSlideCollectionView.center = self.view.center
        }) { (isFinished) in
            self.view.layoutIfNeeded()
        }
        
        carouselProductsSlideCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        carouselProductsSlideCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        carouselProductsSlideCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
        
        if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO {
            carouselProductsSlideCollectionView.heightAnchor.constraint(equalToConstant: 420).isActive = true
        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_SE || SdkGlobalHelper.DeviceType.IS_IPHONE_8_PLUS {
            carouselProductsSlideCollectionView.heightAnchor.constraint(equalToConstant: 430).isActive = true
        } else {
            carouselProductsSlideCollectionView.heightAnchor.constraint(equalToConstant: 450).isActive = true
        }
        
        carouselProductsSlideCollectionView.carouselProductsDelegate = self
        carouselProductsSlideCollectionView.cells.removeAll()
        carouselProductsSlideCollectionView.set(cells: withProducts)
        
        carouselProductsSlideCollectionView.reloadData()
        
        let sIdDetect: String = UserDefaults.standard.string(forKey: "LastViewedSlideMemorySetting") ?? ""
        NotificationCenter.default.post(name: .init(rawValue: "PauseVideoLongTap"), object: nil, userInfo: ["slideID": sIdDetect])
        
        UserDefaults.standard.set(true, forKey: "CarouselTimerStopMemorySetting")
    }
    
    public func closeProductsCarousel() {
        UIView.animate(withDuration: 0.4, delay: 0.0,usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0,
                       options: .allowAnimatedContent, animations: {
            
            self.carouselProductsSlideCollectionView.center = CGPoint(x: self.view.center.x,
                                                                      y: self.view.center.y + self.view.frame.size.height)
            
        }) { (isFinished) in
            self.carouselProductsSlideTintBlurView.removeFromSuperview()
            self.carouselProductsSlideCollectionView.removeFromSuperview()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let sIdDetect: String = UserDefaults.standard.string(forKey: "LastViewedSlideMemorySetting") ?? ""
            NotificationCenter.default.post(name: .init(rawValue: "PlayVideoLongTap"), object: nil, userInfo: ["slideID": sIdDetect])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.continueTimer()
            }
        }
        UserDefaults.standard.set(false, forKey: "CarouselTimerStopMemorySetting")
    }
    
    public func didTapOpenLinkExternalServiceMethod(url: String, slide: Slide) {
        let stateButton: Bool = UserDefaults.standard.bool(forKey: "LastTapButtonMemorySdkSetting")
        if stateButton {
            continueTimer()
            
            let sIdDetect: String = UserDefaults.standard.string(forKey: "LastViewedSlideMemorySetting") ?? ""
            NotificationCenter.default.post(name: .init(rawValue: "PlayVideoLongTap"), object: nil, userInfo: ["slideID": sIdDetect])
            print("SDK Start Timer Play Content")
            UserDefaults.standard.set(false, forKey: "LastTapButtonMemorySdkSetting")
        } else {
            print("SDK Pause Timer\n")
            UserDefaults.standard.set(true, forKey: "LastTapButtonMemorySdkSetting")
        }
    }
    
    public func sendStructSelectedStorySlide(storySlide: StoriesElement) {
        pauseTimer()
        
        let sIdDetect: String = UserDefaults.standard.string(forKey: "LastViewedSlideMemorySetting") ?? ""
        NotificationCenter.default.post(name: .init(rawValue: "PauseVideoLongTap"), object: nil, userInfo: ["slideID": sIdDetect])
        self.sdkLinkDelegate?.sendStructSelectedStorySlide(storySlide: storySlide)
    }
    
    func sendStructSelectedCarouselProduct(product: StoriesProduct) {
        sdkLinkDelegate?.structOfSelectedCarouselProduct(product: product)
        if (product.deeplinkIos != "") {
            openUrl(link: product.deeplinkIos)
        } else {
            openUrl(link: product.url)
        }
    }
    
    public func sendStructSelectedPromocodeSlide(promoCodeSlide: StoriesPromoCodeElement) {
        pauseTimer()
        
        let sIdDetect: String = UserDefaults.standard.string(forKey: "LastViewedSlideMemorySetting") ?? ""
        NotificationCenter.default.post(name: .init(rawValue: "PauseVideoLongTap"), object: nil, userInfo: ["slideID": sIdDetect])
        self.sdkLinkDelegate?.sendStructSelectedPromocodeSlide(promoCodeSlide: promoCodeSlide)
    }
    
    @objc
    func didSwipeDown() {
        dismiss(animated: true)
    }
    
    @objc
    func didTapCloseButton() {
        self.sdkLinkDelegate?.reloadStoriesCollectionSubviews()
        dismiss(animated: true)
    }
}


extension StoryViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        stories.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        stories[section].slides.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        storiesSlideReloadIndicator.startAnimating()
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StoryCollectionViewCell.cellId, for: indexPath) as? StoryCollectionViewCell else {
            return UICollectionViewCell()
        }
        let slide = stories[indexPath.section].slides[indexPath.row]
        cell.configure(slide: slide)
        cell.cellDelegate = self
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let screenSize = UIScreen.main.bounds.size
        return screenSize
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if let visibleCell = collectionView.indexPathsForVisibleItems.first {
            currentPosition = visibleCell
            DispatchQueue.main.async {
                self.updateSlides()
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let _cell = cell as? StoryCollectionViewCell {
            _cell.stopPlayer()
            
            let currentOffset = collectionView.contentOffset
            let scrollDirection = (currentOffset.x > lastContentStoryOffset.x) ? "Left" : "Right"
            if let flowLayout = collectionView.collectionViewLayout as? CustomFlowLayout {
                flowLayout.currentScroll(direction: scrollDirection)
            }
            lastContentStoryOffset = currentOffset
            if (scrollDirection == "Left" && needSaveStoryLocal) {
                saveStorySlideWatching(index: indexPath)
            }
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
//        timer.invalidate()
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? StoryCollectionViewCell else {return}
        cell.stopPlayer()
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        trackViewSlide(index: indexPath)
        if let startWithIndexPath = startWithIndexPath {
            if collectionView.isValid(indexPath: startWithIndexPath) {
                self.collectionView.scrollToItem(at: startWithIndexPath, at: .left, animated: false)
            }
            self.startWithIndexPath = nil
        }
    }
}


extension StoryViewController: StoryCollectionViewCellDelegate {
    public func didTapUrlButton(url: String, slide: Slide) {
        self.openUrl(link: url)
        for (section, story) in stories.enumerated() {
            for (row, storySlide) in story.slides.enumerated() {
                if storySlide.id == slide.id {
                    self.trackClickSlide(index: IndexPath(row: row, section: section))
                }
            }
        }
    }
}


extension UICollectionView {
    func isValid(indexPath: IndexPath) -> Bool {
        guard indexPath.section < numberOfSections,
              indexPath.row < numberOfItems(inSection: indexPath.section)
        else {
            return false
        }
        return true
    }
}


extension NavigationStackController: UINavigationControllerDelegate {
    public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if canBeMadeHeadViewController(viewController: viewController) {
            viewController.navigationItem.setHidesBackButton(false, animated: false)
        }
    }
    
    public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        if canBeMadeHeadViewController(viewController: viewController) {
            resetNavigationStackWithLatestViewControllerAsHead()
        }
    }
}
