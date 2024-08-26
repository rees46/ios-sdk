import UIKit

class AllSearchResultsViewController: UIViewController {
    
    public var sdk: PersonalizationSDK?
    
    var searchResults: [SearchResult]? {
        didSet {
            if let count = searchResults?.count {
                resultsListView.setResultCount(count)
                resultsListView.collectionView.reloadData()
            }
        }
    }
    
    private let headerView: SearchResultHeaderView = {
        let view = SearchResultHeaderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let resultsListView: SearchResultsListView = {
        let view = SearchResultsListView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        setupCollectionView()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        view.addSubview(headerView)
        view.addSubview(resultsListView)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 160),
            
            resultsListView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            resultsListView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            resultsListView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            resultsListView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupActions() {
        headerView.onBackButtonTapped = { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
        
        headerView.onFilterButtonTapped = { [weak self] in
            self?.openFilterScreen()
        }
        
        headerView.onCloseButtonTapped = { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
    }
    
    private func openFilterScreen() {
        let filterVC = SearchFilterViewController()
        filterVC.searchResults = self.searchResults
        filterVC.modalPresentationStyle = .fullScreen
        self.present(filterVC, animated: true, completion: nil)
    }
    
    private func setupCollectionView() {
        resultsListView.collectionView.dataSource = self
        resultsListView.collectionView.delegate = self
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        view.frame = UIScreen.main.bounds
    }
}
