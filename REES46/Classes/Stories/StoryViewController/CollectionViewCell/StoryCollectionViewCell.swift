import UIKit
import AVKit
import AVFoundation

protocol StoryCollectionViewCellDelegate: AnyObject {
    func didTapUrlButton(url: String, slide: Slide)
    func didTapOpenLinkExternalServiceMethod(url: String, slide: Slide)
    func sendStructSelectedStorySlide(storySlide: StoriesElement)
    func openProductsCarouselView(withProducts: [StoriesProduct])
    func closeProductsCarousel()
}

class StoryCollectionViewCell: UICollectionViewCell {
    
    static let cellId = "StoryCollectionViewCellId"
    
    let videoView = UIView()
    let imageView = UIImageView()
    let storyButton = StoryButton()
    let productsButton = ProductsButton()
    let muteButton = UIButton()
    
    private var selectedElement: StoriesElement?
    private var selectedProductsElement: StoriesElement?
    
    private var currentSlide: Slide?
    var cstHeightAnchor: NSLayoutConstraint!
    var cstBottomAnchor: NSLayoutConstraint!
    
    var pstHeightAnchor: NSLayoutConstraint!
    var pstBottomAnchor: NSLayoutConstraint!
    private var customConstraints = [NSLayoutConstraint]()
    
    public weak var cellDelegate: StoryCollectionViewCellDelegate?
    public weak var mainStoriesDelegate: StoriesViewLinkProtocol?
    
    var player = AVPlayer()
    private let timeObserverKeyPath: String = "timeControlStatus"
    fileprivate let kMinVolume = 0.00001
    fileprivate let kMaxVolume = 0.99999
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = .black //.white
        videoView.backgroundColor = .black
        
