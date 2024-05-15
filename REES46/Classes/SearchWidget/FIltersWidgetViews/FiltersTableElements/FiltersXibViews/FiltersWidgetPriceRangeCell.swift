import UIKit

class FiltersWidgetPriceRangeCell: UITableViewCell {
    
    @IBOutlet weak var filtersPriceMaxValueTextField: UITextField!
    @IBOutlet weak var filtersPriceMinValueTextField: UITextField!
    @IBOutlet weak var filtertsPriceRangeSlider: FiltersPriceSlider!
    
    public var minValue: Double = 0
    public var maxValue: Double = 9999990
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        filtersPriceMinValueTextField.delegate = self
        filtersPriceMaxValueTextField.delegate = self
        filtersPriceMinValueTextField.inputAccessoryView = toolBar()
        filtersPriceMaxValueTextField.inputAccessoryView = toolBar()
        
        filtersPriceMinValueTextField.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.7).cgColor
        filtersPriceMinValueTextField.layer.borderWidth = 0.8
        filtersPriceMinValueTextField.layer.cornerRadius = 5
        filtersPriceMinValueTextField.clipsToBounds = true
        
        filtersPriceMaxValueTextField.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.7).cgColor
        filtersPriceMaxValueTextField.layer.borderWidth = 1.0
        filtersPriceMaxValueTextField.layer.cornerRadius = 5
        filtersPriceMinValueTextField.clipsToBounds = true
        
        let minV = UserDefaults.standard.object(forKey: "minimumInstalledPriceConstant") ?? 0
        let maxV = UserDefaults.standard.object(forKey: "maximumInstalledPriceConstant") ?? 9999990
        
        filtersPriceMinValueTextField.text = "от \(String(describing: minV))"
        filtersPriceMaxValueTextField.text = "до \(String(describing: maxV))"
        filtertsPriceRangeSlider.minimumValue = minV as! Double
        filtertsPriceRangeSlider.maximumValue = maxV as! Double
        filtertsPriceRangeSlider.lowerValue = 0
        filtertsPriceRangeSlider.upperValue = maxV as! Double
        filtertsPriceRangeSlider.addTarget(self, action: #selector(sliderValueChange(_:)), for: .valueChanged)
        
        UserDefaults.standard.set(Int(filtertsPriceRangeSlider.lowerValue), forKey: "minimumPriceConstant")
        UserDefaults.standard.set(Int(filtertsPriceRangeSlider.upperValue), forKey: "maximumPriceConstant")
    }
    
    @objc func sliderValueChange(_ sender: FiltersPriceSlider) {
        filtersPriceMinValueTextField.text = "от \(Int(filtertsPriceRangeSlider.lowerValue))"
        filtersPriceMaxValueTextField.text = "до \(Int(filtertsPriceRangeSlider.upperValue))"
        
        UserDefaults.standard.set(Int(filtertsPriceRangeSlider.lowerValue), forKey: "minimumPriceConstant")
        UserDefaults.standard.set(Int(filtertsPriceRangeSlider.upperValue), forKey: "maximumPriceConstant")
    }
    
    static var nib:UINib {
        return UINib(nibName: identifier, bundle: nil)
    }
    
    static var identifier: String {
        return String(describing: self)
    }
}

