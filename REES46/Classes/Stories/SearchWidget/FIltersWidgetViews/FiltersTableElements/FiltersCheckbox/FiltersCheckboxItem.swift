import UIKit

public class FiltersCheckboxItem: CustomStringConvertible {
    
    public enum ItemType {
        case groupCheckbox
        case singleCheckbox
    }
    
    public enum ItemSelectionState {
        case currentFilterOn
        case currentFilterOff
        case currentFilterMixed
    }
    
    public var filtersList = [FiltersDataMenuList]()
    
    public var title: String
    public var subtitle: String?
    
    public var type: ItemType {
        return childrenCheckboxArray.isEmpty ? .singleCheckbox : .groupCheckbox
    }
    
    public var childrenCheckboxArray: [FiltersCheckboxItem] = []
    
    public var isGroupCollapsed: Bool
    
    private var _isEnabled = true
    
    public var isEnabled: Bool {
        get {
            return _isEnabled
        }
        set {
            _isEnabled = newValue
            
            for child in childrenCheckboxArray {
                child.isEnabled = newValue
            }
        }
    }
    
    public var _isSelected: Bool
    
    public var isSelected: Bool {
        get {
            if type == .groupCheckbox {
                return selectionState == .currentFilterOn
            } else {
                return _isSelected
            }
        }
        set {
            if isEnabled == false {
                return
            }
            
            _isSelected = newValue
            
            for child in childrenCheckboxArray {
                child.isSelected = newValue
            }
        }
    }
    
    public var selectionState: ItemSelectionState {
        if type == .groupCheckbox {
            
            if childrenCheckboxArray.isEmpty {
                return .currentFilterOff
            }
            
            let hasMixedChild = childrenCheckboxArray.contains{ $0.selectionState == .currentFilterMixed }
            if hasMixedChild {
                return .currentFilterMixed
            }
            
            let hasSelectedChild = childrenCheckboxArray.contains{ $0.selectionState == .currentFilterOn }
            let hasUnselectedChild = childrenCheckboxArray.contains{ $0.selectionState == .currentFilterOff }
            
            if hasSelectedChild && !hasUnselectedChild {
                return .currentFilterOn
            } else if !hasSelectedChild && hasUnselectedChild {
                return .currentFilterOff
            } else {
                return .currentFilterMixed
            }
        }
        return isSelected ? .currentFilterOn : .currentFilterOff
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
        self.childrenCheckboxArray = children
        self.isGroupCollapsed = isGroupCollapsed
    }
    
    public var description: String {
        var descriptionString = "Filter title = \(title), state = \(selectionState)"
        if !isEnabled {
            descriptionString += ", isEnabled = false"
        }
        if !childrenCheckboxArray.isEmpty {
            descriptionString += ", children = \(childrenCheckboxArray.count)"
        }
        return "\(descriptionString)"
    }
}
