import Foundation

protocol SearchFilterCheckBoxViewDelegate: AnyObject {
    func searchFilterCheckBoxView(
        _ view: SearchFilterCheckBoxView,
        didUpdateSelectedTypes types: Set<String>,
        header:String
    )
}
