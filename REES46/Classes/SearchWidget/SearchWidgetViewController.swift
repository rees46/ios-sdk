import UIKit

open class SearchWidgetViewController: UIViewController, UITextFieldDelegate {
    open var delegate: SearchWidgetDelegate? {
        didSet {
            self.sdkSearchWidgetView.delegate = delegate
        }
    }
    
    @IBOutlet private weak var headerView: UIView!
    
    let width = UIScreen.main.bounds.width
    let height = UIScreen.main.bounds.height + 700
    
    open var sdkSearchWidgetTextFieldView: SearchWidgetTextFieldView!
    
    open var sdkSearchWidgetView: SearchWidgetView!
    
    open var sWidget = SearchWidget()
    
    public var textFieldMinimizedSuccesfully:Bool = false

    override open func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        var safeAreaTopInset: CGFloat = 0
        safeAreaTopInset = view.safeAreaInsets.top
        
        if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PLUS {
            self.sdkSearchWidgetTextFieldView.frame = CGRect(x: 20, y: safeAreaTopInset + 27, width: width - 85, height: 50)
            self.sdkSearchWidgetView.frame = CGRect(x: 0, y: safeAreaTopInset + 77, width: width, height: height - 85 - safeAreaTopInset)
        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO {
            self.sdkSearchWidgetTextFieldView.frame = CGRect(x: 20, y: safeAreaTopInset + 7, width: width - 85, height: 50)
            self.sdkSearchWidgetView.frame = CGRect(x: 0, y: safeAreaTopInset + 57, width: width, height: height - 61 - safeAreaTopInset)
        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_XS_MAX {
            self.sdkSearchWidgetTextFieldView.frame = CGRect(x: 20, y: safeAreaTopInset + 27, width: width - 85, height: 50)
            self.sdkSearchWidgetView.frame = CGRect(x: 0, y: safeAreaTopInset + 77, width: width, height: height - 85 - safeAreaTopInset)
        } else if SdkGlobalHelper.DeviceType.IS_IPHONE_14_PRO_MAX {
            self.sdkSearchWidgetTextFieldView.frame = CGRect(x: 20, y: safeAreaTopInset + 15, width: width - 85, height: 50)
            self.sdkSearchWidgetView.frame = CGRect(x: 0, y: safeAreaTopInset + 65, width: width, height: height - 85 - safeAreaTopInset)
        } else {
            self.sdkSearchWidgetTextFieldView.frame = CGRect(x: 20, y: safeAreaTopInset + 21, width: width - 85, height: 50)
            self.sdkSearchWidgetView.frame = CGRect(x: 0, y: safeAreaTopInset + 71, width: width, height: height - 70 - safeAreaTopInset)
        }
    }

    open func sdkSearchWidgetInit() {
        self.sdkSearchWidgetTextFieldView = SearchWidgetTextFieldView(frame: CGRect(x: 20, y: 20, width: width - 85, height: 50))
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.delegate = self
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.addTarget(self, action: #selector(sdkSearchWidgetTextFieldEnteredTextChanged(_:)), for: .editingChanged)
        self.sdkSearchWidgetTextFieldView.cancelButton.addTarget(self, action: #selector(sdkSearchWidgetTextFieldCancelButtonClicked), for: .touchUpInside)
        
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.clearButtonMode = UITextField.ViewMode.never
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.autocorrectionType = .no
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.spellCheckingType = .yes
        self.view.addSubview(self.sdkSearchWidgetTextFieldView)
        
        self.sdkSearchWidgetView = SearchWidgetView(frame: CGRect(x: 0, y: 70, width: width, height: height - 70))
        self.view.addSubview(self.sdkSearchWidgetView)
    }
    
    open func minimizeSearchTextField() {
        if !textFieldMinimizedSuccesfully {
            if SdkGlobalHelper.DeviceType.IS_IPHONE_14 || SdkGlobalHelper.DeviceType.IS_IPHONE_14_PLUS || SdkGlobalHelper.DeviceType.IS_IPHONE_XS_MAX || SdkGlobalHelper.DeviceType.IS_IPHONE_XS || SdkGlobalHelper.DeviceType.IS_IPHONE_SE || SdkGlobalHelper.DeviceType.IS_IPHONE_8_PLUS || SdkGlobalHelper.DeviceType.IS_IPHONE_5 {
                
                UIView.animate(withDuration: 0.5, animations: {
                    self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.frame.size.width -= 49
                    self.sdkSearchWidgetTextFieldView.cancelButton.frame.origin.x -= 51
                }, completion: { (isFinished) in
                    self.textFieldMinimizedSuccesfully = true
                })
            } else {
                UIView.animate(withDuration: 0.8, animations: {
                    self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.frame.size.width -= 49
                    self.sdkSearchWidgetTextFieldView.cancelButton.frame.origin.x -= 50
                }, completion: { (isFinished) in
                    self.textFieldMinimizedSuccesfully = true
                })
            }
        }
    }
    
    open func setSearchWidgetCategoriesButtonType(type: SearchWidgetCategoriesButtonType) {
        self.sdkSearchWidgetView.sdkSearchWidgetMainView.setSearchWidgetCategoriesButtonType(type: .blacked)
    }
    
    open func initData(database: [Any]) {
        self.sdkSearchWidgetView.sdkSearchWidgetListView.initData(database: database)
    }

    @objc open func sdkSearchWidgetTextFieldCancelButtonClicked() {
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.text = ""
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.endEditing(true)
        
        self.delegate?.reloadBlankSearch()
        
        if textFieldMinimizedSuccesfully {
            if SdkGlobalHelper.DeviceType.IS_IPHONE_14 || SdkGlobalHelper.DeviceType.IS_IPHONE_14_PLUS || SdkGlobalHelper.DeviceType.IS_IPHONE_XS_MAX || SdkGlobalHelper.DeviceType.IS_IPHONE_XS || SdkGlobalHelper.DeviceType.IS_IPHONE_SE || SdkGlobalHelper.DeviceType.IS_IPHONE_8_PLUS || SdkGlobalHelper.DeviceType.IS_IPHONE_5 {
                
                UIView.animate(withDuration: 0.4, animations: {
                    self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.frame.size.width += 49
                    self.sdkSearchWidgetTextFieldView.cancelButton.frame.origin.x += 51
                }, completion: { (isFinished) in
                    self.textFieldMinimizedSuccesfully = false
                })
            } else {
                UIView.animate(withDuration: 0.6, animations: {
                    self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.frame.size.width += 47
                    self.sdkSearchWidgetTextFieldView.cancelButton.frame.origin.x += 47
                }, completion: { (isFinished) in
                    self.textFieldMinimizedSuccesfully = false
                })
            }
        }
        
        UIView.animate(withDuration: 0.3, animations: {
            self.sdkSearchWidgetView.sdkSearchWidgetMainView.alpha = 1
            self.sdkSearchWidgetView.sdkSearchWidgetListView.alpha = 0
            self.sdkSearchWidgetTextFieldView.cancelButton.alpha = 1
            self.sdkSearchWidgetView.resetSearchToSimple()
        }) { (true) in
            self.sdkSearchWidgetView.sdkSearchWidgetMainView.isHidden = false
            self.sdkSearchWidgetView.sdkSearchWidgetListView.isHidden = true
            self.sdkSearchWidgetTextFieldView.cancelButton.isHidden = false
        }
    }
    
    @objc open func sdkSearchWidgetTextFieldEnteredTextChanged(_ textField: UITextField) {
        self.sdkSearchWidgetView.sdkSearchWidgetListView.sdkSearchWidgetTextFieldEnteredText = textField.text
        self.delegate?.searchWidgetCategoriesButtonClicked(productSearchText: textField.text ?? "")
    }
    
    open func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let enteredText = textField.text else {
            return true
        }
        
        if !enteredText.isEmpty {
            self.delegate?.sdkSearchWidgetHistoryButtonClickedFull(productSearchText: enteredText)
        }
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.endEditing(true)
        return true
    }
    
    open func textFieldDidBeginEditing(_ textField: UITextField) {
        UIView.animate(withDuration: 0.3, animations: {
            self.sdkSearchWidgetView.sdkSearchWidgetMainView.alpha = 1
            self.sdkSearchWidgetView.sdkSearchWidgetListView.alpha = 0
            self.sdkSearchWidgetTextFieldView.cancelButton.alpha = 1
        }){ (true) in
            self.sdkSearchWidgetView.sdkSearchWidgetMainView.isHidden = false
            self.sdkSearchWidgetView.sdkSearchWidgetListView.isHidden = false
            self.sdkSearchWidgetTextFieldView.cancelButton.isHidden = false
        }
    }
}
