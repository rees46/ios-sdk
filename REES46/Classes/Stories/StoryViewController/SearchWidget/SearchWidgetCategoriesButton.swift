import UIKit

public enum SearchWidgetCategoriesButtonType {
    case bordered
    case blacked
    case colored
}

open class SearchWidgetCategoriesButton: UIButton {
    open var type: SearchWidgetCategoriesButtonType? {
        didSet {
            guard let _type = type else {
                return
            }
            self.setType(type: _type)
        }
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.initView()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override open var isHighlighted: Bool {
        didSet {
            if let type = self.type {
                switch type {
                case .bordered:
                    switch isHighlighted {
                    case true:
                        layer.borderColor = UIColor.lightGray.cgColor
                    case false:
                        layer.borderColor = UIColor.darkGray.cgColor
                    }

                case .blacked:
                    switch isHighlighted {
                    case true:
                        layer.borderColor = UIColor.lightGray.cgColor
                    case false:
                        layer.borderColor = UIColor.white.cgColor
                    }
                    
                case .colored: break
                }
                
            } else {
                switch isHighlighted {
                case true:
                    layer.borderColor = UIColor.lightGray.cgColor
                case false:
                    layer.borderColor = UIColor.darkGray.cgColor
                }
            }
        }
    }
    open func initView() {
        self.layer.borderColor = nil
        self.layer.borderWidth = 0
        self.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        self.backgroundColor = blackSearchColorScheme()
        self.setTitleColor(UIColor.white, for: .normal)
        self.setTitleColor(UIColor.white.withAlphaComponent(0.3), for: .highlighted)
        self.layer.cornerRadius = self.frame.height * 0.15
    }
    
    open func setType(type: SearchWidgetCategoriesButtonType) {
        switch type {
        case .bordered:
            self.layer.borderColor = UIColor.darkGray.cgColor
            self.layer.borderWidth = 1
            self.setTitleColor(UIColor.darkGray, for: .normal)
            self.setTitleColor(UIColor.darkGray.withAlphaComponent(0.3), for: .highlighted)
            
        case .blacked:
            self.layer.borderColor = nil
            self.layer.borderWidth = 0
            self.backgroundColor = blackSearchColorScheme()
            self.setTitleColor(UIColor.white, for: .normal)
            self.setTitleColor(UIColor.white.withAlphaComponent(0.4), for: .highlighted)
        
        case .colored:
            self.layer.borderColor = nil
            self.layer.borderWidth = 0
            self.backgroundColor = UIColor.init(red: 246.0/255.0, green: 246.0/255.0, blue: 246.0/255.0, alpha: 1)
            self.setTitleColor(UIColor.darkGray, for: .normal)
            self.setTitleColor(UIColor.darkGray.withAlphaComponent(0.3), for: .highlighted)
        }
    }
    
    open func blackSearchColorScheme() -> UIColor {
//        let colorArray = ["ff6699", "ff3366", "ff3333"]
        let colorArray = ["000000"]
        
        let randomNumber = arc4random_uniform(UInt32(colorArray.count))
        return UIColor(hexString: colorArray[Int(randomNumber)])
    }
}
