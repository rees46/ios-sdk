import Foundation

protocol FiltersTagsMenuBaseModel {
    var isCollapsible: Bool { get }
    var isCollapsed: Bool { get set }
}

public class FiltersTagsMenu {
    var filterId: Int = -1
    var title: String = ""
    var titleValues: [String] = [""]
    var selected = false
    var isC = false
    
    var isCollapsible: Bool = false
    var isCollapsed = false
    
    public init(filterId: Int, title: String, titleFiltersValues: [String], selected: Bool) {
        self.filterId = filterId
        self.title = title
        self.titleValues = titleFiltersValues
        self.selected = selected
        self.isCollapsed = true
        self.isCollapsible = true
    }
    
    static func fetch()->[FiltersTagsMenu] {
        let fetchList = [FiltersTagsMenu(filterId: -1, title: "String", titleFiltersValues: ["String"], selected: true),
                        FiltersTagsMenu(filterId: -2, title: "String", titleFiltersValues: ["String"], selected: true),
        ]
        return fetchList
    }
}


