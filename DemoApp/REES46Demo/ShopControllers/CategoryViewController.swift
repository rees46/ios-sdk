import UIKit

class CategoryViewController: UIViewController {
    
    @IBOutlet weak var categoryTable: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        categoryTable.delegate = self
        categoryTable.dataSource = self
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let ProductVC = segue.destination as? ProductsViewController {
            let barButton = UIBarButtonItem()
            barButton.title = ""
            
            var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
            frameworkBundle = Bundle.module
#endif
            navigationController?.navigationBar.backIndicatorImage = UIImage(named: "arrow.backward", in: frameworkBundle, compatibleWith: nil)
            navigationController?.navigationBar.backIndicatorImage = UIImage(named: "arrow.backward", in: frameworkBundle, compatibleWith: nil)
            navigationController?.navigationBar.backIndicatorTransitionMaskImage = UIImage(named: "arrow.backward", in: frameworkBundle, compatibleWith: nil)
            navigationItem.backBarButtonItem = barButton
            ProductVC.modalPresentationStyle = .fullScreen
            guard let category = sender as? ShopCartCaterogy else { return }
            ProductVC.initProducts(from: category)
        }
    }
}

extension CategoryViewController: UITableViewDelegate {}

extension CategoryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ShopCartDataService.instance.getCategories().count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell") as? CategoryCell {
            let category = ShopCartDataService.instance.getCategories()[indexPath.row]
            cell.updateViews(with: category)
            return cell
        } else {
            return CategoryCell()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let category = ShopCartDataService.instance.getCategories()[indexPath.row]
        performSegue(withIdentifier: "ProductVC", sender: category)
    }
}
