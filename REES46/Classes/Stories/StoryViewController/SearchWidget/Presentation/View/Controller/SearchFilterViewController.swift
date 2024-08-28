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
    
    private let headerView: SearchFilterHeaderView = {
        let view = SearchFilterHeaderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let filterPickerSizeView: SearchFilterPickerView = {
        let view = SearchFilterPickerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let colorCheckBoxesView: SearchFilterCheckBoxView = {
        let view = SearchFilterCheckBoxView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        view.addSubview(headerView)
        view.addSubview(filterPickerSizeView)
        view.addSubview(colorCheckBoxesView)
        
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 160),
            
            filterPickerSizeView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            filterPickerSizeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterPickerSizeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterPickerSizeView.heightAnchor.constraint(equalToConstant: 60),
            
            colorCheckBoxesView.topAnchor.constraint(equalTo: filterPickerSizeView.bottomAnchor),
                colorCheckBoxesView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                colorCheckBoxesView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            colorCheckBoxesView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                 
            ])
    }
    
    private func setupActions() {
        headerView.onCloseButtonTapped = { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
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
                print("No filters for product \(result).")
            }
        }
    }
}
