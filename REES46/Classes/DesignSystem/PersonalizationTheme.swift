import UIKit

// Весь UI-кит (тема, токены, компоненты) помечен `@_spi(PersonalizationUI)`: он ещё собирается
// и ничем в SDK не используется, поэтому до релиза остаётся вне публичной поверхности модуля.
// Обычный `import REES46` его не видит; демо-приложение подключает кит напрямую:
//
//     @_spi(PersonalizationUI) import REES46
//
// Перед релизом атрибут снимается, и кит становится обычным публичным API.

/// Тема дизайн-системы: то, что хост может подменить под свой бренд.
///
/// Задаётся один раз на старте:
///
/// ```swift
/// PersonalizationTheme.current.colors.brandPrimary = .systemPurple
/// PersonalizationTheme.current.font = { size, weight in
///     UIFont(name: weight == .semibold ? "Inter-SemiBold" : "Inter-Regular", size: size)
///         ?? .systemFont(ofSize: size, weight: weight)
/// }
/// ```
///
/// Компоненты читают тему через `PersonalizationColor` и `PersonalizationRadius`,
/// поэтому подмена доходит и до уже созданных вью при следующей перерисовке.
///
/// Темизуются цвета, радиусы и шрифт — поверхность брендирования. Отступы, тени
/// и кегли остаются константами: это шкала макета, менять её не предполагается.
///
/// В отличие от Android, Flutter и React Native тема здесь только глобальная:
/// в UIKit нет дерева контекста, через которое её можно передать на поддерево.
/// Если разным магазинам понадобится разный брендинг в одном приложении,
/// тему придётся протаскивать в компоненты явным свойством.
@_spi(PersonalizationUI) public struct PersonalizationTheme {

    public var colors: PersonalizationColorSet
    public var radius: PersonalizationRadiusScale

    /// Шрифт по кеглю и начертанию. Inter в SDK не поставляется, по умолчанию системный.
    public var font: (CGFloat, UIFont.Weight) -> UIFont

    public init(
        colors: PersonalizationColorSet = PersonalizationColorSet(),
        radius: PersonalizationRadiusScale = PersonalizationRadiusScale(),
        font: @escaping (CGFloat, UIFont.Weight) -> UIFont = { size, weight in
            UIFont.systemFont(ofSize: size, weight: weight)
        }
    ) {
        self.colors = colors
        self.radius = radius
        self.font = font
    }

    /// Действующая тема. По умолчанию — значения из макета.
    public static var current = PersonalizationTheme()
}

/// Цвета темы. Значения по умолчанию — коллекция переменных Color, режимы Light и Dark
/// (сверено 2026-09-23).
@_spi(PersonalizationUI) public struct PersonalizationColorSet {

    public var brandPrimary: UIColor
    /// Neutral 50: полупрозрачная ступень, одинаково заметна на любом фоне — заглушки картинок.
    public var neutral50: UIColor
    public var semanticWarning: UIColor
    public var semanticDanger: UIColor
    public var backgroundGeneric: UIColor
    public var backgroundCard: UIColor
    public var backgroundFloat: UIColor
    public var backgroundModal: UIColor
    public var backgroundInput: UIColor
    public var backgroundTransparent: UIColor
    public var backgroundInputDisabled: UIColor
    public var buttonPrimary: UIColor
    public var buttonPrimaryFocus: UIColor
    public var buttonSecondary: UIColor
    public var buttonSecondaryOnDark: UIColor
    public var buttonSecondaryFocus: UIColor
    public var buttonPrimaryDisabled: UIColor
    public var buttonSecondaryDisabled: UIColor
    public var buttonGhost: UIColor
    public var lineBrand: UIColor
    public var lineGeneric: UIColor
    public var lineGenericSubtle: UIColor
    public var lineInput: UIColor
    public var lineInputFocus: UIColor
    public var textPrimary: UIColor
    public var textSecondary: UIColor
    public var textHint: UIColor
    public var textDarkPrimary: UIColor
    public var textDarkSecondary: UIColor
    public var textDarkHint: UIColor
    public var textLightPrimary: UIColor
    public var textLightSecondary: UIColor
    public var textLightHint: UIColor
    public var textInvertedPrimary: UIColor
    public var textInvertedSecondary: UIColor
    public var textInvertedHint: UIColor
    public var textBrand: UIColor
    public var textLink: UIColor
    public var textLinkVisited: UIColor
    /// Shadow/Heavy: цвет тени вместе с её прозрачностью — 8% в светлой, 50% в тёмной.
    public var shadowHeavy: UIColor

