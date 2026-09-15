import UIKit

/// Радиусы скругления дизайн-системы.
///
/// Figma Mobile SDK UI Kit (SSwS49L1fG1psWA7xbakV6), страница Typography.
/// Читает действующую тему: хост может подменить радиусы через
/// `PersonalizationTheme.current.radius`.
///
/// `rounded` — pill: значение заведомо больше любой стороны, платформа
/// ограничит его половиной меньшей стороны сама.
@_spi(PersonalizationUI) public enum PersonalizationRadius {

    /// XS — 2pt.
    public static var xs: CGFloat { PersonalizationTheme.current.radius.xs }

    /// SM — 4pt.
    public static var sm: CGFloat { PersonalizationTheme.current.radius.sm }

    /// MD — 6pt.
    public static var md: CGFloat { PersonalizationTheme.current.radius.md }

    /// LG — 8pt.
    public static var lg: CGFloat { PersonalizationTheme.current.radius.lg }

    /// XL — 10pt.
    public static var xl: CGFloat { PersonalizationTheme.current.radius.xl }

    /// 2XL — 12pt.
    public static var xl2: CGFloat { PersonalizationTheme.current.radius.xl2 }

    /// 3XL — 14pt.
    public static var xl3: CGFloat { PersonalizationTheme.current.radius.xl3 }

    /// 4XL — 16pt.
    public static var xl4: CGFloat { PersonalizationTheme.current.radius.xl4 }

    /// 5XL — 20pt.
    public static var xl5: CGFloat { PersonalizationTheme.current.radius.xl5 }

    /// 6XL — 24pt.
    public static var xl6: CGFloat { PersonalizationTheme.current.radius.xl6 }

    /// Rounded — 999pt.
    public static var rounded: CGFloat { PersonalizationTheme.current.radius.rounded }

    /// Семантические радиусы кнопочного семейства, см. `PersonalizationRadiusScale`.
    public static var buttonLg: CGFloat { PersonalizationTheme.current.radius.buttonLg }
    public static var buttonMd: CGFloat { PersonalizationTheme.current.radius.buttonMd }
    public static var buttonSm: CGFloat { PersonalizationTheme.current.radius.buttonSm }
    public static var segmentedMd: CGFloat { PersonalizationTheme.current.radius.segmentedMd }
    public static var segmentedSm: CGFloat { PersonalizationTheme.current.radius.segmentedSm }

}
