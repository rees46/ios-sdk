import UIKit
import AVKit
import AVFoundation

protocol StoryCollectionViewCellDelegate: AnyObject {
    func didTapUrlButton(url: String, slide: Slide)
    func didTapOpenLinkExternalServiceMethod(url: String, slide: Slide)
    func sendStructSelectedStorySlide(storySlide: StoriesElement)
    func sendStructSelectedPromocodeSlide(promoCodeSlide: StoriesPromoCodeElement)
    func openProductsCarouselView(withProducts: [StoriesProduct], hideLabel: String)
    func closeProductsCarousel()
}

class StoryCollectionViewCell: UICollectionViewCell {
    
    static let cellId = "StoryCollectionViewCellId"
    weak var delegate: StoryCollectionViewCellDelegate?
    
    let videoView = UIView()
    let storySlideImageView = UIImageView()
    let storyButton = StoryButton()
    let productsButton = ProductsButton()
    let muteButton = UIButton()
    let promoBtn = StoryButton()
    let reloadButton = ReloadButton()
    
    private var currentSlide: Slide?
    private var selectedElement: StoriesElement?
    private var selectedProductsElement: StoriesElement?
    private var selectedPromoCodeElement: StoriesPromoCodeElement?
    
    public let productWithPromocodeSuperview = PromoCodeView()
    public let promocodeBannerView = PromocodeBanner(location: PromocodeBannerLocation.bottomLeft)
    public var sdkPopupAlertView = SdkPopupAlertView(title: SdkConfiguration.stories.defaultCopyToClipboardMessageText)
    
    public weak var cellDelegate: StoryCollectionViewCellDelegate?
    public weak var mainStoriesDelegate: StoriesViewLinkProtocol?
    
    private var customConstraints = [NSLayoutConstraint]()
    
    var player = AVPlayer()
    private let timeObserverKeyPath: String = "timeControlStatus"
    
    private var audioSession: AVAudioSession!
    var outputVolumeObservation: NSKeyValueObservation?
    
    fileprivate let kVolumeKey = "volume"
    fileprivate var kAudioLevel : Float = 0.0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        promocodeBannerView.removeFromSuperview()
        
