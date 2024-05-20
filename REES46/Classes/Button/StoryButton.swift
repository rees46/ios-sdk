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
        if SdkConfiguration.stories.slideDefaultButtonFontNameChanged != nil {
            if SdkConfiguration.stories.slideDefaultButtonFontSizeChanged != 0.0 {
                self.titleLabel?.font = SdkStyle.shared.currentColorScheme?.defaultButtonSelectFontName.withSize(SdkStyle.shared.currentColorScheme!.defaultButtonSelectFontSize)
            } else {
                self.titleLabel?.font = SdkStyle.shared.currentColorScheme?.defaultButtonSelectFontName.withSize(19.0)
            }
        } else {
            if let backendFont = buttonData.textBold {
                if SdkConfiguration.stories.slideDefaultButtonFontSizeChanged != nil {
                    self.titleLabel?.font = .systemFont(ofSize: SdkStyle.shared.currentColorScheme!.defaultButtonSelectFontSize, weight: .bold)
                } else {
                    self.titleLabel?.font = .systemFont(ofSize: 17.0, weight: backendFont ? .bold : .regular)
                }
            } else {
                if SdkConfiguration.stories.slideDefaultButtonFontSizeChanged != nil {
                    self.titleLabel?.font = .systemFont(ofSize: SdkStyle.shared.currentColorScheme!.defaultButtonSelectFontSize, weight: .regular)
                } else {
                    self.titleLabel?.font = .systemFont(ofSize: 19.0, weight: .regular)
                }
            }
        }
        
        self.setTitle(buttonData.title ?? "", for: .normal)
        
        if SdkConfiguration.stories.defaultButtonCornerRadius != -1 {
            self.layer.cornerRadius = SdkConfiguration.stories.defaultButtonCornerRadius
        } else {
            self.layer.cornerRadius = CGFloat(buttonData.cornerRadius)
        }
        self.layer.masksToBounds = true
        
        if SdkConfiguration.isDarkMode {
            if SdkConfiguration.stories.slideDefaultButtonBackgroundColorChanged_Dark != nil {
                self.backgroundColor = SdkConfiguration.stories.slideDefaultButtonBackgroundColorChanged_Dark
            } else {
                if let bgColor = buttonData.background {
                    let color = bgColor.hexToRGB()
                    self.backgroundColor = UIColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
                } else {
                    self.backgroundColor = .white
                }
            }
            
            if SdkConfiguration.stories.slideDefaultButtonTextColorChanged_Dark != nil {
                if let components = SdkConfiguration.stories.slideDefaultButtonTextColorChanged_Dark?.rgba {
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
        } else {
            if SdkConfiguration.stories.slideDefaultButtonBackgroundColorChanged_Light != nil {
                self.backgroundColor = SdkConfiguration.stories.slideDefaultButtonBackgroundColorChanged_Light
            } else {
                if let bgColor = buttonData.background {
                    let color = bgColor.hexToRGB()
                    self.backgroundColor = UIColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
                } else {
                    self.backgroundColor = .white
                }
            }
            
            if SdkConfiguration.stories.slideDefaultButtonTextColorChanged_Light != nil {
                if let components = SdkConfiguration.stories.slideDefaultButtonTextColorChanged_Light?.rgba {
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
    }
    
    private func setToDefault() {
        self.backgroundColor = .white
        if SdkConfiguration.stories.productsButtonCornerRadius != -1 {
            self.layer.cornerRadius = SdkConfiguration.stories.productsButtonCornerRadius
        } else {
            self.layer.cornerRadius = layer.frame.size.height / 2
        }
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
