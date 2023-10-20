import UIKit

final class FlatActivityIndicatorAnimator {
    enum Animation: String {
        var f_key: String {
            return rawValue
        }

        case f_spring = "factivity.flatindicator.spring"
        case f_rotation = "factivity.flatindicator.rotation"
    }

    public func addFlatAnimation(to f_layer: CALayer) {
        f_layer.add(rotationAnimation(), forKey: Animation.f_rotation.f_key)
        f_layer.add(springAnimation(), forKey: Animation.f_spring.f_key)
    }

    public func removeFlatAnimation(from f_layer: CALayer) {
        f_layer.removeAnimation(forKey: Animation.f_rotation.f_key)
        f_layer.removeAnimation(forKey: Animation.f_spring.f_key)
    }
}


extension FlatActivityIndicatorAnimator {
    private func rotationAnimation() -> CABasicAnimation {
        let animation = CABasicAnimation(key: .rotationZ)
        animation.duration = 4
        animation.fromValue = 0
        animation.toValue = (2.0 * .pi)
        animation.repeatCount = .infinity

        return animation
    }

    private func springAnimation() -> CAAnimationGroup {
        let animation = CAAnimationGroup()
        animation.duration = 1.5
        animation.animations = [
            flatStartAnimation(),
            flatEndAnimation(),
            flatCatchAnimation(),
            flatFreezeAnimation()
        ]
        animation.repeatCount = .infinity

        return animation
    }

    private func flatStartAnimation() -> CABasicAnimation {
        let animation = CABasicAnimation(key: .flatStart)
        animation.duration = 1
        animation.fromValue = 0
        animation.toValue = 0.15
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        return animation
    }

    private func flatEndAnimation() -> CABasicAnimation {
        let animation = CABasicAnimation(key: .flatEnd)
        animation.duration = 1
        animation.fromValue = 0
        animation.toValue = 1
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        return animation
    }

    private func flatCatchAnimation() -> CABasicAnimation {
        let animation = CABasicAnimation(key: .flatStart)
        animation.beginTime = 1
        animation.duration = 0.8
        animation.fromValue = 0.15
        animation.toValue = 1
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        return animation
    }

    private func flatFreezeAnimation() -> CABasicAnimation {
        let animation = CABasicAnimation(key: .flatEnd)
        animation.beginTime = 1
        animation.duration = 0.9
        animation.fromValue = 1
        animation.toValue = 1
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        return animation
    }
}
