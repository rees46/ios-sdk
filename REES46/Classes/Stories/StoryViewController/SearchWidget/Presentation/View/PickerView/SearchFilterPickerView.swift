import UIKit

class SearchFilterPickerView: UIView, UIPickerViewDelegate, UIPickerViewDataSource {
    
    weak var delegate: SearchFilterPickerViewDelegate?
    
    private let dropdownHeight: CGFloat = 34
    private let horizontalSpacing: CGFloat = 12
    private let verticalSpacing: CGFloat = 16
    private let containerWidth: CGFloat = 120
    private var sizes: [Int] = []
    
    private var minToValue: Int = 1
    private var maxToValue: Int = 1
    
    public var labelText: String? {
        didSet {
            subTitleLabel.text = labelText
        }
    }
    
    public var listLimit: [Int] {
        didSet {
            sizes = listLimit
            pickerView.reloadAllComponents()
            updateDropdownTitles()
        }
    }
    
    private let subTitleLabel: UILabel = {
        let label = UILabel()
        label.text = Bundle.getLocalizedString(forKey: "size_key")
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = UIColor.black
        return label
    }()
    
    private lazy var fromLabel: UILabel = {
        let label = UILabel()
        label.text = Bundle.getLocalizedString(forKey: "from_key")
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var toLabel: UILabel = {
        let label = UILabel()
        label.text = Bundle.getLocalizedString(forKey: "to_key")
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var fromTextField: UITextField = {
        let textField = createTextField()
        textField.placeholder = "From"
        textField.addTarget(self, action: #selector(fromTextFieldEditingChanged), for: .editingChanged)
        return textField
    }()
    
    private lazy var toTextField: UITextField = {
        let textField = createTextField()
        textField.placeholder = "To"
        textField.addTarget(self, action: #selector(toTextFieldEditingChanged), for: .editingChanged)
        return textField
    }()
    
    private var activeTextField: UITextField?
    private let pickerView = UIPickerView()
    private let pickerViewBackgroundView = UIView()
    
    override init(frame: CGRect) {
        self.listLimit = []
        self.sizes = []
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        self.listLimit = []
        self.sizes = []
        super.init(coder: coder)
        setupView()
        updateDropdownTitles()
    }
    
    private func updateDropdownTitles() {
        let minValue = sizes.first ?? 0
        let maxValue = sizes.last ?? 0
        
        fromTextField.text = "\(minToValue)"
        toTextField.text = "\(maxToValue)"
    }
    
    private func setupView() {
        backgroundColor = .white
        
        pickerView.delegate = self
        pickerView.dataSource = self
        pickerView.backgroundColor = .white
        
        addSubview(pickerViewBackgroundView)
        addSubview(subTitleLabel)
        
        pickerViewBackgroundView.isHidden = true
        pickerViewBackgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        pickerViewBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        subTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        pickerViewBackgroundView.addSubview(pickerView)
        
        let filterContainer = UIStackView(arrangedSubviews: [fromLabel, fromTextField, toLabel, toTextField])
        filterContainer.axis = .horizontal
        filterContainer.spacing = horizontalSpacing
        filterContainer.distribution = .equalSpacing
        
        addSubview(filterContainer)
        
        setupConstraints(filterContainer: filterContainer)
        setupPickerViewConstraints()
    }
    
    private func setupConstraints(filterContainer: UIStackView) {
        filterContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            // SubTitle Label
            subTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            subTitleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            subTitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // Filter Container
            filterContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            filterContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            filterContainer.topAnchor.constraint(equalTo: subTitleLabel.bottomAnchor, constant: 16),
            filterContainer.heightAnchor.constraint(equalToConstant: dropdownHeight),
            
            fromTextField.widthAnchor.constraint(equalToConstant: containerWidth),
            toTextField.widthAnchor.constraint(equalToConstant: containerWidth),
        ])
    }
    
    private func setupPickerViewConstraints() {
        pickerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pickerViewBackgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pickerViewBackgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pickerViewBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            pickerViewBackgroundView.topAnchor.constraint(equalTo: topAnchor),
            
            pickerView.leadingAnchor.constraint(equalTo: pickerViewBackgroundView.leadingAnchor),
            pickerView.trailingAnchor.constraint(equalTo: pickerViewBackgroundView.trailingAnchor),
            pickerView.bottomAnchor.constraint(equalTo: pickerViewBackgroundView.bottomAnchor),
            pickerView.heightAnchor.constraint(equalToConstant: 300)
        ])
    }
    
    private func createTextField() -> UITextField {
        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.keyboardType = .numberPad
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }
    
    @objc private func fromTextFieldEditingChanged(_ textField: UITextField) {
        if let text = textField.text, let value = Int(text) {
            minToValue = value
            if minToValue > maxToValue {
                maxToValue = minToValue
                toTextField.text = "\(maxToValue)"
            }
            updateDropdownButton(fromTextField, with: text)
        }
        delegate?.searchFilterPickerView(self, didUpdateFromValue: minToValue, toValue: maxToValue)
    }
    
    @objc private func toTextFieldEditingChanged(_ textField: UITextField) {
        if let text = textField.text, let value = Int(text) {
            maxToValue = value
            if maxToValue < minToValue {
                minToValue = maxToValue
                fromTextField.text = "\(minToValue)"
            }
            updateDropdownButton(toTextField, with: text)
        }
        delegate?.searchFilterPickerView(self, didUpdateFromValue: minToValue, toValue: maxToValue)
    }
    
    private func updateDropdownButton(_ textField: UITextField?, with text: String) {
        textField?.text = text
        if textField == fromTextField {
            minToValue = Int(text) ?? 1
        } else {
            maxToValue = Int(text) ?? 1
        }
    }
    
    private func togglePickerView(for textField: UITextField) {
        activeTextField = textField
        
        let pickerVC = PickerViewController()
        pickerVC.modalPresentationStyle = .overCurrentContext
        pickerVC.modalTransitionStyle = .crossDissolve
        
        pickerVC.didSelectValue = { [weak self] selectedValue in
            self?.updateDropdownButton(textField, with: "\(selectedValue)")
        }
        
        if let viewController = self.parentViewController {
            viewController.present(pickerVC, animated: true, completion: nil)
        }
    }
    
    private func hidePickerView() {
        pickerViewBackgroundView.isHidden = true
        activeTextField = nil
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if activeTextField == toTextField {
            return sizes.filter { $0 >= minToValue }.count
        }
        return sizes.count
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = UILabel()
        if activeTextField == toTextField {
            label.text = "\(sizes.filter { $0 >= minToValue }[row])"
        } else {
            label.text = "\(sizes[row])"
        }
        label.textAlignment = .center
        return label
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        var selectedValue = ""
        if activeTextField == toTextField {
            selectedValue = "\(sizes.filter { $0 >= minToValue }[row])"
        } else {
            selectedValue = "\(sizes[row])"
        }
        updateDropdownButton(activeTextField, with: selectedValue)
        hidePickerView()
    }
}
