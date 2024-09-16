import UIKit

class SearchFilterHeaderView: UIView {
    
    private let colorTint = UIColor(hex: "#737373")
    private let iconSize: CGFloat = 20
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = Bundle.getLocalizedString(forKey:"search_filter_title")
        label.font = UIFont.systemFont(ofSize: 24, weight: .regular)
        label.textColor = UIColor.black
        return label
    }()
    
    private let subTitleLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = UIColor.black
        return label
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: "IconClose"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    
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
        
        closeButton.tintColor = colorTint
        
        addSubview(titleLabel)
        addSubview(subTitleLabel)
        addSubview(closeButton)
        
        closeButton.addTarget(
            self,
            action: #selector(closeButtonTapped),
            for: .touchUpInside
        )
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.imageEdgeInsets = UIEdgeInsets(
            top: iconSize,
            left: iconSize,
            bottom: iconSize,
            right: iconSize
        )
        
        NSLayoutConstraint.activate([
            // Title Label
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            
            // Close Button
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: iconSize),
            closeButton.heightAnchor.constraint(equalToConstant: iconSize),
            
            // SubTitle Label
            subTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            subTitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subTitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -0),
            subTitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -0),
        ])
    }
    
    @objc private func closeButtonTapped() {
        onCloseButtonTapped?()
    }
}
