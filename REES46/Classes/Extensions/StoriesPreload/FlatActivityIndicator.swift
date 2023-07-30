import UIKit

@IBDesignable
public class FlatActivityIndicator: UIView {
    @IBInspectable
    public var color: UIColor = .white {
        didSet {
            f_indicator.strokeColor = color.cgColor
        }
    }

    @IBInspectable
    public var lineWidth: CGFloat = 2.0 {
        didSet {
            f_indicator.lineWidth = lineWidth
            setNeedsLayout()
        }
    }

    private let f_indicator = CAShapeLayer()
    private let f_animator = FlatActivityIndicatorAnimator()

    private var isAnimating = false

    convenience init() {
        self.init(frame: .zero)
        self.setup()
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }

    private func setup() {
        f_indicator.strokeColor = color.cgColor
        f_indicator.fillColor = nil
        f_indicator.lineWidth = lineWidth
        f_indicator.strokeStart = 0.0
        f_indicator.strokeEnd = 0.0
        layer.addSublayer(f_indicator)
    }
}

extension FlatActivityIndicator {
    override public var intrinsicContentSize: CGSize {
        return CGSize(width: 76, height: 76)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        f_indicator.frame = bounds

        let diameter = bounds.size.min - f_indicator.lineWidth
        let f_path = UIBezierPath(center: bounds.center, radius: diameter / 2)
        f_indicator.path = f_path.cgPath
    }
}

extension FlatActivityIndicator {
    public func startFlatIndicatorAnimating() {
        guard !isAnimating else { return }

        f_animator.addFlatAnimation(to: f_indicator)
        isAnimating = true
    }

    public func stopFlatIndicatorAnimating() {
        guard isAnimating else { return }

        f_animator.removeFlatAnimation(from: f_indicator)
        isAnimating = false
    }
}
