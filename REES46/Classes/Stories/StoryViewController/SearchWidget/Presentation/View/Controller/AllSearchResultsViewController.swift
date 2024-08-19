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
        self.view.backgroundColor = .white
        self.title = "All Results"

        // Добавляем headerView и tableView на главный view
        self.view.addSubview(headerView)
        self.view.addSubview(tableView)

        // Настройка Auto Layout
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),  // Высота headerView
            
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])

        tableView.dataSource = self
        tableView.delegate = self
    }

    private func setupActions() {
        headerView.onBackButtonTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        headerView.onFilterButtonTapped = { [weak self] in
            // TODO: Показать экран фильтров
            print("Filter button tapped")
        }
        
        headerView.onCloseButtonTapped = { [weak self] in
            self?.navigationController?.popToRootViewController(animated: true)
        }
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension AllSearchResultsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ResultCell", for: indexPath)
        cell.textLabel?.text = searchResults?[indexPath.row].name  // Пример отображения данных
        return cell
    }
}
