import UIKit

@MainActor
extension SearchWidgetDropDownTextField {
    
    @objc open var menuButton: UIButton {
        privateMenuButton
    }
    
    @objc open var showMenuButton: Bool {
        get {
            privateMenuButton.superview != nil
        }
        set {
            if newValue {
                self.addSubview(privateMenuButton)
                NSLayoutConstraint.activate([
                    privateMenuButton.leadingAnchor.constraint(equalTo: leadingAnchor),
                    privateMenuButton.trailingAnchor.constraint(equalTo: trailingAnchor),
                    privateMenuButton.topAnchor.constraint(equalTo: topAnchor),
                    privateMenuButton.bottomAnchor.constraint(equalTo: bottomAnchor)
                ])
                reconfigureMenu()
            } else {
                privateMenuButton.removeFromSuperview()
            }
        }
    }
    
    internal func initializeMenu() {
        if #available(iOS 13.0, *) {
            privateMenuButton.setImage(UIImage(systemName: "chevron.up.chevron.down"), for: .normal)
        } else {
            //
        }
        privateMenuButton.contentHorizontalAlignment = .trailing
        privateMenuButton.contentEdgeInsets = .init(top: 0, left: 5, bottom: 0, right: 5)
        privateMenuButton.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 14.0, *) {
            privateMenuButton.addTarget(self, action: #selector(menuActionTriggered), for: .menuActionTriggered)
        } else {
            //
        }
        if #available(iOS 14.0, *) {
            privateMenuButton.showsMenuAsPrimaryAction = true
        } else {
            //
        }
    }
    
    internal func reconfigureMenu() {
//        switch dropDownMode {
//            
//        case .list, .multiList:
//            let deferredMenuElement = UIDeferredMenuElement.uncached({ completion in
//                var actions: [UIMenuElement] = []
//                if self.multiItemList.count <= 1 {
//                    let selectedItem = self.selectedItem
//                    actions = self.itemList.map { item in
//                        return UIAction(title: item, image: nil,
//                                        state: item == selectedItem ? .on : .off) { (_) in
//                            self.privateSetSelectedItems(selectedItems: [item], animated: true, shouldNotifyDelegate: true)
//                        }
//                    }
//                } else {
//                    var selectedItems = self.selectedItems
//                    for (index, itemList) in self.multiItemList.enumerated() {
//                        let selectedItem = selectedItems[index]
//                        let childrens: [UIMenuElement] = itemList.map { item in
//                            return UIAction(title: item, image: nil,
//                                            state: item == selectedItem ? .on : .off) { (_) in
//                                selectedItems[index] = item
//                                self.privateSetSelectedItems(selectedItems: selectedItems, animated: true, shouldNotifyDelegate: true)
//                            }
//                        }
//                        
//                        let title: String
//                        if index < self.optionalItemTexts.count {
//                            title = self.optionalItemTexts[index] ?? self.optionalItemText ?? ""
//                        } else {
//                            title = self.optionalItemText ?? ""
//                        }
//                        let subMenu = UIMenu(title: title, children: childrens)
//
//                        actions.append(subMenu)
//                    }
//                }
//                completion(actions)
//            })
//            let deferredMenus = UIMenu(title: self.placeholder ?? "", children: [deferredMenuElement])
//            privateMenuButton.menu = deferredMenus
//            privateMenuButton.isHidden = false
//        case .textField:
//            privateMenuButton.isHidden = true
//            privateMenuButton.menu = nil
//        }
    }
    
    @objc private func menuActionTriggered() {
        containerViewController?.view.endEditing(true)
    }
    
    @objc private func menuButtonTapped() {
        guard let containerViewController = containerViewController else {
            return
        }
        let popoverViewController = UIViewController()
        popoverViewController.modalPresentationStyle = .popover
        popoverViewController.popoverPresentationController?.sourceView = privateMenuButton
        popoverViewController.popoverPresentationController?.sourceRect = privateMenuButton.bounds
        popoverViewController.popoverPresentationController?.delegate = self
        switch dropDownMode {
        case .list, .multiList, .textField:
            break
        }
    }
}

@MainActor
extension SearchWidgetDropDownTextField {
    private var containerViewController: UIViewController? {
        var next = self.next
        repeat {
            if let next = next as? UIViewController {
                return next
            } else {
                next = next?.next
            }
        } while next != nil
            return nil
    }
}

@MainActor
extension SearchWidgetDropDownTextField: UIPopoverPresentationControllerDelegate {
    public func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

    public func prepareForPopoverPresentation(_ popoverPresentationController: UIPopoverPresentationController) {
        containerViewController?.view.endEditing(true)
    }
}
