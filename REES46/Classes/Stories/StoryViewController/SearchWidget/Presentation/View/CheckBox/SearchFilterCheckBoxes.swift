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
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.black, for: .normal)
        button.contentHorizontalAlignment = .left
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .black
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private func updateArrowImageView() {
        var frameworkBundle = Bundle(for: type(of: self))
        let arrowImageName = isExpanded ? "angleUpBlack" : "angleDownBlack"
        let arrowImage = UIImage(named: arrowImageName, in: frameworkBundle, compatibleWith: nil)?.withRenderingMode(.alwaysTemplate)
        arrowImageView.image = arrowImage
    }
    
    private var colors: [String] = []
    private var isExpanded: Bool = false
    private let defaultItemCount = 5
    private var collectionViewHeightConstraint: NSLayoutConstraint?
    
    private let showMoreContainer: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
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
        addSubview(showMoreContainer)
        
        showMoreContainer.addArrangedSubview(selectAllButton)
        showMoreContainer.addArrangedSubview(arrowImageView)
        
        setupLabelConstraints()
        setupCollectionViewConstraints()
        setupShowMoreContainerConstraints()
        updateArrowImageView()
        
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
            collectionView.bottomAnchor.constraint(equalTo: showMoreContainer.topAnchor, constant: -8)
        ])
    }
    
    private func setupShowMoreContainerConstraints() {
        NSLayoutConstraint.activate([
            showMoreContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            showMoreContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            showMoreContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            showMoreContainer.heightAnchor.constraint(equalToConstant: 44),
            showMoreContainer.widthAnchor.constraint(equalToConstant: 150)
        ])
        
        NSLayoutConstraint.activate([
            arrowImageView.widthAnchor.constraint(equalToConstant: 16),
            arrowImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        NSLayoutConstraint.activate([
            selectAllButton.leadingAnchor.constraint(equalTo: showMoreContainer.leadingAnchor),
            selectAllButton.trailingAnchor.constraint(equalTo: arrowImageView.leadingAnchor, constant: -8),
            arrowImageView.trailingAnchor.constraint(equalTo: showMoreContainer.trailingAnchor)
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
        
        let buttonTitle: String
        let arrowImageName: String
        
        if isExpanded {
            buttonTitle = "Collapse"
            arrowImageName = "angleUpBlack"
        } else {
            buttonTitle = "Show more (\(colors.count - defaultItemCount))"
            arrowImageName = "angleDownBlack"
        }
        
        var frameworkBundle = Bundle(for: type(of: self))
        let arrowImage = UIImage(named: arrowImageName, in: frameworkBundle, compatibleWith: nil)?.withRenderingMode(.alwaysTemplate)
        
        selectAllButton.setTitle(buttonTitle, for: .normal)
        arrowImageView.image = arrowImage
    }
}
