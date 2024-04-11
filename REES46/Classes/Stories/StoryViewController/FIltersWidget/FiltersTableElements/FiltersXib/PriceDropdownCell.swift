import UIKit
import REES46

@objc public protocol PickerViewDelegate: AnyObject {
    func pickerViewHeightForRows(_ pickerView: PickerCoreView) -> CGFloat
    @objc optional func pickerView(_ pickerView: PickerCoreView, didSelectRow row: Int)
    @objc optional func pickerView(_ pickerView: PickerCoreView, didTapRow row: Int)
    @objc optional func pickerView(_ pickerView: PickerCoreView, styleForLabel label: UILabel, highlighted: Bool)
    @objc optional func pickerView(_ pickerView: PickerCoreView, viewForRow row: Int, highlighted: Bool, reusingView view: UIView?) -> UIView?
}

protocol PriceDropdownCellDelegate: AnyObject {
    func newPickerNow()
}

@available(iOS 15.0, *)
class PriceDropdownCell: UITableViewCell, SearchWidgetDropDownTextFieldDataSource, UITextFieldDelegate, PickerCoreViewDataSource, PickerCoreViewDelegate {
    
    weak var delegate: PriceDropdownCellDelegate?
    
    func pickerCoreViewHeightForRows(_ pickerCoreView: PickerCoreView) -> CGFloat {
        return 50.0
    }
    
    func pickerViewHeightForRows(_ pickerView: PickerCoreView) -> CGFloat {
        return 50.0
    }
    
    func pickerView(_ pickerView: PickerCoreView, didSelectRow row: Int) {
        //let selectedItem = itemsThatYouWantToPresent[row]
        //print("The selected item is \(selectedItem.name)")
    }

    func pickerView(_ pickerView: PickerCoreView, didTapRow row: Int) {
        print("ЫВЛЖ The row \(row) was tapped by the user")
    }
    
    func pickerView(_ pickerView: PickerCoreView, styleForLabel label: UILabel, highlighted: Bool) {
        //label.textAlignment = .Center
        
        if highlighted {
            //label.font = UIFont.systemFontOfSize(25.0)
           // label.textColor = view.tintColor
        } else {
           // label.font = UIFont.systemFontOfSize(15.0)
           // label.textColor = .lightGrayColor()
        }
    }
    
    @objc func pickerCoreViewNumberOfRows(_ pickerCoreView: PickerCoreView) -> Int {
        return 1
    }
    
    @objc func pickerCoreView(_ pickerCoreView: PickerCoreView, titleForRow row: Int) -> String {
        return "1"
    }

    enum PresentationType {
        case numbers(Int, Int), names(Int, Int)
    }

    @IBOutlet weak var nameLabel: UILabel?
    @IBOutlet weak var pictureImageView: UIImageView?
    
    @IBOutlet var textFieldOptionalTextPicker: SearchWidgetDropDownTextField!
    
    @IBOutlet var textFieldTextPicker: SearchWidgetDropDownTextField!
    
    @IBOutlet var textFieldTextPicker1: UITextField!
    
    @IBOutlet var textFieldMultiListTextPicker: SearchWidgetDropDownTextField!
    
    private var dropDown: SearchWidgetDropDownTextField = SearchWidgetDropDownTextField()
    
    public var indFilters: IndustrialFilters?
    
    //
    enum ItemsType : Int {
        case label, customView
    }
    
    @IBOutlet weak var scrollingStyleOption: UISegmentedControl!
    @IBOutlet weak var selectionStyleOption: UISegmentedControl!
    @IBOutlet weak var itemsOption: UISegmentedControl!
    
    var pickedNumber: String?
    var pickedOSX: String?
    
    var item: ItemBaseModel? {
        didSet {
            guard item is ItemNameAndPicture else {
                return
            }
        }
    }
    
    
    static var nib:UINib {
        return UINib(nibName: identifier, bundle: nil)
    }
    
    static var identifier: String {
        return String(describing: self)
    }
    
    
    @IBAction func myTargetFunction(_ sender: UITextField?) {
        delegate?.newPickerNow()
    }
    
