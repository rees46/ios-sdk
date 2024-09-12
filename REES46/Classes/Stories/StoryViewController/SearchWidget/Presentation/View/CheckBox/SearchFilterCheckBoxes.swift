import UIKit


class SearchFilterCheckBoxView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    weak var delegate: SearchFilterCheckBoxViewDelegate?
    
    private let colorLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = UIColor.black
        return label
    }()
    
    private let spacerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
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
    
    private let showMoreContainer: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private var colors: [String] = []
    private var isExpanded: Bool = false
    private var selectedColors: Set<String> = []
    private let defaultItemCount = 5
    private var collectionViewHeightConstraint: NSLayoutConstraint?
    
    var headerTitle: String? {
        didSet {
            colorLabel.text = headerTitle
        }
    }
    
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
        addSubview(spacerView)
        addSubview(collectionView)
        addSubview(showMoreContainer)
        
        showMoreContainer.addArrangedSubview(selectAllButton)
        showMoreContainer.addArrangedSubview(arrowImageView)
        
        setupLabelConstraints()
        setupSpacerViewConstraints()
        setupCollectionViewConstraints()
        setupShowMoreContainerConstraints()
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(CheckBoxCollectionViewCell.self, forCellWithReuseIdentifier: CheckBoxCollectionViewCell.identifier)
        
        selectAllButton.addTarget(self, action: #selector(showMoreButtonTapped), for: .touchUpInside)
        
        updateArrowImageView()
    }
    
    private func setupSpacerViewConstraints() {
        NSLayoutConstraint.activate([
            spacerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            spacerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            spacerView.topAnchor.constraint(equalTo: colorLabel.bottomAnchor),
            spacerView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    func updateData(with colors: [String]) {
        self.colors = colors
        collectionView.reloadData()
        updateCollectionViewHeight()
        
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.setNeedsLayout()
        
        if colors.count > defaultItemCount {
            let hiddenCount = colors.count - defaultItemCount
            selectAllButton.setTitle("\(Bundle.getLocalizedString(forKey: "show_more_key")) (\(hiddenCount))", for: .normal)
            selectAllButton.isHidden = false
        } else {
            selectAllButton.isHidden = true
        }
    }
    
    func setHeaderTitle(_ title: String) {
        headerTitle = title
    }
    
    private func setupLabelConstraints() {
        colorLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            colorLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            colorLabel.topAnchor.constraint(equalTo: topAnchor),
            colorLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
    
    private func setupCollectionViewConstraints() {
        collectionViewHeightConstraint = collectionView.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: spacerView.bottomAnchor),
            collectionViewHeightConstraint!,
            collectionView.bottomAnchor.constraint(equalTo: showMoreContainer.topAnchor, constant: -8)
        ])
    }
    
    private func setupShowMoreContainerConstraints() {
        NSLayoutConstraint.activate([
            showMoreContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            showMoreContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            showMoreContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0),
            showMoreContainer.heightAnchor.constraint(equalToConstant: 20),
        ])

        NSLayoutConstraint.activate([
            selectAllButton.leadingAnchor.constraint(equalTo: showMoreContainer.leadingAnchor),
            selectAllButton.trailingAnchor.constraint(equalTo: arrowImageView.leadingAnchor, constant: -8),
            arrowImageView.trailingAnchor.constraint(equalTo: showMoreContainer.trailingAnchor)
        ])
    }
    
    private func updateArrowImageView() {
        let arrowImageName = isExpanded ? "angleUpBlack" : "angleDownBlack"
        let frameworkBundle = Bundle(for: type(of: self))
        let arrowImage = UIImage(named: arrowImageName, in: frameworkBundle, compatibleWith: nil)?.withRenderingMode(.alwaysTemplate)
        arrowImageView.image = arrowImage
        arrowImageView.tintColor = .clear
    }
    
    private func updateCollectionViewHeight() {
        let itemCount = isExpanded ? colors.count : min(colors.count, defaultItemCount)
        let itemHeight: CGFloat = 24
        let spacing: CGFloat = 8
        let totalHeight = (itemHeight + spacing) * CGFloat(itemCount)
        
        collectionViewHeightConstraint?.constant = totalHeight + 20
        collectionView.layoutIfNeeded()
        layoutIfNeeded()
    }
    
    @objc private func showMoreButtonTapped() {
        isExpanded.toggle()
        collectionView.reloadData()
        updateCollectionViewHeight()
        updateArrowImageView()
        
        let buttonTitle: String
        if isExpanded {
            buttonTitle = Bundle.getLocalizedString(forKey: "collaps_key")
        } else {
            buttonTitle = String(format: Bundle.getLocalizedString(forKey: "show_more_key", comment: ""), colors.count - defaultItemCount)
        }
        
        selectAllButton.setTitle(buttonTitle, for: .normal)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return isExpanded ? colors.count : min(colors.count, defaultItemCount)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CheckBoxCollectionViewCell.identifier, for: indexPath) as! CheckBoxCollectionViewCell
        let color = colors[indexPath.item]
        cell.configure(with: color)
        
        cell.isChecked = selectedColors.contains(color)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width
        return CGSize(width: width, height: 24)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let color = colors[indexPath.item]
        if selectedColors.contains(color) {
            selectedColors.remove(color)
        } else {
            selectedColors.insert(color)
        }
        collectionView.reloadItems(at: [indexPath])
        
        print("SELECTED CHECK BOX \(selectedColors)")
        delegate?.searchFilterCheckBoxView(self, didUpdateSelectedColors: selectedColors)
    }
}
