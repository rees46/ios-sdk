import Foundation

extension SearchFilterViewController: SearchFilterCheckBoxViewDelegate {
    func searchFilterCheckBoxView(
        _ view: SearchFilterCheckBoxView,
        didUpdateSelectedTypes selectedTypes: Set<String>,
        header:String
    ) {
        selectedFilters[header] = Array(selectedTypes)
        performSearch(with: selectedFilters)
    }
}
