import UIKit

class SearchFilterHeaderView: UIView {
    
    private let colorTint = UIColor(hex: "#737373")
    private let iconSize: CGFloat = 20
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Filters"
        label.font = UIFont.systemFont(ofSize: 24, weight: .regular)
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
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.imageEdgeInsets = UIEdgeInsets(
            top: iconSize,
            left: iconSize,
            bottom: iconSize,
            right: iconSize
        )
        
        NSLayoutConstraint.activate(
            [
                titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
                
                closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
                closeButton.widthAnchor.constraint(equalToConstant: iconSize),
                closeButton.heightAnchor.constraint(equalToConstant: iconSize),
            ]
        )
    }
    
    @objc private func closeButtonTapped() {
        onCloseButtonTapped?()
    }
}
