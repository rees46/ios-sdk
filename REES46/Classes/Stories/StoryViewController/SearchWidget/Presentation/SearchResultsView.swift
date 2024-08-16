import UIKit

class SearchResultsView: UIView {
    public var results: [SearchResult] = []
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
        
        tableView.register(SearchResultTableViewCell.self, forCellReuseIdentifier: "CustomCell")
    }
    
    func updateResults(_ results: [SearchResult]) {
        self.results = results
        tableView.reloadData()
    }
}

class SearchResultTableViewCell: UITableViewCell {
    
    private let firstLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .black
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let secondLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .black
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(firstLabel)
        contentView.addSubview(secondLabel)
        
        NSLayoutConstraint.activate([
            firstLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            firstLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            firstLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            secondLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            secondLabel.topAnchor.constraint(equalTo: firstLabel.bottomAnchor, constant: 4),
            secondLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            secondLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with result: SearchResult) {
        firstLabel.text = result.name
        secondLabel.text = "\(result.price)"
    }
}
