import UIKit

open class SearchWidgetTextField: UITextField {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.initView()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open func initView() {
        self.leftViewMode = .always
        
        let searchUIViewWrapper = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 15))
        
//        var frameworkBundle = Bundle(for: classForCoder)
//#if SWIFT_PACKAGE
//        frameworkBundle = Bundle.module
//#endif
//        
//        let searchImageView = UIImageView(frame: CGRect(x: 10, y: 0, width: 15, height: 15))
//        let search = UIImage(named: "iconSearch", in: frameworkBundle, compatibleWith: nil)
//        searchImageView.image = search
//        searchUIViewWrapper.addSubview(searchImageView)
        
        self.leftView = searchUIViewWrapper
        self.returnKeyType = .search
        self.attributedPlaceholder = NSAttributedString(string: "Search",
                                                        attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        
        self.tintColor = UIColor.darkGray
        self.textColor = UIColor.black
        self.font = UIFont.systemFont(ofSize: 16)
        
        
        if #available(iOS 13.0, *) {
            let searchUIViewWrapper2 = UIView(frame: CGRect(x: 50, y: 0, width: 20, height: 15))
            
            _ = UIImage(systemName: "text.viewfinder")
            self.rightView = searchUIViewWrapper2
            self.attributedPlaceholder = NSAttributedString(string: "Search",
                                                            attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
            
            
          //  self.rightView.sea = true
        } else {
            
        }
    }
    
    deinit {
        print("SDK: deinit UITextField \(self.placeholder ?? "") \(self.text ?? "")")
    }
}

open class SearchWidgetTextFieldView: UIView {
    open var sdkSearchWidgetTextField: SearchWidgetTextField!
    open var cancelButton: UIButton!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.initView()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open func initView() {
        self.sdkSearchWidgetTextField = SearchWidgetTextField(frame: CGRect(x: -6, y: 0, width: self.frame.width + 10, height: self.frame.height))
        
        self.sdkSearchWidgetTextField.layer.cornerRadius = 10
        self.sdkSearchWidgetTextField.layer.borderWidth = 2.3
        self.sdkSearchWidgetTextField.layer.borderColor = UIColor(red:183/255, green:183/255, blue:183/255, alpha: 1.0).cgColor
        self.sdkSearchWidgetTextField.layer.masksToBounds = true
        self.addSubview(self.sdkSearchWidgetTextField)
        
        self.cancelButton = UIButton(frame: CGRect(x: self.frame.width - 35, y: 12, width: 26, height: 26))
        
        var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        frameworkBundle = Bundle.module
#endif
        
        let close = UIImage(named: "iconSearchClose", in: frameworkBundle, compatibleWith: nil)
        self.cancelButton.setImage(close, for: .normal)
        
        self.cancelButton.isHidden = true
        self.addSubview(self.cancelButton)
    }
}
