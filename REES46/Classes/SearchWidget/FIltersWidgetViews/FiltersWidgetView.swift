import UIKit

public class FiltersWidgetView: UIViewController, FiltersTagsTableViewCellDelegate, FiltersWidgetFooterViewDelegate {
    
    public var filtersList = [FiltersDataMenuList]()
    
    @IBOutlet weak var tableView: UITableView?
    
    @IBOutlet weak var cellColorsHeight: NSLayoutConstraint!
    
    @IBOutlet var searchPlaceholder: UIView!
    
    let filtersCheckboxTree = FiltersCheckboxTree()
    
    @IBOutlet public weak var backButton: UIButton!
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        UserDefaults.standard.set(false, forKey: "FiltersMemorySettingKey")
        
        initTableView()
        
        backButton.addTarget(self, action: #selector(closeButtonClicked), for: .touchUpInside)
        
        self.searchPlaceholder.isHidden = true
        
        if filtersList.count == 0 {
            self.searchPlaceholder.isHidden = false
        }
    }

    func initTableView() {
        self.tableView?.rowHeight = UITableView.automaticDimension
        self.tableView?.sectionHeaderHeight = 50
        self.tableView?.sectionFooterHeight = 30
        
        self.tableView?.register(UINib.init(nibName: "FiltersWidgetTagsDoneCell", bundle: nil), forCellReuseIdentifier:"FiltersWidgetTagsDoneCell")
        
        tableView?.backgroundColor = UIColor.white
        
        self.tableView?.register(FiltersWidgetHeaderView.nib, forHeaderFooterViewReuseIdentifier: FiltersWidgetHeaderView.identifier)
        self.tableView?.register(FiltersWidgetFooterView.nib, forHeaderFooterViewReuseIdentifier: FiltersWidgetFooterView.identifier)
        
        self.tableView?.register(FiltersWidgetCheckboxCell.nib, forCellReuseIdentifier: FiltersWidgetCheckboxCell.identifier)
        self.tableView?.register(FiltersWidgetPriceRangeCell.nib, forCellReuseIdentifier: FiltersWidgetPriceRangeCell.identifier)
        self.tableView?.register(FiltersTagsTableViewCell.nib, forCellReuseIdentifier: FiltersTagsTableViewCell.identifier)
        self.tableView?.register(FiltersWidgetResetCell.nib, forCellReuseIdentifier: FiltersWidgetResetCell.identifier)
        
        filtersCheckboxTree.delegate = self
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        //var cellHeight:CGFloat = CGFloat()
        if indexPath.section == 0 {
            return CGFloat(133)
        } else {
            let filtersOpenedBoolKey: Bool = UserDefaults.standard.bool(forKey: "FiltersMemorySettingKey")
            if filtersOpenedBoolKey {
                let spentBudgetInt1 = Int(filtersList[indexPath.section].titleValues.count + 1)
                let height = spentBudgetInt1*38
                return CGFloat(height)
            }
            
            let filterCellHeight = filtersList[indexPath.section].titleValues.count
            if filterCellHeight == 3 {
                return CGFloat(119)
            } else if filterCellHeight == 2 {
                return CGFloat(76)
            } else if filterCellHeight == 1 {
                return CGFloat(38)
            } else {
                //let filterCellIntHeight = Int(data[indexPath.section].titleValues.count + 1)
                //_ = filterCellIntHeight*38
                return CGFloat(119)
            }
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    public override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func closeButtonClicked(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension FiltersWidgetView: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return filtersList.count
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0  {
            return 1
        }  else {
            return 1
        }
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if let cell = tableView.dequeueReusableCell(withIdentifier: FiltersWidgetPriceRangeCell.identifier, for: indexPath) as? FiltersWidgetPriceRangeCell {
                return cell
            } else {
                return UITableViewCell()
            }
        } else {
            if let cell = tableView.dequeueReusableCell(withIdentifier: FiltersWidgetCheckboxCell.identifier, for: indexPath) as? FiltersWidgetCheckboxCell {
                let index = indexPath.section
                let menuItem5 = filtersList[index]
                cell.itemForFiltersWidget?.isCollapsed = false
                
                cell.itemForFiltersWidget?.isCollapsible = true
                cell.menuList = filtersList
                cell.tag = indexPath.row
                cell.delegate = self
                
                var arrWithFinalizedFilters = [FiltersCheckboxItem(indexForFilterTitle: cell.tag, title: "Select All", isSelected: true)]
                var children: [FiltersCheckboxItem] = []
                for title in menuItem5.titleValues {
                    children.append(FiltersCheckboxItem(indexForFilterTitle: cell.tag,
                                                   title: title,
                                                   isSelected: true))
                }
                
                arrWithFinalizedFilters.removeAll()
                arrWithFinalizedFilters.append(FiltersCheckboxItem(indexForFilterTitle: cell.tag,
                                                              title: "Select All",
                                                              isSelected: true,
                                                              children: children,
                                                              isGroupCollapsed: false))
                
                cell.titleLabel?.tintColor = UIColor.black
                cell.menu = filtersList[indexPath.section]
                cell.items = arrWithFinalizedFilters
                //cell.updateView()
                
                return cell
            } else {
                return UITableViewCell()
            }
            
        }
    }
    
    @IBAction func searchDataItemSelected(_ sender: Any?) {
        self.tableView?.reloadData()
        //self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func cancelDataItemSelected(_ sender: Any?) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func headerFooterViewArrowInSection(header: FiltersWidgetFooterView, section: Int) {
        let item = filtersList[section]
        if item.isCollapsible {
            
            let collapsed = !item.isCollapsed
            item.isCollapsed = collapsed
            header.setCollapsed(collapsed: collapsed)
            
            let carouselOpenedBoolKey: Bool = UserDefaults.standard.bool(forKey: "FiltersMemorySettingKey")
            if !carouselOpenedBoolKey {
                _ = "FiltersMemorySettingKey" + "\(item)"
                UserDefaults.standard.set(true, forKey: "FiltersMemorySettingKey")
            } else {
                UserDefaults.standard.set(false, forKey: "FiltersMemorySettingKey")
            }
            
            reloadSectionsInFiltersTable(section)
        }
    }
    
    func didSelectedMenu(menu: FiltersDataMenuList) {
        print("SDK: didSelectedMenu FiltersTagsMenu")
    }
}

extension FiltersWidgetView: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: FiltersWidgetHeaderView.identifier) as? FiltersWidgetHeaderView {
            let item = filtersList[section].title
            headerView.titleLabel?.text = item
            headerView.isUserInteractionEnabled = false
            headerView.section = section
            headerView.delegate = self
            return headerView
        }
        return UIView()
    }
    
    public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 0 {
            return nil
        }
        if let headerViewEnd = tableView.dequeueReusableHeaderFooterView(withIdentifier: FiltersWidgetFooterView.identifier) as? FiltersWidgetFooterView {
            let rre = filtersList[section].titleValues.count
            print(rre)
            
            var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
            frameworkBundle = Bundle.module
#endif
            
            let carouselOpenedBoolKey: Bool = UserDefaults.standard.bool(forKey: "FiltersMemorySettingKey")
            if carouselOpenedBoolKey {
                let imageAttachment = NSTextAttachment()
                imageAttachment.image = UIImage(named: "angleDownBlackIntUp", in: frameworkBundle, compatibleWith: nil)
                let imageOffsetY: CGFloat = -9.0
                imageAttachment.bounds = CGRect(x: 1, y: imageOffsetY, width: imageAttachment.image!.size.width/4, height: imageAttachment.image!.size.height/4)
                let attachmentString = NSAttributedString(attachment: imageAttachment)
                let completeText = NSMutableAttributedString(string: "")
                
                let vHide = "Hide"
                let textAfterIcon = NSAttributedString(string: vHide)
                completeText.append(textAfterIcon)
                completeText.append(attachmentString)
                headerViewEnd.titleLabel?.textAlignment = .left
                headerViewEnd.titleLabel?.attributedText = completeText
            } else {
                let imageAttachment = NSTextAttachment()
                imageAttachment.image = UIImage(named: "angleDownBlackInt", in: frameworkBundle, compatibleWith: nil)
                let imageOffsetY: CGFloat = -8.0
                imageAttachment.bounds = CGRect(x: 0, y: imageOffsetY, width: imageAttachment.image!.size.width/4, height: imageAttachment.image!.size.height/4)
                let attachmentString = NSAttributedString(attachment: imageAttachment)
                let completeText = NSMutableAttributedString(string: "")
                //completeText.append(attachmentString)
                
                let v = "Show ("  + String(rre) + ")"
                let textAfterIcon = NSAttributedString(string: v)
                completeText.append(textAfterIcon)
                completeText.append(attachmentString)
                headerViewEnd.titleLabel?.textAlignment = .left
                headerViewEnd.titleLabel?.attributedText = completeText
            }
            
            headerViewEnd.arrowImage?.isHidden = true
            headerViewEnd.isUserInteractionEnabled = true
            headerViewEnd.section = section
            headerViewEnd.delegate = self
            return headerViewEnd
        }
        return UIView()
    }
}

