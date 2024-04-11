import UIKit

class CategoryCell: UITableViewCell {
    
    @IBOutlet weak var categoryImage: UIImageView! {
        didSet {
            categoryImage.layer.cornerRadius = 20
            categoryImage.layer.masksToBounds = true
        }
    }
    @IBOutlet weak var categoryTitle: UILabel! {
        didSet {
            categoryTitle.layer.shadowColor = UIColor.orange.cgColor
            categoryTitle.layer.shadowRadius = 8
            categoryTitle.layer.shadowOpacity = 1.0
            categoryTitle.layer.shadowOffset = CGSize(width: 4, height: 3)
            categoryTitle.layer.masksToBounds = false
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    func updateViews(with category: ShopCartCaterogy) {
        categoryImage.image = UIImage(named: category.imageName)
        categoryTitle.text = category.title
    }

}
