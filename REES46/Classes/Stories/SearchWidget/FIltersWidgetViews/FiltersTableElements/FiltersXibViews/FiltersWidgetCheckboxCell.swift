import UIKit

public protocol FiltersWidgetCheckboxCellDelegate: AnyObject {
    func collapseSection(header: FiltersWidgetCheckboxCell, section: Int)
    func updateTableWithFiltersNow(_ section: Int)
    func reloadSectionsInFiltersTable(_ section: Int)
}

public class FiltersWidgetCheckboxCell: UITableViewCell, FiltersCheckboxTreeDelegate {
    public func collapseSection(header: FiltersCheckboxItem, section: Int) {
        //SDK: Detect tap filters collape callback
    }
    
    public var cellFiltersList = [FiltersDataMenuList]()
    
    func collapseSection(header: FiltersWidgetCheckboxCell, section: Int) {
        let checkboxCellOpenedBoolKey: Bool = UserDefaults.standard.bool(forKey: "FiltersMemorySettingKey")
        if !checkboxCellOpenedBoolKey {
            UserDefaults.standard.set(true, forKey: "FiltersMemorySettingKey")
        } else {
            UserDefaults.standard.set(false, forKey: "FiltersMemorySettingKey")
        }
    }
    
    public func checkboxItemDidSelected(item: FiltersCheckboxItem) {
        debugPrint(item)
        delegate?.updateTableWithFiltersNow(0)
    }
    
    public func checkboxItemDidSelected(item: FiltersWidgetCheckboxCell) {
        debugPrint(item)
        delegate?.updateTableWithFiltersNow(0)
    }
    
    weak var titleLabel: UILabel?
    
    public var section: Int = 0
    
    public weak var delegate: FiltersWidgetCheckboxCellDelegate?
    
    public var itemsValues = [FiltersCheckboxItem]()
    
    public var cellFiltersDataList = FiltersDataMenuList(filterId: -99, title: "Menu", titleFiltersValues: ["String"], selected: false)
    
    public let checkboxTree = FiltersCheckboxTree()
    
    public var itemForFiltersWidget: FiltersDataMenuList? {
        didSet {
            guard let itemForFiltersWidget = itemForFiltersWidget else {
                return
            }
            setCollapsed(collapsed: true)
            
            titleLabel?.text = itemForFiltersWidget.title
            setCollapsed(collapsed: itemForFiltersWidget.isCollapsed)
        }
    }
    
    public func setCollapsed(collapsed: Bool) {
        //setSelected(false, animated: false)
        //arrowImage?.rotate(collapsed ? 0.0 : .pi)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        updateView()
    }
    
    public func updateView() {
        checkboxTree.items = itemsValues
    }
    
    @objc public func didTapHeader() {
        delegate?.collapseSection(header: self, section: section)
    }
    
    public override func awakeFromNib() {
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
    }
    
    public override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
    }
}
