import UIKit

class AllSearchResultsViewController: UIViewController {

    var searchResults: [SearchResult]? {
        didSet {
            if let count = searchResults?.count {
                resultsListView.setResultCount(count)
            }
        }
    }

    private let headerView: SearchResultHeaderView = {
        let view = SearchResultHeaderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let resultsListView: SearchResultsListView = {
        let view = SearchResultsListView()
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

        resultsListView.tableView.dataSource = self
        resultsListView.tableView.delegate = self
    }

    private func setupActions() {
        headerView.onBackButtonTapped = { [weak self] in
            print("Back button tapped")
            self?.dismiss(animated: true, completion: nil)
        }

        headerView.onFilterButtonTapped = { [weak self] in
            // Открыть экран фильтров
            print("Filter button tapped")
        }

        headerView.onCloseButtonTapped = { [weak self] in
            print("Close button tapped")
            self?.dismiss(animated: true, completion: nil)
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        view.frame = UIScreen.main.bounds
    }
}
