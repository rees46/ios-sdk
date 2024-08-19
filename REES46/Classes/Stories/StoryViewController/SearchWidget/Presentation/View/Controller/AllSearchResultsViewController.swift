import UIKit

class AllSearchResultsViewController: UIViewController {
    
    var searchResults: [SearchResult]?
    
    private let headerView: SearchResultHeaderView = {
        let view = SearchResultHeaderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ResultCell")
        return tableView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        view.addSubview(headerView)
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),
            
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    private func setupActions() {
        headerView.onBackButtonTapped = { [weak self] in
            print("onBackButtonTapped tapped")
            self?.dismiss(animated: true, completion: nil)
        }
        
        headerView.onFilterButtonTapped = { [weak self] in
            // TODO: Показать экран фильтров
            print("onFilterButtonTapped tapped")
        }
        
        headerView.onCloseButtonTapped = { [weak self] in
            print("onCloseButtonTapped tapped")
            self?.dismiss(animated: true, completion: nil)
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        view.frame = UIScreen.main.bounds
    }
}
