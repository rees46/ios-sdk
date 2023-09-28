import UIKit

class PromoCodeView: UIView {
    
    let promoProductNameLabel = UILabel()
    var imageView = UIImageView()
    
    var _promoData: StoriesPromoElement?
    //let dismissablePromocodeBanner = PromocodeBanner(location: PromocodeBannerLocation.bottomRight)
    
    private let loadingPlaceholderView = LoadingPlaceholderView()
    
    init() {
        super.init(frame: .zero)
        setToDefault()
        
//        let sId = String("RESET_TECH_TEST")
//        DispatchQueue.onceTechService(token: sId) {
//            StoryBlockImageCache.shared.cache.removeAllObjects()
//        }
    }
    
    func configPromoView(promoData: StoriesPromoElement) {
        promoProductNameLabel.removeFromSuperview()
        
        if (promoData.name != "") {
            if SdkGlobalHelper.DeviceType.IS_IPHONE_14 || SdkGlobalHelper.DeviceType.IS_IPHONE_14_PLUS || SdkGlobalHelper.DeviceType.IS_IPHONE_XS_MAX || SdkGlobalHelper.DeviceType.IS_IPHONE_XS || SdkGlobalHelper.DeviceType.IS_IPHONE_8 || SdkGlobalHelper.DeviceType.IS_IPHONE_8P || SdkGlobalHelper.DeviceType.IS_IPHONE_5 {
                promoProductNameLabel.frame = CGRect(x: frame.minX + 18, y: frame.minY + 72, width: frame.width - 60, height: 80)
            } else {
                promoProductNameLabel.frame = CGRect(x: frame.minX + 18, y: frame.minY + 116, width: frame.width - 60, height: 80)
            }
            promoProductNameLabel.text = promoData.name
            promoProductNameLabel.numberOfLines = 0
            promoProductNameLabel.textAlignment = .left
            
            if SdkConfiguration.stories.promoSlideFontNameChanged != nil {
                promoProductNameLabel.font = UIFont(name: (SdkConfiguration.stories.promoSlideFontNameChanged)!, size: 16)
                if SdkConfiguration.stories.promoSlideFontSizeChanged != nil {
                    promoProductNameLabel.font = UIFont(name: (SdkConfiguration.stories.promoSlideFontNameChanged)!, size: SdkConfiguration.stories.promoSlideFontSizeChanged!)
                }
            } else {
                promoProductNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
                if SdkConfiguration.stories.promoSlideFontSizeChanged != nil {
                    promoProductNameLabel.font = UIFont.systemFont(ofSize: SdkConfiguration.stories.promoSlideFontSizeChanged!, weight: .semibold)
                }
            }
            if #available(iOS 12.0, *) {
                if SdkConfiguration.isDarkMode {
                    promoProductNameLabel.textColor = SdkConfiguration.stories.promoProductTitleTextColorDarkMode
                } else {
                    promoProductNameLabel.textColor = SdkConfiguration.stories.promoProductTitleTextColorLightMode
                }
            } else {
                promoProductNameLabel.textColor = SdkConfiguration.stories.promoProductTitleTextColorLightMode
            }
            
            promoProductNameLabel.sizeToFit()
            addSubview(promoProductNameLabel)
            
            imageView.backgroundColor = .clear
            imageView.contentMode = .scaleAspectFit
            imageView.layer.masksToBounds = true
            imageView.layer.cornerRadius = 6.0
            imageView.layer.borderColor = UIColor.clear.cgColor
            imageView.alpha = 0.0
            imageView.frame = CGRect(x: 18, y: frame.maxY/2 - frame.size.width/2, width: frame.size.width - 36, height: frame.size.width - 36)
            
//            let transparentAdditionaBorderLayer = CALayer()
//            let equalImageViewFrame = CGRect(x: 0.0, y: 0.0, width: imageView.frame.size.height, height: imageView.frame.size.height)
//            transparentAdditionaBorderLayer.backgroundColor = UIColor.clear.cgColor
//            transparentAdditionaBorderLayer.frame = equalImageViewFrame
//            transparentAdditionaBorderLayer.masksToBounds = true
//            transparentAdditionaBorderLayer.cornerRadius = 6.0
//            transparentAdditionaBorderLayer.borderWidth = 16.0
//            transparentAdditionaBorderLayer.borderColor = UIColor.systemPink.cgColor
//            imageView.layer.addSublayer(transparentAdditionaBorderLayer)
            
            addSubview(imageView)
            
            let url = URL(string: promoData.image_url)
            if url != nil {
                
//                let sId = String("RESET_TECH_TEST")
//                DispatchQueue.onceTechService(token: sId) {
//                    StoryBlockImageCache.shared.cache.removeAllObjects()
//                }
                
                StoryBlockImageCache.image(for: url!.absoluteString) { [self] cachedImage in
                    if cachedImage != nil {
                        let imageBorderRepresentation = cachedImage!.imageWithInsets(insets: UIEdgeInsets(top: 22, left: 22, bottom: 22, right: 22))
                        if cachedImage!.hasAlpha {
                            DispatchQueue.main.async {
                                //Sdk Detect alpha channel
                                self.imageView.backgroundColor = .clear
                                self.imageView.layer.borderWidth = 0.0
                                self.imageView.image = cachedImage
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.imageView.backgroundColor = .white
                                self.imageView.layer.borderWidth = 22.0
                                self.imageView.image = imageBorderRepresentation
                            }
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.loadingPlaceholderView.uncover(animated: false)
                        }
                        UIView.animate(withDuration: 0.2, animations: {
                                self.imageView.alpha = 1.0
                            }, completion: { (b) in
                                //Do nothing
                        })
                    } else {
                        
                        loadingPlaceholderView.gradientColor = .white
                        loadingPlaceholderView.backgroundColor = .clear
                        //loadingPlaceholderView.cover(self, animated: true)
                        
                        UIView.animate(withDuration: 0.1, animations: {
                            self.loadingPlaceholderView.cover(self, animated: true)
                        }, completion: { (b) in
                            //Do nothing coming soon
                        })
                        
                        let task = URLSession.shared.dataTask(with: url!, completionHandler: { data, _, error in
                            if error == nil {
                                
                                guard let unwrappedData = data, let downloadedImage = UIImage(data: unwrappedData) else { return }
                                
                                let imageBorderRepresentation = downloadedImage.imageWithInsets(insets: UIEdgeInsets(top: 22, left: 22, bottom: 22, right: 22))
                                if downloadedImage.hasAlpha {
                                    DispatchQueue.main.async { [self] in
                                        //Sdk Detect alpha channel
                                        self.imageView.backgroundColor = .clear
                                        self.imageView.layer.borderWidth = 0.0
                                        self.imageView.image = downloadedImage
                                    }
                                } else {
                                    DispatchQueue.main.async { [self] in
                                        self.imageView.backgroundColor = .white
                                        self.imageView.layer.borderWidth = 22.0
                                        self.imageView.image = imageBorderRepresentation
                                    }
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                    self.loadingPlaceholderView.uncover(animated: true)
                                }
                                
                                DispatchQueue.main.async { [self] in
                                    UIView.animate(withDuration: 1.8, animations: {
                                        self.imageView.alpha = 1.0
                                    }, completion: { (b) in })
                                }
                                
                                StoryBlockImageCache.save(downloadedImage, for: url!.absoluteString)
                            }
                        })
                        task.resume()
                    }
                }
            }
        }
    }
    
    private func setToDefault() {
        self.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setToDefault()
    }
}


final class TopAlignedLabel: UILabel {
    override func drawText(in rect: CGRect) {
        super.drawText(in: .init(
            origin: .zero,
            size: textRect(
                forBounds: rect,
                limitedToNumberOfLines: numberOfLines
            ).size
        ))
    }
}

extension UIImage {
    func imageWithInsets(insets: UIEdgeInsets) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(
            CGSize(width: self.size.width + insets.left + insets.right,
                   height: self.size.height + insets.top + insets.bottom), false, self.scale)
        let _ = UIGraphicsGetCurrentContext()
        let origin = CGPoint(x: insets.left, y: insets.top)
        self.draw(at: origin)
        let imageWithInsets = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        return imageWithInsets
    }
}

extension UIImage {
    public var hasAlpha: Bool {
        guard let alphaInfo = self.cgImage?.alphaInfo else { return false }
        switch alphaInfo {
            case .none, .noneSkipLast, .noneSkipFirst:
            return false
        default:
            return true
        }
    }
}
