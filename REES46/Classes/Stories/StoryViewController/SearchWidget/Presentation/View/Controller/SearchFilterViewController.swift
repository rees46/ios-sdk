import Foundation
import UIKit

class SearchFilterViewController: UIViewController {
    
    public var sdk: PersonalizationSDK?
    
    var searchResults: [SearchResult]? {
        didSet {
            if let count = searchResults?.count {
                print("Count \(count)")
                printFilters()
            }
        }
    }
    
    private let headerView: SearchResultHeaderView = {
        let view = SearchResultHeaderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        view.addSubview(headerView)
    }
    
    private func printFilters() {
        guard let searchResults = searchResults else {
            print("No search results available.")
            return
        }
        
        for result in searchResults {
            if let filters = result.filters {
                print("Filters for product \(result.name):")
                for (filterName, filter) in filters {
                    print("  \(filterName): \(filter)")
                }
            } else {
                print("No filters for product \(result.name).")
            }
        }
    }
}
