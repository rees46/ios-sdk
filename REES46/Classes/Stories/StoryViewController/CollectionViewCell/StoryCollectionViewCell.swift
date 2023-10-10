import UIKit
import AVKit
import AVFoundation

protocol StoryCollectionViewCellDelegate: AnyObject {
    func didTapUrlButton(url: String, slide: Slide)
    func didTapOpenLinkExternalServiceMethod(url: String, slide: Slide)
    func sendStructSelectedStorySlide(storySlide: StoriesElement)
    func openProductsCarouselView(withProducts: [StoriesProduct], hideLabel: String)
    func closeProductsCarousel()
}

class StoryCollectionViewCell: UICollectionViewCell {
    
    static let cellId = "StoryCollectionViewCellId"
    
    let videoView = UIView()
    let storySlideImageView = UIImageView()
    let storyButton = StoryButton()
    let productsButton = ProductsButton()
    let muteButton = UIButton()
    
    private var currentSlide: Slide?
    private var selectedElement: StoriesElement?
    private var selectedProductsElement: StoriesElement?
    private var selectedPromoElement: StoriesPromoElement?
    
    public let productWithPromocodeSuperview = PromoCodeView()
    public let promocodeBannerView = PromocodeBanner(location: PromocodeBannerLocation.bottomLeft)
    public let sdkPopupAlertView = SdkPopupAlertView(title: SdkConfiguration.stories.defaultCopiedMessage)
    
    public weak var cellDelegate: StoryCollectionViewCellDelegate?
    public weak var mainStoriesDelegate: StoriesViewLinkProtocol?
    
    private var customConstraints = [NSLayoutConstraint]()
    
    var player = AVPlayer()
    private let timeObserverKeyPath: String = "timeControlStatus"
    fileprivate let kMinVolume = 0.00001
    fileprivate let kMaxVolume = 0.99999
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        if currentSlide?.backgroundColor != nil {
            //let color = currentSlide?.backgroundColor.hexToRGB()
            //self.backgroundColor = UIColor(red: color!.red, green: color!.green, blue: color!.blue, alpha: 1)
        } else {
            self.backgroundColor = .black
        }
        videoView.backgroundColor = .black
        
