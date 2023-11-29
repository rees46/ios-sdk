import UIKit

private let SdkActivityIndicatorKey = "Rotation"

@IBDesignable open class SdkActivityIndicator: UIView {
    @IBInspectable open var lineWidth: CGFloat = 3 {
        didSet {
            self.flatLayer.lineWidth = lineWidth
        }
    }
    
    fileprivate(set) open var flatIsInAnimation = false
    
    @IBInspectable open var automaticallyStart: Bool = false {
        didSet {
            if automaticallyStart && self.superview != nil {
                self.animate(true)
            }
        }
    }
    @IBInspectable open var hideIndicatorWhenStopped: Bool = false {
        didSet {
            self.isHidden = true
        }
    }
    
    @IBInspectable open var indicatorColor: UIColor = UIColor.lightGray {
        didSet {
            self.flatLayer.strokeColor = indicatorColor.cgColor
        }
    }
    
    fileprivate var flatLayer = CAShapeLayer()
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupFlat()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupFlat()
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        self.flatLayer.frame = bounds
        self.flatLayer.path = self.circlePath().cgPath
    }
    
    override open func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        
        if newSuperview != nil {
            if self.automaticallyStart {
                self.animate(true)
            }
        } else {
            self.animate(false)
        }
    }
    
    open func startAnimating() {
        self.isHidden = false
        self.animate(true)
    }
    
    open func stopAnimating() {
        self.isHidden = true
        self.animate(false)
    }
    
    fileprivate func animate(_ animated: Bool) {
        if animated {
            self.isHidden = false
            
            if self.flatIsInAnimation == false {
                if self.flatLayer.animation(forKey: SdkActivityIndicatorKey) == nil {
                    self.createFlatAnimationLayer(self.flatLayer)
                } else {
                    self.resumeLayer(self.flatLayer)
                }
            }
            
            self.flatIsInAnimation = true
            
        } else {
            
            self.flatIsInAnimation = false
            self.pauseLayer(self.flatLayer)
            if self.hideIndicatorWhenStopped {
                self.isHidden = true
            }
        }
    }
    
    fileprivate func pauseLayer(_ layer: CALayer) {
        let pausedTime = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0
        layer.timeOffset = pausedTime
    }
    
    fileprivate func resumeLayer(_ layer: CALayer) {
        let pausedTime = layer.timeOffset
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
        let timePreloadPaused = layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        layer.beginTime = timePreloadPaused
    }
    
    fileprivate func createFlatAnimationLayer(_ layer: CALayer) {
        let flatAniation = CABasicAnimation(keyPath: "transform.rotation.z")
        flatAniation.fromValue = NSNumber(value: 0 as Float)
        flatAniation.toValue = NSNumber(value: 2 * CGFloat(Double.pi))
        flatAniation.duration = 1.5
        flatAniation.isRemovedOnCompletion = false
        flatAniation.repeatCount = Float.infinity
        layer.add(flatAniation, forKey: SdkActivityIndicatorKey)
    }
    
    fileprivate func flatCircleFrame() -> CGRect {
        let diameter = min(self.flatLayer.bounds.size.width, self.flatLayer.bounds.size.height)
        var flatCircleFrame = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        flatCircleFrame.origin.x = flatLayer.bounds.midX - flatCircleFrame.midX
        flatCircleFrame.origin.y = flatLayer.bounds.midY - flatCircleFrame.midY
        
        let inset = self.flatLayer.lineWidth / 2
        flatCircleFrame = flatCircleFrame.insetBy(dx: inset, dy: inset)
        return flatCircleFrame
    }
    
    fileprivate func circlePath() -> UIBezierPath {
        return UIBezierPath(ovalIn: self.flatCircleFrame())
    }
    
    fileprivate func setupFlat() {
        flatLayer.frame = bounds
        flatLayer.lineWidth = self.lineWidth
        flatLayer.fillColor = UIColor.clear.cgColor
        flatLayer.strokeColor = self.indicatorColor.cgColor
        flatLayer.strokeEnd = 0.9
        layer.addSublayer(flatLayer)
        backgroundColor = UIColor.clear
    }
}