        NotificationCenter.default.addObserver(self, selector: #selector(pauseVideo(_:)), name: .init(rawValue: "PauseVideoLongTap"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playVideo(_:)), name: .init(rawValue: "PlayVideoLongTap"), object: nil)
        
        //player.addObserver(self, forKeyPath: timeObserverKeyPath, options: [.old, .new], context: nil)
        
        // videoView.contentMode = .scaleAspectFill
        videoView.contentMode = .scaleToFill
        videoView.isOpaque = true
        videoView.clearsContextBeforeDrawing = true
        videoView.autoresizesSubviews = true
        videoView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(videoView)
        
        //imageView.contentMode = .scaleAspectFill
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        //imageView.layer.cornerRadius = 5
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        storyButton.translatesAutoresizingMaskIntoConstraints = false
        storyButton.setTitle("Continue", for: .normal)
        storyButton.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
        addSubview(storyButton)
        
        productsButton.translatesAutoresizingMaskIntoConstraints = false
        productsButton.setTitle("Continue", for: .normal)
        productsButton.addTarget(self, action: #selector(didTapOnProductsButton), for: .touchUpInside)
        addSubview(productsButton)
        
        self.setMuteButtonToDefault()
        
        makeConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func clearConstraints() {
        customConstraints.forEach { $0.isActive = false }
        customConstraints.removeAll()
    }
    
    private func activate(constraints: [NSLayoutConstraint]) {
        customConstraints.append(contentsOf: constraints)
        customConstraints.forEach { $0.isActive = true }
    }
    
    func makeConstraints() {
        
        videoView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        videoView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        videoView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        videoView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        
        imageView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        imageView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        imageView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        imageView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        
        if GlobalHelper.sharedInstance.checkIfHasDynamicIsland() {
            
            clearConstraints()
            
            let ds : Bool = UserDefaults.standard.bool(forKey: "DoubleProductButtonSetting")
            if ds == true {
                let storyButtonConstraints = [
                    storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                    storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                    storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
                    storyButton.heightAnchor.constraint(equalToConstant: 56)
                ]
                
                var productsButtonConstraints = [
                    productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66),
                    productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66),
                    productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -89),
                    productsButton.heightAnchor.constraint(equalToConstant: 36)
                ]
                
                if GlobalHelper.DeviceType.IS_IPHONE_5 {
                    productsButtonConstraints = [
                        productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 52),
                        productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -52),
                        productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -89),
                        productsButton.heightAnchor.constraint(equalToConstant: 36)
                    ]
                }
                
                let muteButtonConstraints = [
                    muteButton.leadingAnchor.constraint(equalTo: storyButton.leadingAnchor, constant: -7),
                    //muteButton.centerYAnchor.constraint(equalTo: productsButton.centerYAnchor),
                    muteButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -83),
                    muteButton.widthAnchor.constraint(equalToConstant: 48),
                    muteButton.heightAnchor.constraint(equalToConstant: 48)
                ]
                
                self.activate(constraints: storyButtonConstraints)
                self.activate(constraints: productsButtonConstraints)
                self.activate(constraints: muteButtonConstraints)
            } else {
                let storyButtonConstraints = [
                    storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                    storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                    storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
                    storyButton.heightAnchor.constraint(equalToConstant: 56)
                ]
                
                var productsButtonConstraints = [
                    productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66),
                    productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66),
                    productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
                    productsButton.heightAnchor.constraint(equalToConstant: 36)
                ]
                
                if GlobalHelper.DeviceType.IS_IPHONE_5 {
                    productsButtonConstraints = [
                        productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 52),
                        productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -52),
                        productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
                        productsButton.heightAnchor.constraint(equalToConstant: 36)
                    ]
                }
                
                let muteButtonConstraints = [
                    muteButton.leadingAnchor.constraint(equalTo: storyButton.leadingAnchor, constant: -7),
                    muteButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -83),
                    muteButton.widthAnchor.constraint(equalToConstant: 48),
                    muteButton.heightAnchor.constraint(equalToConstant: 48)
                ]
                
                self.activate(constraints: storyButtonConstraints)
                self.activate(constraints: productsButtonConstraints)
                self.activate(constraints: muteButtonConstraints)
            }
            layoutIfNeeded()
            
        } else {

            clearConstraints()
            
            let ds : Bool = UserDefaults.standard.bool(forKey: "DoubleProductButtonSetting")
            if ds == true {
                let storyButtonConstraints = [
                    storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                    storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                    storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -22),
                    storyButton.heightAnchor.constraint(equalToConstant: 56)
                ]
                
                var productsButtonConstraints = [
                    productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66),
                    productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66),
                    productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -89),
                    productsButton.heightAnchor.constraint(equalToConstant: 36)
                ]
                
                if GlobalHelper.DeviceType.IS_IPHONE_5 {
                    productsButtonConstraints = [
                        productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 52),
                        productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -52),
                        productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -89),
                        productsButton.heightAnchor.constraint(equalToConstant: 36)
                    ]
                }
                
                let muteButtonConstraints = [
                    muteButton.leadingAnchor.constraint(equalTo: storyButton.leadingAnchor, constant: -7),
                    //muteButton.centerYAnchor.constraint(equalTo: productsButton.centerYAnchor),
                    muteButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -83),
                    muteButton.widthAnchor.constraint(equalToConstant: 48),
                    muteButton.heightAnchor.constraint(equalToConstant: 48)
                ]
                
                self.activate(constraints: storyButtonConstraints)
                self.activate(constraints: productsButtonConstraints)
                self.activate(constraints: muteButtonConstraints)
            } else {
                let storyButtonConstraints = [
                    storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                    storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                    storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -22),
                    storyButton.heightAnchor.constraint(equalToConstant: 56)
                ]
                
                var productsButtonConstraints = [
                    productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66),
                    productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66),
                    productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
                    productsButton.heightAnchor.constraint(equalToConstant: 36)
                ]
                
                if GlobalHelper.DeviceType.IS_IPHONE_5 {
                    productsButtonConstraints = [
                        productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 52),
                        productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -52),
                        productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
                        productsButton.heightAnchor.constraint(equalToConstant: 36)
                    ]
                }
                
                let muteButtonConstraints = [
                    muteButton.leadingAnchor.constraint(equalTo: storyButton.leadingAnchor, constant: -7),
                    muteButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -83),
                    muteButton.widthAnchor.constraint(equalToConstant: 48),
                    muteButton.heightAnchor.constraint(equalToConstant: 48)
                ]
                
                self.activate(constraints: storyButtonConstraints)
                self.activate(constraints: productsButtonConstraints)
                self.activate(constraints: muteButtonConstraints)
            }
            layoutIfNeeded()
        }
    }
    
    @objc private func didTapOnMute() {
        var mainBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        mainBundle = Bundle.module
#endif
        if player.volume == 1.0 {
            player.volume = 0.0
            muteButton.setImage(UIImage(named: "iconStoryMute", in: mainBundle, compatibleWith: nil), for: .normal)
            UserDefaults.standard.set(false, forKey: "MuteSoundSetting")
        } else {
            player.volume = 1.0
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            } catch let error {
                print("Error in AVAudio Session\(error.localizedDescription)")
            }
            
            muteButton.setImage(UIImage(named: "iconStoryVolumeUp", in: mainBundle, compatibleWith: nil), for: .normal)
            UserDefaults.standard.set(true, forKey: "MuteSoundSetting")
        }
    }
    
    @objc
    private func pauseVideo(_ notification: NSNotification) {
        if let slideID = notification.userInfo?["slideID"] as? Int {
            if let currentSlide = currentSlide {
                if currentSlide.id == slideID {
                    player.pause()
                }
            }
        }
    }
    
    @objc
    private func playVideo(_ notification: NSNotification) {
        if let slideID = notification.userInfo?["slideID"] as? Int {
            if let currentSlide = currentSlide {
                if currentSlide.id == slideID {
                    player.play()
                }
            }
        }
    }
    
    private func setMuteButtonToDefault() {
        var mainBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        mainBundle = Bundle.module
#endif
        
        let soundSetting : Bool = UserDefaults.standard.bool(forKey: "MuteSoundSetting")
        if soundSetting == true {
            player.volume = 1
            muteButton.setImage(UIImage(named: "iconStoryVolumeUp", in: mainBundle, compatibleWith: nil), for: .normal)
            UserDefaults.standard.set(true, forKey: "MuteSoundSetting")
        } else {
            player.volume = 0
            muteButton.setImage(UIImage(named: "iconStoryMute", in: mainBundle, compatibleWith: nil), for: .normal)
            UserDefaults.standard.set(false, forKey: "MuteSoundSetting")
        }
        
        muteButton.translatesAutoresizingMaskIntoConstraints = false
        muteButton.isHidden = true
        muteButton.addTarget(self, action: #selector(didTapOnMute), for: .touchUpInside)
        addSubview(muteButton)
    }
    
    public func configure(slide: Slide) {
        self.currentSlide = slide
        if slide.type == .video {
//            if let preview = slide.previewImage {
//                DispatchQueue.main.async {
//                    self.imageView.image = preview
//                    self.videoView.isHidden = true
//                    self.imageView.isHidden = false
//                }
//            }

            videoView.isHidden = false
            imageView.isHidden = true

            self.videoView.layer.sublayers?.forEach {
                if $0.name == "VIDEO" {
                    $0.removeFromSuperlayer()
                }
            }
            if let videoURL = slide.videoURL {
                videoView.isHidden = false
                imageView.isHidden = true

                let asset = AVAsset(url: videoURL)
                let volume = AVAudioSession.sharedInstance().outputVolume
                print("output volume: \(volume)")
//                if (volume < Float(kMinVolume)) {
//                    player.volume = 0
//                } else if (volume >= Float(kMinVolume)) {
//                    player.volume = 1
//                }
                
                let playerItem = AVPlayerItem(asset: asset)
                self.player = AVPlayer(playerItem: playerItem)
                let playerLayer = AVPlayerLayer(player: player)
                let screenSize = UIScreen.main.bounds.size
                playerLayer.frame = CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height)
                playerLayer.name = "VIDEO"
                //playerLayer.videoGravity = .resizeAspectFill
                
                if playerItem.asset.tracks.filter({$0.mediaType == .audio}).count != 0 {
                    var mainBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
                    mainBundle = Bundle.module
#endif
                    let soundSetting : Bool = UserDefaults.standard.bool(forKey: "MuteSoundSetting")
                    if soundSetting == true {
                        player.volume = 1
                        muteButton.setImage(UIImage(named: "iconStoryVolumeUp", in: mainBundle, compatibleWith: nil), for: .normal)
                        UserDefaults.standard.set(true, forKey: "MuteSoundSetting")
                        
                        do {
                            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
                        } catch let error {
                            print("Error in AVAudio Session\(error.localizedDescription)")
                        }
                    } else {
                        player.volume = 0
                        muteButton.setImage(UIImage(named: "iconStoryMute", in: mainBundle, compatibleWith: nil), for: .normal)
                        UserDefaults.standard.set(false, forKey: "MuteSoundSetting")
                    }
                    muteButton.isHidden = false
                } else {
                    muteButton.isHidden = true
                }
                self.videoView.layer.addSublayer(playerLayer)
                player.play()
                UserDefaults.standard.set(Int(currentSlide!.id), forKey: "LastViewedSlideMemorySetting")
            } else {
                muteButton.isHidden = true
                imageView.isHidden = false
                videoView.isHidden = true
                if let preview = slide.previewImage {
                    self.imageView.image = preview //.withRoundedCorners(radius: 14)
                }
            }
        } else {
            
            muteButton.isHidden = true
            imageView.isHidden = false
            videoView.isHidden = true
            if let image = slide.downloadedImage {
                self.imageView.image = image //.withRoundedCorners(radius: 14)
            }
        }
        
        if let element = slide.elements.first(where: {$0.type == .button}) {
            UserDefaults.standard.set(false, forKey: "DoubleProductButtonSetting")
            selectedElement = element
            storyButton.configButton(buttonData: element)
            storyButton.isHidden = false
            productsButton.isHidden = true
            
            makeConstraints()
            
            if let elementProduct = slide.elements.last(where: {$0.type == .products}) {
                UserDefaults.standard.set(true, forKey: "DoubleProductButtonSetting")
                selectedProductsElement = elementProduct
                productsButton.layer.cornerRadius = layer.frame.size.height / 2
                productsButton.layer.masksToBounds = true
                
                storyButton.configButton(buttonData: element)
                productsButton.configProductsButton(buttonData: elementProduct)
                productsButton.isHidden = false
                
                makeConstraints()
                return
            } else {
                UserDefaults.standard.set(false, forKey: "DoubleProductButtonSetting")
                storyButton.configButton(buttonData: element)
                makeConstraints()
            }
            
        } else if let element = slide.elements.first(where: {$0.type == .products}) {
            UserDefaults.standard.set(false, forKey: "DoubleProductButtonSetting")
            selectedProductsElement = element
            productsButton.layer.cornerRadius = layer.frame.size.height / 2
            productsButton.layer.masksToBounds = true
            productsButton.configProductsButton(buttonData: element)
            productsButton.isHidden = false
            
            storyButton.configButton(buttonData: element)
            storyButton.isHidden = true
            
            makeConstraints()
        } else {
            UserDefaults.standard.set(false, forKey: "DoubleProductButtonSetting")
            storyButton.isHidden = true
            productsButton.isHidden = true
            makeConstraints()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

//        if keyPath == "timeControlStatus",
//           let change = change,
//           let newValue = change[NSKeyValueChangeKey.newKey] as? Int,
//           let oldValue = change[NSKeyValueChangeKey.oldKey] as? Int {
//
//            let oldStatus = AVPlayer.TimeControlStatus(rawValue: oldValue)
//            let newStatus = AVPlayer.TimeControlStatus(rawValue: newValue)
//            print(oldStatus?.rawValue)
//            if newStatus != oldStatus {
//                if newStatus == .playing {
//                    player.seek(to: .zero)
//                    player.removeObserver(self, forKeyPath: timeObserverKeyPath)
//                    //delegate?.videoLoaded()
//                } else if newStatus == .waitingToPlayAtSpecifiedRate {
//                    player.seek(to: .zero)
//                    player.removeObserver(self, forKeyPath: timeObserverKeyPath)
//                    player.play()
//                }
//            }
//        }
        
//        if object as AnyObject? === videoView.snapVideo.currentItem && keyPath == "status" {
//            if videoView.status == .readyToPlay  && isViewInFocus && isCompletelyVisible {
//                videoView.play()
//                print("StoryCell: Ready to play video")
//            }
//        }
//
//        if object as AnyObject? === videoView.snapVideo && keyPath == "timeControlStatus" {
//            if videoView.snapVideo.timeControlStatus == .playing && isViewInFocus && isCompletelyVisible {
//                print("StoryCell : timeControlStatus == .playing")
//                var videoDuration: Double = 5
//                if let currentItem = videoView.snapVideo.currentItem {
//                    videoDuration = currentItem.duration.seconds
//                }
//                startAnimatingStory(duration: videoDuration)
//                print("StoryCell: Video started animating")
//            }
//        }
    }
    
    func stopPlayer() {
        player.pause()
    }
    
    @objc
    private func didTapOnProductsButton() {
        if let productsList = selectedProductsElement?.products, productsList.count != 0 {
            UserDefaults.standard.set(Int(currentSlide!.id), forKey: "LastViewedSlideMemorySetting")
            let products = productsList
            cellDelegate?.openProductsCarouselView(withProducts: products)
            return
        }
    }
    
    @objc
    private func didTapButton() {
        if let linkIos = selectedElement?.linkIos, !linkIos.isEmpty {
            if let currentSlide = currentSlide {
                
                UserDefaults.standard.set(Int(currentSlide.id), forKey: "LastViewedSlideMemorySetting")
                
                cellDelegate?.sendStructSelectedStorySlide(storySlide: selectedElement!)
                cellDelegate?.didTapOpenLinkExternalServiceMethod(url: linkIos, slide: currentSlide)
                return
            }
        }
        
        if let link = selectedElement?.link, !link.isEmpty {
            if let currentSlide = currentSlide {
                cellDelegate?.didTapUrlButton(url: link, slide: currentSlide)
                return
            }
        }
    }
    
    private func setImage(imagePath: String) {
        guard let url = URL(string: imagePath) else {
            return
        }

        let task = URLSession.shared.dataTask(with: url, completionHandler: { data, _, error in
            if error == nil {
                guard let unwrappedData = data, let image = UIImage(data: unwrappedData) else { return }
                DispatchQueue.main.async {
                    self.imageView.image = image //.withRoundedCorners(radius: 14)
                }
            }
        })
        task.resume()
    }
}

extension AVPlayer {
    var isAudioAvailable: Bool? {
        return self.currentItem?.asset.tracks.filter({$0.mediaType == .audio}).count != 0
    }

    var isVideoAvailable: Bool? {
        return self.currentItem?.asset.tracks.filter({$0.mediaType == .video}).count != 0
    }
}
