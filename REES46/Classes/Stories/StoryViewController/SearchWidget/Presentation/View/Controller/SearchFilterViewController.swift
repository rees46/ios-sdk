import UIKit

class SearchFilterViewController:
    UIViewController,
    SearchFilterActionButtonsDelegate,
    CheckBoxCollectionViewCellDelegate,
    SearchFilterPickerViewDelegate
{
    
    public var sdk: PersonalizationSDK?
    
    public var searchResults: [SearchResult]? {
        didSet {
            if let count = searchResults?.count {
                print("Count \(count)")
                setupFilterViews()
            }
        }
    }
    
    private var selectedTypes: Set<String> = []
    private var selectedFilters: [String: Any] = [:]
    
    private let headerView: SearchFilterHeaderView = {
        let view = SearchFilterHeaderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let actionButtons: SearchFilterActionButtons = {
        let view = SearchFilterActionButtons()
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        actionButtons.delegate = self
        filterPickerSizeView.delegate = self
        filterPickerPriceView.delegate = self
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        view.addSubview(headerView)
        view.addSubview(scrollView)
        view.addSubview(actionButtons)
        
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            // HeaderView Constraints
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),
            
            // ScrollView Constraints
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: actionButtons.topAnchor),
            
            // Action Buttons Constraints
            actionButtons.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            actionButtons.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            actionButtons.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            actionButtons.heightAnchor.constraint(equalToConstant: 50),
            
            // ContentView Constraints
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func setupFilterViews() {
        guard let searchResults = searchResults, let filters = searchResults.first?.filters else {
            print("No search results or filters found")
            return
        }
        
        var previousView: UIView? = nil
        let defaultTopSpacing: CGFloat = 16
        let defaultSpacing: CGFloat = 16
        
        if let sizePickerView = setupSizePickerView() {
            contentView.addSubview(sizePickerView)
            NSLayoutConstraint.activate([
                sizePickerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                sizePickerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                sizePickerView.heightAnchor.constraint(equalToConstant: 100),
                sizePickerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: defaultTopSpacing)
            ])
            previousView = sizePickerView
        }
        
        for (filterTitle, filter) in filters {
            let checkBoxView = createCheckBoxView(withTitle: filterTitle, values: filter.values.map { $0.key })
            contentView.addSubview(checkBoxView)
            
            NSLayoutConstraint.activate([
                checkBoxView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                checkBoxView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            ])
            
            if let previousView = previousView {
                checkBoxView.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: defaultSpacing).isActive = true
            } else {
                checkBoxView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: defaultTopSpacing).isActive = true
            }
            
            previousView = checkBoxView
        }
        
        if let pricePickerView = setupPricePickerView() {
            contentView.addSubview(pricePickerView)
            NSLayoutConstraint.activate([
                pricePickerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                pricePickerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                pricePickerView.heightAnchor.constraint(equalToConstant: 100),
                pricePickerView.topAnchor.constraint(equalTo: previousView?.bottomAnchor ?? contentView.topAnchor, constant: defaultSpacing)
            ])
            previousView = pricePickerView
        }
        
        if let ratingCheckBoxesView = setupRatingTypeCheckBoxes() {
            contentView.addSubview(ratingCheckBoxesView)
            
            NSLayoutConstraint.activate([
                ratingCheckBoxesView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                ratingCheckBoxesView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                ratingCheckBoxesView.topAnchor.constraint(equalTo: previousView?.bottomAnchor ?? contentView.topAnchor, constant: defaultSpacing),
                ratingCheckBoxesView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
            ])
            
            previousView = ratingCheckBoxesView
        }
    }
    
    private func createCheckBoxView(withTitle title: String, values: [String]) -> SearchFilterCheckBoxView {
        let checkBoxView = SearchFilterCheckBoxView()
        checkBoxView.translatesAutoresizingMaskIntoConstraints = false
        checkBoxView.setHeaderTitle(title)
        checkBoxView.updateData(with: values)
        return checkBoxView
    }
    
    private func setupSizePickerView() -> SearchFilterPickerView? {
        filterPickerSizeView.labelText = Bundle.getLocalizedString(forKey: "size_key", comment: "")
        return filterPickerSizeView
    }
    
    private func setupPricePickerView() -> SearchFilterPickerView? {
        let currency = searchResults?.first?.currency ?? ""
        let localizedPriceLabelText = String(format: Bundle.getLocalizedString(forKey: "price_key", comment: ""), currency)
        filterPickerPriceView.labelText = localizedPriceLabelText
        return filterPickerPriceView
    }
    
    private func setupRatingTypeCheckBoxes() -> SearchFilterCheckBoxView? {
        let ratings = [
            Bundle.getLocalizedString(forKey: "all"),
            Bundle.getLocalizedString(forKey: "rating-5-star"),
            Bundle.getLocalizedString(forKey: "rating-4-star"),
            Bundle.getLocalizedString(forKey: "rating-3-star"),
            Bundle.getLocalizedString(forKey: "rating-2-star"),
            Bundle.getLocalizedString(forKey: "rating-1-star")
        ]
        
        let ratingCheckBoxesView = SearchFilterCheckBoxView()
        ratingCheckBoxesView.translatesAutoresizingMaskIntoConstraints = false
        ratingCheckBoxesView.setHeaderTitle(Bundle.getLocalizedString(forKey: "rating_title"))
        ratingCheckBoxesView.updateData(with: ratings)
        
        return ratingCheckBoxesView
    }
    
    private func setupActions() {
        actionButtons.delegate = self
        headerView.onCloseButtonTapped = { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
    }
    
    func didTapResetButton() {
        selectedFilters.removeAll()
        // Notify delegate or update UI to reflect reset
    }
    
    func didTapShowButton() {
        performSearch(with: selectedFilters)
    }
    
    func searchFilterPickerView(_ pickerView: SearchFilterPickerView, didUpdateFromValue fromValue: Int, toValue: Int) {
        let key = pickerView == filterPickerSizeView ? "size" : "price"
        selectedFilters[key] = ["from": fromValue, "to": toValue]
    }
    
    func checkBoxCell(_ cell: CheckBoxCollectionViewCell, didChangeState isChecked: Bool, for type: String) {
        print("FILTERS checkBoxCell \(type)")
        if isChecked {
            selectedTypes.insert(type)
        } else {
            selectedTypes.remove(type)
        }
        
        selectedFilters["type"] = Array(selectedTypes)
        
        performSearch(with: selectedFilters)
    }
    
    private func performSearch(with filters: [String: Any]) {
        guard let query = searchResults?.first?.query else { return }
        print("FILTERS performSearch \(filters) \(query)")
        sdk?.search(query: query, filters: filters) { response in
            switch response {
            case .success(let searchResponse):
                // Handle success
                print("Search results: \(searchResponse)")
            case .failure(let error):
                // Handle error
                print("Search error: \(error)")
            }
        }
    }
}
