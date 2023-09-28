import Foundation
import UIKit

public enum PromocodeBannerLocation {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

public class PromocodeBanner: UIView {

    static var SDK_OPEN: Bool = false
    static var MAX_BANNERS: Int = 999
    
    internal static var OPEN_BANNERS: Int = 0
    
    internal var location: PromocodeBannerLocation
    
    public var size: CGSize {
        didSet { self.updateFrame() }
    }
    
    public var padding: (CGFloat, CGFloat) {
        didSet { self.updateFrame() }
    }
    
    public var cornerRadius: CGFloat {
        didSet {
            self.layer.cornerRadius = cornerRadius
            self.updateFrame()
            self.updateSubviews()
        }
    }
    
    public var displayTime: Double
    
    public var animationDuration: Double
    
    public required init?(coder aDecoder: NSCoder) {
        location = .bottomRight
        size = CGSize(width: 100, height: 50)
        padding = (20, 20)
        cornerRadius = 0
        displayTime = 1
        animationDuration = 1
        super.init(coder: aDecoder)
        
        self.config()
    }
    
    public init(location: PromocodeBannerLocation) {
        self.location = location
        self.size = CGSize(width: 100, height: 50)
        self.padding = (20, 20)
        self.cornerRadius = 0
        self.displayTime = 1
        self.animationDuration = 1
        
        switch location {
        case .topLeft:
            super.init(frame: CGRect(x: padding.0, y: padding.1, width: size.width, height: size.height))
            break
        case .topRight:
            super.init(frame: CGRect(x: UIScreen.main.bounds.maxX - size.width - padding.0, y: padding.1, width: size.width, height: size.height))
            break
        case .bottomLeft:
            super.init(frame: CGRect(x: padding.0, y: UIScreen.main.bounds.height - size.height - padding.1, width: size.width, height: size.height))
            break
        case .bottomRight:
            super.init(frame: CGRect(x: UIScreen.main.bounds.maxX - size.width - padding.0, y: UIScreen.main.bounds.height - size.height - padding.1, width: size.width, height: size.height))
            break
        }
        
        self.config()
    }
    
    private func config() {
        backgroundColor = .clear
    }
    
    private func updateFrame() {
        switch location {
        case .topLeft:
            self.frame = CGRect(x: padding.0, y: padding.1, width: size.width, height: size.height)
            break
        case .topRight:
            self.frame = CGRect(x: UIScreen.main.bounds.maxX - size.width - padding.0, y: padding.1, width: size.width, height: size.height)
            break
        case .bottomLeft:
            self.frame = CGRect(x: padding.0, y: UIScreen.main.bounds.height - size.height - padding.1, width: size.width, height: size.height)
            break
        case .bottomRight:
            self.frame = CGRect(x: UIScreen.main.bounds.maxX - size.width - padding.0, y: UIScreen.main.bounds.height - size.height - padding.1, width: size.width, height: size.height)
            break
        }
    }
    
    internal func updateSubviews() {
        for view in subviews {
            view.frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
            view.layer.cornerRadius = self.cornerRadius
        }
    }
    
    public func setView(view: UIView) {
        view.frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        view.clipsToBounds = true
        addSubview(view)
    }
    
    internal func startTimer() {
        if displayTime == 0 { return }
        
        let _ = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(PromocodeBanner.decrementTimer(timer:)), userInfo: nil, repeats: true)
    }
    
    @objc private func decrementTimer(timer: Timer) {
        if displayTime > 0 {
            displayTime -= 1
        } else {
            timer.invalidate()
            dismiss()
        }
    }
    
    public func dismissWithoutAnimation() {
        self.updateSubviews()
        self.removeFromSuperview()
    }
    
    public func dismiss() {
        
        switch location {
        case .topLeft:
            UIView.animate(withDuration: self.animationDuration, animations: {
                self.frame = CGRect(x: self.padding.0, y: self.padding.1, width: 0, height: self.size.height)
                self.updateSubviews()
            }, completion: { (b) in
                self.removeFromSuperview()
            })
            break
        case .topRight:
            UIView.animate(withDuration: self.animationDuration, animations: {
                self.frame = CGRect(x: UIScreen.main.bounds.maxX - self.padding.0, y: self.padding.1, width: 0, height: self.size.height)
                self.updateSubviews()
            }, completion: { (b) in
                self.removeFromSuperview()
            })
            break
        case .bottomLeft:
            UIView.animate(withDuration: self.animationDuration, animations: {
                self.frame = CGRect(x: self.padding.0, y: UIScreen.main.bounds.height - self.size.height - self.padding.1, width: 0, height: self.size.height)
                self.updateSubviews()
            }, completion: { (b) in
                self.removeFromSuperview()
            })
            break
        case .bottomRight:
            UIView.animate(withDuration: self.animationDuration, animations: {
                self.frame = CGRect(x: UIScreen.main.bounds.width - self.padding.0, y: UIScreen.main.bounds.height - self.size.height - self.padding.1, width: 0, height: self.size.height)
                self.updateSubviews()
            }, completion: { (b) in
                self.removeFromSuperview()
            })
            break
        }
        
        PromocodeBanner.SDK_OPEN = false
        PromocodeBanner.OPEN_BANNERS -= 1
    }
}
