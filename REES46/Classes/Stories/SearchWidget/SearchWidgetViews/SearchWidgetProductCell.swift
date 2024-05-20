import UIKit

public protocol UpdateCartCountDelegate {
    func updateCart(with count: Int)
}

public class SearchWidgetProductCell: UICollectionViewCell {
    
    @IBOutlet weak var productBrand: UILabel!
    @IBOutlet weak var productTitle: UILabel!
    @IBOutlet weak var productOldPrice: UILabel!
    @IBOutlet weak var productPrice: UILabel!
    @IBOutlet weak var productImage: UIImageView! {
        didSet {
            productImage.layer.cornerRadius = 5
            productImage.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.7).cgColor
            productImage.layer.masksToBounds = true
            productImage.layer.borderWidth = 1
        }
    }
    
    @IBOutlet weak var rateStarsView: RecommendationsStarsView!
    
    @IBOutlet weak var addToCart: UIButton!
    
    public var product: SearchWidgetProductDataPrepare?
    public var addedToCart: Bool = false
    
    public var delegate: UpdateCartCountDelegate?
    
    static let searchWidgetProductCell = "SearchWidgetProductCell"
    
    class var identifier: String {
        return String(describing: self)
    }
    
    func updateCell(with product: SearchWidgetProductDataPrepare) {
        self.product = product
        productBrand.text = product.brandTitle
        productTitle.text = product.title
        productPrice.text = "\(product.price)"
        
        let mainProductText = product.oldPrice
        let textRange = NSMakeRange(0, mainProductText.count)
        let attributedText = NSMutableAttributedString(string: mainProductText)
        attributedText.addAttribute(NSAttributedString.Key.strikethroughStyle , value: NSUnderlineStyle.single.rawValue, range: textRange)
        
        productOldPrice.attributedText = attributedText
        
        rateStarsView.starsSetupSettings.filledImage = UIImage(named: "starFilled")?.withRenderingMode(.alwaysOriginal)
        rateStarsView.starsSetupSettings.emptyImage = UIImage(named: "starEmpty")?.withRenderingMode(.alwaysOriginal)
        
        let randomDouble = Double.random(in: 1 ... 5)
        rateStarsView.rating = randomDouble
        rateStarsView.starsSetupSettings.fillMode = .half
        rateStarsView.starsSetupSettings.reloadOnUserTouch = true
        rateStarsView.translatesAutoresizingMaskIntoConstraints = false
        
        if let url = URL(string: product.imageName) {
            URLSession.shared.dataTask(with: url) { (data, response, error) in
                guard data != nil else { return }
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.4, delay: 0.0,
                                   usingSpringWithDamping: 0.0, initialSpringVelocity: 0.0,
                                   options: .allowAnimatedContent, animations: {
                        guard let imageData = data else { return }
                        let image = UIImage(data: imageData)
                        
                        let imageView = UIImageView(image: image?.imageWithInsets(insets: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)))
                        imageView.frame = CGRect(x: 2, y: 2, width: self.productImage.frame.width - 4, height: self.productImage.frame.height - 4)
                        imageView.contentMode = .scaleAspectFit
                        imageView.backgroundColor = UIColor.white
                        imageView.layer.cornerRadius = 5
                        imageView.layer.masksToBounds = true
                        self.productImage.addSubview(imageView)
                    }) { (isFinished) in
                        //
                    }
                }
            }.resume()
        }
        
        //delegate?.updateCart(with: SearchWidgetProductDataPrepare.instance.getQuantityCount())
    }
    
    public override func draw(_ rect: CGRect) {
        layer.borderWidth = 1
        layer.borderColor = UIColor.clear.cgColor
        layer.cornerRadius = 5
        layer.masksToBounds = true
    }
    
    @objc public func addToCartTappedFromSearchWidget() {
//        addedToCart.toggle()
//        guard let selectedProduct = product else { return }
//        
//        var frameworkBundle = Bundle(for: classForCoder)
//#if SWIFT_PACKAGE
//        frameworkBundle = Bundle.module
//#endif
//        
//        if !dataser.instance.isProductInCart(selectedProduct) {
//            SearchWidgetProductDataPrepare.instance.addProduct(toCart: selectedProduct, numberOfProduct: 1, status: true)
//            if #available(iOS 13.0, *) {
//                addToCart.setImage(UIImage(systemName: "cart"), for: .normal)
//            } else {
//                addToCart.setImage(UIImage(named: "cart", in: frameworkBundle, compatibleWith: nil), for: .normal)
//            }
//        } else {
//            SearchWidgetProductDataPrepare.instance.removeProduct(fromCart: selectedProduct, selectedProduct: nil)
//            if #available(iOS 13.0, *) {
//                addToCart.setImage(UIImage(systemName: "nil"), for: .normal)
//            } else {
//                addToCart.setImage(UIImage(named: "nil", in: frameworkBundle, compatibleWith: nil), for: .normal)
//            }
//        }
//
//            delegate?.updateCart(with: SearchWidgetProductDataPrepare.instance.getQuantityCount())
    }
}
