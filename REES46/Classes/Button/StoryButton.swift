import UIKit

protocol CustomButtonDelegate: AnyObject {
    func openDeepLink(url: String)
    func openLinkIosExternal(url: String)
    func openLinkWebExternal(url: String)
}

class StoryButton: UIButton {
    
    var _buttonData: StoriesElement?
    weak var delegate: CustomButtonDelegate?
    
    init() {
        super.init(frame: .zero)
        setToDefault()
    }
    
    func configButton(buttonData: StoriesElement) {
        if let backendFont = buttonData.textBold {
            self.titleLabel?.font = .systemFont(ofSize: 14, weight: backendFont ? .bold : .regular)
        }
        
        if sdkConfiguration.stories.slideDefaultButtonFontNameChanged != nil {
            if sdkConfiguration.stories.slideDefaultButtonFontSizeChanged != nil {
                self.titleLabel?.font = UIFont(name: sdkConfiguration.stories.slideDefaultButtonFontNameChanged!, size:  25.0)
            } else {
                self.titleLabel?.font = UIFont(name: sdkConfiguration.stories.slideDefaultButtonFontNameChanged!, size: sdkConfiguration.stories.slideDefaultButtonFontSizeConstant)
            }
        } else {
            if let backendFont = buttonData.textBold {
                self.titleLabel?.font = .systemFont(ofSize: 14, weight: backendFont ? .bold : .regular)
            } else {
                self.titleLabel?.font = .systemFont(ofSize: 14, weight: .regular)
            }
        }
        
        self.setTitle(buttonData.title ?? "", for: .normal)
        
        if sdkConfiguration.stories.slideDefaultButtonBackgroundColorChanged != nil {
            self.backgroundColor = sdkConfiguration.stories.slideDefaultButtonBackgroundColorChanged
        } else {
            if let bgColor = buttonData.background {
                let color = bgColor.hexToRGB()
                self.backgroundColor = UIColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
            } else {
                self.backgroundColor = .white
            }
        }
        
        self.layer.cornerRadius = CGFloat(buttonData.cornerRadius)
        self.layer.masksToBounds = true
        
        if sdkConfiguration.stories.slideDefaultButtonTextColorChanged != nil {
            if let components = sdkConfiguration.stories.slideDefaultButtonTextColorChanged?.rgba {
                self.setTitleColor(UIColor(red: components.red, green: components.green, blue: components.blue, alpha: components.alpha), for: .normal)
            } else {
                self.setTitleColor(.black, for: .normal)
            }
        } else {
            if let titleColor = buttonData.color {
                let color = titleColor.hexToRGB()
                self.setTitleColor(UIColor(red: color.red, green: color.green, blue: color.blue, alpha: 1), for: .normal)
            } else {
                self.setTitleColor(.black, for: .normal)
            }
        }
    }
    
    private func setToDefault() {
        self.backgroundColor = .white
        //self.setTitleColor(.black, for: .normal)
        //self.setTitle("", for: .normal)
        self.layer.cornerRadius = layer.frame.size.height / 2
        self.layer.masksToBounds = true
    }
    
    @objc public func didTapOnButton() {
        
        if let iosLink = _buttonData?.linkIos {
            delegate?.openLinkIosExternal(url: iosLink)
            return
        }
        if let link = _buttonData?.link {
            delegate?.openDeepLink(url: link)
            return
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setToDefault()
    }
}

extension UIColor {
    var rgba: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return (red, green, blue, alpha)
    }
}
