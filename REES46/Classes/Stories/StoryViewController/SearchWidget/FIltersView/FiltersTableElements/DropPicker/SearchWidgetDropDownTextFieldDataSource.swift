import UIKit

@MainActor
public protocol SearchWidgetDropDownTextFieldDataSource: AnyObject {
    @MainActor
    func textField(textField: SearchWidgetDropDownTextField, canSelectItem item: String) -> Bool
    
    @MainActor
    func textField(textField: SearchWidgetDropDownTextField, proposedSelectionModeForItem item: String) -> SearchWidgetProposedSelection
}

@MainActor
extension SearchWidgetDropDownTextFieldDataSource {

    func textField(textField: SearchWidgetDropDownTextField, didSelectDate date: Date?) { }
    func textField(textField: SearchWidgetDropDownTextField, canSelectItem item: String) -> Bool { return true }
    func textField(textField: SearchWidgetDropDownTextField, proposedSelectionModeForItem item: String) -> SearchWidgetProposedSelection {
        return .both
    }
}
