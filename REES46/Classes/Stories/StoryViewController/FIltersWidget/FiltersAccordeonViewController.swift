import UIKit
import REES46

@available(iOS 15.0, *)
class FiltersAccordeonViewController: UIViewController, MenuTableViewCellDelegate, FooterViewDelegate {
    
    public var data = [FiltersMenu]()
    public var filtersList = [FiltersMenu]()
    
    var firstRowSelected = true
    
    @IBOutlet weak var tableView: UITableView?
    
    @IBOutlet weak var cellColorsHeight: NSLayoutConstraint!
    
    @IBOutlet var searchPlaceholder: UIView!
    
    public var allFiltersFinal: [String : Filter]?
    public var indFiltersFinal: IndustrialFilters?
    
    @IBOutlet weak var scrollingStyleOption: UISegmentedControl!
    @IBOutlet weak var selectionStyleOption: UISegmentedControl!
    @IBOutlet weak var itemsOption: UISegmentedControl!
    @IBOutlet weak var foundedLabel: UILabel!
    
    var pickedNumber: String?

    fileprivate let viewModel = FiltersCheckboxMainVM()
    let checkboxsTree = FiltersCheckboxTree()
    
    @IBOutlet private weak var backButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UserDefaults.standard.set(false, forKey: "FiltersMemorySettingKey")
        
        initTableView()
        
//        viewModel.getDataItems { response in
//            //self.data.append(contentsOf: response)
//            self.tableView?.reloadData()
//            //print("Filters Data : \(response.count)")
//        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(loadTest), name: .init(rawValue: "FiltersInternalCheckboxCall"), object: nil)
        
        backButton.addTarget(self, action: #selector(closeButtonClicked), for: .touchUpInside)
        
        self.searchPlaceholder.isHidden = true
        
        if data.count == 0 {
            self.searchPlaceholder.isHidden = false
        }
    }
    
    @objc public func queryWithFilters() {
        globalSDK?.search(query: "shoes", sortBy: "popular", locations: "10", filters: ["Screen size, inch": ["15.6"]], colors: ["white", "black"], fashionSizes: ["36", "37", "38", "39", "40"], timeOut: 0.2) { searchResponse in
            print("   Filters search callback")
            switch searchResponse {
            case let .success(searchResponse):
                print("     full search is success")
            case let .failure(error):
                switch error {
                case let .custom(customError):
                    print("Error:", customError)
                default:
                    print("Error:", error.description)
                }
            }
        }
    }
    
    @objc private func loadTest() {
        updateTableWithFiltersNow(0)
    }

