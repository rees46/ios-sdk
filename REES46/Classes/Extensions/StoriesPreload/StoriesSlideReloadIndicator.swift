import UIKit
import QuartzCore

@IBDesignable
public final class StoriesSlideReloadIndicator: UIView {
    public var animationDuration: Double = 1
    public var rotationDuration: Double = 10
    
    @IBInspectable
    public var numSegments: Int = 12 {
        didSet {
            updateSegments()
        }
    }
    @IBInspectable
    public var strokeColor : UIColor = .white {
        didSet {
            indSegmentLayer?.strokeColor = strokeColor.cgColor
        }
    }
    @IBInspectable
    public var lineWidth : CGFloat = 8 {
        didSet {
            indSegmentLayer?.lineWidth = lineWidth
            updateSegments()
        }
    }
    
    public var hidesSlidesWhenStopped: Bool = true
    public private(set) var slideIndicatorIsAnimating = false
    private weak var indReplicatorLayer: CAReplicatorLayer!
    private weak var indSegmentLayer: CAShapeLayer!
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupIndicator()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupIndicator()
    }
    
    private func setupIndicator() {
        let indReplicatorLayer = CAReplicatorLayer()
        
        layer.addSublayer(indReplicatorLayer)
        
        let ind_dot = CAShapeLayer()
        ind_dot.lineCap = CAShapeLayerLineCap.round
        ind_dot.strokeColor = strokeColor.cgColor
        ind_dot.lineWidth = lineWidth
        ind_dot.fillColor = nil
        
        indReplicatorLayer.addSublayer(ind_dot)
        
        self.indReplicatorLayer = indReplicatorLayer
        self.indSegmentLayer = ind_dot
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        let maxSize = max(0,min(bounds.width, bounds.height))
        indReplicatorLayer.bounds = CGRect(x: 0, y: 0, width: maxSize, height: maxSize)
        indReplicatorLayer.position = CGPoint(x: bounds.width / 2, y:bounds.height / 2)
        
        updateSegments()
    }
    
    private func updateSegments() {
        guard numSegments > 0, let indSegmentLayer = indSegmentLayer else { return }
        
        let angle = 2*CGFloat.pi / CGFloat(numSegments)
        indReplicatorLayer.instanceCount = numSegments
        indReplicatorLayer.instanceTransform = CATransform3DMakeRotation(angle, 0.0, 0.0, 1.0)
        indReplicatorLayer.instanceDelay = 1.5*animationDuration/Double(numSegments)
        
        let maxRadius = max(0,min(indReplicatorLayer.bounds.width, indReplicatorLayer.bounds.height))/2
        let radius: CGFloat = maxRadius - lineWidth / 2
        
        indSegmentLayer.bounds = CGRect(x:0, y:0, width: 2*maxRadius, height: 2*maxRadius)
        indSegmentLayer.position = CGPoint(x: indReplicatorLayer.bounds.width / 2, y: indReplicatorLayer.bounds.height/2)
        
        let path = UIBezierPath(arcCenter: CGPoint(x: maxRadius, y: maxRadius), radius: radius, startAngle: -angle/2 - CGFloat.pi/2, endAngle: angle/2 - CGFloat.pi/2, clockwise: true)
        
        indSegmentLayer.path = path.cgPath
    }
    
    public func startAnimating() {
        self.isHidden = false
        slideIndicatorIsAnimating = true
        
        let rotate = CABasicAnimation(keyPath: "transform.rotation")
        rotate.byValue = CGFloat.pi*2
        rotate.duration = rotationDuration
        rotate.repeatCount = Float.infinity
        
        let shrinkStart = CABasicAnimation(keyPath: "strokeStart")
        shrinkStart.fromValue = 0.0
        shrinkStart.toValue = 0.5
        shrinkStart.duration = animationDuration
        shrinkStart.autoreverses = true
        shrinkStart.repeatCount = Float.infinity
        shrinkStart.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        
        let shrinkEnd = CABasicAnimation(keyPath: "strokeEnd")
        shrinkEnd.fromValue = 1.0
        shrinkEnd.toValue = 0.5
        shrinkEnd.duration = animationDuration
        shrinkEnd.autoreverses = true
        shrinkEnd.repeatCount = Float.infinity
        shrinkEnd.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        
        let fade = CABasicAnimation(keyPath: "lineWidth")
        fade.fromValue = lineWidth
        fade.toValue = 0.0
        fade.duration = animationDuration
        fade.autoreverses = true
        fade.repeatCount = Float.infinity
        fade.timingFunction = CAMediaTimingFunction(controlPoints: 0.55, 0.0, 0.45, 1.0)
        
        indReplicatorLayer.add(rotate, forKey: "rotate")
        indSegmentLayer.add(shrinkStart, forKey: "start")
        indSegmentLayer.add(shrinkEnd, forKey: "end")
        indSegmentLayer.add(fade, forKey: "fade")
    }
    
    public func stopAnimating() {
        slideIndicatorIsAnimating = false
        
        indReplicatorLayer.removeAnimation(forKey: "rotate")
        indSegmentLayer.removeAnimation(forKey: "start")
        indSegmentLayer.removeAnimation(forKey: "end")
        indSegmentLayer.removeAnimation(forKey: "fade")
        
        if hidesSlidesWhenStopped {
            self.isHidden = true
        }
    }
    
    public override var intrinsicContentSize: CGSize {
        return CGSize(width: SdkConfiguration.stories.storiesSlideReloadIndicatorSize, height: SdkConfiguration.stories.storiesSlideReloadIndicatorSize)
    }
}
