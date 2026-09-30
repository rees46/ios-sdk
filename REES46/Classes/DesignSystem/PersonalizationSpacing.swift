import UIKit

/// Отступы дизайн-системы.
///
/// Figma Mobile SDK UI Kit (SSwS49L1fG1psWA7xbakV6), коллекция переменных Spacings.
///
/// Шкала независима от типографической: здесь MD вместо Base, ступеней 11 — до 7XL.
@_spi(PersonalizationUI) public enum PersonalizationSpacing {

    /// XS — 2pt.
    public static let xs: CGFloat = 2

    /// SM — 4pt.
    public static let sm: CGFloat = 4

    /// MD — 8pt.
    public static let md: CGFloat = 8

    /// LG — 12pt.
    public static let lg: CGFloat = 12

    /// XL — 16pt.
    public static let xl: CGFloat = 16

    /// 2XL — 20pt.
    public static let xl2: CGFloat = 20

    /// 3XL — 24pt.
    public static let xl3: CGFloat = 24

    /// 4XL — 32pt.
    public static let xl4: CGFloat = 32

    /// 5XL — 48pt.
    public static let xl5: CGFloat = 48

    /// 6XL — 56pt.
    public static let xl6: CGFloat = 56

    /// 7XL — 64pt.
    public static let xl7: CGFloat = 64

    // Семантические отступы: поля и зазоры блоков, модалки и полноэкранного окна.

    /// Padding X — 16pt.
    public static let paddingX: CGFloat = 16

    /// Padding Y — 16pt.
    public static let paddingY: CGFloat = 16

    /// Gap X — 16pt.
    public static let gapX: CGFloat = 16

    /// Gap Y — 16pt.
    public static let gapY: CGFloat = 16

    /// Padding Modal — 20pt.
    public static let paddingModal: CGFloat = 20

    /// Gap Modal — 20pt.
    public static let gapModal: CGFloat = 20

    /// Padding Full Screen — 24pt.
    public static let paddingFullScreen: CGFloat = 24

    /// Gap Full Screen — 24pt.
    public static let gapFullScreen: CGFloat = 24

}

/// Распорка для горизонтальных стеков, лежащих в колонках с `alignment = .fill`:
/// такая колонка растягивает строку на всю ширину, а строка — первый попавшийся
/// лейбл, и «4,7 (128)» разъезжается по краям. Распорка забирает лишнюю ширину
/// на себя, остальные элементы остаются своего размера.
///
/// `axis: .vertical` — та же распорка для колонки: забирает лишнюю высоту, когда
/// ячейка выше содержимого карточки. `minimum` — её высота без растяжения, то есть
/// обычный шаг между соседями (стек вокруг неё идёт без spacing, иначе шаг удвоится).
final class PersonalizationFlexibleSpace: UIView {
    init(axis: NSLayoutConstraint.Axis = .horizontal, minimum: CGFloat = 0) {
        super.init(frame: .zero)
        setContentHuggingPriority(UILayoutPriority(1), for: axis)
        setContentCompressionResistancePriority(UILayoutPriority(1), for: axis)
        if axis == .vertical {
            heightAnchor.constraint(greaterThanOrEqualToConstant: minimum).isActive = true
            let rest = heightAnchor.constraint(equalToConstant: minimum)
            rest.priority = UILayoutPriority(1)
            rest.isActive = true
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
