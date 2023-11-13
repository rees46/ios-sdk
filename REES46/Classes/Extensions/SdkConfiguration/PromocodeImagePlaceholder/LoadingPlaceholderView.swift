import UIKit

open class LoadingPlaceholderView: UIView {
    
    public struct gradientConfiguration {
        
        public var width: Double = 0.2
        public var animationDuration: TimeInterval = 0.7
        public var backgroundColor: UIColor = .clear
        public var primaryColor: UIColor = .clear
        public var secondaryColor: UIColor = .clear
        
        fileprivate mutating func mainGradCnfgColor(_ color: UIColor) {
            backgroundColor = color.withBrightness(brightness: 0.98)
            primaryColor = color.withBrightness(brightness: 0.88)
            secondaryColor = color.withBrightness(brightness: 0.75)
        }
        
        init(color: UIColor) {
            mainGradCnfgColor(color)
        }
    }
    
    open var promocodeDuration: TimeInterval = 1.75
    open var promocodeGradient = gradientConfiguration(color: .white)
    
    open var gradientColor: UIColor = .clear {
        didSet {
            promocodeGradient.mainGradCnfgColor(gradientColor)
        }
    }
    
    private var viewToCover: UIView?
    private var maskLayer = CAShapeLayer()
    private var gradientLayer = CAGradientLayer()
    private var viewToConverObservation: NSKeyValueObservation?
    private var isCovering: Bool { return superview != nil }
    
    public func cover(_ viewToCover: UIView, animated: Bool = true) {
        viewToCover.layoutIfNeeded()
        setupView(viewToCover: viewToCover)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            self?.startLoading(animated: animated)
        }
    }
    
    public func uncover(animated: Bool = true) {
        guard isCovering else { return }
        fadeOut(animated: animated)
        let dispatchTime: DispatchTime = .now() + promocodeDuration
        DispatchQueue.main.asyncAfter(deadline: dispatchTime) { [weak self] in
            self?.removeGradientAndMask()
            self?.removeFromSuperview()
        }
    }
    
    deinit {
		if let observer = viewToConverObservation {
			observer.invalidate()
			removeObserver(observer, forKeyPath: "bounds")
		}
        viewToConverObservation = nil
    }
    
    private func setupView(viewToCover: UIView) {
        self.viewToCover = viewToCover
        self.frame = viewToCover.bounds
        viewToConverObservation = observe(\.bounds) { [weak self] _, _ in
            if self?.isCovering == true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.setupMaskLayerIfNeeded()
                    self?.setupGradientLayerIfNeeded()
                }
            }
        }
    }
    
    private func startLoading(animated: Bool) {
        guard !isCovering, let viewToCover = viewToCover else { return }
        
        viewToCover.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        frame = viewToCover.bounds
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: viewToCover.topAnchor),
            bottomAnchor.constraint(equalTo: viewToCover.bottomAnchor),
            leftAnchor.constraint(equalTo: viewToCover.leftAnchor),
            rightAnchor.constraint(equalTo: viewToCover.rightAnchor)
        ])
        setupMaskLayerIfNeeded()
        setupGradientLayerIfNeeded()
        setupGradientLayerAnimation()
        fadeIn(animated: animated)
    }
    
    private func setupMaskLayerIfNeeded() {
        guard let superview = superview else { return }
        maskLayer.frame = superview.bounds
        let toalBezierPath = superview
            .coverableSubviews()
            .reduce(UIBezierPath(), { totalBezierPath, coverableView in
                coverableView.addCoverablePath(to: totalBezierPath, superview: superview)
                return totalBezierPath
            })
        maskLayer.path = toalBezierPath.cgPath
        maskLayer.fillColor = UIColor.red.cgColor
        layer.addSublayer(maskLayer)
    }
    
    private func setupGradientLayerIfNeeded() {
        guard let superview = superview else { return }
        
        gradientLayer.frame = CGRect(x: 0,
                                     y: 0,
                                     width: superview.bounds.size.width,
                                     height: superview.bounds.size.height)
        superview.layer.addSublayer(gradientLayer)
        gradientLayer.startPoint = CGPoint(x: -1 - promocodeGradient.width*2, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1 + promocodeGradient.width*2, y: 0)
        
        gradientLayer.colors = [
            promocodeGradient.backgroundColor.cgColor,
            promocodeGradient.primaryColor.cgColor,
            promocodeGradient.secondaryColor.cgColor,
            promocodeGradient.primaryColor.cgColor,
            promocodeGradient.backgroundColor.cgColor
        ]

        let startLocations = [NSNumber(value: Double(gradientLayer.startPoint.x)),
                              NSNumber(value: Double(gradientLayer.startPoint.x)),
                              NSNumber(value: 0),
                              NSNumber(value: promocodeGradient.width),
                              NSNumber(value: 1 + promocodeGradient.width)]
        
        gradientLayer.locations = startLocations
        gradientLayer.cornerRadius = superview.layer.cornerRadius
        layer.addSublayer(gradientLayer)
        gradientLayer.mask = maskLayer
    }
    
    private func setupGradientLayerAnimation() {
        let gradientAnimation = CABasicAnimation(keyPath: "locations")
        gradientAnimation.fromValue = gradientLayer.locations
        gradientAnimation.toValue = [NSNumber(value: 0),
                                     NSNumber(value: 1),
                                     NSNumber(value: 1),
                                     NSNumber(value: 1 + promocodeGradient.width),
                                     NSNumber(value: 1 + promocodeGradient.width)]
        
        gradientAnimation.repeatCount = .infinity
        gradientAnimation.isRemovedOnCompletion = false
        gradientAnimation.duration = promocodeGradient.animationDuration
        gradientLayer.add(gradientAnimation, forKey: "locations")
    }
    
    private func fadeIn(animated: Bool) {
        guard
            animated
            else {
                self.alpha = 1
                return
            }
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = alpha
        opacityAnimation.toValue = 1
        opacityAnimation.duration = promocodeDuration
        gradientLayer.add(opacityAnimation, forKey: "opacityAnimationIn")
        
        UIView.animate(withDuration: promocodeDuration) {
            self.alpha = 1
        }
    }
    
    private func fadeOut(animated: Bool) {
        guard 
            animated
        else {
            self.alpha = 0
            return
        }
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = alpha
        opacityAnimation.toValue = 0
        opacityAnimation.duration = promocodeDuration
        
        gradientLayer.add(opacityAnimation, forKey: "opacityAnimationOut")
        
        UIView.animate(withDuration: promocodeDuration) {
            self.alpha = 0
        }
    }
    
    private func removeGradientAndMask() {
        gradientLayer.removeAllAnimations()
        gradientLayer.removeFromSuperlayer()
        maskLayer.removeFromSuperlayer()
    }
}
