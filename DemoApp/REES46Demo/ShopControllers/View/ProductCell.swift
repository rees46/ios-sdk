import UIKit
import REES46

protocol updateCartCountDelegate {
    func updateCart(with count: Int)
}

class ProductCell: UICollectionViewCell {
    
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
    
    var product: ShopCartPrepareProduct?
    var addedToCart: Bool = false
    
    var delegate: updateCartCountDelegate?
    
    func updateCell(with product: ShopCartPrepareProduct) {
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
                    }
                }
            }.resume()
        }
        
        delegate?.updateCart(with: ShopCartDataService.instance.getQuantityCount())
    }
    
    override func draw(_ rect: CGRect) {
        layer.borderWidth = 1
        //layer.borderColor = UIColor.lightGray.cgColor
        layer.borderColor = UIColor.clear.cgColor
        layer.cornerRadius = 5
        layer.masksToBounds = true
    }
    
    @IBAction func addToCartTapped(_ sender: UIButton) {
        addedToCart.toggle()
        guard let selectedProduct = product else { return }
        
        var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        frameworkBundle = Bundle.module
#endif
        
        if !ShopCartDataService.instance.isProductInCart(selectedProduct) {
            ShopCartDataService.instance.addProduct(toCart: selectedProduct, numberOfProduct: 1, status: true)
            if #available(iOS 13.0, *) {
                addToCart.setImage(UIImage(systemName: "cart"), for: .normal)
            } else {
                addToCart.setImage(UIImage(named: "cart", in: frameworkBundle, compatibleWith: nil), for: .normal)
            }
        } else {
            ShopCartDataService.instance.removeProduct(fromCart: selectedProduct, selectedProduct: nil)
            if #available(iOS 13.0, *) {
                addToCart.setImage(UIImage(systemName: "nil"), for: .normal)
            } else {
                addToCart.setImage(UIImage(named: "nil", in: frameworkBundle, compatibleWith: nil), for: .normal)
            }
        }
        
        delegate?.updateCart(with: ShopCartDataService.instance.getQuantityCount())
    }
}

extension UIImage {

    func addImagePadding(x: CGFloat, y: CGFloat) -> UIImage? {
        let width: CGFloat = size.width + x
        let height: CGFloat = size.height + y
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
        let origin: CGPoint = CGPoint(x: (width - size.width) / 2, y: (height - size.height) / 2)
        draw(at: origin)
        let imageWithPadding = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return imageWithPadding
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
