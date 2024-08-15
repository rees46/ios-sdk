import UIKit

public struct SearchResult {
    let image: String
    let name: String
    let price: Double
    
    public init(image: String, name: String, price: Double) {
        self.image = image
        self.name = name
        self.price = price
    }
}

public protocol SearchResultsViewDelegate: AnyObject {
     func didSelectResult(_ result: SearchResult)
}

class SearchResultsView: UIView {
    private var results: [SearchResult] = []
    weak var delegate: SearchResultsViewDelegate?

    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTableView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTableView() {
        addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: self.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    func updateResults(_ results: [SearchResult]) {
        print("Выбран результат in view \(results)")
        self.results = results
        tableView.reloadData()
    }
}

extension SearchResultsView: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = results[indexPath.row].name
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedResult = results[indexPath.row]
        delegate?.didSelectResult(selectedResult)
    }
}
