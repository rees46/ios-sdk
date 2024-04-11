import UIKit

class PriceCell: UITableViewCell, SearchWidgetDropDownTextFieldDataSource, UITextFieldDelegate {

    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var valueLabel: UILabel?
    
    @IBOutlet var textFieldOptionalTextPicker1: SearchWidgetDropDownTextField!
    
    @IBOutlet var textFieldTextPicker1: SearchWidgetDropDownTextField!
   // @IBOutlet var textFieldMultiListTextPicker1: SearchWidgetDropDownTextField!
    
    private var dropDown: SearchWidgetDropDownTextField = SearchWidgetDropDownTextField()
    
    var item: ProfileAttribute?  {
        didSet {
            guard item is ItemAttribute else {
                return
            }
            
            //titleLabel?.text = item?.key
            //valueLabel?.text = item?.value
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
        
        self.dropDown.itemList = ["0",
                                  "50",
                                  "100",
                                  "200",
                                  "300",
                                  "400",
                                  "500",
                                  "600",
                                  "700",
                                  "800",
                                  "900",
                                  "1000"]
        self.dropDown.dropDownMode = .multiList
        self.dropDown.selectedRow = 1
        self.dropDown.isOptionalDropDown = true
        //self.mainStackView?.addArrangedSubview(self.dropDown)
        
        
        textFieldTextPicker1.showDismissToolbar = true
        
        
        textFieldOptionalTextPicker1?.showDismissToolbar = true
       // textFieldMultiListTextPicker1?.showDismissToolbar = true
        
        let indicator: UIActivityIndicatorView! = {
            if #available(iOS 13.0, *) {
                return UIActivityIndicatorView(style: .medium)
            } else {
                return UIActivityIndicatorView(style: .gray)
            }
        }()
        indicator.startAnimating()
        
        let _: UISwitch = UISwitch()
        
        textFieldTextPicker1.itemList = ["0",
                                         "50",
                                         "100",
                                         "200",
                                         "300",
                                         "400",
                                         "500",
                                         "600",
                                         "700",
                                         "800",
                                         "900",
                                         "1000"]
        
        textFieldTextPicker1.selectedRow = 0
        
        //        textFieldTextPicker1.itemList = ["Thomas Jefferson High School for Science and Technology",
        //                                        "Gwinnett School of Mathematics, Science and Technology",
        //                                        "California Academy of Mathematics and Science",
        //                                        "Loveless Academic Magnet Program High School",
        //                                        "Irma Lerma Rangel Young Women's Leadership School",
        //                                        "Middlesex County Academy, Mathematics and Engineering Technologies",
        //                                        "Queens High School for the Sciences at York College"]
        textFieldTextPicker1.adjustsFontSizeToFitWidth = false
        //
        //        textFieldTextPicker1.selectedRow = 2
        //        let viewList: [UIView?] = [nil, indicator, nil, aSwitch]
        //        textFieldTextPicker1.itemListView = viewList
        //        textFieldTextPicker1.font = [UIFont fontWithName:@"Montserrat-Regular" size:16];
        //   textFieldTextPicker1.textColor = UIColor.green
        //textFieldTextPicker1.optionalItemTextColor = [UIColor brownColor];
        
                textFieldOptionalTextPicker1.itemList = ["1100",
                                                        "1500",
                                                        "2000",
                                                        "3000",
                                                        "4000",
                                                        "5000",
                                                        "6000",
                                                        "7000",
                                                        "8000",
                                                        "9000",
                                                        "10000"]
        textFieldOptionalTextPicker1.selectedRow = 10
        
        textFieldOptionalTextPicker1.selectionFormatHandler = { (selectedItem, _) in

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
        
        //textFieldMultiListTextPicker1?.dropDownMode = .list
        let heightFeet: [String] = ["All", "34", "35", "36", "37", "38", "39", "40", "41", "42", "43", "44", "45", "46", "47"]
        let heightInches: [String] = ["All", "34", "35", "36", "37", "38", "39", "40", "41", "42", "43", "44", "45", "46", "47"]
        
//        textFieldMultiListTextPicker1.widthsForComponents = [100, 150]
//        textFieldMultiListTextPicker1.heightsForComponents = [30, 100]
//        
//        textFieldMultiListTextPicker1.isOptionalDropDowns = [true, false]
//        textFieldMultiListTextPicker1.optionalItemTexts = ["Select Feet", "Select Inches"]
//        textFieldMultiListTextPicker1.multiItemList = [heightFeet, heightInches]
//        textFieldMultiListTextPicker1.multiListSelectionFormatHandler = { [self] (selectedItems, selectedIndexes) in
//            if selectedIndexes.first == 0 {
//                return "Not Sure"
//            } else if let first = selectedItems.first, let first = first,
//                      let last = selectedItems.last, let last = last {
//                return "\(first)' \(last)\""
//            } else {
//                return ""
//            }
            
            textFieldTextPicker1.delegate = self
            textFieldTextPicker1.dataSource = self
            
            textFieldOptionalTextPicker1.delegate = self
            textFieldOptionalTextPicker1.dataSource = self
            
            //textFieldMultiListTextPicker1.delegate = self
            //textFieldMultiListTextPicker1.dataSource = self
            
            if #available(iOS 15.0, *) {
                textFieldTextPicker1.showMenuButton = !textFieldTextPicker1.showMenuButton
                textFieldOptionalTextPicker1.showMenuButton = !textFieldOptionalTextPicker1.showMenuButton
              //  textFieldMultiListTextPicker1.showMenuButton = !textFieldMultiListTextPicker1.showMenuButton
            } else {
                
            }
            
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
        
        func textFieldDidEndEditing(textField: UITextField) {
            print(#function)
        }
        
        func doneClicked(button: UIBarButtonItem!) {
            
            endEditing(true)
            
            //        print("textFieldTextPicker1.selectedItem: \(textFieldTextPicker1.selectedItem)")
            //        print("textFieldOptionalTextPicker1.selectedItem: \(textFieldOptionalTextPicker1.selectedItem)")
            //        print("textFieldDatePicker.selectedItem: \(textFieldDatePicker.selectedItem)")
            //        print("textFieldTimePicker.selectedItem: \(textFieldTimePicker.selectedItem)")
            //        print("textFieldDateTimePicker.selectedItem: \(textFieldDateTimePicker.selectedItem)")
        }
        
        func menuToggle(_ sender: UIButton) {
            if #available(iOS 15.0, *) {
                textFieldTextPicker1.showMenuButton = !textFieldTextPicker1.showMenuButton
                   textFieldOptionalTextPicker1.showMenuButton = !textFieldOptionalTextPicker1.showMenuButton
                //textFieldMultiListTextPicker1.showMenuButton = !textFieldMultiListTextPicker1.showMenuButton
            }
        }
        
        func isOptionalToggle(_ sender: UIButton) {
            textFieldTextPicker1.isOptionalDropDown = !textFieldTextPicker1.isOptionalDropDown
            textFieldOptionalTextPicker1.isOptionalDropDown = !textFieldOptionalTextPicker1.isOptionalDropDown
           // textFieldMultiListTextPicker1.isOptionalDropDown = !textFieldMultiListTextPicker1.isOptionalDropDown
            //        self.dropDown.isOptionalDropDown = !self.dropDown.isOptionalDropDown
        }
        
        func resetAction(_ sender: UIButton) {
            textFieldTextPicker1.selectedItem = nil
            textFieldOptionalTextPicker1.selectedItem = nil
            self.dropDown.selectedItem = nil
        }
    
    
        
}
