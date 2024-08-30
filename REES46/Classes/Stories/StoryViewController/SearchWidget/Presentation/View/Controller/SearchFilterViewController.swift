import UIKit

class SearchFilterViewController: UIViewController {
    
    public var sdk: PersonalizationSDK?
    
    var searchResults: [SearchResult]? {
        didSet {
            if let count = searchResults?.count {
                print("Count \(count)")
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
    
    private let materialCheckBoxesView: SearchFilterCheckBoxView = {
        let view = SearchFilterCheckBoxView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let ratingCheckBoxesView: SearchFilterCheckBoxView = {
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
        setSizeList()
        setPriceList()
        setupColorCheckBoxes()
        setupTypeCheckBoxes()
        setupMaterialCheckBoxes()
        setupRatingTypeCheckBoxes()
        
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
        contentView.addSubview(materialCheckBoxesView)
        contentView.addSubview(ratingCheckBoxesView)
        contentView.addSubview(spacerView)
        
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
            
            // MaterialCheckBoxesView Constraints
            materialCheckBoxesView.topAnchor.constraint(equalTo: filterPickerPriceView.bottomAnchor),
            materialCheckBoxesView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            materialCheckBoxesView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            // RatingCheckBoxesView Constraints
            ratingCheckBoxesView.topAnchor.constraint(equalTo: materialCheckBoxesView.bottomAnchor, constant: -50),
            ratingCheckBoxesView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            ratingCheckBoxesView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            // SpacerView Constraints
            spacerView.topAnchor.constraint(equalTo: ratingCheckBoxesView.bottomAnchor),
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
    
    private func setSizeList(){
        filterPickerSizeView.listLimit = Array(1...50)
    }
    
    private func setPriceList(){
        filterPickerPriceView.listLimit = Array(1...1000000)
    }
    
    private func setupColorCheckBoxes() {
        let colors = [
            Bundle.getLocalizedString(forKey: "all"),
            Bundle.getLocalizedString(forKey: "black_color_key"),
            Bundle.getLocalizedString(forKey: "white_color_key"),
            Bundle.getLocalizedString(forKey: "gray_color_key"),
            Bundle.getLocalizedString(forKey: "red_color_key"),
            Bundle.getLocalizedString(forKey: "blue_color_key"),
            Bundle.getLocalizedString(forKey: "orange_color_key"),
            Bundle.getLocalizedString(forKey: "purple_color_key"),
            Bundle.getLocalizedString(forKey: "green_color_key"),
            Bundle.getLocalizedString(forKey: "brown_color_key"),
            Bundle.getLocalizedString(forKey: "yellow_color_key"),
            Bundle.getLocalizedString(forKey: "orange_color_key"),
            Bundle.getLocalizedString(forKey: "pink_color_key"),
        ]
        colorCheckBoxesView.updateData(with: colors)
        
        colorCheckBoxesView.setHeaderTitle(
            Bundle.getLocalizedString(forKey: "color_title")
        )
    }
    
    private func setupTypeCheckBoxes() {
        let colors = [
            Bundle.getLocalizedString(forKey: "all"),
            Bundle.getLocalizedString(forKey: "shoes_key"),
            Bundle.getLocalizedString(forKey: "boots_key"),
            Bundle.getLocalizedString(forKey: "sneakers_key"),
            Bundle.getLocalizedString(forKey: "sandals_key"),
        ]
        typeCheckBoxesView.updateData(with: colors)
        
        typeCheckBoxesView.setHeaderTitle(
            Bundle.getLocalizedString(forKey: "type_title")
        )
    }
    
    private func setupMaterialCheckBoxes() {
        let materials = [
            Bundle.getLocalizedString(forKey: "all"),
            Bundle.getLocalizedString(forKey: "leather_key"),
            Bundle.getLocalizedString(forKey: "rubber_key"),
            Bundle.getLocalizedString(forKey: "cotton_key"),
            Bundle.getLocalizedString(forKey: "polyrethane_key"),
        ]
        materialCheckBoxesView.updateData(with: materials)
        
        materialCheckBoxesView.setHeaderTitle(
            Bundle.getLocalizedString(forKey: "material_title")
        )
    }
    
    private func setupRatingTypeCheckBoxes() {
        let ratings = [
            Bundle.getLocalizedString(forKey: "all"),
            Bundle.getLocalizedString(forKey: "rating-5-star"),
            Bundle.getLocalizedString(forKey: "rating-4-star"),
            Bundle.getLocalizedString(forKey: "rating-3-star"),
            Bundle.getLocalizedString(forKey: "rating-2-star"),
            Bundle.getLocalizedString(forKey: "rating-1-star")
        ]
        
        ratingCheckBoxesView.updateData(with: ratings)
        
        ratingCheckBoxesView.setHeaderTitle(
            Bundle.getLocalizedString(forKey: "rating_title")
        )
    }
    
    private func setupPriceBlock() {
        let currency = searchResults?.first?.currency ?? ""
        let localizedPriceLabelText = String(format: Bundle.getLocalizedString(forKey: "price_key", comment: ""), currency)
         filterPickerPriceView.labelText = localizedPriceLabelText
    }
}
