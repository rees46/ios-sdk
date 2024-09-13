import UIKit

class SearchResultHeaderView: UIView {
    
    private let colorTint = UIColor(hex: "#737373")
    private let iconSize: CGFloat = 20
    
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: "IconArrowBack"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = Bundle.getLocalizedString(forKey: "search_result_key")
        label.font = UIFont.systemFont(ofSize: 24, weight: .regular)
        label.textColor = UIColor.black
        return label
    }()
    
    public let filterButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: "IconFilter"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: "IconClose"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    
    var onBackButtonTapped: (() -> Void)?
    var onFilterButtonTapped: (() -> Void)?
    var onCloseButtonTapped: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = UIColor.white
        
        backButton.tintColor = colorTint
        filterButton.tintColor = colorTint
        closeButton.tintColor = colorTint
        
        addSubview(backButton)
        addSubview(titleLabel)
        addSubview(filterButton)
        addSubview(closeButton)
        
        backButton.addTarget(
            self,
            action: #selector(backButtonTapped),
            for: .touchUpInside
        )
        filterButton.addTarget(
            self,
            action: #selector(filterButtonTapped),
            for: .touchUpInside
        )
        closeButton.addTarget(
            self,
            action: #selector(closeButtonTapped),
            for: .touchUpInside
        )
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        backButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        filterButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        backButton.imageEdgeInsets = UIEdgeInsets(
            top: iconSize,
            left: iconSize,
            bottom: iconSize,
            right: iconSize
        )
        filterButton.imageEdgeInsets = UIEdgeInsets(
            top: iconSize,
            left: iconSize,
            bottom: iconSize,
            right: iconSize
        )
        closeButton.imageEdgeInsets = UIEdgeInsets(
            top: iconSize,
            left: iconSize,
            bottom: iconSize,
            right: iconSize
        )
        
        NSLayoutConstraint.activate([
            // Back Button
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: iconSize),
            backButton.heightAnchor.constraint(equalToConstant: iconSize),
            
            // Title Label
            titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            
            // Filter Button
            filterButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -16),
            filterButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            filterButton.widthAnchor.constraint(equalToConstant: iconSize),
            filterButton.heightAnchor.constraint(equalToConstant: iconSize),
            
            // Close Button
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: iconSize),
            closeButton.heightAnchor.constraint(equalToConstant: iconSize),
            
            // Bottom Constraint for Title Label
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: filterButton.leadingAnchor, constant: -16),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    @objc private func backButtonTapped() {
        onBackButtonTapped?()
    }
    
    @objc private func filterButtonTapped() {
        onFilterButtonTapped?()
    }
    
    @objc private func closeButtonTapped() {
        onCloseButtonTapped?()
    }
}
