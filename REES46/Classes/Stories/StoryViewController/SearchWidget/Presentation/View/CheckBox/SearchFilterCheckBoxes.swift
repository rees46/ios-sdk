import UIKit

class SearchFilterCheckBoxView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    private let colorLabel: UILabel = {
        let label = UILabel()
        label.text = "Color"
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = UIColor.black
        return label
    }()
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear // Цвет фона для отладки
        return collectionView
    }()
    
    private var colors: [String] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView(){
        addSubview(colorLabel)
        addSubview(collectionView)
        
        setupColorLabelConstraints()
        setupCollectionViewConstraints()
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(CheckBoxCollectionViewCell.self, forCellWithReuseIdentifier: CheckBoxCollectionViewCell.identifier)
        
        // Добавляем фиктивные цвета
        colors = ["Black", "White", "Red", "Blue", "Yellow", "Green", "Purple", "Orange", "Pink", "Brown"]
        collectionView.reloadData()
    }
    
    private func setupColorLabelConstraints() {
        colorLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            colorLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            colorLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            colorLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])
    }
    
    private func setupCollectionViewConstraints() {
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            collectionView.topAnchor.constraint(equalTo: colorLabel.bottomAnchor, constant: 16),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return colors.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CheckBoxCollectionViewCell.identifier, for: indexPath) as! CheckBoxCollectionViewCell
        let color = colors[indexPath.item]
        cell.configure(with: color)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width - 32
        return CGSize(width: width, height: 24)
    }
}
