import UIKit

class SearchFilterListView: UIView, UIPickerViewDelegate, UIPickerViewDataSource {

    private let dropdownHeight: CGFloat = 34
    private let horizontalSpacing: CGFloat = 12
    private let verticalSpacing: CGFloat = 16
    private let containerWidth: CGFloat = 120
    private let sizes = Array(1...50)
    
    private var minToValue: Int = 1 // Добавлено для отслеживания минимального значения

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

    private lazy var fromDropdownContainer: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.gray.cgColor
        button.layer.cornerRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("1", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.addTarget(self, action: #selector(fromDropdownContainerTapped), for: .touchUpInside)
        return button
    }()

    private lazy var toDropdownContainer: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.gray.cgColor
        button.layer.cornerRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("50", for: .normal)
        button.setTitleColor(.black, for: .normal)
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
        pickerView.translatesAutoresizingMaskIntoConstraints = false

        let filterContainer = UIStackView(arrangedSubviews: [fromLabel, fromDropdownContainer, toLabel, toDropdownContainer])
        filterContainer.axis = .horizontal
        filterContainer.spacing = horizontalSpacing
        filterContainer.translatesAutoresizingMaskIntoConstraints = false

        addSubview(filterContainer)

        setupConstraints(filterContainer: filterContainer)
        setupPickerViewConstraints()
    }

    private func setupConstraints(filterContainer: UIStackView) {
        NSLayoutConstraint.activate([
            // Filter Container
            filterContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            filterContainer.topAnchor.constraint(equalTo: topAnchor, constant: verticalSpacing),
            filterContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            filterContainer.heightAnchor.constraint(equalToConstant: dropdownHeight + 16), // Added padding

            // Установка ширины для кнопок
            fromDropdownContainer.widthAnchor.constraint(equalToConstant: containerWidth),
            toDropdownContainer.widthAnchor.constraint(equalToConstant: containerWidth),
        ])
    }

    private func setupPickerViewConstraints() {
        NSLayoutConstraint.activate([
            pickerViewBackgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pickerViewBackgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pickerViewBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            pickerViewBackgroundView.topAnchor.constraint(equalTo: topAnchor),

            pickerView.leadingAnchor.constraint(equalTo: pickerViewBackgroundView.leadingAnchor),
            pickerView.trailingAnchor.constraint(equalTo: pickerViewBackgroundView.trailingAnchor),
            pickerView.bottomAnchor.constraint(equalTo: pickerViewBackgroundView.bottomAnchor),
            pickerView.heightAnchor.constraint(equalToConstant: 300) // Высота для UIPickerView
        ])
    }

    @objc private func fromDropdownContainerTapped() {
        showPickerView(for: fromDropdownContainer)
    }

    @objc private func toDropdownContainerTapped() {
        // Устанавливаем минимальное значение для второго дропдауна на основе выбранного значения первого
        if let fromValue = Int(fromDropdownContainer.title(for: .normal) ?? "1") {
            minToValue = fromValue
        }
        showPickerView(for: toDropdownContainer)
    }

    private func showPickerView(for button: UIButton) {
        activeButton = button
        pickerView.reloadAllComponents()
        pickerViewBackgroundView.isHidden = false
    }

    private func hidePickerView() {
        pickerViewBackgroundView.isHidden = true
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
