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
        layer.cornerRadius = rounded ? frame.size.height / 2 : 2
    }
    
    func configProductsButton(buttonData: StoriesElement) {
        if (buttonData.products!.count != 0) {
            
            titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
            setTitle(buttonData.labels?.showCarousel ?? "See all products", for: .normal)
            //setTitleColor(.white, for: .normal)
            
            var mainBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
            mainBundle = Bundle.module
#endif
            
            let angleUpIcon = UIImage(named: "angleUpBlack", in: mainBundle, compatibleWith: nil)
            if GlobalHelper.DeviceType.IS_IPHONE_8 || GlobalHelper.DeviceType.IS_IPHONE_8P || GlobalHelper.DeviceType.IS_IPHONE_5 {
                
                backgroundColor = .white
                setTitleColor(.black, for: .normal)
                
                //angleUpIcon = UIImage(named: "angleUpBlack", in: mainBundle, compatibleWith: nil)
                //backgroundColor = .clear
                //setTitleColor(.white, for: .normal)
            } else {
                backgroundColor = .white
                setTitleColor(.black, for: .normal)
            }
            
//            layer.shadowColor = UIColor.black.cgColor
//            layer.shadowOffset = CGSize(width: 0.0, height: 3.0)
//            layer.shadowRadius = 3
//            layer.shadowOpacity = 1.0
            
            //backgroundColor = .clear
            layer.cornerRadius = layer.frame.size.height/2
            layer.masksToBounds = true
            
            //let angleUpIcon = UIImage(named: "angleUpWhite", in: mainBundle, compatibleWith: nil)
            self.addRightIconForProductsBtn(image: angleUpIcon!)
            
        } else {
            titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
            
            self.layer.cornerRadius = layer.frame.size.height/2
            self.layer.masksToBounds = true
        }
        super.layoutSubviews()
    }
    
    @objc public func didTapButton() {
//        if let productsList = selectedProductsElement?.products, productsList.count != 0 {
//            UserDefaults.standard.set(Int(currentSlide!.id), forKey: "SlideOpenSetting")
//            let products = productsList
//            delegate?.openProductsCarousel(products: products)
//            return
//        }
        
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
        setTitleColor(.black, for: .normal)
        layer.cornerRadius = layer.frame.size.height / 2
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
}