        if currentSlide?.backgroundColor != nil {
            //let color = currentSlide?.backgroundColor.hexToRGB()
            //self.backgroundColor = UIColor(red: color!.red, green: color!.green, blue: color!.blue, alpha: 1)
        } else {
            self.backgroundColor = .black
        }
        videoView.backgroundColor = .black
        
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(pauseVideo(_:)), name: .init(rawValue: "PauseVideoLongTap"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playVideo(_:)), name: .init(rawValue: "PlayVideoLongTap"), object: nil)
        
        audioSession = AVAudioSession.sharedInstance()
        listenVolumeButton()
        
        videoView.contentMode = .scaleToFill
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
        
        promoBtn.isHidden = true
        addSubview(promoBtn)
        
        self.setMuteButtonToDefault()
        
        makeConstraints()
    }
    
    public func configure(slide: Slide) {
        self.currentSlide = slide
        
        // Set the background color
        setupBackgroundColor()
        
        // Hide sdkPopupAlertView if it exists
        hideSdkPopupAlertIfNeeded()
        
        // Delete previous text blocks
        removePreviousTextBlocks()
        
        // Setting for video or image
        configureMedia(for: slide)
        
        // Create and configure text blocks
        setupTextBlocks(for: slide.elements)
        
        // Button configuration
        configureButtons(for: slide)
        
        // Move important subviews to the top
        bringImportantSubviewsToFront()
    }
    
    private func setupBackgroundColor() {
        if let backgroundColorHex = currentSlide?.backgroundColor, !backgroundColorHex.isEmpty {
            let color = backgroundColorHex.hexToRGB()
            self.backgroundColor = UIColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
        } else {
            self.backgroundColor = UIColor.black
        }
    }
    
    private func hideSdkPopupAlertIfNeeded() {
        if sdkPopupAlertView.window != nil {
            hideSdkPopupAlertView()
        }
    }
    
    private func removePreviousTextBlocks() {
        self.subviews.filter { $0 is TextBlockView || $0 is UIStackView }.forEach { $0.removeFromSuperview() }
    }
    
    private func configureMedia(for slide: Slide) {
        if slide.type == .video {
            configureVideoView(for: slide)
        } else {
            configureImageView(for: slide)
        }
    }
    
    private func setupTextBlocks(for elements: [StoriesElement]) {
        let textBlockViews = elements
            .filter { $0.type == .textBlock }
            .map { TextBlockConfiguration(from: $0) }
            .map { TextBlockView(with: $0) }
        
        guard !textBlockViews.isEmpty else { return }
        
        let stackView = createStackView()
        addStackView(stackView)
        
        for textBlockView in textBlockViews {
            stackView.addArrangedSubview(textBlockView)
        }
        
        addSpacers(to: stackView, with: textBlockViews)
    }
    
    private func createStackView() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .equalSpacing
        stackView.spacing = 32
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }
    
    private func addStackView(_ stackView: UIStackView) {
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.bottomAnchor, constant: -32)
        ])
    }
    
    private func addSpacers(to stackView: UIStackView, with textBlockViews: [TextBlockView]) {
        if let firstTextBlockView = textBlockViews.first {
            let topSpacingView = UIView()
            topSpacingView.translatesAutoresizingMaskIntoConstraints = false
            topSpacingView.heightAnchor.constraint(equalToConstant: 32).isActive = true
            stackView.addArrangedSubview(topSpacingView)
            
            stackView.addArrangedSubview(firstTextBlockView)
        }
        
        for index in 1..<textBlockViews.count {
            let textBlockView = textBlockViews[index]
            stackView.addArrangedSubview(textBlockView)
        }
        
        if textBlockViews.last != nil {
            let bottomSpacingView = UIView()
            bottomSpacingView.translatesAutoresizingMaskIntoConstraints = false
            bottomSpacingView.heightAnchor.constraint(equalToConstant: 40).isActive = true
            stackView.addArrangedSubview(bottomSpacingView)
        }
    }
    
    private func bringImportantSubviewsToFront() {
        bringSubviewsToFront([storyButton, productsButton,promoBtn, muteButton, productWithPromocodeSuperview, promocodeBannerView])
    }
    
    
    private func bringSubviewsToFront(_ subviews: [UIView]) {
        subviews.forEach { bringSubviewToFront($0) }
    }
    
    private func configure(_ textBlockViews: [TextBlockView], for slide: Slide) {
        let screenSize: CGRect = UIScreen.main.bounds
        
        textBlockViews.enumerated().forEach { [weak self] (index, textBlockView) in
            guard let self = self else { return }
            let yOffset = textBlockView.yOffset
            textBlockView.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(textBlockView)
            
            NSLayoutConstraint.activate([
                textBlockView.leadingAnchor.constraint(equalTo: self.leadingAnchor,
                                                       constant: screenSize.width / StoryTextBlockConstants.aspectRationRelatedConstant),
                textBlockView.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor,
                                                        constant: -(screenSize.width / StoryTextBlockConstants.aspectRationRelatedConstant))
            ])
            
            if SdkGlobalHelper.sharedInstance.willDeviceHaveDynamicIsland() {
                textBlockView.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor,
                                                   constant: StoryTextBlockConstants.constantToAvoidProgressViewWithNotch + yOffset).isActive = true
            } else {
                textBlockView.topAnchor.constraint(lessThanOrEqualTo: self.topAnchor,
                                                   constant:  StoryTextBlockConstants.constantToAvoidProgressViewNoNotch + yOffset).isActive = true
            }
        }
    }
    
    private func configureButtons(for slide: Slide) {
        if let element = slide.elements.first(where: {$0.type == .button}) {
            UserDefaults.standard.set(false, forKey: "DoubleProductButtonSetting")
            selectedElement = element
            storyButton.configButton(buttonData: element)
            storyButton.isHidden = false
            productsButton.isHidden = true
            productWithPromocodeSuperview.isHidden = true
            
            makeConstraints()
            
            if let elementProduct = slide.elements.last(where: {$0.type == .products}) {
                UserDefaults.standard.set(true, forKey: "DoubleProductButtonSetting")
                selectedProductsElement = elementProduct
                productsButton.layer.cornerRadius = layer.frame.size.height / 2
                productsButton.layer.masksToBounds = true
                
                storyButton.configButton(buttonData: element)
                productsButton.configProductsButton(buttonData: elementProduct)
                
                productsButton.isHidden = false
                productWithPromocodeSuperview.isHidden = true
                
                makeConstraints()
                
            } else if element.product != nil {
                //print("Do nothing coming soon")
            } else {
                UserDefaults.standard.set(false, forKey: "DoubleProductButtonSetting")
                storyButton.configButton(buttonData: element)
                makeConstraints()
            }
            
            if let elementProduct = slide.elements.last(where: {$0.type == .product}) {
                
                selectedPromoCodeElement = elementProduct.product!
                
                promocodeBannerView.dismissWithoutAnimation()
                productWithPromocodeSuperview.configPromoView(promoData: selectedPromoCodeElement!)
                productWithPromocodeSuperview.isHidden = false
                
                if selectedPromoCodeElement!.discount_percent != 0 {
                    self.displayPromocodeBanner(promoTitle: elementProduct.title, promoCodeData: self.selectedPromoCodeElement!)
                } else {
                    self.displayPromocodeBanner(promoTitle: elementProduct.title, promoCodeData: self.selectedPromoCodeElement!)
                }
                
                insertSubview(muteButton, aboveSubview: productWithPromocodeSuperview)
                insertSubview(muteButton, aboveSubview: promocodeBannerView)
                insertSubview(muteButton, aboveSubview: storySlideImageView)
                
                insertSubview(storyButton, aboveSubview: productWithPromocodeSuperview)
                insertSubview(storyButton, aboveSubview: promocodeBannerView)
                insertSubview(storyButton, aboveSubview: storySlideImageView)
                
                insertSubview(productWithPromocodeSuperview, aboveSubview: storySlideImageView)
                
                bringSubviewToFront(muteButton)
                bringSubviewToFront(promoBtn)
                bringSubviewToFront(storyButton)
                bringSubviewToFront(productsButton)
                bringSubviewToFront(promocodeBannerView)
                makeConstraints()
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
            productWithPromocodeSuperview.isHidden = true
            
            makeConstraints()
        } else {
            UserDefaults.standard.set(false, forKey: "DoubleProductButtonSetting")
            storyButton.isHidden = true
            productsButton.isHidden = true
            productWithPromocodeSuperview.isHidden = true
            makeConstraints()
        }
    }
    
    private func configureVideoView(for slide: Slide) {
        videoView.isHidden = false
        storySlideImageView.isHidden = true
        videoView.layer.sublayers?.forEach { $0.name == "VIDEO" ? $0.removeFromSuperlayer() : () }
        
        if let videoURL = slide.videoURL {
            let asset = AVAsset(url: videoURL)
            let playerItem = AVPlayerItem(asset: asset)
            player = AVPlayer(playerItem: playerItem)
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.frame = bounds
            playerLayer.name = "VIDEO"
            
            if asset.tracks(withMediaType: .audio).count > 0 {
                let soundSetting: Bool = UserDefaults.standard.bool(forKey: "MuteSoundSetting")
                player.volume = soundSetting ? 1 : 0
                muteButton.isHidden = false
                updateMuteButtonImage(isMuted: !soundSetting)
            } else {
                muteButton.isHidden = true
            }
            
            self.videoView.layer.addSublayer(playerLayer)
            player.play()
            UserDefaults.standard.set(currentSlide!.id, forKey: "LastViewedSlideMemorySetting")
        } else {
            muteButton.isHidden = true
            storySlideImageView.isHidden = false
            videoView.isHidden = true
            if let preview = slide.previewImage {
                self.storySlideImageView.image = preview
            }
        }
    }
    
    private func updateMuteButtonImage(isMuted: Bool) {
        var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        frameworkBundle = Bundle.module
#endif
        let imageName = isMuted ? "iconStoryMute" : "iconStoryVolumeUp"
        muteButton.setImage(UIImage(named: imageName, in: frameworkBundle, compatibleWith: nil), for: .normal)
    }
    
    private func configureImageView(for slide: Slide) {
        muteButton.isHidden = true
        storySlideImageView.isHidden = false
        videoView.isHidden = true
        
        if let image = slide.downloadedImage {
            storySlideImageView.image = image
        }
    }
    
    private func setImage(imagePath: String) {
        guard let url = URL(string: imagePath) else {
            return
        }
        
        let task = URLSession.shared.dataTask(with: url, completionHandler: { data, _, error in
            if error == nil {
                guard let unwrappedData = data, let image = UIImage(data: unwrappedData) else {
                    return
                }
                DispatchQueue.main.async {
                    self.storySlideImageView.tintColor = UIColor.black
                    self.storySlideImageView.isOpaque = false
                    self.storySlideImageView.image = image
                }
            } else {
                self.sdkErrorReloadTapHandle()
            }
        })
        task.resume()
    }
    
    func listenVolumeButton() {
        do {
            try audioSession.setActive(true, options: [])
            audioSession.addObserver(self, forKeyPath: "outputVolume", options: NSKeyValueObservingOptions.new, context: nil)
            kAudioLevel = audioSession.outputVolume
        } catch {
            print("SDK Output volume listener error")
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume"{
            if audioSession.outputVolume > kAudioLevel {
                kAudioLevel = audioSession.outputVolume
                
                var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
                frameworkBundle = Bundle.module
#endif
                do {
                    try audioSession.setCategory(.playback, mode: .default, options: [])
                    player.volume = audioSession.outputVolume
                    muteButton.setImage(UIImage(named: "iconStoryVolumeUp", in: frameworkBundle, compatibleWith: nil), for: .normal)
                    UserDefaults.standard.set(true, forKey: "MuteSoundSetting")
                } catch let error {
                    player.volume = audioSession.outputVolume
                    muteButton.setImage(UIImage(named: "iconStoryMute", in: frameworkBundle, compatibleWith: nil), for: .normal)
                    print("Error in AVAudio Session\(error.localizedDescription)")
                }
            }
            if audioSession.outputVolume < kAudioLevel {
                player.volume = audioSession.outputVolume
            }
            if audioSession.outputVolume > 0.999 {
                kAudioLevel = 0.9375
            }
            if audioSession.outputVolume < 0.001 {
                var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
                frameworkBundle = Bundle.module
#endif
                kAudioLevel = 0.0625
                muteButton.setImage(UIImage(named: "iconStoryMute", in: frameworkBundle, compatibleWith: nil), for: .normal)
                UserDefaults.standard.set(false, forKey: "MuteSoundSetting")
            }
        }
    }
    
    @objc
    private func didTapOnMute() {
        var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        frameworkBundle = Bundle.module
#endif
        if player.volume == 1.0 {
            player.volume = 0.0
            muteButton.setImage(UIImage(named: "iconStoryMute", in: frameworkBundle, compatibleWith: nil), for: .normal)
            UserDefaults.standard.set(false, forKey: "MuteSoundSetting")
        } else {
            player.volume = 1.0
            do {
                try audioSession.setCategory(.playback, mode: .default, options: [])
            } catch let error {
                print("SDK Error in AVAudio Session\(error.localizedDescription)")
            }
            
            muteButton.setImage(UIImage(named: "iconStoryVolumeUp", in: frameworkBundle, compatibleWith: nil), for: .normal)
            UserDefaults.standard.set(true, forKey: "MuteSoundSetting")
        }
    }
    
    private func setMuteButtonToDefault() {
        var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        frameworkBundle = Bundle.module
#endif
        
        let soundSetting: Bool = UserDefaults.standard.bool(forKey: "MuteSoundSetting")
        if soundSetting {
            player.volume = 1
            muteButton.setImage(UIImage(named: "iconStoryVolumeUp", in: frameworkBundle, compatibleWith: nil), for: .normal)
            UserDefaults.standard.set(true, forKey: "MuteSoundSetting")
        } else {
            player.volume = 0
            muteButton.setImage(UIImage(named: "iconStoryMute", in: frameworkBundle, compatibleWith: nil), for: .normal)
            UserDefaults.standard.set(false, forKey: "MuteSoundSetting")
        }
        
        muteButton.translatesAutoresizingMaskIntoConstraints = false
        muteButton.isHidden = true
        muteButton.addTarget(self, action: #selector(didTapOnMute), for: .touchUpInside)
        addSubview(muteButton)
    }
    
    @objc
    func sdkNilTap(_ sender: UITapGestureRecognizer? = nil) {
        //
    }
    
    @objc
    func sdkErrorReloadTapHandle(_ sender: UITapGestureRecognizer? = nil) {
        var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        frameworkBundle = Bundle.module
#endif
        let errorIcon = UIImage(named: "iconError", in: frameworkBundle, compatibleWith: nil)?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
        
        if #available(iOS 13.0, *) {
            let popupView = SdkPopupAlertView(
                title: "",
                titleFont: .systemFont(ofSize: 5, weight: .light),
                subtitle: SdkConfiguration.stories.storiesSlideReloadPopupMessageError,
                subtitleFont: .systemFont(ofSize: SdkConfiguration.stories.storiesSlideReloadPopupMessageFontSize, weight: SdkConfiguration.stories.storiesSlideReloadPopupMessageFontWeight),
                icon: errorIcon,
                iconSpacing: 16,
                position: .centerCustom,
                onTap: { print("SDK Alert popup tapped") }
            )
            popupView.displayRealAlertTime = SdkConfiguration.stories.storiesSlideReloadPopupMessageDisplayTime
            popupView.show()
        }
    }
    
    func displayPromocodeBanner(promoTitle: String?, promoCodeData: StoriesPromoCodeElement) {
        setupPromocodeBannerView()
        let presentedBannerLabel = createPresentedBannerLabel(promoCodeData: promoCodeData)
        let attributedDiscountSectionString = createDiscountSectionString(
            promoTitle: promoTitle,
            promoCodeData: promoCodeData
        )
        
        let view = UIView()
        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(self.sdkNilTap(_:))
        )
        tap.cancelsTouchesInView = false
        promocodeBannerView.addGestureRecognizer(tap)

        view.addSubview(presentedBannerLabel)

        let promo = createPromoButton(
            promoCodeData: promoCodeData,
            attributedDiscountSectionString: attributedDiscountSectionString
        )
    
        view.addSubview(promoBtn)
        
        promocodeBannerView.setView(view: view)
        promocodeBannerView.isUserInteractionEnabled = true
        showInCellPromocodeBanner(promoBanner: promocodeBannerView)
        
        setupBannerFrames(
            presentedBannerLabel: presentedBannerLabel,
            promoBtn: promoBtn,
            view: view,
            codePromo: promoCodeData.promocode,
            discountPercent: promoCodeData.discount_percent
        )
    }
    
    private func setupPromocodeBannerView() {
        let screenSize = UIScreen.main.bounds
        promocodeBannerView.size = CGSize(width: screenSize.width - 32, height: 68)
        promocodeBannerView.cornerRadius = 6
        promocodeBannerView.displayTime = 0
        promocodeBannerView.padding = (16, 90)
        promocodeBannerView.animationDuration = 0.0
        promocodeBannerView.isUserInteractionEnabled = false
    }
    
    private func createPresentedBannerLabel(promoCodeData: StoriesPromoCodeElement) -> UILabel {
        let presentedBannerLabel = UILabel()
        presentedBannerLabel.backgroundColor = SdkConfiguration.stories.bannerPriceSectionBackgroundColor ?? UIColor(
            red: 252/255,
            green: 107/255,
            blue: 63/255,
            alpha: 1.0
        )
        
        let clearPriceAttributedString = createPriceAttributedString(promoCodeData: promoCodeData)
        presentedBannerLabel.numberOfLines = 3
        presentedBannerLabel.attributedText = clearPriceAttributedString
        
        return presentedBannerLabel
    }
    
    private func createPriceAttributedString(promoCodeData: StoriesPromoCodeElement) -> NSMutableAttributedString {
        let clearPriceAttributedString = NSMutableAttributedString(string: "")
        let oldPriceText = createOldPriceText(promoCodeData: promoCodeData)
        clearPriceAttributedString.append(oldPriceText)
        
        let newPriceText = createNewPriceText(promoCodeData: promoCodeData)
        clearPriceAttributedString.append(newPriceText)
        
        let currencyText = createCurrencyText(promoCodeData: promoCodeData)
        clearPriceAttributedString.append(currencyText)
        
        return clearPriceAttributedString
    }
    
    private func createOldPriceText(promoCodeData: StoriesPromoCodeElement) -> NSAttributedString {
        var oldPriceText = "   "
        if promoCodeData.oldprice != 0 {
            oldPriceText = "   " + (promoCodeData.oldprice_formatted.isEmpty ? String(promoCodeData.oldprice) : promoCodeData.oldprice_formatted)
            let oldPriceTextColor = SdkConfiguration.stories.bannerOldPriceSectionFontColor?.withAlphaComponent(0.7) ?? UIColor.white.withAlphaComponent(0.7)
            let oldPriceFont = SdkConfiguration.stories.promoCodeSlideFontNameChanged.flatMap { UIFont(name: $0, size: 16) } ?? UIFont.systemFont(ofSize: 16, weight: .heavy)
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: oldPriceFont,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: oldPriceTextColor,
                .strikethroughColor: oldPriceTextColor.withAlphaComponent(0.5)
            ]
            return NSAttributedString(string: oldPriceText, attributes: attributes)
        }
        return NSAttributedString(string: oldPriceText)
    }
    
    private func createNewPriceText(promoCodeData: StoriesPromoCodeElement) -> NSAttributedString {
        var formattedPrice = promoCodeData.price_with_promocode_formatted.isEmpty ? promoCodeData.price_formatted : promoCodeData.price_with_promocode_formatted
        formattedPrice = formattedPrice.replacingOccurrences(of: promoCodeData.currency, with: "")
        let newPriceText = "   " + formattedPrice
        
        let priceFontColor = SdkConfiguration.stories.bannerPriceSectionFontColor ?? UIColor.white
        let fontSize: CGFloat
        
        switch newPriceText.utf16.count {
        case 0...10:
            fontSize = 26
        case 11:
            fontSize = 25
        case 12:
            fontSize = 23
        case 13...16:
            fontSize = 17
        default:
            fontSize = 14
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .black),
            .foregroundColor: priceFontColor
        ]
        return NSAttributedString(string: newPriceText, attributes: attributes)
    }
    
    private func createCurrencyText(promoCodeData: StoriesPromoCodeElement) -> NSAttributedString {
        let currencyText = " " + promoCodeData.currency
        let priceFontColor = SdkConfiguration.stories.bannerPriceSectionFontColor ?? UIColor.white
        let fontSize: CGFloat
        
        switch currencyText.utf16.count {
        case 0...10:
            fontSize = 26
        case 11:
            fontSize = 25
        case 12:
            fontSize = 23
        case 13...16:
            fontSize = 17
        default:
            fontSize = 14
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .black),
            .foregroundColor: priceFontColor
        ]
        return NSAttributedString(string: currencyText, attributes: attributes)
    }
    
    private func createDiscountSectionString(
        promoTitle: String?,
        promoCodeData: StoriesPromoCodeElement
    ) -> NSMutableAttributedString {
        
        let attributedDiscountSectionString = NSMutableAttributedString()
        let nextStepSymbol = " \n"
        let percentSymbol = "%"
        
        let titlePromo = (promoTitle ?? "") + nextStepSymbol
        
        let titlePromoAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let discountSectionString = NSMutableAttributedString(
            string: titlePromo,
            attributes: titlePromoAttributes
        )
        attributedDiscountSectionString.append(discountSectionString)
        
        let nextStepSymbolAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 1, weight: .thin),
            .foregroundColor: UIColor.white
        ]
        let nextStepSymbolString = NSMutableAttributedString(string: nextStepSymbol, attributes: nextStepSymbolAttributes)
        attributedDiscountSectionString.append(nextStepSymbolString)
        
        if promoCodeData.promocode.isEmpty {
            let percentReplacement = "-" + String(promoCodeData.discount_percent) + percentSymbol
            let priceLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 27, weight: .heavy),
                .foregroundColor: UIColor.black
            ]
            let promoCodeLabelAttributedString = NSMutableAttributedString(string: percentReplacement, attributes: priceLabelAttributes)
            attributedDiscountSectionString.append(promoCodeLabelAttributedString)
        } else {
            let priceLabelAttributes = getPromoCodeLabelAttributes(promoCode: promoCodeData.promocode)
            let promoCodeLabelAttributedString = NSMutableAttributedString(string: promoCodeData.promocode, attributes: priceLabelAttributes)
            attributedDiscountSectionString.append(promoCodeLabelAttributedString)
        }
        
        return attributedDiscountSectionString
    }
    
    private func getPromoCodeLabelAttributes(promoCode: String) -> [NSAttributedString.Key: Any] {
        var priceLabelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 25, weight: .heavy),
            .foregroundColor: UIColor.white
        ]
        
        switch promoCode.utf16.count {
        case 0...4:
            priceLabelAttributes[.font] = UIFont.systemFont(ofSize: 31, weight: .heavy)
        case 5...8:
            priceLabelAttributes[.font] = UIFont.systemFont(ofSize: 27, weight: .heavy)
        case 9...10:
            priceLabelAttributes[.font] = UIFont.systemFont(ofSize: 25, weight: .heavy)
        case 11...12:
            priceLabelAttributes[.font] = UIFont.systemFont(ofSize: 20, weight: .heavy)
        case 13...14:
            priceLabelAttributes[.font] = UIFont.systemFont(ofSize: 16, weight: .heavy)
        case 15...16:
            priceLabelAttributes[.font] = UIFont.systemFont(ofSize: 15, weight: .bold)
        case 17...18:
            priceLabelAttributes[.font] = UIFont.systemFont(ofSize: 13, weight: .bold)
        default:
            priceLabelAttributes[.font] = UIFont.systemFont(ofSize: 11, weight: .regular)
        }
        
        return priceLabelAttributes
    }
    
    private func createPromoButton(promoCodeData: StoriesPromoCodeElement, attributedDiscountSectionString: NSAttributedString) -> UIButton {
        promoBtn.isHidden = false
        promoBtn.isUserInteractionEnabled = true
        promoBtn.addTarget(self, action: #selector(copyPromocodeToClipboard(_:)), for: .touchUpInside)
        
        if promoCodeData.discount_percent != 0 || !promoCodeData.promocode.isEmpty {
            promoBtn.setAttributedTitle(attributedDiscountSectionString, for: .normal)
            promoBtn.titleLabel?.textAlignment = .left
            promoBtn.titleLabel?.numberOfLines = 3

            var bgAdditionalColor = SdkConfiguration.stories.bannerPromocodeSectionBackgroundColor ?? UIColor(red: 23/255, green: 170/255, blue: 223/255, alpha: 1.0)
            if promoCodeData.promocode.isEmpty {
                bgAdditionalColor = SdkConfiguration.stories.bannerDiscountSectionBackgroundColor ?? UIColor(red: 251/255, green: 184/255, blue: 0/255, alpha: 1.0)
            } else {
                addCopyIcon(to: promoBtn)

                objc_setAssociatedObject(promoBtn, &AssociatedKeys.promocodeKey, promoCodeData.promocode, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

                promoBtn.addTarget(self, action: #selector(copyPromocodeToClipboard(_:)), for: .touchUpInside)
                print("Target added to promoBtn")
            }
            promoBtn.backgroundColor = bgAdditionalColor
        } else {
            let bgPriceSectionColor = SdkConfiguration.stories.bannerPriceSectionBackgroundColor ?? UIColor(red: 252/255, green: 107/255, blue: 63/255, alpha: 1.0)
            promoBtn.backgroundColor = bgPriceSectionColor
        }

        return promoBtn
    }

    private struct AssociatedKeys {
        static var promocodeKey = "promocodeKey"
    }

    @objc
    public func copyPromocodeToClipboard(_ sender: UIButton) {
        print("PROMO WAS COPIED ")
        if let promocode = objc_getAssociatedObject(sender, &AssociatedKeys.promocodeKey) as? String {
            print("PROMO WAS COPIED \(promocode)")
            let pasteboard = UIPasteboard.general
            pasteboard.string = promocode

            showToast(message: "Промокод скопирован: \(promocode)")
        }
    }

    func showToast(message: String) {
        guard let window = UIApplication.shared.keyWindow else { return }

        let toastContainer = UIView(frame: CGRect())
        toastContainer.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastContainer.alpha = 0.0
        toastContainer.layer.cornerRadius = 25
        toastContainer.clipsToBounds = true

        let toastLabel = UILabel(frame: CGRect())
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center
        toastLabel.font = UIFont(name: "Montserrat-Light", size: 12.0)
        toastLabel.text = message
        toastLabel.clipsToBounds = true
        toastLabel.numberOfLines = 0

        toastContainer.addSubview(toastLabel)
        window.addSubview(toastContainer)

        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        toastContainer.translatesAutoresizingMaskIntoConstraints = false

        let labelConstraints = [
            toastLabel.leadingAnchor.constraint(equalTo: toastContainer.leadingAnchor, constant: 15),
            toastLabel.trailingAnchor.constraint(equalTo: toastContainer.trailingAnchor, constant: -15),
            toastLabel.topAnchor.constraint(equalTo: toastContainer.topAnchor, constant: 15),
            toastLabel.bottomAnchor.constraint(equalTo: toastContainer.bottomAnchor, constant: -15)
        ]
        NSLayoutConstraint.activate(labelConstraints)

        let containerConstraints = [
            toastContainer.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 25),
            toastContainer.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -25),
            toastContainer.bottomAnchor.constraint(equalTo: window.bottomAnchor, constant: -75)
        ]
        NSLayoutConstraint.activate(containerConstraints)

        UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseIn, animations: {
            toastContainer.alpha = 1.0
        }, completion: { _ in
            UIView.animate(withDuration: 0.5, delay: 2.5, options: .curveEaseOut, animations: {
                toastContainer.alpha = 0.0
            }, completion: { _ in
                toastContainer.removeFromSuperview()
            })
        })
    }
    
    private func addCopyIcon(to button: UIButton) {
        var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        frameworkBundle = Bundle.module
#endif
        let copyIcon = UIImage(named: "iconCopyLight", in: frameworkBundle, compatibleWith: nil)
        let copyIconImageView = UIImageView(image: copyIcon)
        copyIconImageView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(copyIconImageView)
        let copyIconLength = CGFloat(17)
        NSLayoutConstraint.activate([
            copyIconImageView.leadingAnchor.constraint(equalTo: button.trailingAnchor, constant: -28),
            copyIconImageView.centerYAnchor.constraint(equalTo: button.centerYAnchor, constant: -15),
            copyIconImageView.widthAnchor.constraint(equalToConstant: copyIconLength),
            copyIconImageView.heightAnchor.constraint(equalToConstant: copyIconLength)
        ])
    }
    
    private func setupBannerFrames(presentedBannerLabel: UILabel, promoBtn: UIButton, view: UIView, codePromo: String, discountPercent: Int) {
        if codePromo.isEmpty {
            presentedBannerLabel.frame = CGRect(x: 0, y: 0, width: view.frame.width * 0.72, height: view.frame.height)
            promoBtn.frame = CGRect(x: (view.frame.width * 0.72) - 5, y: 0, width: view.frame.width - (view.frame.width * 0.72) + 10, height: view.frame.height)
        } else {
            if discountPercent != 0 || !codePromo.isEmpty {
                if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO_MAX || SdkGlobalHelper.DeviceType.IS_IPHONE_14_PLUS {
                    switch codePromo.utf16.count {
                    case 0...10:
                        presentedBannerLabel.frame = CGRect(x: 0, y: 0, width: view.frame.width * 0.6, height: view.frame.height)
                        promoBtn.frame = CGRect(x: view.frame.width * 0.6, y: 0, width: view.frame.width - (view.frame.width * 0.6), height: view.frame.height)
                    case 11...12:
                        presentedBannerLabel.frame = CGRect(x: 0, y: 0, width: view.frame.width * 0.54, height: view.frame.height)
                        promoBtn.frame = CGRect(x: view.frame.width * 0.54, y: 0, width: view.frame.width - (view.frame.width * 0.54), height: view.frame.height)
                    default:
                        presentedBannerLabel.frame = CGRect(x: 0, y: 0, width: view.frame.width * 0.6, height: view.frame.height)
                        promoBtn.frame = CGRect(x: view.frame.width * 0.6, y: 0, width: view.frame.width - (view.frame.width * 0.6), height: view.frame.height)
                    }
                } else {
                    presentedBannerLabel.frame = CGRect(x: 0, y: 0, width: view.frame.width * 0.53, height: view.frame.height)
                    promoBtn.frame = CGRect(x: view.frame.width * 0.53, y: 0, width: view.frame.width - (view.frame.width * 0.53), height: view.frame.height)
                }
            } else {
                presentedBannerLabel.frame = CGRect(x: 0, y: 0, width: view.frame.width * 1.0, height: view.frame.height)
                promoBtn.frame = CGRect(x: view.frame.width * 1.0, y: 0, width: view.frame.width - (view.frame.width * 1.0), height: view.frame.height)
            }
        }
    }
    
    @objc
    public func hideSdkPopupAlertView() {
        sdkPopupAlertView.hideImmediately()
    }
    
    @objc
    public func dismissPromocodeBanner() {
        promocodeBannerView.dismiss()
    }
    
    @objc
    public func dismissPromocodeBannerWithoutAnimation() {
        promocodeBannerView.dismissWithoutAnimation()
    }
    
    @objc
    private func didTapOnProductsButton() {
        if let productsList = selectedProductsElement?.products, productsList.count != 0 {
            UserDefaults.standard.set(currentSlide!.id, forKey: "LastViewedSlideMemorySetting")
            let products = productsList
            cellDelegate?.openProductsCarouselView(withProducts: products, hideLabel: (selectedProductsElement?.labels?.hideCarousel)!)
            return
        }
    }
    
    @objc
    private func didTapButton() {
        
        if let promoCodeDeeplinkIos = selectedPromoCodeElement?.deeplinkIos, !promoCodeDeeplinkIos.isEmpty {
            if let currentSlide = currentSlide {
                
                UserDefaults.standard.set(currentSlide.id, forKey: "LastViewedSlideMemorySetting")
                
                cellDelegate?.sendStructSelectedPromocodeSlide(promoCodeSlide: selectedPromoCodeElement!)
                cellDelegate?.didTapOpenLinkExternalServiceMethod(url: promoCodeDeeplinkIos, slide: currentSlide)
                return
            }
        }
        
        if let deeplinkIos = selectedElement?.product?.deeplinkIos, !deeplinkIos.isEmpty {
            if let currentSlide = currentSlide {
                
                UserDefaults.standard.set(currentSlide.id, forKey: "LastViewedSlideMemorySetting")
                
                cellDelegate?.sendStructSelectedStorySlide(storySlide: selectedElement!)
                cellDelegate?.didTapOpenLinkExternalServiceMethod(url: deeplinkIos, slide: currentSlide)
                return
            }
        }
        
        if let linkIos = selectedElement?.linkIos, !linkIos.isEmpty {
            if let currentSlide = currentSlide {
                
                UserDefaults.standard.set(currentSlide.id, forKey: "LastViewedSlideMemorySetting")
                
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
    
    @objc
    private func pauseVideo(_ notification: NSNotification) {
        if let slideID = notification.userInfo?["slideID"] as? String {
            if let currentSlide = currentSlide {
                if currentSlide.id == slideID {
                    player.pause()
                }
            }
        }
    }
    
    @objc
    private func playVideo(_ notification: NSNotification) {
        if let slideID = notification.userInfo?["slideID"] as? String {
            if let currentSlide = currentSlide {
                if currentSlide.id == slideID {
                    player.play()
                }
            }
        }
    }
    
    @objc
    func willEnterForeground() {
        do {
            try audioSession.setCategory(AVAudioSession.Category.playback)
        } catch {
            print("SDK Error in AVAudio Session\(error.localizedDescription)")
        }
        player.play()
    }
    
    @objc
    func didEnterBackground() {
        player.pause()
    }
    
    func stopPlayer() {
        player.pause()
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
            if ds {
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
                if selectedPromoCodeElement != nil {
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
            if ds {
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
                if selectedPromoCodeElement != nil {
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
    
    private func clearConstraints() {
        customConstraints.forEach { $0.isActive = false }
        customConstraints.removeAll()
    }
    
    private func activate(constraints: [NSLayoutConstraint]) {
        customConstraints.append(contentsOf: constraints)
        customConstraints.forEach { $0.isActive = true }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        audioSession.removeObserver(self, forKeyPath: "outputVolume", context: nil)
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
