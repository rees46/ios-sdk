import UIKit

open class FiltersCheckboxItem: CustomStringConvertible {
    
    public enum ItemType {
        case groupCheckbox
        case single
    }

    public enum ItemSelectionState {
        case on
        case off
        case mixed
    }
    
    var menuList = [FiltersMenu]()
    
    public var title: String
    
    public var subtitle: String?

    public var type: ItemType {
        return children.isEmpty ? .single : .groupCheckbox
    }

    public var children: [FiltersCheckboxItem] = []

    public var isGroupCollapsed: Bool

    private var _isEnabled = true

    public var isEnabled: Bool {
        get {
            return _isEnabled
        }
        set {
            _isEnabled = newValue

            for child in children {
                child.isEnabled = newValue
            }
        }
    }

    private var _isSelected: Bool

    public var isSelected: Bool {
        get {
            if type == .groupCheckbox {
                return selectionState == .on
            } else {
                return _isSelected
            }
        }
        set {
            if isEnabled == false {
                return
            }

            _isSelected = newValue

            for child in children {
                child.isSelected = newValue
            }
        }
    }

    public var selectionState: ItemSelectionState {
        if type == .groupCheckbox {

            if children.isEmpty {
                return .off
            }

            let hasMixedChild = children.contains{ $0.selectionState == .mixed }
            if hasMixedChild {
                return .mixed
            }

            let hasSelectedChild = children.contains{ $0.selectionState == .on }
            let hasUnselectedChild = children.contains{ $0.selectionState == .off }

            if hasSelectedChild && !hasUnselectedChild {
                return .on
            } else if !hasSelectedChild && hasUnselectedChild {
                return .off
            } else {
                return .mixed
            }
        }
        return isSelected ? .on : .off
    }
    
    public convenience init(indexForFilterTitle: Int, title: String, subtitle: String? = nil, children: [FiltersCheckboxItem] = [], isGroupCollapsed: Bool = false) {
        self.init(indexForFilterTitle: indexForFilterTitle, title: title, subtitle: subtitle, isSelected: false, children: children, isGroupCollapsed: isGroupCollapsed)
    }
    
    public convenience init(indexForFilterTitle: Int, title: String, subtitle: String? = nil, isSelected: Bool = false) {
        self.init(indexForFilterTitle: indexForFilterTitle, title: title, subtitle: subtitle, isSelected: isSelected, children: [], isGroupCollapsed: false)
    }
    
    public init(indexForFilterTitle: Int, title: String, subtitle: String? = nil, isSelected: Bool, children: [FiltersCheckboxItem], isGroupCollapsed: Bool) {
        self.title = title
        self.subtitle = subtitle
        self._isSelected = isSelected
        self.children = children
        self.isGroupCollapsed = isGroupCollapsed
    }
    
    open var description: String {
        var descriptionString = "title = \(title), state = \(selectionState)"
        if !isEnabled {
            descriptionString += ", isEnabled = false"
        }
        if !children.isEmpty {
            descriptionString += ", children = \(children.count)"
        }
        return "\(descriptionString)"
    }
}
