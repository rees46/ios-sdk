import Foundation

protocol FiltersCheckboxItemDelegate: NSObject {
    func checkboxItemDidSelected(item: FiltersCheckboxItem)
    func collapseItemDidSelected(item: FiltersCheckboxItem)
}
