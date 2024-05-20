import UIKit

public protocol Coverable {
    var defaultCoverablePath: UIBezierPath? { get }
}

typealias CoverableView = UIView & Coverable

extension Coverable where Self: UIView {
    func makeCoverablePath(superview: UIView? = nil) -> UIBezierPath? {
        guard let superview = superview ?? self.superview else {
            return nil
        }
        
        layoutIfNeeded()
        let offsetPoint = convert(bounds, to: superview).origin
        let relativePath = coverablePath ?? UIBezierPath()
        relativePath.translate(to: offsetPoint)
        return relativePath
    }
    
    func addCoverablePath(to totalCoverablePath: UIBezierPath, superview: UIView? = nil) {
        guard let coverablePath = makeCoverablePath(superview: superview) else {
            return
        }
        totalCoverablePath.append(coverablePath)
    }
    
    public var defaultCoverablePath: UIBezierPath? {
        return UIBezierPath(roundedRect: bounds,
                            cornerRadius: layer.cornerRadius)
    }
}

extension Array where Element: CoverableView {
    var coverablePath: UIBezierPath {
        return reduce(UIBezierPath(), { totalPath, cell in
            cell.addCoverablePath(to: totalPath)
            return totalPath
        })
    }
}

extension UIView {
    func coverableSubviews() -> [CoverableView] {
        var foundedViews = [CoverableView]()
        subviews.forEach { view in
            if let coverableView = view as? CoverableView & UIView, coverableView.isC {
                foundedViews.append(coverableView)
            } else {
                foundedViews += view.coverableSubviews()
            }
        }
        return foundedViews
    }
}
