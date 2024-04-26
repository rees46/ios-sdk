import UIKit

class DetailScreenViewController: UIViewController {
    
    @IBOutlet weak var productTitle: UILabel!
    @IBOutlet weak var productPrice: UILabel!
    @IBOutlet weak var productDescription: UILabel!
    @IBOutlet weak var sliderCollectionView: UICollectionView!
    @IBOutlet weak var pageView: UIPageControl!
    
    @IBOutlet private weak var backButton: UIButton!
    
    public var product: ShopCartPrepareProduct?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        sliderCollectionView.delegate = self
        sliderCollectionView.dataSource = self
        
        guard let productInfo = product else {
            return
        }
        
        productTitle.text = productInfo.title
        productPrice.text = "\(productInfo.price)"
        productDescription.text = productInfo.description
        pageView.currentPage = 0
        
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
    }
    
    func updateView(with selectedProduct: ShopCartPrepareProduct) {
        product = selectedProduct
    }
    
    @IBAction func checkoutTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "CheckoutVC", sender: product)
        guard let product = product else { return }
        
        if !ShopCartDataService.instance.isProductInCart(product) {
            ShopCartDataService.instance.addProduct(toCart: product, numberOfProduct: 1, status: true)
        } else {
            ShopCartDataService.instance.updateQuantity(incart:nil, optionalItem: product, with: 1)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let barButton = UIBarButtonItem()
        barButton.title = ""
        navigationItem.backBarButtonItem = barButton
    }
}

extension DetailScreenViewController: UICollectionViewDelegate {
    //
}

extension DetailScreenViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {

        guard let count = product?.imagesArray.count else {
            return 1
        }
        pageView.size(forNumberOfPages: 44)
        pageView.numberOfPages = count
        return count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImagesCell", for: indexPath) as? SliderCell {
            
            if let image = product?.imageName {
                cell.updateCell(with: image)
                pageView.currentPage = indexPath.row
                return cell
            }
        }
        return SliderCell()
    }
    
    @objc private func didTapBack() {
        self.dismiss(animated: false, completion: nil)
    }
}
