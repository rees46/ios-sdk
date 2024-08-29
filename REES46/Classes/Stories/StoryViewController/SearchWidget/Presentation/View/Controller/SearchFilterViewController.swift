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
    
    private let spacerView: UIView = {
          let view = UIView()
          view.translatesAutoresizingMaskIntoConstraints = false
          return view
      }()
    
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
    
    private let filterPickerPriceView: SearchFilterPickerView = {
        let view = SearchFilterPickerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let colorCheckBoxesView: SearchFilterCheckBoxView = {
        let view = SearchFilterCheckBoxView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let typeCheckBoxesView: SearchFilterCheckBoxView = {
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
        setupColorCheckBoxes()
        setupTypeCheckBoxes()
        setupPriceBlock()
        setupActions()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(headerView)
        contentView.addSubview(filterPickerSizeView)
        contentView.addSubview(colorCheckBoxesView)
        contentView.addSubview(typeCheckBoxesView)
        contentView.addSubview(filterPickerPriceView)
        contentView.addSubview(spacerView)  // Добавляем spacerView
        
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
            filterPickerSizeView.heightAnchor.constraint(equalToConstant: 100),
            
            // ColorCheckBoxesView Constraints
            colorCheckBoxesView.topAnchor.constraint(equalTo: filterPickerSizeView.bottomAnchor),
            colorCheckBoxesView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            colorCheckBoxesView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            // TypeCheckBoxesView Constraints
            typeCheckBoxesView.topAnchor.constraint(equalTo: colorCheckBoxesView.bottomAnchor),
            typeCheckBoxesView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            typeCheckBoxesView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            // FilterPickerPriceView Constraints
            filterPickerPriceView.topAnchor.constraint(equalTo: typeCheckBoxesView.bottomAnchor, constant: -50),
            filterPickerPriceView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            filterPickerPriceView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            filterPickerPriceView.heightAnchor.constraint(equalToConstant: 100),
            
            // SpacerView Constraints
            spacerView.topAnchor.constraint(equalTo: filterPickerPriceView.bottomAnchor),
            spacerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            spacerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            spacerView.heightAnchor.constraint(equalToConstant: 100),
            spacerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    private func setupActions() {
        headerView.onCloseButtonTapped = { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
    }
    
    private func setupColorCheckBoxes() {
        let colors = ["All","Black", "White", "Red", "Blue", "Yellow", "Green", "Purple", "Orange", "Pink", "Brown"]
        colorCheckBoxesView.updateData(with: colors)
        colorCheckBoxesView.setHeaderTitle("Color")
    }
    
    private func setupTypeCheckBoxes() {
        let colors = ["All", "Shoes", "Boots", "Sneakers", "Sandals"]
        typeCheckBoxesView.updateData(with: colors)
        typeCheckBoxesView.setHeaderTitle("Type")
    }
    
    private func setupPriceBlock(){
        filterPickerPriceView.labelText = "Price"
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
