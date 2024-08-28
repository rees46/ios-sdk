import UIKit

class CheckBoxCollectionViewCell: UICollectionViewCell {
    static let identifier = "CheckBoxCollectionViewCell"
    
    private let checkBoxContainer: UIView = {
        let view = UIView()
        view.layer.borderWidth = 2.0
        view.layer.borderColor = UIColor.lightGray.cgColor
        view.layer.cornerRadius = 4.0
        return view
    }()
    
    private let label: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .black
        return label
    }()
    
    private var isChecked: Bool = false {
        didSet {
            updateCheckBoxAppearance()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(checkBoxContainer)
        contentView.addSubview(label)
        
        setupConstraints()
        addTapGesture()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupConstraints()
        addTapGesture()
    }
    
    private func setupConstraints() {
        checkBoxContainer.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            checkBoxContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            checkBoxContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkBoxContainer.widthAnchor.constraint(equalToConstant: 24),
            checkBoxContainer.heightAnchor.constraint(equalToConstant: 24),
            
            label.leadingAnchor.constraint(equalTo: checkBoxContainer.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }
    
    private func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleCheckBox))
        contentView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func toggleCheckBox() {
        isChecked.toggle()
    }
    
    private func updateCheckBoxAppearance() {
        checkBoxContainer.backgroundColor = isChecked ? UIColor.systemBlue : UIColor.clear
        checkBoxContainer.layer.borderColor = isChecked ? UIColor.systemBlue.cgColor : UIColor.lightGray.cgColor
    }
    
    func configure(with text: String) {
        label.text = text
    }
}
