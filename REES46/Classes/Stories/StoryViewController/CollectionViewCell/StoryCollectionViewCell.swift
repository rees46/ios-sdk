import UIKit
import AVKit
import AVFoundation

protocol StoryCollectionViewCellDelegate: AnyObject {
    func didTapUrlButton(url: String, slide: Slide)
    func didTapOpenLinkIosExternalWeb(url: String, slide: Slide)
    func openProductsCarousel(products: [StoriesProduct])
    func closeProductsCarousel()
}

class StoryCollectionViewCell: UICollectionViewCell {
    
    static let cellId = "StoryCollectionViewCellId"
    
    let videoView = UIView()
    let imageView = UIImageView()
    let storyButton = StoryButton()
    let productsButton = ProductsButton()
//    let muteButton = UIButton()
    
    private var selectedElement: StoriesElement?
    private var currentSlide: Slide?
    
    public weak var delegate: StoryCollectionViewCellDelegate?
    public weak var mainStoriesDelegate: StoriesViewMainProtocol?
    
    var player = AVPlayer()
    private let timeObserverKeyPath: String = "timeControlStatus"
    
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
        
        videoView.contentMode = .scaleToFill
        videoView.isOpaque = true
        videoView.clearsContextBeforeDrawing = true
        videoView.autoresizesSubviews = true
        videoView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(videoView)
        
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
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
        
//        let bundle = Bundle(for: classForCoder)
//        muteButton.setImage(UIImage(named: "iconStoryVolumeUp", in: bundle, compatibleWith: nil), for: .normal)
//        muteButton.translatesAutoresizingMaskIntoConstraints = false
//        muteButton.isHidden = true
//        muteButton.addTarget(self, action: #selector(didTapOnMute), for: .touchUpInside)
//        addSubview(muteButton)
        
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
            
            productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66).isActive = true
            productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66).isActive = true
            productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28).isActive = true
            productsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        } else {
            storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16).isActive = true
            storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16).isActive = true
            storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -22).isActive = true
            storyButton.heightAnchor.constraint(equalToConstant: 60).isActive = true
            
            productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -66).isActive = true
            productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 66).isActive = true
            productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28).isActive = true
            productsButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
            
            if GlobalHelper.DeviceType.IS_IPHONE_XS_MAX {
                storyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16).isActive = true
                storyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16).isActive = true
                storyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18).isActive = true
                storyButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
            }
        }
    }
    
//    @objc private func didTapOnMute() {
//        let bundle = Bundle(for: classForCoder)
//        if player.volume == 1.0 {
//            player.volume = 0.0
//            muteButton.setImage(UIImage(named: "iconStoryMute", in: bundle, compatibleWith: nil), for: .normal)
//        } else {
//            player.volume = 1.0
//            muteButton.setImage(UIImage(named: "iconStoryVolumeUp", in: bundle, compatibleWith: nil), for: .normal)
//        }
//    }
    
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
    
//    private func setButtonToDefault() {
//        let bundle = Bundle(for: classForCoder)
//        muteButton.setImage(UIImage(named: "iconStoryVolumeUp", in: bundle, compatibleWith: nil), for: .normal)
//    }
    
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
                //muteButton.isHidden = false
                videoView.isHidden = false
                imageView.isHidden = true

                let asset = AVAsset(url: videoURL)
//                let length = Float(asset.duration.value)/Float(asset.duration.timescale)
//                if length != 0.0  {
//                } else {
//                }
                
                let playerItem = AVPlayerItem(asset: asset)
                self.player = AVPlayer(playerItem: playerItem)
                let playerLayer = AVPlayerLayer(player: player)
                player.volume = 1
                let screenSize = UIScreen.main.bounds.size
                playerLayer.frame = CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height)
                playerLayer.name = "VIDEO"
                self.videoView.layer.addSublayer(playerLayer)
                player.play()
            } else {
                //muteButton.isHidden = true
                imageView.isHidden = false
                videoView.isHidden = true
                if let preview = slide.previewImage {
                    self.imageView.image = preview
                }
            }
        } else {
            //preloader.startPreloaderAnimation()
            
            //muteButton.isHidden = true
            imageView.isHidden = false
            videoView.isHidden = true
            if let image = slide.downloadedImage {
                self.imageView.image = image
            }
        }

        if let element = slide.elements.first(where: {$0.type == .button}) {
            selectedElement = element
            storyButton.configButton(buttonData: element)
            storyButton.isHidden = false
            productsButton.isHidden = true
        } else if let element = slide.elements.first(where: {$0.type == .products}) {
            selectedElement = element
            productsButton.layer.cornerRadius = layer.frame.size.height / 2
            productsButton.layer.masksToBounds = true
            productsButton.configProductsButton(buttonData: element)
            storyButton.isHidden = true
            productsButton.isHidden = false
        } else {
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
                delegate?.didTapOpenLinkIosExternalWeb(url: linkIos, slide: currentSlide)
                mainStoriesDelegate?.extendLinkIos(url: linkIos)
                (UIApplication.shared.delegate as? StoriesAppDelegateProtocol)?.didTapLinkIosOpeningForAppDelegate(url: linkIos)
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
