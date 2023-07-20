import UIKit
import AVKit
import AVFoundation

protocol StoryCollectionViewCellDelegate: AnyObject {
    func didTapUrlButton(url: String, slide: Slide)
    func didTapOpenLinkIosExternalWeb(url: String, slide: Slide)
    func sendProductStructForExternal(product: StoriesElement)
    
    func openProductsCarousel(products: [StoriesProduct])
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
    private var currentSlide: Slide?
    
    public weak var delegate: StoryCollectionViewCellDelegate?
    public weak var mainStoriesDelegate: StoriesViewMainProtocol?
    
    var player = AVPlayer()
    private let timeObserverKeyPath: String = "timeControlStatus"
    fileprivate let kMinVolume = 0.00001
    fileprivate let kMaxVolume = 0.99999
    
    var preloader = StoriesRingView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = .black //.white
        videoView.backgroundColor = .black
        
        NotificationCenter.default.addObserver(self, selector: #selector(pauseVideo(_:)), name: .init(rawValue: "PauseVideoLongTap"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playVideo(_:)), name: .init(rawValue: "PlayVideoLongTap"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showSpinnner(_:)), name: .init(rawValue: "NeedLongSpinnerShow"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hideSpinnner(_:)), name: .init(rawValue: "NeedLongSpinnerHide"), object: nil)
        
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
        productsButton.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
        addSubview(productsButton)
        
        self.setMuteButtonToDefault()
        
        //preloader = StoriesRingLoader.createStoriesLoader()
        //preloader.startPreloaderAnimation()
        
        makeConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func makeConstraints(){
        videoView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        videoView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        videoView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        videoView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        
        imageView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        imageView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        imageView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        imageView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        
        if GlobalHelper.sharedInstance.checkIfHasDynamicIsland() {
            storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16).isActive = true
            storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16).isActive = true
            storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18).isActive = true
            storyButton.heightAnchor.constraint(equalToConstant: 56).isActive = true
            
