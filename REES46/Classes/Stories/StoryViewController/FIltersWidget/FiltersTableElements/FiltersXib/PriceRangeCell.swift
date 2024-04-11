import UIKit

class PriceRangeCell: UITableViewCell {
    
    @IBOutlet weak var maxValueTextField: UITextField!
    @IBOutlet weak var minValueTextField: UITextField!
    @IBOutlet weak var rangeSlider: FiltersPriceSlider!
    public var minValue: Double = 5
    public var maxValue: Double = 55
    
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
        
        let min = UserDefaults.standard.object(forKey: "pMin") ?? 0
        let max = UserDefaults.standard.object(forKey: "pMax") ?? 9999999
        
        minValueTextField.text = "от \(String(describing: min))"
        maxValueTextField.text = "до \(String(describing: max))"
        rangeSlider.minimumValue = min as! Double //as! Double//77
        rangeSlider.maximumValue = max as! Double //as! Double//88
        rangeSlider.lowerValue = 0.0
        rangeSlider.upperValue = max as! Double
        rangeSlider.addTarget(self, action: #selector(sliderValueChange(_:)), for: .valueChanged)
        
        UserDefaults.standard.set(Int(rangeSlider.lowerValue), forKey: "upMin")
        UserDefaults.standard.set(Int(rangeSlider.upperValue), forKey: "upMax")
    }
    
    @objc func sliderValueChange(_ sender: FiltersPriceSlider) {
        minValueTextField.text = "от \(Int(rangeSlider.lowerValue))"
        maxValueTextField.text = "до \(Int(rangeSlider.upperValue))"
        
        UserDefaults.standard.set(Int(rangeSlider.lowerValue), forKey: "upMin")
        UserDefaults.standard.set(Int(rangeSlider.upperValue), forKey: "upMax")
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
            if let text1 = textField.text, let textRange = Range(range, in: text1) {
                //let str0 = text.decimalDigits
                //let strDec = text.unicodeScalars.filter(CharacterSet.decimalDigits.contains)
                //print(strDec)
                
                let stringArray1 = text1.components(separatedBy: CharacterSet.decimalDigits.inverted)
                for item1 in stringArray1 {
                    if let number1 = Int(item1) {
                        print(number1)
                        UserDefaults.standard.set(number1, forKey: "upMin")
                    }
                }
            }
            return true
        } else {
            if let text2 = textField.text, let textRange = Range(range, in: text2) {
                //let str0 = text.decimalDigits
                //let strDec = text.unicodeScalars.filter(CharacterSet.decimalDigits.contains)
                //;print(strDec)
                
                let stringArray2 = text2.components(separatedBy: CharacterSet.decimalDigits.inverted)
                for item2 in stringArray2 {
                    if let number2 = Int(item2) {
                        print(number2)
                        UserDefaults.standard.set(number2, forKey: "upMax")
                    }
                }
            }
            return true
        }
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if (textField == minValueTextField) {
            let min = UserDefaults.standard.object(forKey: "upMin") ?? ""
            if String(describing: min) != "" {
                minValueTextField.text = "\(String(describing: min))"
            } else {
                minValueTextField.text = "\(Int(rangeSlider.lowerValue))"
            }
        } else {
            let max = UserDefaults.standard.object(forKey: "upMax") ?? ""
            if String(describing: max) != "" {
                maxValueTextField.text = "\(String(describing: max))"
            } else {
                maxValueTextField.text = "\(Int(rangeSlider.upperValue))"
            }
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        let min = UserDefaults.standard.object(forKey: "pMin") ?? ""
        minValueTextField.text = "от \(String(describing: min))"
        
        let max = UserDefaults.standard.object(forKey: "pMax") ?? ""
        maxValueTextField.text = "до \(String(describing: max))"
        
        let minx = UserDefaults.standard.object(forKey: "upMin") ?? ""
        let maxx = UserDefaults.standard.object(forKey: "upMax") ?? ""
        
        if (textField == minValueTextField) {
            if String(describing: minx) != "" {
                var n1 = Int(0)
                var n2 = Int(0)
                let stringArray1 = String(describing: minx).components(separatedBy: CharacterSet.decimalDigits.inverted)
                for item1 in stringArray1 {
                    if let number1 = Int(item1) {
                        print(number1)
                        n1 = number1
                    }
                    
                    let stringArray2 = String(describing: maxx).components(separatedBy: CharacterSet.decimalDigits.inverted)
                    for item2 in stringArray2 {
                        if let number2 = Int(item2) {
                            print(number2)
                            n2 = number2
                        }
                    }
                    
                    if (n1 > n2) {
                        rangeSlider.lowerValue = Double(n2)
                        minValueTextField.text = "от \(String(describing: n2))"
                    } else {
                        rangeSlider.lowerValue = Double(n1)
                        minValueTextField.text = "от \(String(describing: n1))"
                    }
                }
            } else {
                rangeSlider.lowerValue = Double(minValueTextField.text ?? "0") ?? 0
                minValueTextField.text = "от \(Int(rangeSlider.lowerValue))"
            }
        } else {
            if String(describing: maxx) != "" {
                var n1 = Int(0)
                var n2 = Int(0)
                let stringArray1 = String(describing: minx).components(separatedBy: CharacterSet.decimalDigits.inverted)
                for item1 in stringArray1 {
                    if let number1 = Int(item1) {
                        print(number1)
                        n1 = number1
                    }
                    
                    let stringArray2 = String(describing: maxx).components(separatedBy: CharacterSet.decimalDigits.inverted)
                    for item2 in stringArray2 {
                        if let number2 = Int(item2) {
                            print(number2)
                            n2 = number2
                        }
                    }
                    
                    if (n2 < n1) {
                        rangeSlider.upperValue = Double(n1)
                        maxValueTextField.text = "до \(String(describing: n1))"
                    } else {
                        rangeSlider.upperValue = Double(n2)
                        maxValueTextField.text = "до \(String(describing: n2))"
                    }
                }
            } else {
                rangeSlider.upperValue = Double(maxValueTextField.text ?? "99999999") ?? 99999999
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
        var buttonTitle = "Done"
        var cancelButtonTitle = "Cancel"
        let doneButton = UIBarButtonItem(title: buttonTitle, style: .done, target: self, action: #selector(onClickDoneButton))
        let cancelButton = UIBarButtonItem(title: cancelButtonTitle, style: .plain, target: self, action: #selector(onClickCancelButton))
        doneButton.tintColor = .darkGray
        cancelButton.tintColor = .darkGray
        toolBar.setItems([cancelButton, space, doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        toolBar.sizeToFit()
        return toolBar
    }

    @objc
    func onClickDoneButton() {
        // let y = maxValueTextField.text
        self.endEditing(true)
    }

    @objc
    func onClickCancelButton() {
        self.endEditing(true)
    }
}

extension String {
    var decimalDigits: String {
        return String(unicodeScalars.filter(CharacterSet.decimalDigits.contains))
    }
}
