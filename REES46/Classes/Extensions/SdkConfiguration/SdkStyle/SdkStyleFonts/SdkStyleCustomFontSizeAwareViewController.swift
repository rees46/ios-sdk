import UIKit

protocol SdkStyleCustomFontsAwareViewController {
    func applySdkCustomFonts(_ fonts: SdkStyleCustomFonts)
}


extension UIViewController: SdkStyleCustomFontsAwareViewController {
    func applySdkCustomFonts(_ fonts: SdkStyleCustomFonts) {
        if let tableVC = self as? UITableViewController {
            for cell in tableVC.tableView.visibleCells {
                cell.downcastSdkAllFonts(fonts)
            }
            tableVC.tableView.reloadData()
        }
        else {
            view.downcastSdkAllFonts(fonts)
        }
    }
}


extension UIView {
    func downcastSdkAllFonts(_ fonts: SdkStyleCustomFonts) {
        if let sdkCustomFontsAwareSelf = self as? SdkStyleCustomFontsAwareView {
            sdkCustomFontsAwareSelf.applySdkCustomFonts(fonts)
            return
        }

        for subview in subviews {
            subview.downcastSdkAllFonts(fonts)
        }
    }
}
