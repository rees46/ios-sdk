import UIKit

open class SearchWidgetViewController: UIViewController, UITextFieldDelegate {
    open var delegate: SearchWidgetDelegate? {
        didSet {
            self.sdkSearchWidgetView.delegate = delegate
        }
    }
    
    let width = UIScreen.main.bounds.width
    let height = UIScreen.main.bounds.height
    
    open var sdkSearchWidgetTextFieldView: SearchWidgetTextFieldView!
    open var sdkSearchWidgetView: SearchWidgetView!
    
    open var sWidget = SearchWidget()

    override open func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        var safeAreaTopInset: CGFloat = 0
        safeAreaTopInset = view.safeAreaInsets.top
        
        self.sdkSearchWidgetTextFieldView.frame = CGRect(x: 20, y: safeAreaTopInset + 20, width: width - 40, height: 50)
        self.sdkSearchWidgetView.frame = CGRect(x: 0, y: 70 + safeAreaTopInset, width: width, height: height - 70 - safeAreaTopInset)
    }

    open func sdkSearchWidgetInit() {
        self.sdkSearchWidgetTextFieldView = SearchWidgetTextFieldView(frame: CGRect(x: 20, y: 20, width: width - 40, height: 50))
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.delegate = self
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.addTarget(self, action: #selector(sdkSearchWidgetTextFieldTextChanged(_:)), for: .editingChanged)
        self.sdkSearchWidgetTextFieldView.cancelButton.addTarget(self, action: #selector(sdkSearchWidgetTextFieldCancelButtonClicked), for: .touchUpInside)
        
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.clearButtonMode = UITextField.ViewMode.never
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.autocorrectionType = .no
        
        self.view.addSubview(self.sdkSearchWidgetTextFieldView)
        
        self.sdkSearchWidgetView = SearchWidgetView(frame: CGRect(x: 0, y: 70, width: width, height: height - 70))
        self.view.addSubview(self.sdkSearchWidgetView)
    }
    
    open func setSearchWidgetCategoriesButtonType(type: SearchWidgetCategoriesButtonType) {
        self.sdkSearchWidgetView.sdkSearchWidgetMainView.setSearchWidgetCategoriesButtonType(type: .blacked)
    }
    
    open func initData(database: [Any]) {
        self.sdkSearchWidgetView.sdkSearchWidgetListView.initData(database: database)
    }

    @objc
    open func sdkSearchWidgetTextFieldCancelButtonClicked() {
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.text = ""
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.endEditing(true)
        self.sdkSearchWidgetView.sdkSearchWidgetMainView.redrawSearchRecentlyTableView()
        
        UIView.animate(withDuration: 0.3, animations: {
            self.sdkSearchWidgetView.sdkSearchWidgetMainView.alpha = 1
            self.sdkSearchWidgetTextFieldView.cancelButton.alpha = 0
            self.sdkSearchWidgetView.sdkSearchWidgetListView.alpha = 0
        }) { (true) in
            self.sdkSearchWidgetView.sdkSearchWidgetMainView.isHidden = false
            self.sdkSearchWidgetView.sdkSearchWidgetListView.isHidden = true
            self.sdkSearchWidgetTextFieldView.cancelButton.isHidden = true
        }
    }
    @objc
    open func sdkSearchWidgetTextFieldTextChanged(_ textField: UITextField) {
        self.sdkSearchWidgetView.sdkSearchWidgetListView.sdkSearchWidgetTextFieldText = textField.text
    }
    
    open func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let text = textField.text else {
            return true
        }
        
        if !text.isEmpty {
            self.sWidget.appendSearchHistories(value: text)
            self.sdkSearchWidgetView.sdkSearchWidgetMainView.redrawSearchRecentlyTableView()
        }
        self.sdkSearchWidgetTextFieldView.sdkSearchWidgetTextField.endEditing(true)
        
        return true
    }
    
    open func textFieldDidBeginEditing(_ textField: UITextField) {
        UIView.animate(withDuration: 0.3, animations: {
            self.sdkSearchWidgetView.sdkSearchWidgetMainView.alpha = 1 //0
            self.sdkSearchWidgetTextFieldView.cancelButton.alpha = 1
            self.sdkSearchWidgetView.sdkSearchWidgetListView.alpha = 0 //1
        }){ (true) in
            self.sdkSearchWidgetView.sdkSearchWidgetMainView.isHidden = false //true
            self.sdkSearchWidgetView.sdkSearchWidgetListView.isHidden = false
            self.sdkSearchWidgetTextFieldView.cancelButton.isHidden = true //false
        }
    }
}