    func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showNumberPicker" {
            let numberNav = segue.destination as! UINavigationController
            let numberPicker = numberNav.topViewController as! ExamplePickerCoreViewController
            numberPicker.currentSelectedValue = pickedNumber
            numberPicker.presentationType = ExamplePickerCoreViewController.PresentationType.numbers(scrollingStyleOption.selectedSegmentIndex,
                                                                                                 selectionStyleOption.selectedSegmentIndex)
            numberPicker.updateSelectedValue = { (newSelectedValue) in
                self.pickedNumber = newSelectedValue
                //self.tableView.reloadData()
            }
            //numberPicker.itemsType = ItemsType(rawValue: itemsOption.selectedSegmentIndex)!
        }
        
        if segue.identifier == "showNamePicker" {
            let osxNav = segue.destination as! UINavigationController
            let osxPicker = osxNav.topViewController as! ExamplePickerCoreViewController
            osxPicker.currentSelectedValue = pickedOSX
            osxPicker.presentationType = ExamplePickerCoreViewController.PresentationType.names(scrollingStyleOption.selectedSegmentIndex,
                                                                                            selectionStyleOption.selectedSegmentIndex)
            osxPicker.updateSelectedValue = { (newSelectedValue) in
                self.pickedOSX = newSelectedValue
                //self.tableView.reloadData()
            }
            //osxPicker.itemsType = ItemsType(rawValue: itemsOption.selectedSegmentIndex)!
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
       //textFieldTextPicker1.addTarget(self, action: #selector(myTargetFunction), for: .touchDown)
        return
        //var ss = indFilters
//        for item in indFilters?.fashionSizes {
//            
//        }
        
//        if indFilters != nil {
//            if indFilters!.fashionSizes.count != 0 {
//                let rr = indFilters?.fashionSizes as! [String]
//            }
//            
//        }
//        
//        //let rr = indFilters?.fashionSizes as! [String]
//        
        self.dropDown.itemList = ["31",
                                  "32",
                                  "33",
                                  "34",
                                  "35",
                                  "36",
                                  "37",
                                  "38",
                                  "39",
                                  "40",
                                  "41",
                                  "42"]
        
        //self.dropDown.itemList = indFilters?.fashionSizes as! [String]
        
        self.dropDown.dropDownMode = .multiList
        self.dropDown.selectedRow = 1
        self.dropDown.isOptionalDropDown = true
        //self.mainStackView?.addArrangedSubview(self.dropDown)
        

        textFieldTextPicker.showDismissToolbar = true
        
        
        textFieldOptionalTextPicker?.showDismissToolbar = true
        textFieldMultiListTextPicker?.showDismissToolbar = true

        let indicator: UIActivityIndicatorView! = {
            if #available(iOS 13.0, *) {
                return UIActivityIndicatorView(style: .medium)
            } else {
                return UIActivityIndicatorView(style: .gray)
            }
        }()
        indicator.startAnimating()

        let _: UISwitch = UISwitch()

        textFieldTextPicker.itemList = ["All",
                                        "31",
                                        "32",
                                        "33",
                                        "34",
                                        "35",
                                        "36",
                                        "37",
                                        "38",
                                        "39",
                                        "40",
                                        "41"]
        
        textFieldTextPicker.selectedRow = 0
        

//        textFieldTextPicker.itemList = ["Thomas Jefferson High School for Science and Technology",
//                                        "Gwinnett School of Mathematics, Science and Technology",
//                                        "California Academy of Mathematics and Science",
//                                        "Loveless Academic Magnet Program High School",
//                                        "Irma Lerma Rangel Young Women's Leadership School",
//                                        "Middlesex County Academy, Mathematics and Engineering Technologies",
//                                        "Queens High School for the Sciences at York College"]
        textFieldTextPicker.adjustsFontSizeToFitWidth = false
        //
        //        textFieldTextPicker.selectedRow = 2
        //        let viewList: [UIView?] = [nil, indicator, nil, aSwitch]
        //        textFieldTextPicker.itemListView = viewList
//        textFieldTextPicker.font = [UIFont fontWithName:@"Montserrat-Regular" size:16];
     //   textFieldTextPicker.textColor = UIColor.green
        textFieldTextPicker.optionalItemText = "Select"

        textFieldOptionalTextPicker.itemList = ["All", "34", "35", "36", "37", "38", "39", "40", "41", "42", "43", "44", "45", "46", "47"]
        textFieldOptionalTextPicker.selectedRow = 0
        textFieldOptionalTextPicker.optionalItemText = "Select"
        
        textFieldOptionalTextPicker.selectionFormatHandler = { (selectedItem, _) in

            if let selectedItem = selectedItem {
                if selectedItem == "1" {
                    return selectedItem + " "
                } else {
                    return selectedItem + " "
                }
            } else {
                return ""
            }
        }
        
        textFieldMultiListTextPicker?.dropDownMode = .list
        let heightFeet: [String] = ["All", "34", "35", "36", "37", "38", "39", "40", "41", "42", "43", "44", "45", "46", "47"]
        let heightInches: [String] = ["All", "34", "35", "36", "37", "38", "39", "40", "41", "42", "43", "44", "45", "46", "47"]

//        textFieldMultiListTextPicker.widthsForComponents = [100, 150]
//        textFieldMultiListTextPicker.heightsForComponents = [30, 100]
        
