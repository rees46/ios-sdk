import UIKit
import REES46

@available(iOS 13.0, *)
protocol CheckboxTypeCellDelegate: AnyObject {
    func collapseSection(header: CheckboxTypeCell, section: Int)
}

@available(iOS 13.0, *)
class CheckboxTypeCell: UITableViewCell, FiltersCheckboxTreeDelegate {
    func collapseSection(header: FiltersCheckboxItem, section: Int) {
        print("asss")
        
        let carouselOpenedBoolKey: Bool = UserDefaults.standard.bool(forKey: "FiltersMemorySetting2")
        if !carouselOpenedBoolKey {
            UserDefaults.standard.set(true, forKey: "FiltersMemorySetting2")
        } else {
            UserDefaults.standard.set(false, forKey: "FiltersMemorySetting2")
        }
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "FiltersInternalCheckboxCall"), object: nil)
    }
    
    func collapseSection(header: CheckboxTypeCell, section: Int) {
        //print(item)
    }
    
    func checkboxItemDidSelected(item: FiltersCheckboxItem) {
        print(item)
    }
    
    func checkboxItemDidSelected(item: CheckboxTypeCell) {
        print(item)
    }

    @IBOutlet weak var pictureImageView: UIImageView?
    @IBOutlet weak var nameLabel: UILabel?
    
    weak var delegate: CheckboxTypeCellDelegate?
    
//    var items = [FiltersCheckboxItem(title: "All",
//                                isSelected: true),
//                 FiltersCheckboxItem(title: "Shoes",
//                                isSelected: true),
//                 FiltersCheckboxItem(title: "Boots",
//                                isSelected: true),
//                 FiltersCheckboxItem(title: "Dress",
//                                isSelected: true),
//                 FiltersCheckboxItem(title: "Jacket",
//                                isSelected: true),
//                 FiltersCheckboxItem(title: "Jeans",
//                                isSelected: true),
//                 
//                 FiltersCheckboxItem(title: "Show more (4)",
//                                children: [
//                                    FiltersCheckboxItem(title: "Casual Top",
//                                                   isSelected: true),
//                                    FiltersCheckboxItem(title: "T-shirt",
//                                                   isSelected: true),
//                                    FiltersCheckboxItem(title: "Pants",
//                                                   isSelected: true),
//                                    FiltersCheckboxItem(title: "Coats",
//                                                   isSelected: true),
//                                    FiltersCheckboxItem(title: "Knitwear",
//                                                   isSelected: true),
//                                ], isGroupCollapsed: true),
//    ]

    let checkboxTree = FiltersCheckboxTree()
    
    var item: Friend? {
        didSet {
            guard let item = item else {
                return
            }
            
            if let pictureUrl = item.pictureURL {
                pictureImageView?.image = UIImage(named: pictureUrl)
            }
            
            nameLabel?.text = item.name
        }
    }
    
    static var nib:UINib {
        return UINib(nibName: identifier, bundle: nil)
    }
    
    static var identifier: String {
        return String(describing: self)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isScrollEnabled = false
        
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leftAnchor.constraint(equalTo: leftAnchor),
            scrollView.rightAnchor.constraint(equalTo: rightAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
            contentView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            contentView.widthAnchor.constraint(equalTo: widthAnchor)
        ])

        let contentStackView = UIStackView()
        contentStackView.spacing = 8
        contentStackView.axis = .vertical
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(contentStackView)

        if SdkGlobalHelper.DeviceType.IS_IPHONE_XS {
            NSLayoutConstraint.activate([
                contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
                contentStackView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 22),
                contentStackView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -90),
                contentStackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: 0)
            ])
        } else {
            NSLayoutConstraint.activate([
                contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
                contentStackView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 22),
                contentStackView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -110),
                contentStackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: 0)
            ])
        }
        
        checkboxTree.delegate = self
        //checkboxTree.items = items

        contentStackView.addArrangedSubview(checkboxTree)
        //addSubview(contentStackView)
        
        pictureImageView?.layer.cornerRadius = 40
        pictureImageView?.clipsToBounds = true
        pictureImageView?.contentMode = .scaleAspectFit
        pictureImageView?.backgroundColor = UIColor.lightGray
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        pictureImageView?.image = nil
    }
}
