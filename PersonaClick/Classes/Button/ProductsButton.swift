import UIKit

protocol CustomProductButtonDelegate: AnyObject {
    func openDeepLink(url: String)
    func openLinkIosExternal(url: String)
    func openLinkWebExternal(url: String)
}

@IBDesignable class ProductsButton: UIButton {
    
    var _buttonData: StoriesElement?
    weak var delegate: CustomProductButtonDelegate?
    
    init() {
        super.init(frame: .zero)
        setToDefaultProductsButton()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateCornerRadius()
    }

    @IBInspectable var rounded: Bool = true {
        didSet {
            updateCornerRadius()
        }
    }

    func updateCornerRadius() {
        if SdkConfiguration.stories.productsButtonCornerRadius != -1 {
            layer.cornerRadius = SdkConfiguration.stories.productsButtonCornerRadius
        } else {
            layer.cornerRadius = rounded ? frame.size.height / 2 : 2
        }
    }
    
    func configProductsButton(buttonData: StoriesElement) {
        if (buttonData.products!.count != 0) {
            if SdkConfiguration.stories.slideProductsButtonFontNameChanged != nil {
                if SdkConfiguration.stories.slideProductsButtonFontSizeChanged != nil {
                    self.titleLabel?.font = UIFont(name: (SdkConfiguration.stories.slideProductsButtonFontNameChanged)!, size:  (SdkConfiguration.stories.slideProductsButtonFontSizeChanged)!)
                } else {
                    self.titleLabel?.font = UIFont(name: (SdkConfiguration.stories.slideProductsButtonFontNameChanged)!, size: 14)
                }
            } else {
                if SdkConfiguration.stories.slideProductsButtonFontSizeChanged != nil {
                    self.titleLabel?.font = .systemFont(ofSize: SdkConfiguration.stories.slideProductsButtonFontSizeChanged!, weight: .bold)
                } else {
                    self.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
                }
            }
            
            setTitle(buttonData.labels?.showCarousel ?? SdkConfiguration.stories.defaultShowProductsButtonText, for: .normal)
            if buttonData.labels?.showCarousel == "" {
                setTitle(SdkConfiguration.stories.defaultShowProductsButtonText, for: .normal)
            }
            
            var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
            frameworkBundle = Bundle.module
#endif
            
            let angleUpIcon = UIImage(named: "angleUpBlack", in: frameworkBundle, compatibleWith: nil)?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
            
            if SdkConfiguration.isDarkMode {
                if SdkConfiguration.stories.slideProductsButtonBackgroundColorChanged_Dark != nil {
                    self.backgroundColor = SdkConfiguration.stories.slideProductsButtonBackgroundColorChanged_Dark
                } else {
                    self.backgroundColor = .white
                }
            } else {
                if SdkConfiguration.stories.slideProductsButtonBackgroundColorChanged_Light != nil {
                    self.backgroundColor = SdkConfiguration.stories.slideProductsButtonBackgroundColorChanged_Light
                } else {
                    self.backgroundColor = .white
                }
            }
            
            if SdkConfiguration.stories.productsButtonCornerRadius != -1 {
                layer.cornerRadius = SdkConfiguration.stories.productsButtonCornerRadius
            } else {
                layer.cornerRadius = layer.frame.size.height/2
            }
            layer.masksToBounds = true
            
            if SdkConfiguration.isDarkMode {
                if SdkConfiguration.stories.slideProductsButtonTextColorChanged_Dark != nil {
                    if let components = SdkConfiguration.stories.slideProductsButtonTextColorChanged_Dark?.rgba {
                        self.setTitleColor(UIColor(red: components.red, green: components.green, blue: components.blue, alpha: components.alpha), for: .normal)
                    } else {
                        self.setTitleColor(.black, for: .normal)
                    }
                    self.addRightIconForProductsBtn(image: angleUpIcon!)
                    tintColor = SdkConfiguration.stories.slideProductsButtonTextColorChanged_Dark
                } else {
                    setTitleColor(.black, for: .normal)
                    self.addRightIconForProductsBtn(image: angleUpIcon!)
                    tintColor = .black
                }
            } else {
                if SdkConfiguration.stories.slideProductsButtonTextColorChanged_Light != nil {
                    if let components = SdkConfiguration.stories.slideProductsButtonTextColorChanged_Light?.rgba {
                        self.setTitleColor(UIColor(red: components.red, green: components.green, blue: components.blue, alpha: components.alpha), for: .normal)
                    } else {
                        self.setTitleColor(.black, for: .normal)
                    }
                    self.addRightIconForProductsBtn(image: angleUpIcon!)
                    tintColor = SdkConfiguration.stories.slideProductsButtonTextColorChanged_Light
                } else {
                    setTitleColor(.black, for: .normal)
                    self.addRightIconForProductsBtn(image: angleUpIcon!)
                    tintColor = .black
                }
            }
            
        } else {
            titleLabel?.font = .systemFont(ofSize: 17.0, weight: .semibold)
            if SdkConfiguration.stories.productsButtonCornerRadius != -1 {
                self.layer.cornerRadius = SdkConfiguration.stories.productsButtonCornerRadius
            } else {
                self.layer.cornerRadius = layer.frame.size.height/2
            }
            self.layer.masksToBounds = true
        }
        super.layoutSubviews()
    }
    
    @objc
    public func didTapButton() {
        
        if let iosLink = _buttonData?.linkIos {
            delegate?.openLinkIosExternal(url: iosLink)
            return
        }
        if let link = _buttonData?.link {
            delegate?.openDeepLink(url: link)
            return
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setToDefaultProductsButton()
        super.layoutSubviews()
    }
    
    private func setToDefaultProductsButton() {
        backgroundColor = .white
        setTitle("", for: .normal)
        if SdkConfiguration.stories.productsButtonCornerRadius != -1 {
            layer.cornerRadius = SdkConfiguration.stories.productsButtonCornerRadius
        } else {
            layer.cornerRadius = layer.frame.size.height / 2
        }
        layer.masksToBounds = true
        super.layoutSubviews()
    }
}


extension UIButton {
    func addRightIconForProductsBtn(image: UIImage) {
        
        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        let length = CGFloat(21)
        titleEdgeInsets.right += length

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: self.titleLabel!.trailingAnchor, constant: 6),
            imageView.centerYAnchor.constraint(equalTo: self.titleLabel!.centerYAnchor, constant: 1),
            imageView.widthAnchor.constraint(equalToConstant: length),
            imageView.heightAnchor.constraint(equalToConstant: length)
        ])
    }
    
    func setImageTintColor(_ color: UIColor) {
        let tintedImage = self.imageView?.image?.withRenderingMode(.alwaysTemplate)
        self.setImage(tintedImage, for: .normal)
        self.tintColor = color
    }
}
