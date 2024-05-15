import UIKit

protocol FiltersWidgetCheckboxCellDelegate: AnyObject {
    func collapseSection(header: FiltersWidgetCheckboxCell, section: Int)
    func updateTableWithFiltersNow(_ section: Int)
    func reloadSectionsInFiltersTable(_ section: Int)
}

class FiltersWidgetCheckboxCell: UITableViewCell, FiltersCheckboxTreeDelegate {
    public func collapseSection(header: FiltersCheckboxItem, section: Int) {
        //SDK: Detect tap callback
    }
    
    var menuList = [FiltersTagsMenu]()
    
    func collapseSection(header: FiltersWidgetCheckboxCell, section: Int) {
        let carouselOpenedBoolKey: Bool = UserDefaults.standard.bool(forKey: "FiltersMemorySettingKey")
        if !carouselOpenedBoolKey {
            UserDefaults.standard.set(true, forKey: "FiltersMemorySettingKey")
        } else {
            UserDefaults.standard.set(false, forKey: "FiltersMemorySettingKey")
        }
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "FiltersInternalCheckboxObserver"), object: nil)
    }
    
    func checkboxItemDidSelected(item: FiltersCheckboxItem) {
        print(item)
        delegate?.updateTableWithFiltersNow(0)
        //NotificationCenter.default.post(name: NSNotification.Name(rawValue: "FiltersInternalCheckboxObserver"), object: nil)
    }
    
    func checkboxItemDidSelected(item: FiltersWidgetCheckboxCell) {
        delegate?.updateTableWithFiltersNow(0)
        print(item)
    }
    
    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var pictureImageView: UIImageView?
    @IBOutlet weak var nameLabel: UILabel?
    
    var section: Int = 0
    
    weak var delegate: FiltersWidgetCheckboxCellDelegate?
    
    var items = [FiltersCheckboxItem]()
    
    var menu = FiltersTagsMenu(filterId: -99, title: "Menu", titleFiltersValues: ["String"], selected: false)

    let checkboxTree = FiltersCheckboxTree()
    
    var itemForFiltersWidget: FiltersTagsMenu? {
        didSet {
            guard let itemForFiltersWidget = itemForFiltersWidget else {
                return
            }
            setCollapsed(collapsed: true)
            
            nameLabel?.text = itemForFiltersWidget.title
            setCollapsed(collapsed: itemForFiltersWidget.isCollapsed)
        }
    }
    
    func setCollapsed(collapsed: Bool) {
        //setSelected(false, animated: false)
        //arrowImage?.rotate(collapsed ? 0.0 : .pi)
    }
    
    static var nib:UINib {
        return UINib(nibName: identifier, bundle: nil)
    }
    
    static var identifier: String {
        return String(describing: self)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateView()
    }
    
    func updateView(){
        checkboxTree.items = items
        
    }
    
    @objc private func didTapHeader() {
        delegate?.collapseSection(header: self, section: section)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapHeader)))
        
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
        
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            contentStackView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: -18),
            contentStackView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: 0),
            contentStackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: 0)
        ])
        
        checkboxTree.delegate = self
        
        contentStackView.addArrangedSubview(checkboxTree)
        
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