    func initTableView() {
        self.tableView?.rowHeight = UITableView.automaticDimension
        self.tableView?.sectionHeaderHeight = 50
        self.tableView?.sectionFooterHeight = 30
        
        self.tableView?.register(UINib.init(nibName: "DoneTableViewCell", bundle: nil), forCellReuseIdentifier:"DoneTableViewCell")
        
        tableView?.backgroundColor = UIColor.white
        
        self.tableView?.register(HeaderView.nib, forHeaderFooterViewReuseIdentifier: HeaderView.identifier)
        self.tableView?.register(FooterView.nib, forHeaderFooterViewReuseIdentifier: FooterView.identifier)
        
        self.tableView?.register(MainFiltersCheckboxCell.nib, forCellReuseIdentifier: MainFiltersCheckboxCell.identifier)
        self.tableView?.register(PriceRangeCell.nib, forCellReuseIdentifier: PriceRangeCell.identifier)
        self.tableView?.register(MenuTableViewCell.nib, forCellReuseIdentifier: MenuTableViewCell.identifier)
        self.tableView?.register(ResetCell.nib, forCellReuseIdentifier: ResetCell.identifier)
        
        checkboxsTree.delegate = self
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        //var cellHeight:CGFloat = CGFloat()
        if indexPath.section == 0 {
            return CGFloat(133)
        } else {
            let carouselOpenedBoolKey: Bool = UserDefaults.standard.bool(forKey: "FiltersMemorySettingKey")
            if carouselOpenedBoolKey {
                //let s = data[indexPath.section].titleValues
                //let height = CGFloat(s.count) * 32 //self.classTableView.rowHeight
                //cellHeight = 460
                
                //let sw = data[indexPath.section].titleValues.count
                //let spentBudgetInt = Int(swwewe1)
                let spentBudgetInt1 = Int(data[indexPath.section].titleValues.count + 1)
                print("!!!")
                //print("!!!")
                let height1 = spentBudgetInt1*38// //+477
                print(height1)
                print("!!!")
                return CGFloat(height1)
            }
            
            let swwewe = data[indexPath.section].titleValues.count
            if swwewe == 3 {
                return CGFloat(119)
            } else if swwewe == 2 {
                return CGFloat(76)
            } else if swwewe == 1 {
                return CGFloat(38)
            } else {
                let spentBudgetIntww = Int(data[indexPath.section].titleValues.count + 1)
                let height = spentBudgetIntww*38
                return CGFloat(119)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func closeButtonClicked(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}

@available(iOS 15.0, *)
extension FiltersAccordeonViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        //let s = data[tableView.indexp].titleValues.count
        return data.count //data.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0  {
            return 1
        }  else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if let cell = tableView.dequeueReusableCell(withIdentifier: PriceRangeCell.identifier, for: indexPath) as? PriceRangeCell {
                return cell
            } else {
                return UITableViewCell()
            }
        } else {
            if let cell = tableView.dequeueReusableCell(withIdentifier: MainFiltersCheckboxCell.identifier, for: indexPath) as? MainFiltersCheckboxCell {
                let index = indexPath.section
                let menuItem5 = data[index]
                cell.itemForFiltersWIdget?.isCollapsed = false
                
                cell.itemForFiltersWIdget?.isCollapsible = true
                cell.menuList = data
                cell.tag = indexPath.row
                cell.delegate = self
                
                var arrWithFinalizedFilters = [FiltersCheckboxItem(indexForFilterTitle: cell.tag, title: "Выбрать все", isSelected: true)]
                var children: [FiltersCheckboxItem] = []
                for title in menuItem5.titleValues {
                    children.append(FiltersCheckboxItem(indexForFilterTitle: cell.tag,
                                                   title: title,
                                                   isSelected: true))
                }
                
                arrWithFinalizedFilters.removeAll()
                arrWithFinalizedFilters.append(FiltersCheckboxItem(indexForFilterTitle: cell.tag,
                                                              title: "Выбрать все",
                                                              isSelected: true,
                                                              children: children,
                                                              isGroupCollapsed: false))
                
                cell.titleLabel?.tintColor = UIColor.black
                cell.menu = data[indexPath.section]
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
    
    func headerFooterViewArrowInSection(header: FooterView, section: Int) {
        let item = data[section]
        if item.isCollapsible {
            
            let collapsed = !item.isCollapsed
            item.isCollapsed = collapsed
            header.setCollapsed(collapsed: collapsed)
            
            let carouselOpenedBoolKey: Bool = UserDefaults.standard.bool(forKey: "FiltersMemorySettingKey")
            if !carouselOpenedBoolKey {
                let withTag = "FiltersMemorySettingKey" + "\(item)"
                UserDefaults.standard.set(true, forKey: "FiltersMemorySettingKey")
            } else {
                UserDefaults.standard.set(false, forKey: "FiltersMemorySettingKey")
            }
            
            reloadSectionsInFiltersTable(section)
        }
    }
    
    func didSelectedMenu(menu: FiltersMenu) {
        print("SDK: didSelectedMenu FiltersMenu")
    }
    
}

@available(iOS 15.0, *)
extension FiltersAccordeonViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: HeaderView.identifier) as? HeaderView {
            let item = data[section].title
            headerView.titleLabel?.text = item
            headerView.isUserInteractionEnabled = false
            headerView.section = section
            headerView.delegate = self
            return headerView
        }
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 0 {
            return nil
        }
        if let headerViewEnd = tableView.dequeueReusableHeaderFooterView(withIdentifier: FooterView.identifier) as? FooterView {
            let rre = data[section].titleValues.count// data[section]
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
                
                let vHide = "Cкрыть"
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
                
                let v = "Показать ("  + String(rre) + ")"
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

@available(iOS 15.0, *)
extension FiltersAccordeonViewController: SearchWidgetDropDownTextFieldDelegate, SearchWidgetDropDownTextFieldDataSource {
    func textField(textField: SearchWidgetDropDownTextField, didSelectItems items: [String?]) {
        //
    }

    func textField(textField: SearchWidgetDropDownTextField, didSelectDate date: Date?) {
        //
    }

    func textField(textField: SearchWidgetDropDownTextField, canSelectItem item: String) -> Bool {
        return true
    }

    func textField(textField: SearchWidgetDropDownTextField, proposedSelectionModeForItem item: String) -> SearchWidgetProposedSelection {
        return .both
    }
}

@available(iOS 15.0, *)
extension FiltersAccordeonViewController: HeaderViewDelegate {
    func headerExpandArrowInSection(header: HeaderView, section: Int) {
//        var item = data[section]
//        if item.isCollapsible {
//            
//            let collapsed = !item.isCollapsed
//            item.isCollapsed = collapsed
//            header.setCollapsed(collapsed: collapsed)
//            
//            let carouselOpenedBoolKey: Bool = UserDefaults.standard.bool(forKey: "FiltersMemorySettingKey")
//            if !carouselOpenedBoolKey {
//                let withTag = "FiltersMemorySettingKey" + "\(item)"
//                UserDefaults.standard.set(true, forKey: "FiltersMemorySettingKey")
//            } else {
//                UserDefaults.standard.set(false, forKey: "FiltersMemorySettingKey")
//            }
//            
//            reloadSectionsInFiltersTable(section)
//        }
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

@available(iOS 15.0, *)
extension FiltersAccordeonViewController: MainFiltersCheckboxCellDelegate {
    func collapseSection(header: MainFiltersCheckboxCell, section: Int) {
        
//        guard let indexPath = self.tableView?.indexPath(for: header) else {
//            return
//        }
        
        guard (self.tableView?.indexPath(for: header)) != nil else {
            return
        }
        
        //let item = data[indexPath.section]
        
        let carouselOpenedBoolKey: Bool = UserDefaults.standard.bool(forKey: "FiltersMemorySettingKey")
        if !carouselOpenedBoolKey {
            UserDefaults.standard.set(true, forKey: "FiltersMemorySettingKey")
        } else {
            UserDefaults.standard.set(false, forKey: "FiltersMemorySettingKey")
        }
    }
    
    func updateTableWithFiltersNow(_ section: Int) {
        //let item = data[section]
        //let iterm = data[section]
        //data.removeAll()
        //tableView?.reloadData()
    }
}

@available(iOS 15.0, *)
extension FiltersAccordeonViewController: FiltersCheckboxTreeDelegate {
    func collapseSection(header: FiltersCheckboxItem, section: Int) {
        print("item")
    }
    
    func checkboxItemDidSelected(item: FiltersCheckboxItem) {
        print(item)
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