extension FiltersWidgetPriceRangeCell: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        if (textField == filtersPriceMinValueTextField) {
            if let textMinValue = textField.text {
                let stringArrayForMin = textMinValue.components(separatedBy: CharacterSet.decimalDigits.inverted)
                for itemMin in stringArrayForMin {
                    if let numberMin = Int(itemMin) {
                        print(numberMin)
                        UserDefaults.standard.set(numberMin, forKey: "minimumPriceConstant")
                    }
                }
            }
            return true
        } else {
            if let textMaxValue = textField.text {
                let stringArrayForMax = textMaxValue.components(separatedBy: CharacterSet.decimalDigits.inverted)
                for itemMax in stringArrayForMax {
                    if let numberMax = Int(itemMax) {
                        print(numberMax)
                        UserDefaults.standard.set(numberMax, forKey: "maximumPriceConstant")
                    }
                }
            }
            return true
        }
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if (textField == filtersPriceMinValueTextField) {
            let minV = UserDefaults.standard.object(forKey: "minimumPriceConstant") ?? ""
            if String(describing: minV) != "" {
                filtersPriceMinValueTextField.text = "\(String(describing: minV))"
            } else {
                filtersPriceMinValueTextField.text = "\(Int(filtertsPriceRangeSlider.lowerValue))"
            }
        } else {
            let maxV = UserDefaults.standard.object(forKey: "maximumPriceConstant") ?? ""
            if String(describing: maxV) != "" {
                filtersPriceMaxValueTextField.text = "\(String(describing: maxV))"
            } else {
                filtersPriceMaxValueTextField.text = "\(Int(filtertsPriceRangeSlider.upperValue))"
            }
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        let minV = UserDefaults.standard.object(forKey: "minimumInstalledPriceConstant") ?? ""
        filtersPriceMinValueTextField.text = "от \(String(describing: minV))"
        
        let maxV = UserDefaults.standard.object(forKey: "maximumInstalledPriceConstant") ?? ""
        filtersPriceMaxValueTextField.text = "до \(String(describing: maxV))"
        
        let minX = UserDefaults.standard.object(forKey: "minimumPriceConstant") ?? ""
        let maxX = UserDefaults.standard.object(forKey: "maximumPriceConstant") ?? ""
        
        if (textField == filtersPriceMinValueTextField) {
            if String(describing: minX) != "" {
                var intDefault = Int(0)
                var intCompare = Int(0)
                let stringArrayMin = String(describing: minX).components(separatedBy: CharacterSet.decimalDigits.inverted)
                for itemMin in stringArrayMin {
                    if let numberMin = Int(itemMin) {
                        print(numberMin)
                        intDefault = numberMin
                    }
                    
                    let stringArrayMax = String(describing: maxX).components(separatedBy: CharacterSet.decimalDigits.inverted)
                    for itemMax in stringArrayMax {
                        if let numberMax = Int(itemMax) {
                            print(numberMax)
                            intCompare = numberMax
                        }
                    }
                    
                    if (intDefault > intCompare) {
                        filtertsPriceRangeSlider.lowerValue = Double(intCompare)
                        filtersPriceMinValueTextField.text = "от \(String(describing: intCompare))"
                    } else {
                        filtertsPriceRangeSlider.lowerValue = Double(intDefault)
                        filtersPriceMinValueTextField.text = "от \(String(describing: intDefault))"
                    }
                }
            } else {
                filtertsPriceRangeSlider.lowerValue = Double(filtersPriceMinValueTextField.text ?? "0") ?? 0
                filtersPriceMinValueTextField.text = "от \(Int(filtertsPriceRangeSlider.lowerValue))"
            }
        } else {
            if String(describing: maxX) != "" {
                var intDefaultMax = Int(0)
                var intCompareMax = Int(0)
                let stringArrayForMin = String(describing: minX).components(separatedBy: CharacterSet.decimalDigits.inverted)
                for itemMin in stringArrayForMin {
                    if let numberMin = Int(itemMin) {
                        print(numberMin)
                        intDefaultMax = numberMin
                    }
                    
                    let stringArrayForMax = String(describing: maxX).components(separatedBy: CharacterSet.decimalDigits.inverted)
                    for itemMax in stringArrayForMax {
                        if let numberMax = Int(itemMax) {
                            print(numberMax)
                            intCompareMax = numberMax
                        }
                    }
                    
                    if (intCompareMax < intDefaultMax) {
                        filtertsPriceRangeSlider.upperValue = Double(intDefaultMax)
                        filtersPriceMaxValueTextField.text = "до \(String(describing: intDefaultMax))"
                    } else {
                        filtertsPriceRangeSlider.upperValue = Double(intCompareMax)
                        filtersPriceMaxValueTextField.text = "до \(String(describing: intCompareMax))"
                    }
                }
            } else {
                filtertsPriceRangeSlider.upperValue = Double(filtersPriceMaxValueTextField.text ?? "9999990") ?? 9999990
                filtersPriceMaxValueTextField.text = "до \(Int(filtertsPriceRangeSlider.upperValue))"
            }
        }
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }

    func toolBar() -> UIToolbar{
        let toolBar = UIToolbar()
        toolBar.barStyle = .default
        toolBar.isTranslucent = true
        toolBar.barTintColor = UIColor.init(red: 250/255, green: 250/255, blue: 250/255, alpha: 1)
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let buttonTitle = "Done"
        let cancelButtonTitle = "Cancel"
        let doneButton = UIBarButtonItem(title: buttonTitle, style: .done, target: self, action: #selector(onClickDoneButton))
        let cancelButton = UIBarButtonItem(title: cancelButtonTitle, style: .plain, target: self, action: #selector(onClickCancelButton))
        doneButton.tintColor = .darkGray
        cancelButton.tintColor = .darkGray
        toolBar.setItems([cancelButton, space, doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        toolBar.sizeToFit()
        return toolBar
    }

    @objc func onClickDoneButton() {
        self.endEditing(true)
    }

    @objc func onClickCancelButton() {
        self.endEditing(true)
    }
}

extension String {
    var decimalDigits: String {
        return String(unicodeScalars.filter(CharacterSet.decimalDigits.contains))
    }
}