//        textFieldMultiListTextPicker.isOptionalDropDowns = [true, false]
//        textFieldMultiListTextPicker.optionalItemTexts = ["Select Feet", "Select Inches"]
//        textFieldMultiListTextPicker.multiItemList = [heightFeet, heightInches]
//        textFieldMultiListTextPicker.multiListSelectionFormatHandler = { (selectedItems, selectedIndexes) in
//            if selectedIndexes.first == 0 {
//                return "Not Sure"
//            } else if let first = selectedItems.first, let first = first,
//                        let last = selectedItems.last, let last = last {
//                return "\(first)' \(last)\""
//            } else {
//                return ""
//        }
       
        textFieldTextPicker.delegate = self
        textFieldTextPicker.dataSource = self

        textFieldOptionalTextPicker.delegate = self
        textFieldOptionalTextPicker.dataSource = self

//        textFieldMultiListTextPicker.delegate = self
//        textFieldMultiListTextPicker.dataSource = self
        
        if #available(iOS 15.0, *) {
            textFieldTextPicker.showMenuButton = !textFieldTextPicker.showMenuButton
            textFieldOptionalTextPicker.showMenuButton = !textFieldOptionalTextPicker.showMenuButton
            //textFieldMultiListTextPicker.showMenuButton = !textFieldMultiListTextPicker.showMenuButton
        } else {
            
        }
        
    }
    
    
    func showAsMultiSelectPopover(sender: UIView) {
        
        // selection type as multiple with subTitle Cell
        
        
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        
        //pictureImageView?.image = nil
    }
    
    func textField(textField: SearchWidgetDropDownTextField, didSelectItem item: String?) {
        print(#function)
//        print(item)
    }

    func textField(textField: SearchWidgetDropDownTextField!, didSelectDate date: NSDate?) {
        print(#function)
//        print(date)
    }

    func textField(textField: SearchWidgetDropDownTextField, canSelectItem item: String?) -> Bool {
        print(#function)
//        print(item)
        return true
    }

    func textField(textField: SearchWidgetDropDownTextField, proposedSelectionModeForItem item: String?) -> SearchWidgetProposedSelection {
        print(#function)
//        print(item)
        return .both
    }

    private func textFieldDidBeginEditing(textField: UITextField) {
        print(#function)
    }

    private func textFieldDidEndEditing(textField: UITextField) {
        print(#function)
    }

    func doneClicked(button: UIBarButtonItem!) {
        //self.view.endEditing(true)
        print("oo")
//        print("textFieldTextPicker.selectedItem: \(textFieldTextPicker.selectedItem)")
//        print("textFieldOptionalTextPicker.selectedItem: \(textFieldOptionalTextPicker.selectedItem)")
//        print("textFieldDatePicker.selectedItem: \(textFieldDatePicker.selectedItem)")
//        print("textFieldTimePicker.selectedItem: \(textFieldTimePicker.selectedItem)")
//        print("textFieldDateTimePicker.selectedItem: \(textFieldDateTimePicker.selectedItem)")
    }

    @IBAction func menuToggle(_ sender: UIButton) {
        if #available(iOS 15.0, *) {
            textFieldTextPicker.showMenuButton = !textFieldTextPicker.showMenuButton
            textFieldOptionalTextPicker.showMenuButton = !textFieldOptionalTextPicker.showMenuButton
            textFieldMultiListTextPicker.showMenuButton = !textFieldMultiListTextPicker.showMenuButton
        }
    }

    @IBAction func isOptionalToggle(_ sender: UIButton) {
        textFieldTextPicker.isOptionalDropDown = !textFieldTextPicker.isOptionalDropDown
        textFieldOptionalTextPicker.isOptionalDropDown = !textFieldOptionalTextPicker.isOptionalDropDown
       // textFieldMultiListTextPicker.isOptionalDropDown = !textFieldMultiListTextPicker.isOptionalDropDown
//        self.dropDown.isOptionalDropDown = !self.dropDown.isOptionalDropDown
    }

    @IBAction func resetAction(_ sender: UIButton) {
        textFieldTextPicker.selectedItem = nil
        textFieldOptionalTextPicker.selectedItem = nil
        //textFieldMultiListTextPicker.selectedItem = nil
//        self.dropDown.selectedItem = nil
    }
}

extension UIApplication {
    class func topViewController(controller: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
}


@IBDesignable class SSSFiltersButton: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()
        updateButtonCornerRadius()
    }

    @IBInspectable var rounded: Bool = false {
        didSet {
            updateButtonCornerRadius()
        }
    }

    func updateButtonCornerRadius() {
        layer.backgroundColor = UIColor.black.cgColor
        layer.masksToBounds = true
        layer.borderWidth = 2.0
        layer.borderColor = UIColor.white.cgColor
        layer.cornerRadius = 8
        //layer.cornerRadius = frame.size.height / 2
    }
}