        NotificationCenter.default.addObserver(self, selector: #selector(pauseVideo(_:)), name: .init(rawValue: "PauseVideoLongTap"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playVideo(_:)), name: .init(rawValue: "PlayVideoLongTap"), object: nil)
        
        videoView.contentMode = .scaleToFill //.scaleAspectFill
        videoView.isOpaque = true
        videoView.clearsContextBeforeDrawing = true
        videoView.autoresizesSubviews = true
        videoView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(videoView)
        
        storySlideImageView.contentMode = .scaleAspectFit
        storySlideImageView.clipsToBounds = true
        storySlideImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(storySlideImageView)
        
        productWithPromocodeSuperview.translatesAutoresizingMaskIntoConstraints = false
        productWithPromocodeSuperview.isHidden = true
        productWithPromocodeSuperview.autoresizesSubviews = true
        addSubview(productWithPromocodeSuperview)
        
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
        
        storySlideImageView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        storySlideImageView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        storySlideImageView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        storySlideImageView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        
        productWithPromocodeSuperview.topAnchor.constraint(equalTo: topAnchor).isActive = true
        productWithPromocodeSuperview.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        productWithPromocodeSuperview.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        productWithPromocodeSuperview.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        
        if SdkGlobalHelper.sharedInstance.willDeviceHaveDynamicIsland() {
            
            clearConstraints()
            let ds: Bool = UserDefaults.standard.bool(forKey: "DoubleProductButtonSetting")
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
                if SdkGlobalHelper.DeviceType.IS_IPHONE_5 {
                    productsButtonConstraints = [
                        productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 52),
                        productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -52),
                        productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -89),
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
                if SdkGlobalHelper.DeviceType.IS_IPHONE_5 {
                    productsButtonConstraints = [
                        productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 52),
                        productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -52),
                        productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
                        productsButton.heightAnchor.constraint(equalToConstant: 36)
                    ]
                }
                
                var muteButtonConstraints = [
                    muteButton.leadingAnchor.constraint(equalTo: storyButton.leadingAnchor, constant: -7),
                    muteButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -83),
                    muteButton.widthAnchor.constraint(equalToConstant: 48),
                    muteButton.heightAnchor.constraint(equalToConstant: 48)
                ]
                if selectedPromoElement != nil {
                    muteButtonConstraints = [
                        muteButton.leadingAnchor.constraint(equalTo: storyButton.leadingAnchor, constant: -7),
                        muteButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -163),
                        muteButton.widthAnchor.constraint(equalToConstant: 48),
                        muteButton.heightAnchor.constraint(equalToConstant: 48)
                    ]
                }
                
                self.activate(constraints: storyButtonConstraints)
                self.activate(constraints: productsButtonConstraints)
                self.activate(constraints: muteButtonConstraints)
            }
            layoutIfNeeded()
            
        } else {

            clearConstraints()
            
            let ds: Bool = UserDefaults.standard.bool(forKey: "DoubleProductButtonSetting")
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
                if SdkGlobalHelper.DeviceType.IS_IPHONE_5 {
                    productsButtonConstraints = [
                        productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 52),
                        productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -52),
                        productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -89),
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
                if SdkGlobalHelper.DeviceType.IS_IPHONE_5 {
                    productsButtonConstraints = [
                        productsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 52),
                        productsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -52),
                        productsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
                        productsButton.heightAnchor.constraint(equalToConstant: 36)
                    ]
                }
                
                var muteButtonConstraints = [
                    muteButton.leadingAnchor.constraint(equalTo: storyButton.leadingAnchor, constant: -7),
                    muteButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -83),
                    muteButton.widthAnchor.constraint(equalToConstant: 48),
                    muteButton.heightAnchor.constraint(equalToConstant: 48)
                ]
                if selectedPromoElement != nil {
                    muteButtonConstraints = [
                        muteButton.leadingAnchor.constraint(equalTo: storyButton.leadingAnchor, constant: -7),
                        muteButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -163),
                        muteButton.widthAnchor.constraint(equalToConstant: 48),
                        muteButton.heightAnchor.constraint(equalToConstant: 48)
                    ]
                }
                
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
        
        let soundSetting: Bool = UserDefaults.standard.bool(forKey: "MuteSoundSetting")
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
        
        if (currentSlide?.backgroundColor != nil || currentSlide?.backgroundColor != "") {
            let color = currentSlide?.backgroundColor.hexToRGB()
            self.backgroundColor = UIColor(red: color!.red, green: color!.green, blue: color!.blue, alpha: 1)
        } else {
            self.backgroundColor = UIColor.black
        }
        
        if slide.type == .video {
            videoView.isHidden = false
            storySlideImageView.isHidden = true

            self.videoView.layer.sublayers?.forEach {
                if $0.name == "VIDEO" {
                    $0.removeFromSuperlayer()
                }
            }
            if let videoURL = slide.videoURL {
                videoView.isHidden = false
                storySlideImageView.isHidden = true

                let asset = AVAsset(url: videoURL)
                let playerItem = AVPlayerItem(asset: asset)
                self.player = AVPlayer(playerItem: playerItem)
                let playerLayer = AVPlayerLayer(player: player)
                let screenSize = UIScreen.main.bounds.size
                playerLayer.frame = CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height)
                playerLayer.name = "VIDEO"
                
                //let videoDuration = asset.duration
                //let durationTime = CMTimeGetSeconds(videoDuration)
                //print(videoDuration)
                //playerLayer.videoGravity = .resizeAspectFill
                
                if playerItem.asset.tracks.filter({$0.mediaType == .audio}).count != 0 {
                    var mainBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
                    mainBundle = Bundle.module
#endif
                    let soundSetting: Bool = UserDefaults.standard.bool(forKey: "MuteSoundSetting")
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
                storySlideImageView.isHidden = false
                videoView.isHidden = true
                if let preview = slide.previewImage {
                    self.storySlideImageView.image = preview
                }
            }
        } else {
            
            muteButton.isHidden = true
            storySlideImageView.isHidden = false
            videoView.isHidden = true
            if let image = slide.downloadedImage {
                self.storySlideImageView.image = image
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
                
            } else if element.product != nil {
                //print("Do nothing coming soon")
            } else {
                UserDefaults.standard.set(false, forKey: "DoubleProductButtonSetting")
                storyButton.configButton(buttonData: element)
                makeConstraints()
            }
            
            if let elementProduct = slide.elements.last(where: {$0.type == .product}) {
                
                selectedPromoElement = elementProduct.product!

                promocodeBannerView.dismissWithoutAnimation()
                productWithPromocodeSuperview.configPromoView(promoData: selectedPromoElement!)

                if selectedPromoElement!.discount_percent != 0 {
                    productWithPromocodeSuperview.isHidden = false
                    self.displayPromocodeBanner(promoTitle: elementProduct.title, promoData: self.selectedPromoElement!)
                } else {
                    productWithPromocodeSuperview.isHidden = false
                    self.displayPromocodeBanner(promoTitle: elementProduct.title, promoData: self.selectedPromoElement!)
                }

                insertSubview(muteButton, aboveSubview: productWithPromocodeSuperview)
                insertSubview(muteButton, aboveSubview: promocodeBannerView)
                insertSubview(muteButton, aboveSubview: storySlideImageView)

                insertSubview(storyButton, aboveSubview: productWithPromocodeSuperview)
                insertSubview(storyButton, aboveSubview: promocodeBannerView)
                insertSubview(storyButton, aboveSubview: storySlideImageView)

                insertSubview(productWithPromocodeSuperview, aboveSubview: storySlideImageView)
                
//                if SdkGlobalHelper.DeviceType.IS_IPHONE_5 {
//                    insertSubview(promocodeBannerView, aboveSubview: storySlideImageView)
//                }
                
                makeConstraints()
                
                //self.sdkPopupTapHandle() //TEST
            }
            
        } else if let element = slide.elements.first(where: {$0.type == .products}) {
            
            UserDefaults.standard.set(false, forKey: "DoubleProductButtonSetting")
            
            selectedProductsElement = element
            productsButton.layer.cornerRadius = layer.frame.size.height / 2
            productsButton.layer.masksToBounds = true
            
            productsButton.configProductsButton(buttonData: element)
            if element.products?.count == 0 {
                productsButton.isHidden = true
            } else {
                productsButton.isHidden = false
            }
            
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
    
    @objc func sdkPopupTapHandle(_ sender: UITapGestureRecognizer? = nil) {
        if #available(iOS 13.0, *) {
            let popupView = SdkPopupAlertView(
                title: "",
                titleFont: .systemFont(ofSize: 5, weight: .light),
                subtitle: SdkConfiguration.stories.storiesSlideReloadPopupMessageError,
                subtitleFont: .systemFont(ofSize: SdkConfiguration.stories.storiesSlideReloadPopupMessageFontSize, weight: SdkConfiguration.stories.storiesSlideReloadPopupMessageFontWeight),
                //icon: UIImage(systemName: "defaultIcon"), // Coming soon
                //iconSpacing: 16,
                position: .centerCustom,
                onTap: { print("Sdk Alert popup tapped")
                }
            )
            popupView.displayTime = SdkConfiguration.stories.storiesSlideReloadPopupMessageDisplayTime
            popupView.show()
        }
    }
    
    func displayPromocodeBanner(promoTitle: String?, promoData: StoriesPromoElement) {
        
        let screenSize: CGRect = UIScreen.main.bounds
        promocodeBannerView.size = CGSize(width: screenSize.width - 32, height: 68)
        promocodeBannerView.cornerRadius = 6
        promocodeBannerView.displayTime = 0
        promocodeBannerView.padding = (16, 90)
        promocodeBannerView.animationDuration = 0.0 //0.75
        
        let presentedBannerLabel = UILabel()
        let presentedColor = UIColor(red: 252/255, green: 107/255, blue: 63/255, alpha: 1.0) //TO DO
        presentedBannerLabel.backgroundColor = presentedColor
        
        let codePromo = promoData.promocode
        let normalClearText = ""
        let normalAttributedString = NSMutableAttributedString(string:normalClearText)
        
        let oldPriceText = "     " + String(promoData.oldprice)
        if promoData.oldprice != 0 {
            let attrs = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16, weight: .heavy),
                         NSAttributedString.Key.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                         .foregroundColor: UIColor.white.withAlphaComponent(0.7)] as [NSAttributedString.Key: Any]
            let boldString = NSMutableAttributedString(string: oldPriceText, attributes:attrs)
            normalAttributedString.append(boldString)
            
            normalAttributedString.addAttributes([
                .strikethroughColor: UIColor.white.withAlphaComponent(0.5)
            ], range: NSRange(location: 0, length: oldPriceText.count))
            
            let spaceText = "  \n"
            let attrsSpace = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 1, weight: .thin), .foregroundColor: UIColor.white]
            let boldStringSpace = NSMutableAttributedString(string: spaceText, attributes:attrsSpace)
            normalAttributedString.append(boldStringSpace)
        } else {
            //print("SDK Old Price Implementation")
        }
        
        let newPriceText = "   " + String(promoData.price)
        
        var newPriceTextAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 28, weight: .black), .foregroundColor: UIColor.white]
        if newPriceText.utf16.count <= 10 {
            newPriceTextAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 26, weight: .black), .foregroundColor: UIColor.white]
        } else if newPriceText.utf16.count <= 11 {
            newPriceTextAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 25, weight: .black), .foregroundColor: UIColor.white]
        } else if newPriceText.utf16.count <= 12 {
            newPriceTextAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 23, weight: .black), .foregroundColor: UIColor.white]
        } else if newPriceText.utf16.count <= 16 {
            newPriceTextAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17, weight: .bold), .foregroundColor: UIColor.white]
        } else {
            newPriceTextAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14, weight: .bold), .foregroundColor: UIColor.white]
        }
        
        let boldString1 = NSMutableAttributedString(string: newPriceText, attributes:newPriceTextAttributes)
        normalAttributedString.append(boldString1)
        
        let currencyText = " " + promoData.currency
        let attrs2 = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 19, weight: .black), .foregroundColor: UIColor.white]
        let boldString2 = NSMutableAttributedString(string: currencyText, attributes:attrs2)
        normalAttributedString.append(boldString2)
        
        presentedBannerLabel.numberOfLines = 3 //0
        presentedBannerLabel.attributedText = normalAttributedString
        
        let nextStepSymbol = " \n"
        let percentSymbol = "%"
        
        var titlePromo = promoTitle! + nextStepSymbol
        if codePromo == "" {
            titlePromo = ""
        }
        let attributedDiscountSectionString = NSMutableAttributedString(string:"")
        
        let titlePromoAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .bold), .foregroundColor: UIColor.white]
        let discountSectionString = NSMutableAttributedString(string: titlePromo, attributes:titlePromoAttributes)
        attributedDiscountSectionString.append(discountSectionString)
        
        let nextStepSymbolAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 1, weight: .thin), .foregroundColor: UIColor.white]
        let nextStepSymbolString = NSMutableAttributedString(string: nextStepSymbol, attributes:nextStepSymbolAttributes)
        attributedDiscountSectionString.append(nextStepSymbolString)
        
        if codePromo == "" {
            let percentReplacement = "-" + String(promoData.discount_percent) + percentSymbol
            
            let priceLabelAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 27, weight: .heavy), .foregroundColor: UIColor.black]
            let promoCodeLabelAttributedString = NSMutableAttributedString(string: percentReplacement, attributes:priceLabelAttributes)
            attributedDiscountSectionString.append(promoCodeLabelAttributedString)
        } else {
            var priceLabelAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 25, weight: .heavy), .foregroundColor: UIColor.white]
            if codePromo.utf16.count <= 4 {
                 priceLabelAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 31, weight: .heavy), .foregroundColor: UIColor.white]
            } else if codePromo.utf16.count <= 8 {
                 priceLabelAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 27, weight: .heavy), .foregroundColor: UIColor.white]
            } else if codePromo.utf16.count < 11 {
                 priceLabelAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 25, weight: .heavy), .foregroundColor: UIColor.white]
            } else if codePromo.utf16.count <= 12 {
                priceLabelAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 20, weight: .heavy), .foregroundColor: UIColor.white]
            } else if codePromo.utf16.count <= 14 {
                priceLabelAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16, weight: .heavy), .foregroundColor: UIColor.white]
            } else if codePromo.utf16.count <= 16 {
                priceLabelAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15, weight: .bold), .foregroundColor: UIColor.white]
            } else if codePromo.utf16.count <= 18 {
                priceLabelAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .bold), .foregroundColor: UIColor.white]
            } else {
                priceLabelAttributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 11, weight: .regular), .foregroundColor: UIColor.white]
            }
            let promoCodeLabelAttributedString = NSMutableAttributedString(string: codePromo, attributes:priceLabelAttributes)
            attributedDiscountSectionString.append(promoCodeLabelAttributedString)
        }
        
        let v = UIView()
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.sdkPopupTapHandle(_:)))
        v.addGestureRecognizer(tap)
        v.addSubview(presentedBannerLabel)
        
        let btn = UIButton()
        if promoData.discount_percent != 0 || codePromo != "" {
            btn.setAttributedTitle(attributedDiscountSectionString, for: .normal)
            btn.titleLabel?.textAlignment = .left
            btn.titleLabel?.numberOfLines = 3

            var bgAdditionalColor = SdkConfiguration.stories.bannerPromocodeSectionBackgroundColor ?? UIColor(red: 23/255, green: 170/255, blue: 223/255, alpha: 1.0)
            
            if codePromo == "" {
                bgAdditionalColor = SdkConfiguration.stories.bannerDiscountSectionBackgroundColor ?? UIColor(red: 251/255, green: 184/255, blue: 0/255, alpha: 1.0)
            } else {
                btn.addTarget(self, action: #selector(copyPromocodeToClipboard), for: .touchUpInside)
            }
            btn.backgroundColor = bgAdditionalColor
            v.addSubview(btn)
        } else {
            let bgAdditionalColor = UIColor(red: 252/255, green: 107/255, blue: 63/255, alpha: 1.0)
            //let bgAdditionalColor = SdkConfiguration.stories.bannerPriceSectionBackgroundColor
            btn.backgroundColor = bgAdditionalColor
            v.addSubview(btn)
        }
        
        promocodeBannerView.setView(view: v)
        showInCellPromocodeBanner(banner: promocodeBannerView)
        
        if codePromo == "" {
            presentedBannerLabel.frame = CGRect(x: 0, y: 0, width: v.frame.width * 0.72, height: v.frame.height)
            btn.frame = CGRect(x: (v.frame.width * 0.72) - 5, y: 0, width: v.frame.width - (v.frame.width * 0.72) + 10, height: v.frame.height)
        } else {
            if promoData.discount_percent != 0 || codePromo != "" {
                if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO_MAX || SdkGlobalHelper.DeviceType.IS_IPHONE_14_PLUS {
                    if codePromo.utf16.count < 11 {
                        presentedBannerLabel.frame = CGRect(x: 0, y: 0, width: v.frame.width * 0.6, height: v.frame.height)
                        btn.frame = CGRect(x: v.frame.width * 0.6, y: 0, width: v.frame.width - (v.frame.width * 0.6), height: v.frame.height)
                    } else if codePromo.utf16.count <= 12 {
                        presentedBannerLabel.frame = CGRect(x: 0, y: 0, width: v.frame.width * 0.54, height: v.frame.height)
                        btn.frame = CGRect(x: v.frame.width * 0.54, y: 0, width: v.frame.width - (v.frame.width * 0.54), height: v.frame.height)
                    } else {
                        presentedBannerLabel.frame = CGRect(x: 0, y: 0, width: v.frame.width * 0.6, height: v.frame.height)
                        btn.frame = CGRect(x: v.frame.width * 0.6, y: 0, width: v.frame.width - (v.frame.width * 0.6), height: v.frame.height)
                    }
                } else {
                    presentedBannerLabel.frame = CGRect(x: 0, y: 0, width: v.frame.width * 0.53, height: v.frame.height)
                    btn.frame = CGRect(x: v.frame.width * 0.53, y: 0, width: v.frame.width - (v.frame.width * 0.53), height: v.frame.height)
                }
            } else {
                presentedBannerLabel.frame = CGRect(x: 0, y: 0, width: v.frame.width * 1.0, height: v.frame.height)
                btn.frame = CGRect(x: v.frame.width * 1.0, y: 0, width: v.frame.width - (v.frame.width * 1.0), height: v.frame.height)
            }
        }
    }
    
    @objc public func copyPromocodeToClipboard() {
        let pasteboard = UIPasteboard.general
        pasteboard.string = selectedPromoElement?.promocode
        
        if (sdkPopupAlertView.window != nil) {
            return
        }
        sdkPopupAlertView.show()
    }
    
    @objc public func dismissPromocodeBanner() {
        promocodeBannerView.dismiss()
    }
    
    @objc public func dismissPromocodeBannerWithoutAnimation() {
        promocodeBannerView.dismissWithoutAnimation()
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        //Video time seek & play/pause implementation
    }
    
    func stopPlayer() {
        player.pause()
    }
    
    @objc
    private func didTapOnProductsButton() {
        if let productsList = selectedProductsElement?.products, productsList.count != 0 {
            UserDefaults.standard.set(Int(currentSlide!.id), forKey: "LastViewedSlideMemorySetting")
            let products = productsList
            cellDelegate?.openProductsCarouselView(withProducts: products, hideLabel: (selectedProductsElement?.labels?.hideCarousel)!)
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
                    self.storySlideImageView.tintColor = UIColor.black
                    self.storySlideImageView.isOpaque = false
                    self.storySlideImageView.image = image
                }
            } else {
                self.sdkPopupTapHandle()
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
