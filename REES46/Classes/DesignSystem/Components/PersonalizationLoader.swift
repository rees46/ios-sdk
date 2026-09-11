import UIKit

/// Индикатор загрузки дизайн-системы.
///
/// Источник: Figma Mobile SDK UI Kit, секция Loader (296:3717).
/// Кольцо 26 с внешним радиусом 13 и толщиной 3.5, свип-градиент от прозрачного
/// к чёрному 47%, непрерывное вращение.
///
/// Градиент снят с растрового экспорта макета: в переменных Figma значение
/// `Gradient/Loader` приходит пустым. Рисуется коническим `CAGradientLayer`
/// (доступен с iOS 12) с маской-кольцом, а не картинкой — чтобы не зависеть
/// от плотности экрана.
public final class PersonalizationLoader: UIView {

    public static let defaultSide: CGFloat = 26
    private static let referenceStroke: CGFloat = 3.5

    private let gradientLayer = CAGradientLayer()
    private let maskLayer = CAShapeLayer()
    private var isAnimating = false

    public init(side: CGFloat = PersonalizationLoader.defaultSide) {
        super.init(frame: CGRect(x: 0, y: 0, width: side, height: side))
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear

        gradientLayer.type = .conic
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.colors = [
            UIColor(white: 0, alpha: 0).cgColor,
            UIColor(white: 0, alpha: 0.47).cgColor
        ]
        gradientLayer.locations = [0, 1]

        maskLayer.fillColor = UIColor.clear.cgColor
        maskLayer.strokeColor = UIColor.black.cgColor
        maskLayer.lineCap = .round
        gradientLayer.mask = maskLayer

        layer.addSublayer(gradientLayer)
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: Self.defaultSide, height: Self.defaultSide)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        gradientLayer.frame = bounds

        // Толщина пропорциональна эталонным 26 из макета.
        let scale = min(bounds.width, bounds.height) / Self.defaultSide
        let stroke = Self.referenceStroke * scale
        maskLayer.frame = bounds
        maskLayer.lineWidth = stroke
        maskLayer.path = UIBezierPath(
            ovalIn: bounds.insetBy(dx: stroke / 2, dy: stroke / 2)
        ).cgPath
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        // Анимация слоя сбрасывается, когда вью уходит из иерархии.
        if window == nil {
            gradientLayer.removeAnimation(forKey: Self.animationKey)
        } else if isAnimating {
            addRotation()
        }
    }

    private static let animationKey = "personalization.loader.rotation"

    public func startAnimating() {
        isAnimating = true
        addRotation()
    }

    public func stopAnimating() {
        isAnimating = false
        gradientLayer.removeAnimation(forKey: Self.animationKey)
    }

    private func addRotation() {
        guard gradientLayer.animation(forKey: Self.animationKey) == nil else { return }
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = 2 * Double.pi
        rotation.duration = 0.9
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        gradientLayer.add(rotation, forKey: Self.animationKey)
    }
}
