import UIKit

class ProductsViewController: UIViewController {
    
    @IBOutlet weak var productTable: UICollectionView!
    
    var addToCart = CartButton(image: UIImage(named: "cart"))

    private(set) public var products = [ShopCartPrepareProduct]()
    var cartItemCount: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        productTable.delegate = self
        productTable.dataSource = self
        
        navigationItem.rightBarButtonItem = addToCart
//        addToCart.setBadge(with: cartItemCount)
        addToCart.tapAction = {
            self.performSegue(withIdentifier: "CheckoutVC", sender: self)
        }
    }
    
    func initProducts(from category: ShopCartCaterogy) {
        //products = ShopCartDataService.instance.getProducts(forCategory: category.title)
        //navigationItem.title = category.title
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let DetailVC = segue.destination as? DetailScreenViewController {
            let barButton = UIBarButtonItem()
            barButton.title = ""
            navigationItem.backBarButtonItem = barButton
            guard let product = sender as? ShopCartPrepareProduct else { return }
            DetailVC.updateView(with: product)
        }
    }
    
    @IBAction func upwindSegue(with segue: UIStoryboardSegue) {
        productTable.reloadData()
    }
}

extension ProductsViewController: UICollectionViewDelegate {}

extension ProductsViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return products.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProductCell", for: indexPath) as? ProductCell {
            cell.delegate = self
            let product = products[indexPath.row]
            cell.updateCell(with: product)
            return cell
        }
        return ProductCell()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedProduct = products[indexPath.row]
        performSegue(withIdentifier: "DetailVC", sender: selectedProduct)
    }
}

extension ProductsViewController: updateCartCountDelegate {
    func updateCart(with count: Int) {
        cartItemCount = count
        addToCart.setBadge(with: count)
    }
}