            let ds : Bool = UserDefaults.standard.bool(forKey: "doubleProductsConfig")
            if ds == true {
                productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -90).isActive = true
                productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 90).isActive = true
                productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -96).isActive = true
                productsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
            } else {
                productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66).isActive = true
                productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66).isActive = true
                productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28).isActive = true
                productsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
            }
        } else {
            storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16).isActive = true
            storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16).isActive = true
            storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -22).isActive = true
            storyButton.heightAnchor.constraint(equalToConstant: 60).isActive = true
            
            let ds : Bool = UserDefaults.standard.bool(forKey: "doubleProductsConfig")
            if ds == true {
                productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66).isActive = true
                productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66).isActive = true
                productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -97).isActive = true
                productsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
            } else {
                productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66).isActive = true
                productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66).isActive = true
                productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28).isActive = true
                productsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
            }
            
            if GlobalHelper.DeviceType.IS_IPHONE_XS_MAX {
                storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16).isActive = true
                storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16).isActive = true
                storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18).isActive = true
                storyButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
            }
        }
        
        muteButton.leadingAnchor.constraint(equalTo: storyButton.leadingAnchor, constant: -7).isActive = true
        muteButton.bottomAnchor.constraint(equalTo: storyButton.bottomAnchor, constant: -70).isActive = true
        muteButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
        muteButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
    }
    
    @objc private func didTapOnMute() {
        var mainBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        mainBundle = Bundle.module
#endif
        if player.volume == 1.0 {
            player.volume = 0.0
            muteButton.setImage(UIImage(named: "iconStoryMute", in: mainBundle, compatibleWith: nil), for: .normal)
            UserDefaults.standard.set(false, forKey: "soundSetting")
        } else {
            player.volume = 1.0
            muteButton.setImage(UIImage(named: "iconStoryVolumeUp", in: mainBundle, compatibleWith: nil), for: .normal)
            UserDefaults.standard.set(true, forKey: "soundSetting")
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
        //preloader.stopPreloaderAnimation()
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
        
        let soundSetting : Bool = UserDefaults.standard.bool(forKey: "soundSetting")
        if soundSetting == true {
            player.volume = 1
            muteButton.setImage(UIImage(named: "iconStoryVolumeUp", in: mainBundle, compatibleWith: nil), for: .normal)
            UserDefaults.standard.set(true, forKey: "soundSetting")
        } else {
            player.volume = 0
            muteButton.setImage(UIImage(named: "iconStoryMute", in: mainBundle, compatibleWith: nil), for: .normal)
            UserDefaults.standard.set(false, forKey: "soundSetting")
        }
        
        muteButton.translatesAutoresizingMaskIntoConstraints = false
        muteButton.isHidden = true
        muteButton.addTarget(self, action: #selector(didTapOnMute), for: .touchUpInside)
        addSubview(muteButton)
    }
    
    public func configure(slide: Slide) {
//        setButtonToDefault()
        
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
                    let soundSetting : Bool = UserDefaults.standard.bool(forKey: "soundSetting")
                    if soundSetting == true {
                        player.volume = 1
                        muteButton.setImage(UIImage(named: "iconStoryVolumeUp", in: mainBundle, compatibleWith: nil), for: .normal)
                        UserDefaults.standard.set(true, forKey: "soundSetting")
                        
                        do {
                            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
                        } catch let error {
                            print("Error in AVAudio Session\(error.localizedDescription)")
                        }
                    } else {
                        player.volume = 0
                        muteButton.setImage(UIImage(named: "iconStoryMute", in: mainBundle, compatibleWith: nil), for: .normal)
                        UserDefaults.standard.set(false, forKey: "soundSetting")
                    }
                    muteButton.isHidden = false
                } else {
                    muteButton.isHidden = true
                }
                self.videoView.layer.addSublayer(playerLayer)
                player.play()
            } else {
                muteButton.isHidden = true
                imageView.isHidden = false
                videoView.isHidden = true
                if let preview = slide.previewImage {
                    self.imageView.image = preview
                }
            }
        } else {
            //preloader.startPreloaderAnimation()
            
            muteButton.isHidden = true
            imageView.isHidden = false
            videoView.isHidden = true
            if let image = slide.downloadedImage {
                self.imageView.image = image
            }
        }
        
        if let element = slide.elements.first(where: {$0.type == .button}) {
            
            UserDefaults.standard.set(false, forKey: "doubleProductsConfig")
            
            selectedElement = element
            storyButton.configButton(buttonData: element)
            storyButton.isHidden = false
            productsButton.isHidden = true
            
            //TEST
//            productsButton.layer.cornerRadius = layer.frame.size.height / 2
//            productsButton.layer.masksToBounds = true
//
//            productsButton.configProductsButton(buttonData: element)
//            productsButton.isHidden = false
//            makeConstraints()
            //TEST
            
            if let element = slide.elements.first(where: {$0.type == .products}) {
                UserDefaults.standard.set(true, forKey: "doubleProductsConfig")
                productsButton.layer.cornerRadius = layer.frame.size.height / 2
                productsButton.layer.masksToBounds = true
                productsButton.configProductsButton(buttonData: element)
                productsButton.isHidden = false
                makeConstraints()
                return
            }
            
        } else if let element = slide.elements.first(where: {$0.type == .products}) {
            UserDefaults.standard.set(false, forKey: "doubleProductsConfig")
            selectedElement = element
            productsButton.layer.cornerRadius = layer.frame.size.height / 2
            productsButton.layer.masksToBounds = true
            
            
            //storyButton.configButton(buttonData: element)
            storyButton.isHidden = true
            
            productsButton.configProductsButton(buttonData: element)
            productsButton.isHidden = false
            
            makeConstraints()
        } else {
            UserDefaults.standard.set(false, forKey: "doubleProductsConfig")
            storyButton.isHidden = true
            productsButton.isHidden = true
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
    private func didTapButton() {
        
        if let productsList = selectedElement?.products, productsList.count != 0 {
            let products = productsList
            delegate?.openProductsCarousel(products: products)
            return
        }
        
        if let linkIos = selectedElement?.linkIos, !linkIos.isEmpty {
            if let currentSlide = currentSlide {
                
                mainStoriesDelegate?.structOfSelectedProduct(product: selectedElement!)
                mainStoriesDelegate?.extendLinkIos(url: linkIos)
                
                delegate?.didTapOpenLinkIosExternalWeb(url: linkIos, slide: currentSlide)
                delegate?.sendProductStructForExternal(product: selectedElement!)
                
                return
            }
        }
        
        if let link = selectedElement?.link, !link.isEmpty {
            if let currentSlide = currentSlide {
                delegate?.didTapUrlButton(url: link, slide: currentSlide)
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
                    self.imageView.image = image
                }
            }
        })
        task.resume()
    }

    @objc
    private func showSpinnner(_ notification: NSNotification) {
        //preloader.startPreloaderAnimation()
    }
    
    @objc
    private func hideSpinnner(_ notification: NSNotification) {
        //preloader.stopPreloaderAnimation()
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
