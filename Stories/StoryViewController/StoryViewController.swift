//
//  StoryViewController.swift
//  FirebaseCore
//
//  Created by Arseniy Dorogin on 17.08.2022.
//

import UIKit

class StoryViewController: UIViewController, UIGestureRecognizerDelegate {
    private var collectionView: UICollectionView = {
        let testFrame = CGRect(x: 0, y: 0, width: 300, height: 100)
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 100, height: 130)
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        let collectionView = UICollectionView(frame: testFrame, collectionViewLayout: layout)
        collectionView.isPagingEnabled = true
        collectionView.isScrollEnabled = false
        collectionView.backgroundColor = .black
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
//        collectionView.isScrollEnabled = false
        if #available(iOS 10.0, *) {
            collectionView.isPrefetchingEnabled = false
        }
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
    
    public var sdk: PersonalizationSDK?

    override func viewDidLoad() {
        super.viewDidLoad()
        commonInit()
        setupLongGestureRecognizerOnCollection()
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc
    func willEnterForeground() {
        print("WILL ENTER")
        continueTimer()
    }

    @objc
    func didEnterBackground() {
        print("DID ENTER")
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

        NSLayoutConstraint(item: pageIndicator, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1, constant: 40).isActive = true

        NSLayoutConstraint(item: pageIndicator, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 8).isActive = true
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint(item: closeButton, attribute: NSLayoutConstraint.Attribute.right, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.right, multiplier: 1, constant: -10).isActive = true
        NSLayoutConstraint(item: closeButton, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: pageIndicator, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: 1, constant: 10).isActive = true
        NSLayoutConstraint(item: closeButton, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 30).isActive = true
        NSLayoutConstraint(item: closeButton, attribute: NSLayoutConstraint.Attribute.height, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: 30).isActive = true


        configureView()
        closeButton.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)
        
        
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(didSwipeLeft))
        leftSwipe.direction = .left
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(didSwipeRight))
        rightSwipe.direction = .right
        
        collectionView.addGestureRecognizer(leftSwipe)
        collectionView.addGestureRecognizer(rightSwipe)
    }
    
    @objc
    func didSwipeLeft() {
        if currentPosition.section >= stories.count - 1 {
            self.dismiss(animated: true)
        } else if currentPosition.section < stories.count - 1 {
            currentPosition.section += 1
            currentPosition.row = 0
            collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)

            DispatchQueue.main.async {
                self.updateSlides()
            }
        }
//        if currentPosition.row < stories[currentPosition.section].slides.count - 1 {
//            currentPosition.row += 1
//            collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
//            DispatchQueue.main.async {
//                self.updateSlides()
//            }
//        } else if currentPosition.section > stories.count - 1 {
//            self.dismiss(animated: true)
//            // break
//        } else if currentPosition.section < stories.count - 1 {
//            currentPosition.section += 1
//            currentPosition.row = 0
//            collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
//
//            DispatchQueue.main.async {
//                self.updateSlides()
//            }
//        }
    }
    
    @objc
    func didSwipeRight() {
        if currentPosition.section > 0 {
            currentPosition.section -= 1
            currentPosition.row = 0
            collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)

            DispatchQueue.main.async {
                self.updateSlides()
            }
        }
//        if currentPosition.row > 0 {
//            currentPosition.row -= 1
//            collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
//            DispatchQueue.main.async {
//                self.updateSlides()
//            }
//        } else if currentPosition.section > 0 {
//            currentPosition.section -= 1
//            currentPosition.row = stories[currentPosition.section].slides.count - 1
//            collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
//
//            DispatchQueue.main.async {
//                self.updateSlides()
//            }
//        }
    }

    private func configureView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        let bundle = Bundle(for: classForCoder)
        closeButton.setImage(UIImage(named: "iconClose", in: bundle, compatibleWith: nil), for: .normal)

        let nib = UINib(nibName: "StoryCollectionViewCell", bundle: bundle)
        collectionView.register(nib, forCellWithReuseIdentifier: "StoryCollectionViewCell")
        updateSlides()
    }

    @objc
    func didTapCloseButton() {
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
        timer.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(updateTime), userInfo: nil, repeats: true)
    }

    @objc func updateTime() {
        if timeLeft > 0 {
            timeLeft = endTime?.timeIntervalSinceNow ?? 0
            currentProgressView?.progress = 1 - Float(timeLeft) / currentDuration
        } else {
            currentProgressView?.progress = 0
            timer.invalidate()
            if currentPosition.row < stories[currentPosition.section].slides.count - 1 {
                currentPosition.row += 1
                collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
                DispatchQueue.main.async {
                    self.updateSlides()
                }
            } else if currentPosition.section >= stories.count - 1 {
                self.dismiss(animated: true)
            } else if currentPosition.section < stories.count - 1 {
                currentPosition.section += 1
                currentPosition.row = 0
                collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)

                DispatchQueue.main.async {
                    self.updateSlides()
                }
            }
        }
    }
    
    private func openUrl(link: String) {
        if let url = URL(string: link) {
            if #available(iOS 10.0, *) {
                pauseTimer()
                UIApplication.shared.open(url)
            } else {
                // Fallback on earlier versions
            }
        }
    }
    
    private func pauseTimer() {
        timer.invalidate()
    }
    
    private func continueTimer() {
        endTime = Date().addingTimeInterval(timeLeft)
        timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(updateTime), userInfo: nil, repeats: true)
    }
    
    private func trackViewSlide(index: IndexPath) {
        let storyId = String(stories[index.section].id)
        let slideId = String(stories[index.section].slides[index.row].id)
//        sdk?.track(event: .slideView(storyId: storyId, slideId: slideId), recommendedBy: nil, completion: { result in
//        })
    }
    
    private func trackClickSlide(index: IndexPath) {
        let storyId = String(stories[index.section].id)
        let slideId = String(stories[index.section].slides[index.row].id)
//        sdk?.track(event: .slideClick(storyId: storyId, slideId: slideId), recommendedBy: nil, completion: { result in
//        })
        
    }
    
    private func setupLongGestureRecognizerOnCollection() {
        let longPressedGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(gestureRecognizer:)))
        longPressedGesture.minimumPressDuration = 0.2
        longPressedGesture.delegate = self
        longPressedGesture.delaysTouchesBegan = true
        collectionView.addGestureRecognizer(longPressedGesture)
    }

    @objc func handleLongPress(gestureRecognizer: UILongPressGestureRecognizer) {
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
}

extension StoryViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        stories.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        stories[section].slides.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StoryCollectionViewCell", for: indexPath) as! StoryCollectionViewCell
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

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
//        timer.invalidate()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if currentPosition.row < stories[currentPosition.section].slides.count - 1 {
            currentPosition.row += 1
            collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)
            DispatchQueue.main.async {
                self.updateSlides()
            }
        } else if currentPosition.section >= stories.count - 1 {
            // break
            self.dismiss(animated: true)
        } else if currentPosition.section < stories.count - 1 {
            currentPosition.section += 1
            currentPosition.row = 0
            collectionView.scrollToItem(at: currentPosition, at: .left, animated: true)

            DispatchQueue.main.async {
                self.updateSlides()
            }
        }
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
    func didTapUrlButton(url: String, slide: StorySlide) {
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
        else { return false }
        return true
    }
}