    public init(
        brandPrimary: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x007DF2, 1),
            dark: PersonalizationColorSet.rgba(0x007DF2, 1)
        ),
        neutral50: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x000000, 0.05),
            dark: PersonalizationColorSet.rgba(0xFFFFFF, 0.05)
        ),
        semanticWarning: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0xF37A17, 1),
            dark: PersonalizationColorSet.rgba(0xF37A17, 1)
        ),
        semanticDanger: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0xE51919, 1),
            dark: PersonalizationColorSet.rgba(0xE51919, 1)
        ),
        backgroundGeneric: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0xF2F2F2, 1),
            dark: PersonalizationColorSet.rgba(0x0D0D0D, 1)
        ),
        backgroundCard: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0xFFFFFF, 1),
            dark: PersonalizationColorSet.rgba(0x1A1A1A, 1)
        ),
        // Поверхности поверх карточки. В светлой все белые, различаются только в тёмной.
        backgroundFloat: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0xFFFFFF, 1),
            dark: PersonalizationColorSet.rgba(0x262626, 1)
        ),
        backgroundModal: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0xFFFFFF, 1),
            dark: PersonalizationColorSet.rgba(0x333333, 1)
        ),
        backgroundInput: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0xF2F2F2, 1),
            dark: PersonalizationColorSet.rgba(0x0D0D0D, 1)
        ),
        backgroundTransparent: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0xFFFFFF, 0),
            dark: PersonalizationColorSet.rgba(0xFFFFFF, 0)
        ),
        backgroundInputDisabled: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x000000, 0.05),
            dark: PersonalizationColorSet.rgba(0xFFFFFF, 0.05)
        ),
        buttonPrimary: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x007DF2, 1),
            dark: PersonalizationColorSet.rgba(0x007DF2, 1)
        ),
        buttonPrimaryFocus: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x004BC0, 1),
            dark: PersonalizationColorSet.rgba(0x32AFFF, 1)
        ),
        buttonSecondary: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x000000, 0.05),
            dark: PersonalizationColorSet.rgba(0xFFFFFF, 0.05)
        ),
        // Secondary поверх тёмного (картинки-фона): белая 5%, как в тёмном режиме файла.
        buttonSecondaryOnDark: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0xFFFFFF, 0.05),
            dark: PersonalizationColorSet.rgba(0xFFFFFF, 0.05)
        ),
        buttonSecondaryFocus: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x000000, 0.1),
            dark: PersonalizationColorSet.rgba(0xFFFFFF, 0.1)
        ),
        // Brand/Primary с прозрачностью 65%.
        buttonPrimaryDisabled: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x007DF2, 0.65),
            dark: PersonalizationColorSet.rgba(0x007DF2, 0.65)
        ),
        buttonSecondaryDisabled: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x000000, 0.05),
            dark: PersonalizationColorSet.rgba(0xFFFFFF, 0.05)
        ),
        buttonGhost: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0xFFFFFF, 0),
            dark: PersonalizationColorSet.rgba(0xFFFFFF, 0)
        ),
        lineBrand: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x007DF2, 1),
            dark: PersonalizationColorSet.rgba(0x007DF2, 1)
        ),
        lineGeneric: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x000000, 0.2),
            dark: PersonalizationColorSet.rgba(0xFFFFFF, 0.2)
        ),
        lineGenericSubtle: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x000000, 0.05),
            dark: PersonalizationColorSet.rgba(0xFFFFFF, 0.05)
        ),
        lineInput: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x000000, 0.2),
            dark: PersonalizationColorSet.rgba(0xFFFFFF, 0.2)
        ),
        lineInputFocus: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x007DF2, 1),
            dark: PersonalizationColorSet.rgba(0x007DF2, 1)
        ),
        textPrimary: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x000000, 1),
            dark: PersonalizationColorSet.rgba(0xFFFFFF, 1)
        ),
        textSecondary: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x000000, 0.7),
            dark: PersonalizationColorSet.rgba(0xFFFFFF, 0.8)
        ),
        textHint: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x000000, 0.4),
            dark: PersonalizationColorSet.rgba(0xFFFFFF, 0.5)
        ),
        textDarkPrimary: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x000000, 1),
            dark: PersonalizationColorSet.rgba(0x000000, 1)
        ),
        textDarkSecondary: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x000000, 0.7),
            dark: PersonalizationColorSet.rgba(0x000000, 0.7)
        ),
        textDarkHint: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x000000, 0.4),
            dark: PersonalizationColorSet.rgba(0x000000, 0.4)
        ),
        textLightPrimary: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0xFFFFFF, 1),
            dark: PersonalizationColorSet.rgba(0xFFFFFF, 1)
        ),
        textLightSecondary: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0xFFFFFF, 0.8),
            dark: PersonalizationColorSet.rgba(0xFFFFFF, 0.8)
        ),
        textLightHint: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0xFFFFFF, 0.5),
            dark: PersonalizationColorSet.rgba(0xFFFFFF, 0.5)
        ),
        textInvertedPrimary: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0xFFFFFF, 1),
            dark: PersonalizationColorSet.rgba(0x000000, 1)
        ),
        textInvertedSecondary: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0xFFFFFF, 0.8),
            dark: PersonalizationColorSet.rgba(0x000000, 0.7)
        ),
        textInvertedHint: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0xFFFFFF, 0.5),
            dark: PersonalizationColorSet.rgba(0x000000, 0.4)
        ),
        textBrand: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x007DF2, 1),
            dark: PersonalizationColorSet.rgba(0x007DF2, 1)
        ),
        textLink: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x007DF2, 1),
            dark: PersonalizationColorSet.rgba(0x007DF2, 1)
        ),
        textLinkVisited: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x4D00F2, 1),
            dark: PersonalizationColorSet.rgba(0x4D00F2, 1)
        ),
        shadowHeavy: UIColor = PersonalizationColorSet.dynamic(
            light: PersonalizationColorSet.rgba(0x000000, 0.08),
            dark: PersonalizationColorSet.rgba(0x000000, 0.5)
        )
    ) {
        self.brandPrimary = brandPrimary
        self.neutral50 = neutral50
        self.semanticWarning = semanticWarning
        self.semanticDanger = semanticDanger
        self.backgroundGeneric = backgroundGeneric
        self.backgroundCard = backgroundCard
        self.backgroundFloat = backgroundFloat
        self.backgroundModal = backgroundModal
        self.backgroundInput = backgroundInput
        self.backgroundTransparent = backgroundTransparent
        self.backgroundInputDisabled = backgroundInputDisabled
        self.buttonPrimary = buttonPrimary
        self.buttonPrimaryFocus = buttonPrimaryFocus
        self.buttonSecondary = buttonSecondary
        self.buttonSecondaryOnDark = buttonSecondaryOnDark
        self.buttonSecondaryFocus = buttonSecondaryFocus
        self.buttonPrimaryDisabled = buttonPrimaryDisabled
        self.buttonSecondaryDisabled = buttonSecondaryDisabled
        self.buttonGhost = buttonGhost
        self.lineBrand = lineBrand
        self.lineGeneric = lineGeneric
        self.lineGenericSubtle = lineGenericSubtle
        self.lineInput = lineInput
        self.lineInputFocus = lineInputFocus
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.textHint = textHint
        self.textDarkPrimary = textDarkPrimary
        self.textDarkSecondary = textDarkSecondary
        self.textDarkHint = textDarkHint
        self.textLightPrimary = textLightPrimary
        self.textLightSecondary = textLightSecondary
        self.textLightHint = textLightHint
        self.textInvertedPrimary = textInvertedPrimary
        self.textInvertedSecondary = textInvertedSecondary
        self.textInvertedHint = textInvertedHint
        self.textBrand = textBrand
        self.textLink = textLink
        self.textLinkVisited = textLinkVisited
        self.shadowHeavy = shadowHeavy
    }

    /// Цвет из hex и прозрачности. Публичный: используется в значениях по умолчанию
    /// и пригодится хосту, который собирает свой набор.
    public static func rgba(_ hex: UInt32, _ alpha: CGFloat) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// Динамические цвета требуют iOS 13, а SDK поддерживает 12 — проверка версии
    /// живёт здесь, а не в каждом цвете. На iOS 12 отдаётся светлое значение.
    public static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        if #available(iOS 13.0, *) {
            return UIColor { $0.userInterfaceStyle == .dark ? dark : light }
        }
        return light
    }
}

