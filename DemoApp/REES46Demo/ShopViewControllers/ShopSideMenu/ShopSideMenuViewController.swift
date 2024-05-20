import UIKit

protocol ShopSideMenuViewControllerDelegate {
    func selectedCell(_ row: Int)
}

class ShopSideMenuViewController: UIViewController {
    @IBOutlet var headerImageView: UIImageView!
    @IBOutlet var sideMenuTableView: UITableView!
    @IBOutlet var additionalMenuTableView: UITableView!
    
    @IBOutlet var loginLabel: UILabel!
    @IBOutlet var signUpLabel: UILabel!
    @IBOutlet var shopSideMenuFooterLabel: UILabel!
    @IBOutlet var closeMenuBtn: UIButton!

    var delegate: ShopSideMenuViewControllerDelegate?
    var defaultHighlightedCell: Int = 0
    
    var sideShopMenu: [ShopSideMenuModel] = [
//        ShopSideMenuModel(icon: UIImage(systemName: "house.fill")!, title: "Home"),
//        ShopSideMenuModel(icon: UIImage(systemName: "house.fill")!, title: "WOMENS"),
//        ShopSideMenuModel(icon: UIImage(systemName: "music.note")!, title: "MENS"),
//        ShopSideMenuModel(icon: UIImage(systemName: "film.fill")!, title: "GIRLS"),
//        ShopSideMenuModel(icon: UIImage(systemName: "book.fill")!, title: "BOYS"),
//        ShopSideMenuModel(icon: UIImage(systemName: "person.fill")!, title: "BABY"),
//        ShopSideMenuModel(icon: UIImage(systemName: "slider.horizontal.3")!, title: "HOLIDAY SHOP"),
//        ShopSideMenuModel(icon: UIImage(systemName: "book.fill")!, title: "BRANDS"),
//        ShopSideMenuModel(icon: UIImage(systemName: "hand.thumbsup.fill")!, title: "TREDING"),
//        ShopSideMenuModel(icon: UIImage(systemName: "music.note")!, title: "SALE"),
//        ShopSideMenuModel(icon: UIImage(systemName: "hand.thumbsup.fill")!, title: "Delivery"),
//        ShopSideMenuModel(icon: UIImage(systemName: "hand.thumbsup.fill")!, title: "Returns"),
//        ShopSideMenuModel(icon: UIImage(systemName: "house.fill")!, title: "Shopping cart")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        self.sideMenuTableView.delegate = self
        self.sideMenuTableView.dataSource = self
        self.sideMenuTableView.backgroundColor = #colorLiteral(red: 0.9921568627, green: 0.9921568627, blue: 0.9921568627, alpha: 1)
        self.sideMenuTableView.separatorStyle = .none

        self.shopSideMenuFooterLabel.textColor = UIColor.white
        //self.footerLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        self.shopSideMenuFooterLabel.text = "Who I Am?"
        self.shopSideMenuFooterLabel.layer.borderColor = UIColor.black.cgColor
        self.shopSideMenuFooterLabel.layer.borderWidth = 5.0
        self.shopSideMenuFooterLabel.layer.cornerRadius = 10.0
        self.shopSideMenuFooterLabel.layer.masksToBounds = true
        self.shopSideMenuFooterLabel.layer.backgroundColor = UIColor.black.cgColor
        
        self.loginLabel.textColor = UIColor.black
        self.loginLabel.layer.borderColor = UIColor.black.cgColor
        self.loginLabel.layer.borderWidth = 1.4
        self.loginLabel.layer.cornerRadius = 10.0
        self.loginLabel.layer.masksToBounds = true
        self.loginLabel.layer.backgroundColor = UIColor.clear.cgColor
        
        self.signUpLabel.textColor = UIColor.black
        self.signUpLabel.layer.borderColor = UIColor.black.cgColor
        self.signUpLabel.layer.borderWidth = 1.4
        self.signUpLabel.layer.cornerRadius = 10.0
        self.signUpLabel.layer.masksToBounds = true
        self.signUpLabel.layer.backgroundColor = UIColor.clear.cgColor
        
        self.sideMenuTableView.register(ShopSideMenuCell.nib, forCellReuseIdentifier: ShopSideMenuCell.identifier)

        self.sideMenuTableView.reloadData()
        
        closeMenuBtn.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
    }
    
    @objc private func didTapBack() {
        self.delegate?.selectedCell(0)
    }
}

extension ShopSideMenuViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 48
    }
}

extension ShopSideMenuViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if #available(iOS 13.0, *) {
            return self.sideShopMenu.count
        } else {
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ShopSideMenuCell.identifier, for: indexPath) as? ShopSideMenuCell else { fatalError("SDK: ShopSideMenuCell Xib doesn't exist") }

        cell.iconImageView.image = self.sideShopMenu[indexPath.row].icon
        
        if indexPath.row == 0 {
            cell.iconImageView.isHidden = false
        } else {
            cell.iconImageView.isHidden = true
            //cell.iconImageView.frame.size.width -= 20
        }
        cell.titleLabel.text = self.sideShopMenu[indexPath.row].title

        let myCustomSelectionColorView = UIView()
        myCustomSelectionColorView.backgroundColor = #colorLiteral(red: 0.9759920635, green: 0.9754939579, blue: 0.9777660236, alpha: 0.9699803566)
        cell.selectedBackgroundView = myCustomSelectionColorView
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.delegate?.selectedCell(indexPath.row)
//        if indexPath.row == 4 || indexPath.row == 6 {
//            tableView.deselectRow(at: indexPath, animated: true)
//        }
    }
}
