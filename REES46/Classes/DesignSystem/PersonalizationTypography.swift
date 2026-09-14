import UIKit

/// Типографика дизайн-системы.
///
/// Figma Mobile SDK UI Kit (SSwS49L1fG1psWA7xbakV6), страница Typography.
/// Сгенерировано скриптом; правки вносить в источник, не здесь.
///
/// Inter в SDK не поставляется — по умолчанию системный шрифт с нужным весом.
/// Чтобы перейти на Inter, хост задаёт `PersonalizationTheme.current.font`.
public struct PersonalizationTextStyle {

    public let size: CGFloat
    public let lineHeight: CGFloat
    /// Межбуквенное расстояние в пунктах, как `kern`.
    public let tracking: CGFloat
    public let weight: UIFont.Weight

    /// Шрифт берётся из темы: хост подменяет его одним замыканием в
    /// `PersonalizationTheme.current.font`, кегли и начертания остаются нашими.
    public var font: UIFont {
        PersonalizationTheme.current.font(size, weight)
    }

    public var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        return style
    }

    /// Атрибуты для `NSAttributedString`: шрифт, интерлиньяж и трекинг сразу.
    public var attributes: [NSAttributedString.Key: Any] {
        var result: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            // Сдвигает базовую линию так, чтобы текст стоял по центру строки.
            .baselineOffset: (lineHeight - font.lineHeight) / 4
        ]
        if tracking != 0 { result[.kern] = tracking }
        return result
    }

    /// Ставит стиль на лейбл вместе с текстом: только через `attributedText`
    /// интерлиньяж и трекинг доезжают до отрисовки.
    public func apply(to label: UILabel, text: String?) {
        guard let text else {
            label.attributedText = nil
            return
        }
        label.attributedText = NSAttributedString(string: text, attributes: attributes)
    }
}

public enum PersonalizationTypography {

    /// XS/Default — 12/16, трекинг 0.05.
    public static let xsDefault = PersonalizationTextStyle(
        size: 12, lineHeight: 16, tracking: 0.05, weight: .regular
    )

    /// XS/Emphasized — 12/16, трекинг 0.05.
    public static let xsEmphasized = PersonalizationTextStyle(
        size: 12, lineHeight: 16, tracking: 0.05, weight: .semibold
    )

    /// SM/Default — 14/20, трекинг 0.05.
    public static let smDefault = PersonalizationTextStyle(
        size: 14, lineHeight: 20, tracking: 0.05, weight: .regular
    )

    /// SM/Emphasized — 14/20, трекинг 0.05.
    public static let smEmphasized = PersonalizationTextStyle(
        size: 14, lineHeight: 20, tracking: 0.05, weight: .semibold
    )

    /// Base/Default — 16/24, трекинг 0.
    public static let baseDefault = PersonalizationTextStyle(
        size: 16, lineHeight: 24, tracking: 0, weight: .regular
    )

    /// Base/Emphasized — 16/24, трекинг 0.
    public static let baseEmphasized = PersonalizationTextStyle(
        size: 16, lineHeight: 24, tracking: 0, weight: .semibold
    )

    /// LG/Default — 18/28, трекинг 0.
    public static let lgDefault = PersonalizationTextStyle(
        size: 18, lineHeight: 28, tracking: 0, weight: .regular
    )

    /// LG/Emphasized — 18/28, трекинг 0.
    public static let lgEmphasized = PersonalizationTextStyle(
        size: 18, lineHeight: 28, tracking: 0, weight: .semibold
    )

    /// XL/Default — 20/32, трекинг 0.
    public static let xlDefault = PersonalizationTextStyle(
        size: 20, lineHeight: 32, tracking: 0, weight: .regular
    )

    /// XL/Emphasized — 20/32, трекинг 0.
    public static let xlEmphasized = PersonalizationTextStyle(
        size: 20, lineHeight: 32, tracking: 0, weight: .semibold
    )

    /// 2XL/Default — 24/36, трекинг 0.
    public static let xl2Default = PersonalizationTextStyle(
        size: 24, lineHeight: 36, tracking: 0, weight: .regular
    )

    /// 2XL/Emphasized — 24/36, трекинг 0.
    public static let xl2Emphasized = PersonalizationTextStyle(
        size: 24, lineHeight: 36, tracking: 0, weight: .semibold
    )

    /// 3XL/Default — 30/40, трекинг -0.5.
    public static let xl3Default = PersonalizationTextStyle(
        size: 30, lineHeight: 40, tracking: -0.5, weight: .regular
    )

    /// 3XL/Emphasized — 30/40, трекинг -0.5.
    public static let xl3Emphasized = PersonalizationTextStyle(
        size: 30, lineHeight: 40, tracking: -0.5, weight: .semibold
    )

    /// 4XL/Default — 36/52, трекинг -0.5.
    public static let xl4Default = PersonalizationTextStyle(
        size: 36, lineHeight: 52, tracking: -0.5, weight: .regular
    )

    /// 4XL/Emphasized — 36/52, трекинг -0.5.
    public static let xl4Emphasized = PersonalizationTextStyle(
        size: 36, lineHeight: 52, tracking: -0.5, weight: .semibold
    )

    /// 5XL/Default — 48/64, трекинг -0.5.
    public static let xl5Default = PersonalizationTextStyle(
        size: 48, lineHeight: 64, tracking: -0.5, weight: .regular
    )

    /// 5XL/Emphasized — 48/64, трекинг -0.5.
    public static let xl5Emphasized = PersonalizationTextStyle(
        size: 48, lineHeight: 64, tracking: -0.5, weight: .semibold
    )

    /// 6XL/Default — 60/72, трекинг -0.5.
    public static let xl6Default = PersonalizationTextStyle(
        size: 60, lineHeight: 72, tracking: -0.5, weight: .regular
    )

    /// 6XL/Emphasized — 60/72, трекинг -0.5.
    public static let xl6Emphasized = PersonalizationTextStyle(
        size: 60, lineHeight: 72, tracking: -0.5, weight: .semibold
    )

}
