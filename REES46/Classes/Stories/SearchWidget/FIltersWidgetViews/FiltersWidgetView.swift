import UIKit

public class FiltersWidgetView: UIViewController, FiltersTagsTableViewCellDelegate, FiltersWidgetFooterViewDelegate {
    
    public var filtersList = [FiltersDataMenuList]()
    
    @IBOutlet weak var tableView: UITableView?
    
    @IBOutlet weak var searchPlaceholder: UIView!
    
    public let filtersCheckboxTree = FiltersCheckboxTree()
    
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var searchDataButton: UIButton!
    @IBOutlet weak var resetDataButton: UIButton!
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        UserDefaults.standard.set(false, forKey: "FiltersMemorySettingKey")
        
        initTableView()
        
        backButton.addTarget(self, action: #selector(closeButtonClicked), for: .touchUpInside)
        searchDataButton.addTarget(self, action: #selector(searchDataItemSelected), for: .touchUpInside)
        resetDataButton.addTarget(self, action: #selector(cancelDataItemSelected), for: .touchUpInside)
        
        searchPlaceholder.isHidden = true
    }
    
    func initTableView() {
        self.tableView?.rowHeight = UITableView.automaticDimension
        self.tableView?.sectionHeaderHeight = 50
        self.tableView?.sectionFooterHeight = 30
        
        tableView?.backgroundColor = UIColor.white
        
        var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        frameworkBundle = Bundle.module
#endif
        
        self.tableView?.register(UINib(nibName: "FiltersWidgetHeaderView", bundle: frameworkBundle), forHeaderFooterViewReuseIdentifier: "FiltersWidgetHeaderView")
        
        self.tableView?.register(UINib(nibName: "FiltersWidgetFooterView", bundle: frameworkBundle), forHeaderFooterViewReuseIdentifier: "FiltersWidgetFooterView")
        
        self.tableView?.register(UINib.init(nibName: "FiltersWidgetTagsDoneCell", bundle: frameworkBundle), forCellReuseIdentifier:"FiltersWidgetTagsDoneCell")
        
        self.tableView?.register(UINib.init(nibName: "FiltersWidgetCheckboxCell", bundle: frameworkBundle), forCellReuseIdentifier:"FiltersWidgetCheckboxCell")
        
        self.tableView?.register(UINib.init(nibName: "FiltersWidgetPriceRangeCell", bundle: frameworkBundle), forCellReuseIdentifier:"FiltersWidgetPriceRangeCell")
        
        self.tableView?.register(UINib.init(nibName: "FiltersTagsTableViewCell", bundle: frameworkBundle), forCellReuseIdentifier:"FiltersTagsTableViewCell")
        
        self.tableView?.register(UINib.init(nibName: "FiltersWidgetResetCell", bundle: frameworkBundle), forCellReuseIdentifier:"FiltersWidgetResetCell")
        
        filtersCheckboxTree.delegate = self
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return CGFloat(133)
        } else {
            let filtersOpenedBoolKey: Bool = UserDefaults.standard.bool(forKey: "FiltersMemorySettingKey")
            if filtersOpenedBoolKey {
                let spentBudgetInt = Int(filtersList[indexPath.section].titleValues.count + 1)
                let height = spentBudgetInt*38
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
                return CGFloat(119)
            }
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if filtersList.count == 0 {
            searchPlaceholder.isHidden = false
        } else {
            searchPlaceholder.isHidden = true
        }
    }
    
    @objc public func closeButtonClicked() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc public func searchDataItemSelected() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc public func cancelDataItemSelected() {
        self.dismiss(animated: true, completion: nil)
    }
    
    public override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
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
            if let cell = tableView.dequeueReusableCell(withIdentifier: "FiltersWidgetPriceRangeCell", for: indexPath) as? FiltersWidgetPriceRangeCell {
                return cell
            } else {
                return UITableViewCell()
            }
        } else {
            if let cell = tableView.dequeueReusableCell(withIdentifier: "FiltersWidgetCheckboxCell", for: indexPath) as? FiltersWidgetCheckboxCell {
                let index = indexPath.section
                let cellForItem = filtersList[index]
                cell.itemForFiltersWidget?.isCollapsed = false
                
                cell.itemForFiltersWidget?.isCollapsible = true
                cell.cellFiltersList = filtersList
                cell.tag = indexPath.row
                cell.delegate = self
                
                var arrWithFinalizedFilters = [FiltersCheckboxItem(indexForFilterTitle: cell.tag, title: "Select All", isSelected: true)]
                var children: [FiltersCheckboxItem] = []
                for title in cellForItem.titleValues {
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
                cell.cellFiltersDataList = filtersList[indexPath.section]
                cell.itemsValues = arrWithFinalizedFilters
                return cell
            } else {
                return UITableViewCell()
            }
        }
    }
    
    public func headerFooterViewArrowInSection(header: FiltersWidgetFooterView, section: Int) {
        let headerFilterItem = filtersList[section]
        if headerFilterItem.isCollapsible {
            let collapsed = !headerFilterItem.isCollapsed
            headerFilterItem.isCollapsed = collapsed
            header.setCollapsed(collapsed: collapsed)
            
            let headerCheckboxOpenedBoolKey: Bool = UserDefaults.standard.bool(forKey: "FiltersMemorySettingKey")
            if !headerCheckboxOpenedBoolKey {
                _ = "FiltersMemorySettingKey" + "\(headerFilterItem)"
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
        if let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "FiltersWidgetHeaderView") as? FiltersWidgetHeaderView {
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
        if let headerViewEnd = tableView.dequeueReusableHeaderFooterView(withIdentifier: "FiltersWidgetFooterView") as? FiltersWidgetFooterView {
            let filterTitle = filtersList[section].titleValues.count
            
            var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
            frameworkBundle = Bundle.module
#endif
            
            let filtersOpenedBoolKey: Bool = UserDefaults.standard.bool(forKey: "FiltersMemorySettingKey")
            if filtersOpenedBoolKey {
                let imageAttachment = NSTextAttachment()
                imageAttachment.image = UIImage(named: "angleUpBlack", in: frameworkBundle, compatibleWith: nil)
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
                imageAttachment.image = UIImage(named: "angleDownBlack", in: frameworkBundle, compatibleWith: nil)
                let imageOffsetY: CGFloat = -8.0
                imageAttachment.bounds = CGRect(x: 0, y: imageOffsetY, width: imageAttachment.image!.size.width/4, height: imageAttachment.image!.size.height/4)
                let attachmentString = NSAttributedString(attachment: imageAttachment)
                let completeText = NSMutableAttributedString(string: "")
                
                let showText = "Show ("  + String(filterTitle) + ")"
                let textAfterIcon = NSAttributedString(string: showText)
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
    public func headerExpandArrowInSection(header: FiltersWidgetHeaderView, section: Int) {
        //Implementation
    }
    
    public func reloadSectionsInFiltersTable(_ section: Int) {
        self.tableView?.beginUpdates()
        let indexPath = IndexPath(row: 0, section: section)
        self.tableView?.reloadRows(at: [indexPath], with: .fade)
        self.tableView?.reloadSections(IndexSet(integer: section), with: .fade)
        self.tableView?.endUpdates()
        
        self.tableView?.reloadData()
    }
}

extension FiltersWidgetView: FiltersWidgetCheckboxCellDelegate {
    public func collapseSection(header: FiltersWidgetCheckboxCell, section: Int) {
        guard (self.tableView?.indexPath(for: header)) != nil else {
            return
        }
        
        let filtersOpenedBoolKey: Bool = UserDefaults.standard.bool(forKey: "FiltersMemorySettingKey")
        if !filtersOpenedBoolKey {
            UserDefaults.standard.set(true, forKey: "FiltersMemorySettingKey")
        } else {
            UserDefaults.standard.set(false, forKey: "FiltersMemorySettingKey")
        }
    }
    
    public func updateTableWithFiltersNow(_ section: Int) {
//        let item = filtersList[section]
//        filtersList.removeAll()
//        tableView?.reloadData()
    }
}

extension FiltersWidgetView: FiltersCheckboxTreeDelegate {
    public func collapseSection(header: FiltersCheckboxItem, section: Int) {
        //print(section)
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
    func individualPathsForSection(_ section: Int) -> [IndexPath] {
        return self.map { IndexPath(item: $0, section: section) }
    }
}