/// Радиусы темы. `rounded` — pill: значение заведомо больше любой стороны.
@_spi(PersonalizationUI) public struct PersonalizationRadiusScale {

    public var xs: CGFloat
    public var sm: CGFloat
    public var md: CGFloat
    public var lg: CGFloat
    public var xl: CGFloat
    public var xl2: CGFloat
    public var xl3: CGFloat
    public var xl4: CGFloat
    public var xl5: CGFloat
    public var xl6: CGFloat
    public var xl7: CGFloat
    public var rounded: CGFloat

    /// Семантические радиусы из коллекции Radius. К Button LG/MD/SM привязаны Button,
    /// Input, Badge, Tag, к Segmented Button — Button Group, к Modal — попап.
    /// Дизайнер меняет их отдельно от шкалы, поэтому и здесь они отдельно.
    public var buttonLg: CGFloat
    public var buttonMd: CGFloat
    public var buttonSm: CGFloat
    public var segmentedLg: CGFloat
    public var segmentedMd: CGFloat
    public var segmentedSm: CGFloat
    public var card: CGFloat
    public var toast: CGFloat
    public var modal: CGFloat

    public init(
        xs: CGFloat = 2,
        sm: CGFloat = 4,
        md: CGFloat = 6,
        lg: CGFloat = 8,
        xl: CGFloat = 10,
        xl2: CGFloat = 12,
        xl3: CGFloat = 14,
        xl4: CGFloat = 16,
        xl5: CGFloat = 20,
        xl6: CGFloat = 24,
        xl7: CGFloat = 32,
        rounded: CGFloat = 999,
        buttonLg: CGFloat = 12,
        buttonMd: CGFloat = 10,
        buttonSm: CGFloat = 8,
        segmentedLg: CGFloat = 10,
        segmentedMd: CGFloat = 8,
        segmentedSm: CGFloat = 6,
        card: CGFloat = 16,
        toast: CGFloat = 999,
        modal: CGFloat = 24
    ) {
        self.xs = xs
        self.sm = sm
        self.md = md
        self.lg = lg
        self.xl = xl
        self.xl2 = xl2
        self.xl3 = xl3
        self.xl4 = xl4
        self.xl5 = xl5
        self.xl6 = xl6
        self.xl7 = xl7
        self.rounded = rounded
        self.buttonLg = buttonLg
        self.buttonMd = buttonMd
        self.buttonSm = buttonSm
        self.segmentedLg = segmentedLg
        self.segmentedMd = segmentedMd
        self.segmentedSm = segmentedSm
        self.card = card
        self.toast = toast
        self.modal = modal
    }
}
