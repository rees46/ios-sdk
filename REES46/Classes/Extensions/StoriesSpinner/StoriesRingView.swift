import UIKit

public class StoriesRingView: UIView {
    
    internal var loaderView = UIView()
    internal var loaderSuperview: UIView?
    internal var isAnimating = false
    
    public static func createStoriesLoader() -> Self {
        
        let ldr = self.init()
        ldr.setupPreloaderView()
        
        return ldr
    }
    
    internal func configureLoader() {
        preconditionFailure("StoriesRing preloader subclass")
    }
 
    open func startPreloaderAnimation() {
        
        self.configureLoader()
        isHidden = false
        if superview == nil {
            loaderSuperview?.addSubview(self)
        }
    }
    
    open func stopPreloaderAnimation() {
        
        self.isHidden = false
        self.isAnimating = false
        self.removeFromSuperview()
        self.layer.removeAllAnimations()
        
    }
    
    internal func setupPreloaderView() {
        
        guard let window = UIApplication.shared.delegate?.window else { return }
        guard let mainWindow = window else {return}
        
        self.frame = mainWindow.frame
        self.center = CGPoint(x: mainWindow.bounds.midX, y: mainWindow.bounds.midY)
        
        mainWindow.addSubview(self)
        
        self.loaderSuperview = mainWindow
        self.loaderView.frame = CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width/2, height: frame.width/2)
        self.loaderView.center = CGPoint(x: frame.width/2, y: frame.height/2)
        self.loaderView.backgroundColor = UIColor.clear
        self.isHidden = true
        self.addSubview(loaderView)
        
    }
    
}
