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
        if let font = buttonData.textBold {
            self.titleLabel?.font = .systemFont(ofSize: 14, weight: font ? .bold : .regular)
        }
        
        self.setTitle(buttonData.title ?? "", for: .normal)
        
        if let bgColor = buttonData.background {
            let color = bgColor.hexToRGB()
            self.backgroundColor = UIColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
        } else {
            self.backgroundColor = .white
            //self.backgroundColor = UIColor(red: 33/255, green: 150/255, blue: 243/255, alpha: 1)
        }
        
        self.layer.cornerRadius = CGFloat(buttonData.cornerRadius)
        self.layer.masksToBounds = true
        
        if let titleColor = buttonData.color {
            let color = titleColor.hexToRGB()
            self.setTitleColor(UIColor(red: color.red, green: color.green, blue: color.blue, alpha: 1), for: .normal)
        } else {
            self.setTitleColor(.black, for: .normal)
            //self.setTitleColor(.white, for: .normal)
        }
    }
    
    private func setToDefault() {
        self.backgroundColor = .white
        self.setTitleColor(.black, for: .normal)
        self.setTitle("", for: .normal)
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
