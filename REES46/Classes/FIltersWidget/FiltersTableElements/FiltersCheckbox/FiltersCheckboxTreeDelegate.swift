import Foundation

public protocol FiltersCheckboxTreeDelegate: NSObject {
    func checkboxItemDidSelected(item: FiltersCheckboxItem)
    func collapseSection(header: FiltersCheckboxItem, section: Int)
}
