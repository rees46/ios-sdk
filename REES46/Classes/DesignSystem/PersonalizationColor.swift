import UIKit

/// Цвета дизайн-системы.
///
/// Figma Mobile SDK UI Kit (SSwS49L1fG1psWA7xbakV6), страница Colors,
/// фреймы 57:141 (Light) и 187:362 (Dark). Снято 2026-09-09.
///
/// Читает действующую тему, поэтому хост может подменить любой цвет через
/// `PersonalizationTheme.current.colors` — и подмена дойдёт до уже созданных вью.
/// Значения по умолчанию и разбор `userInterfaceStyle` живут в
/// `PersonalizationColorSet`.
@_spi(PersonalizationUI) public enum PersonalizationColor {



    // MARK: brand

    public static var brandPrimary: UIColor { PersonalizationTheme.current.colors.brandPrimary }

    // MARK: semantic

    public static var semanticWarning: UIColor { PersonalizationTheme.current.colors.semanticWarning }
    public static var semanticDanger: UIColor { PersonalizationTheme.current.colors.semanticDanger }

    // MARK: background

    public static var backgroundPrimary: UIColor { PersonalizationTheme.current.colors.backgroundPrimary }

    public static var backgroundGeneric: UIColor { PersonalizationTheme.current.colors.backgroundGeneric }

    public static var backgroundCard: UIColor { PersonalizationTheme.current.colors.backgroundCard }

    public static var backgroundFloat: UIColor { PersonalizationTheme.current.colors.backgroundFloat }

    public static var backgroundModal: UIColor { PersonalizationTheme.current.colors.backgroundModal }

    public static var backgroundInput: UIColor { PersonalizationTheme.current.colors.backgroundInput }

    public static var backgroundTransparent: UIColor { PersonalizationTheme.current.colors.backgroundTransparent }

    public static var backgroundInputDisabled: UIColor { PersonalizationTheme.current.colors.backgroundInputDisabled }

    // MARK: button

    public static var buttonPrimary: UIColor { PersonalizationTheme.current.colors.buttonPrimary }

    public static var buttonPrimaryFocus: UIColor { PersonalizationTheme.current.colors.buttonPrimaryFocus }

    public static var buttonSecondary: UIColor { PersonalizationTheme.current.colors.buttonSecondary }

    public static var buttonSecondaryOnDark: UIColor { PersonalizationTheme.current.colors.buttonSecondaryOnDark }

    public static var buttonSecondaryFocus: UIColor { PersonalizationTheme.current.colors.buttonSecondaryFocus }

    public static var buttonPrimaryDisabled: UIColor { PersonalizationTheme.current.colors.buttonPrimaryDisabled }

    public static var buttonSecondaryDisabled: UIColor { PersonalizationTheme.current.colors.buttonSecondaryDisabled }

    public static var buttonGhost: UIColor { PersonalizationTheme.current.colors.buttonGhost }

    // MARK: line

    public static var lineBrand: UIColor { PersonalizationTheme.current.colors.lineBrand }

    public static var lineGeneric: UIColor { PersonalizationTheme.current.colors.lineGeneric }

    public static var lineGenericSubtle: UIColor { PersonalizationTheme.current.colors.lineGenericSubtle }

    public static var lineInput: UIColor { PersonalizationTheme.current.colors.lineInput }

    public static var lineInputFocus: UIColor { PersonalizationTheme.current.colors.lineInputFocus }

    // MARK: text

    public static var textPrimary: UIColor { PersonalizationTheme.current.colors.textPrimary }

    public static var textSecondary: UIColor { PersonalizationTheme.current.colors.textSecondary }

    public static var textHint: UIColor { PersonalizationTheme.current.colors.textHint }

    public static var textDarkPrimary: UIColor { PersonalizationTheme.current.colors.textDarkPrimary }

    public static var textDarkSecondary: UIColor { PersonalizationTheme.current.colors.textDarkSecondary }

    public static var textDarkHint: UIColor { PersonalizationTheme.current.colors.textDarkHint }

    public static var textLightPrimary: UIColor { PersonalizationTheme.current.colors.textLightPrimary }

    public static var textLightSecondary: UIColor { PersonalizationTheme.current.colors.textLightSecondary }

    public static var textLightHint: UIColor { PersonalizationTheme.current.colors.textLightHint }

    public static var textInvertedPrimary: UIColor { PersonalizationTheme.current.colors.textInvertedPrimary }

    public static var textInvertedSecondary: UIColor { PersonalizationTheme.current.colors.textInvertedSecondary }

    public static var textInvertedHint: UIColor { PersonalizationTheme.current.colors.textInvertedHint }

    public static var textBrand: UIColor { PersonalizationTheme.current.colors.textBrand }

    public static var textLink: UIColor { PersonalizationTheme.current.colors.textLink }

    public static var textLinkVisited: UIColor { PersonalizationTheme.current.colors.textLinkVisited }

}
