import UIKit

protocol UpdateTotalQuantity {
    func updateQuantity(with item: Int)
    func updateTotalAmount(of items: Double)
    func emptyCart(item: ShopSelectedProduct)
}

class CheckoutCell: UITableViewCell {
    
    @IBOutlet weak var productTitle: UILabel!
    @IBOutlet weak var productPrice: UILabel!
    @IBOutlet weak var productQuantity: UILabel!
    @IBOutlet weak var productImage: UIImageView! {
        didSet {
            productImage.layer.cornerRadius = 3
            productImage.layer.masksToBounds = true
        }
    }
    @IBOutlet weak var quantityStepper: UIStepper!
    var product: ShopSelectedProduct?
    var delegate: UpdateTotalQuantity?
    
    func updateCell(with product: ShopSelectedProduct) {
        self.product = product
        productTitle.text = product.selectedProduct.title
        productPrice.text = "\(product.selectedProduct.price)"
        
        productPrice.textColor = UIColor.black
        
        if let url = URL(string: product.selectedProduct.imageName) {
            URLSession.shared.dataTask(with: url) { (data, response, error) in
                
                guard let imageData = data else { return }
                
                DispatchQueue.main.async {
                    
                    UIView.animate(withDuration: 0.7, delay: 0.0,
                                   usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0,
                                   options: .allowAnimatedContent, animations: {
                        self.productImage.image = UIImage(data: imageData)
                    }) { (isFinished) in
                    }
                    
                    self.productImage.image = UIImage(data: imageData)
                }
            }.resume()
        }
        
        quantityStepper.setDecrementImage(quantityStepper.decrementImage(for: .normal), for: .normal)
        quantityStepper.setIncrementImage(quantityStepper.incrementImage(for: .normal), for: .normal)
        quantityStepper.backgroundColor = .black
        quantityStepper.layer.cornerRadius = 5
        quantityStepper.value = Double(product.quantity)
        productQuantity.text = "x\(Int(quantityStepper.value))"
        delegate?.updateTotalAmount(of: ShopCartDataService.instance.getTotalAmount())
        clipsToBounds = true
    }

    @IBAction func quantityStepperTapped(_ sender: UIStepper) {
        guard let selectedProduct = product else { return }
        if sender.value == 0 {
            ShopCartDataService.instance.removeProduct(fromCart: nil, selectedProduct: selectedProduct)
            delegate?.emptyCart(item: selectedProduct)
        } else {
            productQuantity.text = "x\(Int(sender.value))"
            ShopCartDataService.instance.updateQuantity(incart: selectedProduct, with: Int(sender.value))
            delegate?.updateQuantity(with: ShopCartDataService.instance.getQuantityCount())
            delegate?.updateTotalAmount(of: ShopCartDataService.instance.getTotalAmount())
        }
        delegate?.updateQuantity(with: ShopCartDataService.instance.getQuantityCount())
        delegate?.updateTotalAmount(of: ShopCartDataService.instance.getTotalAmount())
        print(sender.value)
    }
}
