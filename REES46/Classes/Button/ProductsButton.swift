import UIKit

protocol CustomProductButtonDelegate: AnyObject {
    func openDeepLink(url: String)
    func openLinkIosExternal(url: String)
    func openLinkWebExternal(url: String)
}

@IBDesignable class ProductsButton: UIButton {
    
    var _buttonData: StoriesElement?
    weak var delegate: CustomProductButtonDelegate?
    var sdk: PersonalizationSDK!
    
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
        layer.cornerRadius = rounded ? frame.size.height / 2 : 2
    }
    
    func configProductsButton(buttonData: StoriesElement) {
        if (buttonData.products!.count != 0) {
            if sdkConfiguration.stories.slideProductsButtonFontNameChanged != nil {
                if sdkConfiguration.stories.slideProductsButtonFontSizeChanged != nil {
                    self.titleLabel?.font = UIFont(name: sdkConfiguration.stories.slideProductsButtonFontNameChanged!, size:  sdkConfiguration.stories.slideProductsButtonFontSizeChanged!)
                } else {
                    self.titleLabel?.font = UIFont(name: sdkConfiguration.stories.slideProductsButtonFontNameChanged!, size: 14)
                }
            } else {
                titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
            }
            
            //titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
            setTitle(buttonData.labels?.showCarousel ?? "See all products", for: .normal)
            
            var mainBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
            mainBundle = Bundle.module
#endif
            
            let angleUpIcon = UIImage(named: "angleUpBlack", in: mainBundle, compatibleWith: nil)?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
            
            if sdkConfiguration.stories.slideProductsButtonBackgroundColorChanged != nil {
                self.backgroundColor = sdkConfiguration.stories.slideProductsButtonBackgroundColorChanged
            } else {
                self.backgroundColor = .white
                //angleUpIcon = UIImage(named: "angleUpBlack", in: mainBundle, compatibleWith: nil)
                //backgroundColor = .clear
                //setTitleColor(.white, for: .normal)
            }
            
            layer.cornerRadius = layer.frame.size.height/2
            layer.masksToBounds = true
            
            //self.titleLabel?.font = UIFont(name: "Roboto-Regular", size: 17.0)
            
            if sdkConfiguration.stories.slideProductsButtonTextColorChanged != nil {
                if let components = sdkConfiguration.stories.slideProductsButtonTextColorChanged?.rgba {
                    self.setTitleColor(UIColor(red: components.red, green: components.green, blue: components.blue, alpha: components.alpha), for: .normal)
                } else {
                    self.setTitleColor(.black, for: .normal)
                }
                self.addRightIconForProductsBtn(image: angleUpIcon!)
                tintColor = sdkConfiguration.stories.slideProductsButtonTextColorChanged
            } else {
                setTitleColor(.black, for: .normal)
                tintColor = .black
            }
        } else {
            titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
            
            self.layer.cornerRadius = layer.frame.size.height/2
            self.layer.masksToBounds = true
        }
        super.layoutSubviews()
    }
    
    @objc public func didTapButton() {
        
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
        //setTitleColor(.black, for: .normal)
        layer.cornerRadius = layer.frame.size.height / 2
        layer.masksToBounds = true
        super.layoutSubviews()
    }
}

extension UIButton {
    func addRightIconForProductsBtn(image: UIImage) {
        
        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        //imageView.tintColor = .red
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
