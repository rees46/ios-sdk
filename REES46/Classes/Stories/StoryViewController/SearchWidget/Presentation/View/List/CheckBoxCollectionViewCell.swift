class CheckBoxCollectionViewCell: UICollectionViewCell {
    static let identifier = "CheckBoxCollectionViewCell"
    
    private let checkBoxContainer: UIView = {
        let view = UIView()
        view.layer.borderWidth = 2.0
        view.layer.borderColor = UIColor.lightGray.cgColor
        view.layer.cornerRadius = 4.0
        return view
    }()
    
    private let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "SelectedCheckBox")
        imageView.tintColor = .systemBlue
        imageView.isHidden = true
        return imageView
    }()
    
    private let label: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .black
        return label
    }()
    
    var isChecked: Bool = false {
        didSet {
            updateCheckBoxAppearance()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(checkBoxContainer)
        contentView.addSubview(label)
        checkBoxContainer.addSubview(checkmarkImageView)
        
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
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            checkBoxContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            checkBoxContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkBoxContainer.widthAnchor.constraint(equalToConstant: 24),
            checkBoxContainer.heightAnchor.constraint(equalToConstant: 24),
            
            checkmarkImageView.centerXAnchor.constraint(equalTo: checkBoxContainer.centerXAnchor),
            checkmarkImageView.centerYAnchor.constraint(equalTo: checkBoxContainer.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 16),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 16),
            
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
        // TODO Передать обновленное состояние чекбокса обратно в контроллер
    }
    
    private func updateCheckBoxAppearance() {
        checkmarkImageView.isHidden = !isChecked
        checkBoxContainer.layer.borderColor = isChecked ? UIColor.systemBlue.cgColor : UIColor.lightGray.cgColor
    }
    
    func configure(with text: String) {
        label.text = text
    }
}
