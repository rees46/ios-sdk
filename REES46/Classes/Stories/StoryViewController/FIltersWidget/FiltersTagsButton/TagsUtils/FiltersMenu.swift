import Foundation

protocol FiltersMenuBaseModel {
    var isCollapsible: Bool { get }
    var isCollapsed: Bool { get set }
}

class FiltersMenu {
    var filterId: Int = -1
    var title: String = ""
    var titleValues: [String] = [""]
    var selected = false
    var isC = false
    
    var isCollapsible: Bool = false
    var isCollapsed = false
    
    init(filterId: Int, title: String, titleFiltersValues: [String], selected: Bool) {
        self.filterId = filterId
        self.title = title
        self.titleValues = titleFiltersValues
        self.selected = selected
        self.isCollapsed = true
        self.isCollapsible = true
    }
    
    static func fetch()->[FiltersMenu] {
        let fetchList = [FiltersMenu(filterId: -1, title: "T", titleFiltersValues: ["String"], selected: true),
                        FiltersMenu(filterId: -2, title: "S", titleFiltersValues: ["String"], selected: true),
        ]
        return fetchList
    }
}


