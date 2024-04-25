import UIKit

class PriceRangeCell: UITableViewCell {
    
    @IBOutlet weak var maxValueTextField: UITextField!
    @IBOutlet weak var minValueTextField: UITextField!
    @IBOutlet weak var rangeSlider: FiltersPriceSlider!
    public var minValue: Double = 0
    public var maxValue: Double = 9999990
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        minValueTextField.delegate = self
        maxValueTextField.delegate = self
        minValueTextField.inputAccessoryView = toolBar()
        maxValueTextField.inputAccessoryView = toolBar()
        
        minValueTextField.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.7).cgColor
        minValueTextField.layer.borderWidth = 0.8
        minValueTextField.layer.cornerRadius = 5
        minValueTextField.clipsToBounds = true
        
        maxValueTextField.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.7).cgColor
        maxValueTextField.layer.borderWidth = 1.0
        maxValueTextField.layer.cornerRadius = 5
        minValueTextField.clipsToBounds = true
        
        let min = UserDefaults.standard.object(forKey: "minimumInstalledPriceConstant") ?? 0
        let max = UserDefaults.standard.object(forKey: "maximumInstalledPriceConstant") ?? 9999990
        
        minValueTextField.text = "от \(String(describing: min))"
        maxValueTextField.text = "до \(String(describing: max))"
        rangeSlider.minimumValue = min as! Double
        rangeSlider.maximumValue = max as! Double
        rangeSlider.lowerValue = 0
        rangeSlider.upperValue = max as! Double
        rangeSlider.addTarget(self, action: #selector(sliderValueChange(_:)), for: .valueChanged)
        
        UserDefaults.standard.set(Int(rangeSlider.lowerValue), forKey: "minimumPriceConstant")
        UserDefaults.standard.set(Int(rangeSlider.upperValue), forKey: "maximumPriceConstant")
    }
    
    @objc func sliderValueChange(_ sender: FiltersPriceSlider) {
        minValueTextField.text = "от \(Int(rangeSlider.lowerValue))"
        maxValueTextField.text = "до \(Int(rangeSlider.upperValue))"
        
        UserDefaults.standard.set(Int(rangeSlider.lowerValue), forKey: "minimumPriceConstant")
        UserDefaults.standard.set(Int(rangeSlider.upperValue), forKey: "maximumPriceConstant")
    }
    
    static var nib:UINib {
        return UINib(nibName: identifier, bundle: nil)
    }
    
    static var identifier: String {
        return String(describing: self)
    }
}

extension PriceRangeCell: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        if (textField == minValueTextField) {
            if let textMinValue = textField.text, let textRange = Range(range, in: textMinValue) {
                //let str0 = text.decimalDigits
                //let strDec = text.unicodeScalars.filter(CharacterSet.decimalDigits.contains)
                //print(strDec)
                
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
            if let textMaxValue = textField.text, let textRange = Range(range, in: textMaxValue) {
                //let str0 = text.decimalDigits
                //let strDec = text.unicodeScalars.filter(CharacterSet.decimalDigits.contains)
                //print(strDec)
                
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
        if (textField == minValueTextField) {
            let min = UserDefaults.standard.object(forKey: "minimumPriceConstant") ?? ""
            if String(describing: min) != "" {
                minValueTextField.text = "\(String(describing: min))"
            } else {
                minValueTextField.text = "\(Int(rangeSlider.lowerValue))"
            }
        } else {
            let max = UserDefaults.standard.object(forKey: "maximumPriceConstant") ?? ""
            if String(describing: max) != "" {
                maxValueTextField.text = "\(String(describing: max))"
            } else {
                maxValueTextField.text = "\(Int(rangeSlider.upperValue))"
            }
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        let min = UserDefaults.standard.object(forKey: "minimumInstalledPriceConstant") ?? ""
        minValueTextField.text = "от \(String(describing: min))"
        
        let max = UserDefaults.standard.object(forKey: "maximumInstalledPriceConstant") ?? ""
        maxValueTextField.text = "до \(String(describing: max))"
        
        let minX = UserDefaults.standard.object(forKey: "minimumPriceConstant") ?? ""
        let maxX = UserDefaults.standard.object(forKey: "maximumPriceConstant") ?? ""
        
        if (textField == minValueTextField) {
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
                        rangeSlider.lowerValue = Double(intCompare)
                        minValueTextField.text = "от \(String(describing: intCompare))"
                    } else {
                        rangeSlider.lowerValue = Double(intDefault)
                        minValueTextField.text = "от \(String(describing: intDefault))"
                    }
                }
            } else {
                rangeSlider.lowerValue = Double(minValueTextField.text ?? "0") ?? 0
                minValueTextField.text = "от \(Int(rangeSlider.lowerValue))"
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
                        rangeSlider.upperValue = Double(intDefaultMax)
                        maxValueTextField.text = "до \(String(describing: intDefaultMax))"
                    } else {
                        rangeSlider.upperValue = Double(intCompareMax)
                        maxValueTextField.text = "до \(String(describing: intCompareMax))"
                    }
                }
            } else {
                rangeSlider.upperValue = Double(maxValueTextField.text ?? "9999990") ?? 9999990
                maxValueTextField.text = "до \(Int(rangeSlider.upperValue))"
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
