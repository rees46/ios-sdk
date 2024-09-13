import UIKit

class SearchFilterActionButtons: UIView {
    
    weak var delegate: SearchFilterActionButtonsDelegate?
    
    private let resetButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(
            Bundle.getLocalizedString(forKey: "button_reset_title"),
            for: .normal
        )
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = .white
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 2.0
        button.layer.borderColor = UIColor.black.cgColor
        button.layer.masksToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let showButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(
            String(format: Bundle.getLocalizedString(forKey: "button_show_title", comment: ""), ""), // Default to 0
            for: .normal
        )
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .black
        button.layer.cornerRadius = 16
        button.layer.masksToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let spacer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(resetButton)
        addSubview(spacer)
        addSubview(showButton)
        
        resetButton.addTarget(self, action: #selector(resetButtonTapped), for: .touchUpInside)
        showButton.addTarget(self, action: #selector(showButtonTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            resetButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            resetButton.topAnchor.constraint(equalTo: topAnchor),
            resetButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            resetButton.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.3),
            
            spacer.leadingAnchor.constraint(equalTo: resetButton.trailingAnchor),
            spacer.widthAnchor.constraint(equalToConstant: 12),
            spacer.topAnchor.constraint(equalTo: topAnchor),
            spacer.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            showButton.leadingAnchor.constraint(equalTo: spacer.trailingAnchor),
            showButton.topAnchor.constraint(equalTo: topAnchor),
            showButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            showButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            showButton.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.7, constant: -38)
        ])
    }
    
    func updateShowButtonTitle(with count: Int) {
        self.showButton.setTitle(
            String(format: Bundle.getLocalizedString(forKey: "button_show_title", comment: ""), "\(count)"),
            for: .normal
        )
    }
    
    @objc private func resetButtonTapped() {
        delegate?.didTapResetButton()
    }
    
    @objc private func showButtonTapped() {
        delegate?.didTapShowButton()
    }
}
