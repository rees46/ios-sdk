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
    
    private let filterPickerSizeView: SearchFilterPickerView = {
        let view = SearchFilterPickerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let colorCheckBoxesView: SearchFilterCheckBoxView = {
        let view = SearchFilterCheckBoxView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
//        setupColorCheckBoxes()
        setupActions()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(headerView)
        contentView.addSubview(filterPickerSizeView)
        contentView.addSubview(colorCheckBoxesView)
        
        NSLayoutConstraint.activate([
            // ScrollView Constraints
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView Constraints
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // HeaderView Constraints
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            // FilterPickerSizeView Constraints
            filterPickerSizeView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            filterPickerSizeView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            filterPickerSizeView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            filterPickerSizeView.heightAnchor.constraint(equalToConstant: 60),
            
            // ColorCheckBoxesView Constraints
            colorCheckBoxesView.topAnchor.constraint(equalTo: filterPickerSizeView.bottomAnchor),
            colorCheckBoxesView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            colorCheckBoxesView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            colorCheckBoxesView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            colorCheckBoxesView.heightAnchor.constraint(equalToConstant: 260),
        ])
        
        // Ensure contentView has a sufficient height
    }
    
    private func setupActions() {
        headerView.onCloseButtonTapped = { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
    }
    
//    private func setupColorCheckBoxes() {
//        let colors = ["Black", "White", "Red", "Blue", "Yellow", "Green", "Purple", "Orange", "Pink", "Brown"]
//        colorCheckBoxesView.updateColors(with: colors)
//    }
    
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
