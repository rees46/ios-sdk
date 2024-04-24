import UIKit

class PromoCodeView: UIView {
    var _promoData: StoriesPromoCodeElement?
    
    private let loadingPlaceholderView = LoadingPlaceholderView()
    
    let promoProductNameLabel = UILabel()
    var promocodeSlideProductImage = UIImageView()
    
    init() {
        super.init(frame: .zero)
        setToDefault()
    }
    
    func configPromoView(promoData: StoriesPromoCodeElement) {
        promoProductNameLabel.removeFromSuperview()
        
        if (promoData.name != "") {
            if SdkGlobalHelper.DeviceType.IS_IPHONE_14 || SdkGlobalHelper.DeviceType.IS_IPHONE_14_PLUS || SdkGlobalHelper.DeviceType.IS_IPHONE_XS_MAX || SdkGlobalHelper.DeviceType.IS_IPHONE_XS || SdkGlobalHelper.DeviceType.IS_IPHONE_SE || SdkGlobalHelper.DeviceType.IS_IPHONE_8_PLUS || SdkGlobalHelper.DeviceType.IS_IPHONE_5 {
                promoProductNameLabel.frame = CGRect(x: frame.minX + 18, y: frame.minY + 72, width: frame.width - 60, height: 80)
            } else {
                promoProductNameLabel.frame = CGRect(x: frame.minX + 18, y: frame.minY + 116, width: frame.width - 60, height: 80)
            }
            promoProductNameLabel.text = promoData.name
            promoProductNameLabel.numberOfLines = 0
            promoProductNameLabel.textAlignment = .left
            
            if SdkConfiguration.stories.promoCodeSlideFontNameChanged != nil {
                if let customFont = UIFont(name: SdkConfiguration.stories.promoCodeSlideFontNameChanged!, size: 16) {
                    promoProductNameLabel.font = customFont
                }
                if SdkConfiguration.stories.promoCodeSlideFontSizeChanged != nil {
                    if let customFontWithSize = UIFont(name: SdkConfiguration.stories.promoCodeSlideFontNameChanged!, size: SdkConfiguration.stories.promoCodeSlideFontSizeChanged!) {
                        promoProductNameLabel.font = customFontWithSize
                    }
                }
            } else {
                promoProductNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
                if SdkConfiguration.stories.promoCodeSlideFontSizeChanged != nil {
                    promoProductNameLabel.font = UIFont.systemFont(ofSize: SdkConfiguration.stories.promoCodeSlideFontSizeChanged!, weight: .semibold)
                }
            }
            
            if SdkConfiguration.isDarkMode {
                promoProductNameLabel.textColor = SdkConfiguration.stories.promoProductTitleTextColorDarkMode ?? .white
            } else {
                promoProductNameLabel.textColor = SdkConfiguration.stories.promoProductTitleTextColorLightMode ?? .white
            }
            
            promoProductNameLabel.sizeToFit()
            addSubview(promoProductNameLabel)
            
            promocodeSlideProductImage.backgroundColor = .clear
            promocodeSlideProductImage.contentMode = .scaleAspectFit
            promocodeSlideProductImage.layer.masksToBounds = true
            promocodeSlideProductImage.layer.cornerRadius = 6.0
            promocodeSlideProductImage.layer.borderColor = UIColor.clear.cgColor
            promocodeSlideProductImage.frame = CGRect(x: 18, y: frame.maxY / 2 - frame.size.width / 2, width: frame.size.width - 36, height: frame.size.width - 36)
            
            addSubview(promocodeSlideProductImage)
            
            let urlImgFullSize: String = promoData.image_url
            let urlImgDownloadAndResize = URL(string: promoData.image_url_resized?.image_url_resized520 ?? urlImgFullSize)
            
            if urlImgDownloadAndResize != nil {
                SdkImagesCacheLoader.image(for: urlImgDownloadAndResize!.absoluteString) { [self] cachedImage in
                    if cachedImage != nil {
                        let imageBorderRepresentation = cachedImage!.imageWithInsets(insets: UIEdgeInsets(top: 22, left: 22, bottom: 22, right: 22))
                        if cachedImage!.hasAlpha {
                            DispatchQueue.main.async {
                                self.promocodeSlideProductImage.backgroundColor = .clear
                                self.promocodeSlideProductImage.layer.borderWidth = 0.0
                                self.promocodeSlideProductImage.image = cachedImage
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.promocodeSlideProductImage.backgroundColor = .white
                                self.promocodeSlideProductImage.layer.borderWidth = 22.0
                                self.promocodeSlideProductImage.image = imageBorderRepresentation
                            }
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.loadingPlaceholderView.uncover(animated: false)
                        }
                        UIView.animate(withDuration: 0.2, animations: {
                                self.promocodeSlideProductImage.alpha = 1.0
                            }, completion: { (isFinished) in
                                // TODO Implementation
                        })
                    } else {
                        
                        loadingPlaceholderView.gradientColor = .white
                        loadingPlaceholderView.backgroundColor = .clear
                        
                        UIView.animate(withDuration: 0.1, animations: {
                            self.loadingPlaceholderView.cover(self, animated: true)
                        }, completion: { (isFinished) in
                            // TODO Implementation
                        })
                        
                        let task = URLSession.shared.dataTask(with: urlImgDownloadAndResize!, completionHandler: { data, _, error in
                            if error == nil {
                                guard let unwrappedImageData = data, let downloadedImage = UIImage(data: unwrappedImageData) else {
                                    return
                                }
                                
                                let imageBorderRepresentation = downloadedImage.imageWithInsets(insets: UIEdgeInsets(top: 22, left: 22, bottom: 22, right: 22))
                                if downloadedImage.hasAlpha {
                                    DispatchQueue.main.async { [self] in
                                        self.promocodeSlideProductImage.backgroundColor = .clear
                                        self.promocodeSlideProductImage.layer.borderWidth = 0.0
                                        self.promocodeSlideProductImage.image = downloadedImage
                                    }
                                } else {
                                    DispatchQueue.main.async { [self] in
                                        self.promocodeSlideProductImage.backgroundColor = .white
                                        self.promocodeSlideProductImage.layer.borderWidth = 22.0
                                        self.promocodeSlideProductImage.image = imageBorderRepresentation
                                    }
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                    self.loadingPlaceholderView.uncover(animated: true)
                                }
                                
                                DispatchQueue.main.async { [self] in
                                    UIView.animate(withDuration: 1.8, animations: {
                                        self.promocodeSlideProductImage.alpha = 1.0
                                    }, completion: { (isFinished) in })
                                }
                                
                                SdkImagesCacheLoader.save(downloadedImage, for: urlImgDownloadAndResize!.absoluteString)
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

extension UIImage {
    func imageWithInsets(insets: UIEdgeInsets) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(
            CGSize(width: self.size.width + insets.left + insets.right,
                   height: self.size.height + insets.top + insets.bottom), false, self.scale)
        let origin = CGPoint(x: insets.left, y: insets.top)
        self.draw(at: origin)
        let imageWithInsets = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        return imageWithInsets
    }
}

extension UIImage {
    public var hasAlpha: Bool {
        guard let alphaInfo = self.cgImage?.alphaInfo else {
            return false
        }
        
        switch alphaInfo {
            case .none, .noneSkipLast, .noneSkipFirst:
            return false
        default:
            return true
        }
    }
}
