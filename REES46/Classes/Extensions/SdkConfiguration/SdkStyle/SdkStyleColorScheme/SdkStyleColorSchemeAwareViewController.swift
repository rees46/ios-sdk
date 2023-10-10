import UIKit

protocol SdkStyleColorSchemeAwareViewController {
    func applyColorScheme(_ colorScheme: SdkStyleColorScheme, animated: Bool)
}

extension UIViewController: SdkStyleColorSchemeAwareViewController {
    func applyColorScheme(_ colorScheme: SdkStyleColorScheme, animated: Bool) {
        view.downcastColorScheme(colorScheme, animated: animated)

        SdkStyle.applySdkStyleApperance(animated: animated) {
            if let customColorScheme = colorScheme as? SdkStyleCustomColorScheme,
                let customColorSchemeAwareSelf = self as? SdkStyleCustomColorSchemeAwareViewController {
                customColorSchemeAwareSelf.applyCustomColorScheme(customColorScheme)
            }
            else if let tableVC = self as? UITableViewController,
                let tableViewColorScheme = colorScheme as? SdkStyleTableViewColorScheme {
                tableVC.tableView.backgroundColor = tableViewColorScheme.tableViewBackgroundColor
                tableVC.tableView.separatorColor = tableViewColorScheme.tableViewSeparatorColor
            }
            else if let collectionVC = self as? UICollectionViewController,
                let collectionViewColorScheme = colorScheme as? SdkStyleCollectionViewColorScheme {
                collectionVC.collectionView.backgroundColor = collectionViewColorScheme.collectionViewBackgroundColor
            }
            else {
                if self.view.backgroundColor != nil,
                    self.view.backgroundColor != UIColor.clear {
                    self.view.backgroundColor = colorScheme.viewControllerBackground
                }
            }


            if self.applyNavBarColors {
                self.applyNavigationBarColorScheme(colorScheme)
            }
        }
    }

    func applyNavigationBarColorScheme(_ colorScheme: SdkStyleColorScheme) {
        self.navigationController?.navigationBar.barStyle = colorScheme.navigationBarStyle
        self.navigationController?.navigationBar.tintColor = colorScheme.navigationBarTextColor
        self.navigationController?.navigationBar.barTintColor = colorScheme.navigationBarBackgroundColor
    }
}


extension UIView {
    func downcastColorScheme(_ colorScheme: SdkStyleColorScheme, animated: Bool) {

        if let customColorScheme = colorScheme as? SdkStyleCustomColorScheme,
            let customColorSchemeAwareSelf = self as? SdkStyleCustomColorSchemeAwareView {
            SdkStyle.applySdkStyleApperance(animated: animated) {
                customColorSchemeAwareSelf.applyCustomColorScheme(customColorScheme)
            }
            if !customColorSchemeAwareSelf.shouldDowncastCustomColorScheme {
                return
            }
        }

        if let colorSchemeAwareSelf = self as? SdkStyleColorSchemeAwareView {
            SdkStyle.applySdkStyleApperance(animated: animated) {
                colorSchemeAwareSelf.applyColorScheme(colorScheme)
            }

            if !colorSchemeAwareSelf.shouldDowncastColorScheme {
                return
            }
        }

        for subview in subviews {
            subview.downcastColorScheme(colorScheme, animated: animated)
        }

        if type(of: self) == UIView.self,
            parentViewController?.view != self,
            let viewColorScheme = colorScheme as? SdkStyleViewColorScheme,
            backgroundColor != UIColor.clear {

            SdkStyle.applySdkStyleApperance(animated: animated) {
                self.backgroundColor = viewColorScheme.viewBackgroundColor
            }
        }
    }
}

extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder!.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}

extension UIView {
    private struct AssociatedKey {
        static var key = "skipColorScheme"
    }

    public var skipColorScheme: Bool {
        get {
            return objc_getAssociatedObject(self, AssociatedKey.key) as? Bool ?? false
        }
        set {
            if newValue {
                objc_setAssociatedObject(self, AssociatedKey.key, true, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            else {
                if let obj = objc_getAssociatedObject(self, AssociatedKey.key) as? Bool {
                    objc_removeAssociatedObjects(obj)
                }
            }
        }
    }
}

extension UIViewController {
    private struct AssociatedKey {
        static var key = "applyNavBarColors"
    }

    public var applyNavBarColors: Bool {
        get {
            return objc_getAssociatedObject(self, AssociatedKey.key) as? Bool ?? true
        }
        set {
            if newValue {
                objc_setAssociatedObject(self, AssociatedKey.key, true, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            else {
                if let obj = objc_getAssociatedObject(self, AssociatedKey.key) as? Bool {
                    objc_removeAssociatedObjects(obj)
                }
            }
        }
    }
}
