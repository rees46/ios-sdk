//import UIKit
//
//class PickerExamplesTableViewController: UITableViewController {
//    
//    enum ItemsType : Int {
//        case label, customView
//    }
//    
//    @IBOutlet weak var scrollingStyleOption: UISegmentedControl!
//    @IBOutlet weak var selectionStyleOption: UISegmentedControl!
//    @IBOutlet weak var itemsOption: UISegmentedControl!
//    
//    var pickedNumber: String?
//    var pickedOSX: String?
//    
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        if segue.identifier == "showNumberPicker" {
//            let numberNav = segue.destination as! UINavigationController
//            let numberPicker = numberNav.topViewController as! ExamplePickerCoreViewController
//            numberPicker.currentSelectedValue = pickedNumber
//            numberPicker.presentationType = ExamplePickerCoreViewController.PresentationType.numbers(scrollingStyleOption.selectedSegmentIndex,
//                                                                                                 selectionStyleOption.selectedSegmentIndex)
//            numberPicker.updateSelectedValue = { (newSelectedValue) in
//                self.pickedNumber = newSelectedValue
//                self.tableView.reloadData()
//            }
//            numberPicker.itemsType = ItemsType(rawValue: itemsOption.selectedSegmentIndex)!
//        }
//        
//        if segue.identifier == "showNamePicker" {
//            let osxNav = segue.destination as! UINavigationController
//            let osxPicker = osxNav.topViewController as! ExamplePickerCoreViewController
//            osxPicker.currentSelectedValue = pickedOSX
//            osxPicker.presentationType = ExamplePickerCoreViewController.PresentationType.names(scrollingStyleOption.selectedSegmentIndex,
//                                                                                            selectionStyleOption.selectedSegmentIndex)
//            osxPicker.updateSelectedValue = { (newSelectedValue) in
//                self.pickedOSX = newSelectedValue
//                self.tableView.reloadData()
//            }
//            osxPicker.itemsType = ItemsType(rawValue: itemsOption.selectedSegmentIndex)!
//        }
//    }
//    
//}
//
//extension PickerExamplesTableViewController {
//
//    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
//        switch (section) {
//        case 1:
//            return pickedNumber != nil ? "You picked the number \(pickedNumber!)." : "You don't picked any number."
//        case 2:
//            return pickedOSX != nil ? "You picked the OS \(pickedOSX!)." : "You don't picked any OS"
//        default:
//            return "You can also set a custom apperance for the text in two different states (regular and highlighted) through PickerViewDelegate methods."
//        }
//    }
//
//    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        switch (indexPath as NSIndexPath).section {
//        case 1:
//            performSegue(withIdentifier: "showNumberPicker", sender: nil)
//        case 2:
//            performSegue(withIdentifier: "showNamePicker", sender: nil)
//        default:
//            break
//        }
//    }
//    
//}
