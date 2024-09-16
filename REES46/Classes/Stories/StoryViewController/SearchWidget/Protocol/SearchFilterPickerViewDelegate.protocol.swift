import Foundation

protocol SearchFilterPickerViewDelegate: AnyObject {
    func searchFilterPickerView(
        _ pickerView: SearchFilterPickerView,
        didUpdateFromValue fromValue: Int,
        toValue: Int
    )
}
