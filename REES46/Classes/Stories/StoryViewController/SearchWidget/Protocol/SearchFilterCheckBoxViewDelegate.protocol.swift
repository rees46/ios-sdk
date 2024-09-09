import Foundation

protocol SearchFilterCheckBoxViewDelegate: AnyObject {
    func searchFilterCheckBoxView(
        _ checkBoxView: SearchFilterCheckBoxView,
        didUpdateSelectedColors selectedColors: Set<String>
    )
}
