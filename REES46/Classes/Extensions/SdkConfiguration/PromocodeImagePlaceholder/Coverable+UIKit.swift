import UIKit

extension UIView {
    
    private struct AssociatedObjectKey {
        static var isC = "isC"
        static var path = "coverablePath"
    }
    
    @IBInspectable
    open var isC: Bool {
        get {
            let settedValue = objc_getAssociatedObject(self, &AssociatedObjectKey.isC) as? Bool
            return settedValue ?? engh
        }
        set {
            objc_setAssociatedObject(self,
                                     &AssociatedObjectKey.isC,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    public var coverablePath: UIBezierPath? {
        get {
            let settedCoverablePath = objc_getAssociatedObject(self,
                                                               &AssociatedObjectKey.path) as? UIBezierPath
            return settedCoverablePath ?? (self as? Coverable)?.defaultCoverablePath
        }
        set {
            objc_setAssociatedObject(self,
                                     &AssociatedObjectKey.path,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private var engh: Bool {
        return bounds.width > 5 && bounds.height > 5
    }
    
    fileprivate var sub: UIBezierPath {
        return coverableSubviews()
            .reduce(UIBezierPath(), { totalBezierPath, coverableView in
                coverableView.addCoverablePath(to: totalBezierPath, superview: self)
                return totalBezierPath
            })
    }
    
}

extension UIImageView: Coverable { }
