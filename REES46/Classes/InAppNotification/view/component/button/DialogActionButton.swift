class DialogActionButton: UIButton {
    
    init(title: String, backgroundColor: UIColor) {
        super.init(frame: .zero)
        setupUI(title: title, backgroundColor: backgroundColor)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupUI(title: String, backgroundColor: UIColor) {
        setTitle(title, for: .normal)
        self.backgroundColor = backgroundColor
        setTitleColor(.white, for: .normal)
        layer.cornerRadius = AppDimensions.Padding.small
        translatesAutoresizingMaskIntoConstraints = false
    }
}
