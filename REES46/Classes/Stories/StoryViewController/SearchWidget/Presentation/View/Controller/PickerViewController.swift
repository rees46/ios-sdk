import UIKit

class PickerViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    var didSelectValue: ((Int) -> Void)?
    
    private let pickerView = UIPickerView()
    private let containerView = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        setupContainerView()
        setupPickerView()
        setupActionButtons()
    }
    
    private func setupContainerView() {
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 10
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 260)
        ])
    }
    
    private func setupPickerView() {
        pickerView.delegate = self
        pickerView.dataSource = self
        pickerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(pickerView)
        
        NSLayoutConstraint.activate([
            pickerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pickerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            pickerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            pickerView.heightAnchor.constraint(equalToConstant: 216)
        ])
    }
    
    private func setupActionButtons() {
        let buttonStackView = UIStackView()
        buttonStackView.axis = .horizontal
        buttonStackView.distribution = .fillEqually
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(buttonStackView)
        
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        buttonStackView.addArrangedSubview(cancelButton)
        
        let doneButton = UIButton(type: .system)
        doneButton.setTitle("Done", for: .normal)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        buttonStackView.addArrangedSubview(doneButton)
        
        NSLayoutConstraint.activate([
            buttonStackView.topAnchor.constraint(equalTo: pickerView.bottomAnchor),
            buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            buttonStackView.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func doneTapped() {
        let selectedValue = pickerView.selectedRow(inComponent: 0) + 1
        didSelectValue?(selectedValue)
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 50 // Adjust according to your needs
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return "\(row + 1)"
    }
}
