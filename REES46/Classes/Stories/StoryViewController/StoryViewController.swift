import UIKit

public protocol StoryViewControllerProtocol: AnyObject {
    func didTapLinkIosOpeningExternal(url: String)
    func reloadStoriesCollectionSubviews()
}

public protocol CarouselCollectionViewCellDelegate: AnyObject {
    func closeProductsCarousel()
    func didTapLinkIosOpeningExternal(url: String)
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
        //collectionView.isScrollEnabled = false
        collectionView.isPrefetchingEnabled = false
        return collectionView
    }()

    private var closeButton: UIButton = {
        let closeButton = UIButton()
        closeButton.tintColor = .white
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
    public var linkDelegate: StoriesViewMainProtocol?
    
    var preloader = StoriesRingView()
    
    private let tintBlurView = UIView()
    private var carouselCollectionView = CarouselCollectionView()

    override func viewDidLoad() {
        super.viewDidLoad()
        commonInit()
        setupGestureRecognizerOnCollection()
        
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(pauseTimer), name: .init(rawValue: "ExternalActionStoryPause"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(continueTimer), name: .init(rawValue: "ExternalActionStoryPlay"), object: nil)
    }
    
    @objc
    func willEnterForeground() {
        continueTimer()
    }

    @objc
    func didEnterBackground() {
        pauseTimer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer.invalidate()
    }

    private func commonInit() {
        view.addSubview(collectionView)
        view.addSubview(closeButton)
        view.addSubview(pageIndicator)

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint(item: collectionView, attribute: NSLayoutConstraint.Attribute.left, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.left, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: collectionView, attribute: NSLayoutConstraint.Attribute.right, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.right, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: collectionView, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: collectionView, attribute: NSLayoutConstraint.Attribute.bottom, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: 1, constant: 0).isActive = true

        pageIndicator.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint(item: pageIndicator, attribute: NSLayoutConstraint.Attribute.right, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.right, multiplier: 1, constant: -16).isActive = true

        NSLayoutConstraint(item: pageIndicator, attribute: NSLayoutConstraint.Attribute.left, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.left, multiplier: 1, constant: 16).isActive = true
        
        if GlobalHelper.sharedInstance.checkIfHasDynamicIsland() {
            NSLayoutConstraint(item: pageIndicator, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1, constant: 62).isActive = true }
        else {
            NSLayoutConstraint(item: pageIndicator, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1, constant: 40).isActive = true
        }

        NSLayoutConstraint(item: pageIndicator, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 4).isActive = true
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        if GlobalHelper.sharedInstance.checkIfHasDynamicIsland() {
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

        configureView()
        closeButton.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)
    }
    
    @objc private func didSingleTapOnScreen(_ gestureRecognizer: UITapGestureRecognizer) {
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
        let storyId = String(stories[currentPosition.section].id)
        let storyName = "story." + storyId
        let slideId = String(stories[currentPosition.section].slides[currentPosition.row].id)
        
        var watchedStoriesArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(storyName)) as? [String] ?? []
        let watchedStoryIdExists = watchedStoriesArray.contains(where: {
            $0.range(of: String(slideId)) != nil
        })
        
        if !watchedStoryIdExists {
            watchedStoriesArray.append(slideId)
            UserDefaults.standard.setValue(watchedStoriesArray, for: UserDefaults.Key(storyName))
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
            
            let storyId = String(stories[currentPosition.section + 1].id)
            let storyName = "story." + storyId
            let slideId = String(stories[currentPosition.section + 1].slides[currentPosition.row].id)
            
            var allStoriesMainArray: [String] = []
            for (index, _) in stories[currentPosition.section + 1].slides.enumerated() {
                //print("Story has \(index + 1): \(stories[currentPosition.section + 1].slides[(index)].id)")
                allStoriesMainArray.append(String(stories[currentPosition.section + 1].slides[(index)].id))
            }
            
            let watchedStoriesArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(storyName)) as? [String] ?? []
            let watchedStoryIdExists = watchedStoriesArray.contains(where: {
                $0.range(of: String(slideId)) != nil
            })
            
            if watchedStoryIdExists {
                let lastWatchedIndexValue = watchedStoriesArray.last
                var currentDefaultIndex = 0
                for name in allStoriesMainArray {
                    if name == lastWatchedIndexValue {
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
            
            let storyId = String(stories[currentPosition.section - 1].id)
            let storyName = "story." + storyId
            let slideId = String(stories[currentPosition.section - 1].slides[currentPosition.row].id)
            
            var allStoriesMainArray: [String] = []
            for (index, _) in stories[currentPosition.section - 1].slides.enumerated() {
                //print("Story has \(index + 1): \(stories[currentPosition.section - 1].slides[(index)].id)")
                allStoriesMainArray.append(String(stories[currentPosition.section - 1].slides[(index)].id))
            }
            
            let watchedStoriesArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(storyName)) as? [String] ?? []
            let watchedStoryIdExists = watchedStoriesArray.contains(where: {
                $0.range(of: String(slideId)) != nil
            })
            
            if watchedStoryIdExists {
                let lastWatchedIndexValue = watchedStoriesArray.last
                var currentDefaultIndex = 0
                for name in allStoriesMainArray {
                    if name == lastWatchedIndexValue {
                        //print("Story \(name) for index \(currentDefaultIndex)")
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
                        print(stories[currentPosition.section - 1].slides.count)
                        print(stories[currentPosition.section].slides.count)
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
            
            let storyId = String(stories[currentPosition.section + 1].id)
            let storyName = "story." + storyId
            let slideId = String(stories[currentPosition.section + 1].slides[currentPosition.row].id)
            
            var allStoriesMainArray: [String] = []
            for (index, _) in stories[currentPosition.section + 1].slides.enumerated() {
                //print("Story has \(index + 1): \(stories[currentPosition.section + 1].slides[(index)].id)")
                allStoriesMainArray.append(String(stories[currentPosition.section + 1].slides[(index)].id))
            }
            
            let watchedStoriesArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(storyName)) as? [String] ?? []
            let watchedStoryIdExists = watchedStoriesArray.contains(where: {
                $0.range(of: String(slideId)) != nil
            })
            
            if watchedStoryIdExists {
                let lastWatchedIndexValue = watchedStoriesArray.last
                var currentDefaultIndex = 0
                for name in allStoriesMainArray {
                    if name == lastWatchedIndexValue {
                        //print("Story \(name) for index \(currentDefaultIndex)")
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
        //print(sectionFrame)
        collectionView.setContentOffset(CGPoint(x: sectionFrame.origin.x - collectionView.contentInset.left, y: 0), animated: false)
    }
    
    @objc
    func didSwipeRight() {
        if currentPosition.section > 0 {
            currentPosition.row = 0
            
            let storyId = String(stories[currentPosition.section - 1].id)
            let storyName = "story." + storyId
            let slideId = String(stories[currentPosition.section - 1].slides[currentPosition.row].id)
            
            var allStoriesMainArray: [String] = []
            for (index, _) in stories[currentPosition.section - 1].slides.enumerated() {
                //print("Story has \(index + 1): \(stories[currentPosition.section - 1].slides[(index)].id)")
                allStoriesMainArray.append(String(stories[currentPosition.section - 1].slides[(index)].id))
            }
            
            let watchedStoriesArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(storyName)) as? [String] ?? []
            let watchedStoryIdExists = watchedStoriesArray.contains(where: {
                $0.range(of: String(slideId)) != nil
            })
            
            if watchedStoryIdExists {
                let lastWatchedIndexValue = watchedStoriesArray.last
                var currentDefaultIndex = 0
                for name in allStoriesMainArray {
                    if name == lastWatchedIndexValue {
                        //print("Story \(name) for index \(currentDefaultIndex)")
                        break
                    }
                    currentDefaultIndex += 1
                }
                
                if (currentDefaultIndex + 1 < stories[currentPosition.section - 1].slides.count) {
                    print(stories[currentPosition.section - 1].slides.count)
                    print(stories[currentPosition.section].slides.count)
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
        
        var mainBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        mainBundle = Bundle.module
#endif
        let image = UIImage(named: "iconStoryClose", in: mainBundle, compatibleWith: nil)
        closeButton.setImage(image, for: .normal)

        collectionView.register(StoryCollectionViewCell.self, forCellWithReuseIdentifier: StoryCollectionViewCell.cellId)
        //preloader = StoriesRingLoader.createStoriesLoader()
        updateSlides()
    }

    @objc
    func didTapCloseButton() {
        self.linkDelegate?.reloadStoriesCollectionSubviews()
        dismiss(animated: true)
    }

    private func updateSlides() {
        timeLeft = TimeInterval(storyTime)
        for view in pageIndicator.arrangedSubviews {
            pageIndicator.removeArrangedSubview(view)
        }
        let slides = stories[currentPosition.section].slides
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
        
        let storyImageSlideId = String(stories[currentPosition.section].slides[currentPosition.row].id)
        let prefix = "waitStorySlideCached." + storyImageSlideId
        let imagesForStoriesDownloadedArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(prefix)) as? [String] ?? []
        let imageStoryIdDownloaded = imagesForStoriesDownloadedArray.contains(where: {
            $0.range(of: String(prefix)) != nil
        })
        
        if imageStoryIdDownloaded {
            timer.invalidate()
            timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(updateTime), userInfo: nil, repeats: true)
            //preloader.stopPreloaderAnimation()
        } else {
            let name = "waitStorySlideCached." + storyImageSlideId
            NotificationCenter.default.addObserver(self, selector: #selector(self.updateVisibleCells(notification:)), name: Notification.Name(name), object: nil)
            
            //preloader = StoriesRingLoader.createStoriesLoader()
            //preloader.startAnimation()
        }
    }
    
    @objc func updateVisibleCells(notification: NSNotification){
        DispatchQueue.main.async {
            if let visibleCell = self.collectionView.indexPathsForVisibleItems.first {
                self.currentPosition = visibleCell
                self.collectionView.reloadItems(at: self.collectionView.indexPathsForVisibleItems)
                DispatchQueue.main.async {
                    self.updateSlides()
                }
            }
        }
    }

    @objc func updateTime() {
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
                
                let storyId = String(stories[currentPosition.section + 1].id)
                let storyName = "story." + storyId
                let slideId = String(stories[currentPosition.section + 1].slides[currentPosition.row].id)
                
                var allStoriesMainArray: [String] = []
                for (index, _) in stories[currentPosition.section + 1].slides.enumerated() {
                    //print("Story has \(index + 1): \(stories[currentPosition.section + 1].slides[(index)].id)")
                    allStoriesMainArray.append(String(stories[currentPosition.section + 1].slides[(index)].id))
                }
                
                let watchedStoriesArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(storyName)) as? [String] ?? []
                let watchedStoryIdExists = watchedStoriesArray.contains(where: {
                    $0.range(of: String(slideId)) != nil
                })
                
                if watchedStoryIdExists {
                    let lastWatchedIndexValue = watchedStoriesArray.last
                    var currentDefaultIndex = 0
                    for name in allStoriesMainArray {
                        if name == lastWatchedIndexValue {
                            //print("Story \(name) for index \(currentDefaultIndex)")
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
        let storyId = String(stories[index.section].id)
        let storyName = "story." + storyId
        let slideId = String(stories[index.section].slides[index.row].id)
        
        var watchedStoriesArray: [String] = UserDefaults.standard.getValue(for: UserDefaults.Key(storyName)) as? [String] ?? []
        let watchedStoryIdExists = watchedStoriesArray.contains(where: {
            $0.range(of: String(slideId)) != nil
        })
        
        if !watchedStoryIdExists {
            watchedStoriesArray.append(slideId)
            UserDefaults.standard.setValue(watchedStoriesArray, for: UserDefaults.Key(storyName))
        }
    }
    
    private func openUrl(link: String) {
        if let url = URL(string: link) {
            pauseTimer()
            present(url: url, completion: nil)
            //UIApplication.shared.open(url) //Safari default
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
        let storyId = String(stories[index.section].id)
        let slideId = String(stories[index.section].slides[index.row].id)
        sdk?.track(event: .slideView(storyId: storyId, slideId: slideId), recommendedBy: nil, completion: { result in
        })
    }
    
    private func trackClickSlide(index: IndexPath) {
        let storyId = String(stories[index.section].id)
        let slideId = String(stories[index.section].slides[index.row].id)
        sdk?.track(event: .slideClick(storyId: storyId, slideId: slideId), recommendedBy: nil, completion: { result in
        })
    }
    
    private func setupGestureRecognizerOnCollection() {
        
        let longPressedGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(gestureRecognizer:)))
        
        collectionView.gestureRecognizers = []
        longPressedGesture.isEnabled = true
        longPressedGesture.minimumPressDuration = 0.20

        longPressedGesture.allowableMovement = 50
        longPressedGesture.delaysTouchesBegan = true
        longPressedGesture.cancelsTouchesInView = true
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(didSingleTapOnScreen(_:)))
        singleTap.require(toFail: longPressedGesture)
        collectionView.addGestureRecognizer(longPressedGesture)
        collectionView.addGestureRecognizer(singleTap)
        
        
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(didSwipeLeft))
        leftSwipe.direction = .left
        leftSwipe.require(toFail: longPressedGesture)
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(didSwipeRight))
        rightSwipe.direction = .right
        rightSwipe.require(toFail: longPressedGesture)
        
        collectionView.addGestureRecognizer(leftSwipe)
        collectionView.addGestureRecognizer(rightSwipe)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    @objc private func handleLongPress(gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            let p = gestureRecognizer.location(in: collectionView)
            if let indexPath = collectionView.indexPathForItem(at: p) {
                let slide = stories[indexPath.section].slides[indexPath.row]
                NotificationCenter.default.post(name: .init(rawValue: "PlayVideoLongTap"), object: nil, userInfo: ["slideID": slide.id])
                continueTimer()
            }
            return
        }
        if (gestureRecognizer.state != .began) {
            let p = gestureRecognizer.location(in: collectionView)

            if let indexPath = collectionView.indexPathForItem(at: p) {
                let slide = stories[indexPath.section].slides[indexPath.row]
                NotificationCenter.default.post(name: .init(rawValue: "PauseVideoLongTap"), object: nil, userInfo: ["slideID": slide.id])
                pauseTimer()
            }
            return
        } else {
            let p = gestureRecognizer.location(in: collectionView)
            if let indexPath = collectionView.indexPathForItem(at: p) {
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
    
    public func didTapOpenLinkIosExternalWeb(url: String, slide: Slide) {
        self.linkDelegate?.extendLinkIos(url: url)
    }
    
    public func sendProductStructForExternal(product: StoriesElement) {
        self.linkDelegate?.structOfSelectedProduct(product: product)
    }
    
    public func openProductsCarousel(products: [StoriesProduct]) {
        pauseTimer()
        view.backgroundColor = .clear
        
        tintBlurView.backgroundColor = UIColor(white: 0, alpha: 0.8)
        tintBlurView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
        view.addSubview(tintBlurView)
        
        view.addSubview(self.carouselCollectionView)
        
        self.carouselCollectionView.center = CGPoint(x: self.view.center.x,
                y: self.view.center.y + self.view.frame.size.height)
        self.view.addSubview(self.carouselCollectionView)
        self.view.bringSubviewToFront(self.carouselCollectionView)
        
        UIView.animate(withDuration: 0.7, delay: 0.0,
            usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0,
            options: .allowAnimatedContent, animations: {
            self.carouselCollectionView.center = self.view.center
        }) { (isFinished) in
            self.view.layoutIfNeeded()
        }
        
        carouselCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        carouselCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        carouselCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
        carouselCollectionView.heightAnchor.constraint(equalToConstant: 410).isActive = true
        //self.carouselCollectionView.center.y -= self.carouselCollectionView.frame.height
        
        carouselCollectionView.productsDelegate = self
        carouselCollectionView.set(cells: products)
    }
    
    public func closeProductsCarousel() {
        UIView.animate(withDuration: 0.4, delay: 0.0,
                       usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0,
            options: .allowAnimatedContent, animations: {
            self.carouselCollectionView.center = CGPoint(x: self.view.center.x,
            y: self.view.center.y + self.view.frame.size.height)
        }) { (isFinished) in
            self.tintBlurView.removeFromSuperview()
            self.carouselCollectionView.removeFromSuperview()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.continueTimer()
            }
        }
    }
    
    func didTapLinkIosOpeningExternal(url: String) {
        self.openUrl(link: url)
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
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StoryCollectionViewCell.cellId, for: indexPath) as? StoryCollectionViewCell else {return UICollectionViewCell()}
        let slide = stories[indexPath.section].slides[indexPath.row]
        cell.configure(slide: slide)
        cell.delegate = self
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
    func didTapUrlButton(url: String, slide: Slide) {
        self.openUrl(link: url)
        for (section, story) in stories.enumerated() {
            for (row, storySlide) in story.slides.enumerated() {
                if storySlide.id == slide.id {
                    self.trackClickSlide(index: IndexPath(row: row, section: section))
                }
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(continueTimer), name: Notification.Name("ContinueTimerWebKitClosed"), object: nil)
    }
}

extension UICollectionView {
    func isValid(indexPath: IndexPath) -> Bool {
        guard indexPath.section < numberOfSections,
              indexPath.row < numberOfItems(inSection: indexPath.section)
        else { return false }
        return true
    }
}
