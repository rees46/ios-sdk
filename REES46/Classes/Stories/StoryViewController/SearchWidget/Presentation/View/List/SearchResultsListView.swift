import UIKit


class SearchResultsListView: UIView {
    
    public var sdk: PersonalizationSDK?
    
    private let resultCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .black
        label.numberOfLines = 1
        label.textAlignment = .left
        return label
    }()
    
    let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        let itemWidth = (UIScreen.main.bounds.width - 16) / 2
        layout.itemSize = CGSize(width: itemWidth, height: 380)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .white
        collectionView.register(RecommendationsWidgetViewCell.self, forCellWithReuseIdentifier: RecommendationsWidgetViewCell.reuseRecommCellId)
        return collectionView
    }()
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        addSubview(resultCountLabel)
        addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            resultCountLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            resultCountLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            resultCountLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            collectionView.topAnchor.constraint(equalTo: resultCountLabel.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
            
        ])
    }
    
    func setResultCount(_ count: Int) {
        resultCountLabel.text = "found \(count) products"
    }
}
