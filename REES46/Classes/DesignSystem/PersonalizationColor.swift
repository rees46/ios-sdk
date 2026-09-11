import UIKit

/// Цвета дизайн-системы.
///
/// Figma Mobile SDK UI Kit (SSwS49L1fG1psWA7xbakV6), страница Colors,
/// фреймы 57:141 (Light) и 187:362 (Dark). Снято 2026-09-09.
///
/// Каждый цвет динамический: сам разрешается по `userInterfaceStyle`.
/// Динамические цвета требуют iOS 13, а SDK поддерживает 12 — проверка
/// версии живёт в одном месте, в `dynamic(light:dark:)`, а не в каждом
/// цвете. На iOS 12 отдаётся светлое значение.
public enum PersonalizationColor {

    private static func rgba(_ hex: UInt32, _ alpha: CGFloat) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    private static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        if #available(iOS 13.0, *) {
            return UIColor { $0.userInterfaceStyle == .dark ? dark : light }
        }
        return light
    }

    // MARK: brand

    public static let brandPrimary = dynamic(
        light: rgba(0x007DF2, 1),
        dark: rgba(0x007DF2, 1)
    )

    // MARK: semantic

    public static let semanticWarning = dynamic(
        light: rgba(0xF37A17, 1),
        dark: rgba(0xF37A17, 1)
    )

    // MARK: background

    public static let backgroundPrimary = dynamic(
        light: rgba(0x007DF2, 1),
        dark: rgba(0x007DF2, 1)
    )

    public static let backgroundGeneric = dynamic(
        light: rgba(0xFAFAFA, 1),
        dark: rgba(0x141414, 1)
    )

    public static let backgroundCard = dynamic(
        light: rgba(0xF2F2F2, 1),
        dark: rgba(0x0D0D0D, 1)
    )

    public static let backgroundInput = dynamic(
        light: rgba(0xFAFAFA, 1),
        dark: rgba(0x141414, 1)
    )

    public static let backgroundTransparent = dynamic(
        light: rgba(0xFFFFFF, 0),
        dark: rgba(0xFFFFFF, 0)
    )

    public static let backgroundInputDisabled = dynamic(
        light: rgba(0x000000, 0.05),
        dark: rgba(0xFFFFFF, 0.05)
    )

    // MARK: button

    public static let buttonPrimary = dynamic(
        light: rgba(0x007DF2, 1),
        dark: rgba(0x007DF2, 1)
    )

    public static let buttonPrimaryFocus = dynamic(
        light: rgba(0x004BC0, 1),
        dark: rgba(0x32AFFF, 1)
    )

    public static let buttonSecondary = dynamic(
        light: rgba(0x000000, 0.05),
        dark: rgba(0xFFFFFF, 0.05)
    )

    public static let buttonSecondaryFocus = dynamic(
        light: rgba(0x000000, 0.1),
        dark: rgba(0xFFFFFF, 0.1)
    )

    public static let buttonPrimaryDisabled = dynamic(
        light: rgba(0x32AFFF, 1),
        dark: rgba(0x32AFFF, 1)
    )

    public static let buttonSecondaryDisabled = dynamic(
        light: rgba(0x000000, 0.05),
        dark: rgba(0xFFFFFF, 0.05)
    )

    public static let buttonGhost = dynamic(
        light: rgba(0xFFFFFF, 0),
        dark: rgba(0xFFFFFF, 0)
    )

    // MARK: line

    public static let lineBrand = dynamic(
        light: rgba(0x007DF2, 1),
        dark: rgba(0x007DF2, 1)
    )

    public static let lineGeneric = dynamic(
        light: rgba(0x000000, 0.2),
        dark: rgba(0xFFFFFF, 0.2)
    )

    public static let lineGenericSubtle = dynamic(
        light: rgba(0x000000, 0.05),
        dark: rgba(0xFFFFFF, 0.05)
    )

    public static let lineInput = dynamic(
        light: rgba(0x000000, 0.2),
        dark: rgba(0xFFFFFF, 0.2)
    )

    public static let lineInputFocus = dynamic(
        light: rgba(0x007DF2, 1),
        dark: rgba(0x007DF2, 1)
    )

    // MARK: text

    public static let textPrimary = dynamic(
        light: rgba(0x000000, 1),
        dark: rgba(0xFFFFFF, 1)
    )

    public static let textSecondary = dynamic(
        light: rgba(0x000000, 0.7),
        dark: rgba(0xFFFFFF, 0.8)
    )

    public static let textHint = dynamic(
        light: rgba(0x000000, 0.4),
        dark: rgba(0xFFFFFF, 0.5)
    )

    public static let textDarkPrimary = dynamic(
        light: rgba(0x000000, 1),
        dark: rgba(0x000000, 1)
    )

    public static let textDarkSecondary = dynamic(
        light: rgba(0x000000, 0.7),
        dark: rgba(0x000000, 0.7)
    )

    public static let textDarkHint = dynamic(
        light: rgba(0x000000, 0.4),
        dark: rgba(0x000000, 0.4)
    )

    public static let textLightPrimary = dynamic(
        light: rgba(0xFFFFFF, 1),
        dark: rgba(0xFFFFFF, 1)
    )

    public static let textLightSecondary = dynamic(
        light: rgba(0xFFFFFF, 0.8),
        dark: rgba(0xFFFFFF, 0.8)
    )

    public static let textLightHint = dynamic(
        light: rgba(0xFFFFFF, 0.5),
        dark: rgba(0xFFFFFF, 0.5)
    )

    public static let textInvertedPrimary = dynamic(
        light: rgba(0xFFFFFF, 1),
        dark: rgba(0x000000, 1)
    )

    public static let textInvertedSecondary = dynamic(
        light: rgba(0xFFFFFF, 0.8),
        dark: rgba(0x000000, 0.7)
    )

    public static let textInvertedHint = dynamic(
        light: rgba(0xFFFFFF, 0.5),
        dark: rgba(0x000000, 0.4)
    )

    public static let textBrand = dynamic(
        light: rgba(0x007DF2, 1),
        dark: rgba(0x007DF2, 1)
    )

    public static let textLink = dynamic(
        light: rgba(0x007DF2, 1),
        dark: rgba(0x007DF2, 1)
    )

    public static let textLinkVisited = dynamic(
        light: rgba(0x4D00F2, 1),
        dark: rgba(0x4D00F2, 1)
    )

}
