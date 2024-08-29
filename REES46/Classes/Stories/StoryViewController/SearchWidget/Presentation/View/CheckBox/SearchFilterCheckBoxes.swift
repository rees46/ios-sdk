import UIKit

class SearchFilterCheckBoxView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    private let colorLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = UIColor.black
        return label
    }()
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        return collectionView
    }()
    
    private let selectAllButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Show more", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.black, for: .normal)
        button.contentHorizontalAlignment = .left
        return button
    }()
    
    private var colors: [String] = []
    private var isExpanded: Bool = false
    private let defaultItemCount = 5
    private var collectionViewHeightConstraint: NSLayoutConstraint?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        addSubview(colorLabel)
        addSubview(collectionView)
        addSubview(selectAllButton)
        
        setupLabelConstraints()
        setupCollectionViewConstraints()
        setupShowMoreButtonConstraints()
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(CheckBoxCollectionViewCell.self, forCellWithReuseIdentifier: CheckBoxCollectionViewCell.identifier)
        
        selectAllButton.addTarget(self, action: #selector(showMoreButtonTapped), for: .touchUpInside)
    }
    
    
    func updateData(with colors: [String]) {
        self.colors = colors
        collectionView.reloadData()
        updateCollectionViewHeight()
        
        if colors.count > defaultItemCount {
            let hiddenCount = colors.count - defaultItemCount
            selectAllButton.setTitle("Show more (\(hiddenCount))", for: .normal)
            selectAllButton.isHidden = false
        } else {
            selectAllButton.isHidden = true
        }
    }
    
    func setHeaderTitle(_ title: String) {
        colorLabel.text = title
    }
    
    private func setupLabelConstraints() {
        colorLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            colorLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            colorLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            colorLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])
    }
    
    private func setupCollectionViewConstraints() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionViewHeightConstraint = collectionView.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            collectionView.topAnchor.constraint(equalTo: colorLabel.bottomAnchor, constant: 16),
            collectionViewHeightConstraint!,
            collectionView.bottomAnchor.constraint(equalTo: selectAllButton.topAnchor, constant: -8)
        ])
    }
    
    private func setupShowMoreButtonConstraints() {
        selectAllButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            selectAllButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            selectAllButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            selectAllButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            selectAllButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func updateCollectionViewHeight() {
        let itemCount = isExpanded ? colors.count : min(colors.count, defaultItemCount)
        let itemHeight: CGFloat = 24
        let spacing: CGFloat = 8
        let totalHeight = (itemHeight + spacing) * CGFloat(itemCount)
        
        collectionViewHeightConstraint?.constant = totalHeight + 20
        layoutIfNeeded()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return isExpanded ? colors.count : min(colors.count, defaultItemCount)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CheckBoxCollectionViewCell.identifier, for: indexPath) as! CheckBoxCollectionViewCell
        let list = colors[indexPath.item]
        cell.configure(with: list)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width - 32
        return CGSize(width: width, height: 24)
    }
    
    @objc private func showMoreButtonTapped() {
        isExpanded.toggle()
        collectionView.reloadData()
        updateCollectionViewHeight()
        
        let buttonTitle = isExpanded ? "Collapse" : "Show more (\(colors.count - defaultItemCount))"
        selectAllButton.setTitle(buttonTitle, for: .normal)
    }
}
