import UIKit

/// Высоты дизайн-системы.
///
/// Figma Mobile SDK UI Kit (SSwS49L1fG1psWA7xbakV6), страница Typography.
/// Сгенерировано скриптом; правки вносить в источник, не здесь.
///
/// Каждая ступень — две наложенные тени, а `CALayer` рисует только одну.
/// Поэтому `layers` отдаёт обе, а `apply(to:)` ставит верхнюю: для точного
/// совпадения с макетом нужен отдельный подслой под вторую тень.
public struct PersonalizationShadow {

    public let offsetY: CGFloat
    /// Радиус размытия CoreAnimation: половина CSS-размытия из макета.
    public let blur: CGFloat
    public let opacity: Float
    public let color: UIColor = .black

    init(offsetY: CGFloat, cssBlur: CGFloat, opacity: Float = 0.08) {
        self.offsetY = offsetY
        self.blur = cssBlur / 2
        self.opacity = opacity
    }

    public func apply(to layer: CALayer) {
        layer.shadowColor = color.cgColor
        layer.shadowOffset = CGSize(width: 0, height: offsetY)
        layer.shadowRadius = blur
        layer.shadowOpacity = opacity
    }
}

public enum PersonalizationElevation {

    /// None — без тени.
    public static let none: [PersonalizationShadow] = []

    /// Elevation 1. Первый слой — основной, второй прижимает объект к поверхности.
    public static let e1: [PersonalizationShadow] = [PersonalizationShadow(offsetY: 2, cssBlur: 4), PersonalizationShadow(offsetY: 1, cssBlur: 2)]

    /// Elevation 2. Первый слой — основной, второй прижимает объект к поверхности.
    public static let e2: [PersonalizationShadow] = [PersonalizationShadow(offsetY: 6, cssBlur: 8), PersonalizationShadow(offsetY: 3, cssBlur: 6)]

    /// Elevation 3. Первый слой — основной, второй прижимает объект к поверхности.
    public static let e3: [PersonalizationShadow] = [PersonalizationShadow(offsetY: 10, cssBlur: 10), PersonalizationShadow(offsetY: 3, cssBlur: 6)]

    /// Elevation 4. Первый слой — основной, второй прижимает объект к поверхности.
    public static let e4: [PersonalizationShadow] = [PersonalizationShadow(offsetY: 15, cssBlur: 15), PersonalizationShadow(offsetY: 4, cssBlur: 8)]

    /// Elevation 5. Первый слой — основной, второй прижимает объект к поверхности.
    public static let e5: [PersonalizationShadow] = [PersonalizationShadow(offsetY: 23, cssBlur: 23), PersonalizationShadow(offsetY: 6, cssBlur: 13)]

}