extension FiltersWidgetView: FiltersWidgetHeaderViewDelegate {
    func headerExpandArrowInSection(header: FiltersWidgetHeaderView, section: Int) {
        //Implementation
    }
    
    func reloadSectionsInFiltersTable(_ section: Int) {
        
        self.tableView?.beginUpdates()
        let indexPath = IndexPath(row: 0, section: section)
        self.tableView?.reloadRows(at: [indexPath], with: .fade)
        self.tableView?.reloadSections(IndexSet(integer: section), with: .fade)
        self.tableView?.endUpdates()
        
        self.tableView?.reloadData()
    }
}

extension FiltersWidgetView: FiltersWidgetCheckboxCellDelegate {
    func collapseSection(header: FiltersWidgetCheckboxCell, section: Int) {
        guard (self.tableView?.indexPath(for: header)) != nil else {
            return
        }
        
        let carouselOpenedBoolKey: Bool = UserDefaults.standard.bool(forKey: "FiltersMemorySettingKey")
        if !carouselOpenedBoolKey {
            UserDefaults.standard.set(true, forKey: "FiltersMemorySettingKey")
        } else {
            UserDefaults.standard.set(false, forKey: "FiltersMemorySettingKey")
        }
    }
    
    func updateTableWithFiltersNow(_ section: Int) {
        // let item = data[section]
        // let iterm = data[section]
        // data.removeAll()
        // tableView?.reloadData()
    }
}

extension FiltersWidgetView: FiltersCheckboxTreeDelegate {
    public func collapseSection(header: FiltersCheckboxItem, section: Int) {
        //print("item")
    }
    
    public func checkboxItemDidSelected(item: FiltersCheckboxItem) {
        //print(item)
    }
}

extension Sequence {
    func limit(_ max: Int) -> [Element] {
        return self.enumerated()
            .filter { $0.offset < max }
            .map { $0.element }
    }
    
    func limitEnd(_ max: Int) -> [Element] {
        return self.enumerated()
            .filter { $0.offset >= max }
            .map { $0.element }
    }
}

extension IndexSet {
    func indPathsForSection(_ section: Int) -> [IndexPath] {
        return self.map { IndexPath(item: $0, section: section) }
    }
}