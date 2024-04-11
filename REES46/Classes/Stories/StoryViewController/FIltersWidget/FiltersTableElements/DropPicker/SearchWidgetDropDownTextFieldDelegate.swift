import UIKit

@MainActor
public protocol SearchWidgetDropDownTextFieldDelegate: UITextFieldDelegate {

    @MainActor
    func textField(textField: SearchWidgetDropDownTextField, didSelectItem item: String?)

    @MainActor
    func textField(textField: SearchWidgetDropDownTextField, didSelectItems items: [String?])

    @MainActor
    func textField(textField: SearchWidgetDropDownTextField, didSelectDate date: Date?)
}

@MainActor
extension SearchWidgetDropDownTextFieldDelegate {
    func textField(textField: SearchWidgetDropDownTextField, didSelectItem item: String?) { }
    func textField(textField: SearchWidgetDropDownTextField, didSelectItems items: [String?]) { }
    func textField(textField: SearchWidgetDropDownTextField, didSelectDate date: Date?) { }
}
