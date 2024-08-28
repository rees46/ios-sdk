import UIKit

class SearchFilterListView: UIView, UIPickerViewDelegate, UIPickerViewDataSource {

    private let dropdownHeight: CGFloat = 34
    private let horizontalSpacing: CGFloat = 12
    private let verticalSpacing: CGFloat = 16
    private let containerWidth: CGFloat = 120
    private let sizes = Array(1...50)
    
    private var minToValue: Int = 1

    private lazy var fromLabel: UILabel = {
        let label = UILabel()
        label.text = "From"
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var toLabel: UILabel = {
        let label = UILabel()
        label.text = "to"
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let colorLabel: UILabel = {
        let label = UILabel()
        label.text = "Color"
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = UIColor.black
        return label
    }()

    private lazy var fromDropdownContainer: UIButton = {
        let button = createDropdownButton(title: "1")
        button.addTarget(self, action: #selector(fromDropdownContainerTapped), for: .touchUpInside)
        return button
    }()

    private lazy var toDropdownContainer: UIButton = {
        let button = createDropdownButton(title: "50")
        button.addTarget(self, action: #selector(toDropdownContainerTapped), for: .touchUpInside)
        return button
    }()

    private var activeButton: UIButton?
    private let pickerView = UIPickerView()
    private let pickerViewBackgroundView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        backgroundColor = .white

        pickerView.delegate = self
        pickerView.dataSource = self
        pickerView.backgroundColor = .white

        addSubview(pickerViewBackgroundView)
        pickerViewBackgroundView.isHidden = true
        pickerViewBackgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        pickerViewBackgroundView.translatesAutoresizingMaskIntoConstraints = false

        pickerViewBackgroundView.addSubview(pickerView)

        let filterContainer = UIStackView(arrangedSubviews: [fromLabel, fromDropdownContainer, toLabel, toDropdownContainer])
        filterContainer.axis = .horizontal
        filterContainer.spacing = horizontalSpacing

        addSubview(filterContainer)
        addSubview(colorLabel)
        
        setupConstraints(filterContainer: filterContainer)
        setupPickerViewConstraints()
        setupColorLabelConstraints(filterContainer: filterContainer)
    }

    private func setupConstraints(filterContainer: UIStackView) {
        filterContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            filterContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            filterContainer.topAnchor.constraint(equalTo: topAnchor, constant: verticalSpacing),
            filterContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            filterContainer.heightAnchor.constraint(equalToConstant: dropdownHeight + 16),
            

            fromDropdownContainer.widthAnchor.constraint(equalToConstant: containerWidth),
            toDropdownContainer.widthAnchor.constraint(equalToConstant: containerWidth),
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
     
     private func setupColorLabelConstraints(filterContainer: UIStackView) {
         colorLabel.translatesAutoresizingMaskIntoConstraints = false
         NSLayoutConstraint.activate([
             colorLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
             colorLabel.topAnchor.constraint(equalTo: filterContainer.bottomAnchor, constant: verticalSpacing),
             colorLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
         ])
     }

    private func createDropdownButton(title: String) -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.gray.cgColor
        button.layer.cornerRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.contentHorizontalAlignment = .left
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
        
        let arrow = UIImageView(image: UIImage(named: "IconClosed"))
        arrow.tintColor = .black
        arrow.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(arrow)
        
        NSLayoutConstraint.activate([
            arrow.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -10),
            arrow.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        
        return button
    }

    @objc private func fromDropdownContainerTapped() {
        togglePickerView(for: fromDropdownContainer)
    }

    @objc private func toDropdownContainerTapped() {
        if let fromValue = Int(fromDropdownContainer.title(for: .normal) ?? "1") {
            minToValue = fromValue
        }
        togglePickerView(for: toDropdownContainer)
    }

    private func togglePickerView(for button: UIButton) {
        if activeButton == button && !pickerViewBackgroundView.isHidden {
            hidePickerView()
        } else {
            activeButton = button
            pickerView.reloadAllComponents()
            pickerViewBackgroundView.isHidden = false
        }
    }

    private func hidePickerView() {
        pickerViewBackgroundView.isHidden = true
        activeButton = nil
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if activeButton == toDropdownContainer {
            return sizes.filter { $0 >= minToValue }.count
        }
        return sizes.count
    }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = UILabel()
        if activeButton == toDropdownContainer {
            label.text = "\(sizes.filter { $0 >= minToValue }[row])"
        } else {
            label.text = "\(sizes[row])"
        }
        label.textAlignment = .center
        return label
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        var selectedValue = ""
        if activeButton == toDropdownContainer {
            selectedValue = "\(sizes.filter { $0 >= minToValue }[row])"
        } else {
            selectedValue = "\(sizes[row])"
        }
        updateDropdownButton(activeButton, with: selectedValue)
        hidePickerView()
    }

    private func updateDropdownButton(_ button: UIButton?, with title: String) {
        button?.setTitle(title, for: .normal)
        if button == fromDropdownContainer {
            minToValue = Int(title) ?? 1
            toDropdownContainer.setTitle("\(minToValue)", for: .normal)
        }
    }
}
