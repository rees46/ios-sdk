import UIKit

/// Иконки дизайн-системы, 32x32.
///
/// Источник: Figma Mobile SDK UI Kit (SSwS49L1fG1psWA7xbakV6),
/// страница Icons, секция 157:5185.
///
/// Ассеты векторные (PDF с сохранённым вектором) и помечены как
/// шаблонные, поэтому красятся через `tintColor` у `UIImageView`.
public enum PersonalizationIcons {

    /// Нужен только чтобы найти бандл фреймворка через `Bundle(for:)`.
    private final class BundleMarker {}

    private static var bundle: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: BundleMarker.self)
        #endif
    }

    private static func image(_ name: String) -> UIImage? {
        UIImage(named: name, in: bundle, compatibleWith: nil)?
            .withRenderingMode(.alwaysTemplate)
    }

    public static var angleDown: UIImage? { image("personalization_angle_down") }
    public static var angleLargeRight: UIImage? { image("personalization_angle_large_right") }
    public static var angleUp: UIImage? { image("personalization_angle_up") }
    public static var arrowLeft: UIImage? { image("personalization_arrow_left") }
    public static var arrowRotateCw: UIImage? { image("personalization_arrow_rotate_cw") }
    public static var arrowsUpDown: UIImage? { image("personalization_arrows_up_down") }
    public static var copy: UIImage? { image("personalization_copy") }
    public static var crossLarge: UIImage? { image("personalization_cross_large") }
    public static var cross: UIImage? { image("personalization_cross") }
    public static var equalizerHorizontal: UIImage? { image("personalization_equalizer_horizontal") }
    public static var grid2x2Fill: UIImage? { image("personalization_grid_2x2_fill") }
    public static var grid2x2: UIImage? { image("personalization_grid_2x2") }
    public static var listFill: UIImage? { image("personalization_list_fill") }
    public static var list: UIImage? { image("personalization_list") }
    public static var magnifier: UIImage? { image("personalization_magnifier") }
    public static var spacingMd: UIImage? { image("personalization_spacing_md") }
    public static var starFill: UIImage? { image("personalization_star_fill") }
}
