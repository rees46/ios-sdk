import UIKit

class CheckoutViewController: UIViewController {

    @IBOutlet weak var checkoutTable: UITableView!
    @IBOutlet weak var totalItem: UILabel!
    @IBOutlet weak var totalAmoutValue: UILabel!
    @IBOutlet weak var shippingLabel: UILabel!
    @IBOutlet weak var totalLabel: UILabel!
    @IBOutlet weak var purchaseButton: UIButton!
    
    @IBOutlet weak var messageLabel: UILabel!
    
    @IBOutlet weak var backButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        checkoutTable.delegate = self
        checkoutTable.dataSource = self
        
        view.backgroundColor = .white
        checkoutTable.backgroundColor = .white
        
        shippingLabel.isHidden = true
        messageLabel.isHidden = true
        messageLabel.text = "Your Cart is empty, Let's fill it"
        //let c: String = String(format: "%.0f", (DataService.instance.getQuantityCount()))

        //totalItem.text = "There are no products in your cart"//"Total \(DataService.instance.getQuantityCount()) items:"
        //let ddd = ShopCartDataService.instance.getQuantityCount()
        if ShopCartDataService.instance.getQuantityCount() == 0 {
            totalItem.text = "There are no products in your cart"
            totalItem.isHidden = true
            
            
            messageLabel.isHidden = false
            totalAmoutValue.isHidden = true
            totalLabel.isHidden = true
            purchaseButton.isHidden = true
            shippingLabel.isHidden = true
        } else {
            let dd = "\(ShopCartDataService.instance.getTotalAmount())"
            
            let cw: String = String(format: "%f", (ShopCartDataService.instance.getQuantityCount()))
            totalAmoutValue.text = dd
            totalItem.text = "Total " + cw + "products:"
            totalItem.isHidden = false
            totalAmoutValue.text = dd
            
            messageLabel.isHidden = true
            totalAmoutValue.isHidden = false
            totalLabel.isHidden = false
            purchaseButton.isHidden = false
            shippingLabel.isHidden = true
        }
        
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        checkoutTable.reloadData()
    }
    

    @IBAction func purchaseTapped(_ sender: UIButton) {
//        let AlertVC = UIAlertController(title: "Purchase Successful ", message: "Order placed successfully and will be delivered within 7 working days.", preferredStyle: .alert)
//        let action = UIAlertAction(title: "Done", style: .cancel, handler: nil)
//        AlertVC.addAction(action)
//        present(AlertVC, animated: true, completion: nil)
//        ShopCartDataService.instance.emptyCart()
//        checkoutTable.reloadData()
        emptyCartMessage()
    }
    
    func emptyCartMessage() {
        if ShopCartDataService.instance.getQuantityCount() == 0 {
            messageLabel.isHidden = false
            messageLabel.text = "Your Cart is empty, Let's fill it"
            totalItem.text = ""
//            totalAmoutValue.text = ""
            totalAmoutValue.isHidden = true
            totalLabel.isHidden = true
            purchaseButton.isHidden = true
            shippingLabel.isHidden = true
        } else {
            
            messageLabel.isHidden = false
            shippingLabel.isHidden = true
            totalAmoutValue.isHidden = true
            totalLabel.isHidden = true
            purchaseButton.isHidden = true
            shippingLabel.isHidden = true
            
            let AlertVC = UIAlertController(title: "Purchase Successful ", message: "Order placed successfully and will be delivered within 7 working days.", preferredStyle: .alert)
            let action = UIAlertAction(title: "Continue Shopping", style: .cancel, handler: nil)
            AlertVC.addAction(action)
            present(AlertVC, animated: true, completion: nil)
            ShopCartDataService.instance.emptyCart()
            checkoutTable.reloadData()
        }
    }
    
    @objc private func didTapBack() {
        self.dismiss(animated: false, completion: nil)
    }
}

extension CheckoutViewController: UITableViewDelegate {}

extension CheckoutViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ShopCartDataService.instance.getCartProductCount()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "CheckoutCell") as? CheckoutCell {
            cell.delegate = self
            cell.updateCell(with: ShopCartDataService.instance.cart.products[indexPath.row])
            return cell
        }
        return CheckoutCell()
    }
}

extension CheckoutViewController: UpdateTotalQuantity {
    func updateQuantity(with item: Int) {
        if item == 0 {
            totalItem.text = "There are no products in your cart"
            totalItem.isHidden = true
        } else {
            self.messageLabel.isHidden = true
            
            let cw: String = String(format: "%f", (ShopCartDataService.instance.getQuantityCount()))
            totalItem.text = "Total " + cw + " products:"
        }
    }
    
    func emptyCart(item:  ShopSelectedProduct) {
        ShopCartDataService.instance.removeProduct(fromCart: nil, selectedProduct: item)
        checkoutTable.reloadData()
        emptyCartMessage()
    }
    
    func updateTotalAmount(of items: Double) {
        let cd: String = String(format: "%.0f", items)
        
        if cd != "0.0" || cd != "0" {
            //let dd = "\(ShopCartDataService.instance.getTotalAmount())"
            
            let cw: String = String(format: "%.0f", (ShopCartDataService.instance.getQuantityCount()))
            
            if cw != "0" {
                totalItem.text = "Total " + cw + " products:"
            } else {
                totalItem.text = "Total products:"
            }
            
            totalAmoutValue.isHidden = false
            totalItem.isHidden = false
            totalLabel.isHidden = false
            messageLabel.isHidden = true
            shippingLabel.isHidden = false
            purchaseButton.isHidden = false
        } else {
            totalAmoutValue.isHidden = true
            totalLabel.isHidden = true
            totalItem.isHidden = true
            messageLabel.isHidden = false
            shippingLabel.isHidden = true
            purchaseButton.isHidden = true
        }
        
        totalAmoutValue.text = cd
        
    }
}
