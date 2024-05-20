import UIKit

open class SearchWidgetHistoryView: UIView {
    open var sdkSearchWidgetHistoryButton: SearchWidgetHistoryButton!
    open var deleteButton: UIButton!
    open var bottomLine: UIView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.initView()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open func initView() {
        self.sdkSearchWidgetHistoryButton = SearchWidgetHistoryButton(frame: CGRect(x: 0, y: 0, width: self.frame.width - 15, height: self.frame.height))
        self.addSubview(sdkSearchWidgetHistoryButton)
        
        var frameworkBundle = Bundle(for: classForCoder)
#if SWIFT_PACKAGE
        frameworkBundle = Bundle.module
#endif
        
        self.deleteButton = UIButton(frame: CGRect(x: self.frame.width - 15, y: (self.frame.height - 15)/2, width: 15, height: 15))
        let close = UIImage(named: "iconSearchClose", in: frameworkBundle, compatibleWith: nil)

        self.deleteButton.setImage(close, for: .normal)
        self.deleteButton.isHidden = true
        self.addSubview(deleteButton)
        
//        self.bottomLine = UIView(frame: CGRect(x: 0, y: self.frame.height-1, width: self.frame.width, height: 1))
//        self.bottomLine.backgroundColor = UIColor(red: 242.0/255.0, green: 242.0/255.0, blue: 242.0/255.0, alpha: 1.0)
//        self.addSubview(bottomLine)
    }
}

open class SearchWidgetHistoryButton: UIButton {
    open var textLabel: UILabel!

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.initView()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override open var isHighlighted: Bool {
        didSet {
            switch isHighlighted {
            case true:
                self.textLabel.textColor = UIColor.darkGray.withAlphaComponent(0.3)
            case false:
                self.textLabel.textColor = UIColor.darkGray
            }
        }
    }
    
    open func initView() {
//        var frameworkBundle = Bundle(for: classForCoder)
//#if SWIFT_PACKAGE
//        frameworkBundle = Bundle.module
//#endif
//        let searchHistoryImageView = UIImageView(frame: CGRect(x: 0, y: (self.frame.height - 15)/2, width: 15, height: 15))
//        let search_history = UIImage(named: "iconSearchHistory", in: frameworkBundle, compatibleWith: nil)
//        searchHistoryImageView.image = search_history
//        self.addSubview(searchHistoryImageView)
        
        self.textLabel = UILabel(frame: CGRect(x: 2, y: 0, width: self.frame.width - 40, height: self.frame.height)) //25
        self.textLabel.font = UIFont.systemFont(ofSize: 14)
        self.textLabel.textColor = UIColor.black.withAlphaComponent(0.9)
        self.addSubview(textLabel)
        
    }

}

