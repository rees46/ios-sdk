import UIKit

/// Высоты дизайн-системы.
///
/// Figma Mobile SDK UI Kit (SSwS49L1fG1psWA7xbakV6), стили Elevation 1–3.
///
/// Каждая ступень — две наложенные тени, а `CALayer` рисует только одну.
/// Поэтому ступень отдаёт обе, а `apply(to:)` ставит верхнюю: для точного
/// совпадения с макетом нужен отдельный подслой под вторую тень.
///
/// Цвет — токен Shadow/Heavy вместе с прозрачностью (8% в светлой, 50% в тёмной).
/// `cgColor` динамический цвет не отслеживает: после смены темы `apply(to:)`
/// надо позвать ещё раз, из `traitCollectionDidChange`.
@_spi(PersonalizationUI) public struct PersonalizationShadow {

    public let offsetY: CGFloat
    /// Радиус размытия CoreAnimation: половина CSS-размытия из макета.
    public let blur: CGFloat
    public var color: UIColor { PersonalizationColor.shadowHeavy }

    init(offsetY: CGFloat, cssBlur: CGFloat) {
        self.offsetY = offsetY
        self.blur = cssBlur / 2
    }

    public func apply(to layer: CALayer) {
        layer.shadowColor = color.cgColor
        layer.shadowOffset = CGSize(width: 0, height: offsetY)
        layer.shadowRadius = blur
        // Прозрачность уже в цвете.
        layer.shadowOpacity = 1
    }
}

@_spi(PersonalizationUI) public enum PersonalizationElevation {

    /// None — без тени.
    public static let none: [PersonalizationShadow] = []

    /// Elevation 1. Первый слой — основной, второй прижимает объект к поверхности.
    public static let e1: [PersonalizationShadow] = [PersonalizationShadow(offsetY: 2, cssBlur: 4), PersonalizationShadow(offsetY: 1, cssBlur: 2)]

    /// Elevation 2. Первый слой — основной, второй прижимает объект к поверхности.
    public static let e2: [PersonalizationShadow] = [PersonalizationShadow(offsetY: 10, cssBlur: 10), PersonalizationShadow(offsetY: 3, cssBlur: 6)]

    /// Elevation 3. Первый слой — основной, второй прижимает объект к поверхности.
    public static let e3: [PersonalizationShadow] = [PersonalizationShadow(offsetY: 23, cssBlur: 23), PersonalizationShadow(offsetY: 6, cssBlur: 13)]

}
