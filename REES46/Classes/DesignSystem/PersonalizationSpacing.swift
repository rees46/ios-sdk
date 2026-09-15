import CoreGraphics

/// Отступы дизайн-системы.
///
/// Figma Mobile SDK UI Kit (SSwS49L1fG1psWA7xbakV6), страница Typography.
/// Сгенерировано скриптом; правки вносить в источник, не здесь.
///
/// Шкала независима от типографической: здесь MD вместо Base и нет 6XL.
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

    /// 2XL — 24pt.
    public static let xl2: CGFloat = 24

    /// 3XL — 32pt.
    public static let xl3: CGFloat = 32

    /// 4XL — 48pt.
    public static let xl4: CGFloat = 48

    /// 5XL — 64pt.
    public static let xl5: CGFloat = 64

}

/// Распорка для горизонтальных стеков, лежащих в колонках с `alignment = .fill`:
/// такая колонка растягивает строку на всю ширину, а строка — первый попавшийся
/// лейбл, и «4,7 (128)» разъезжается по краям. Распорка забирает лишнюю ширину
/// на себя, остальные элементы остаются своего размера.
final class PersonalizationFlexibleSpace: UIView {
    init() {
        super.init(frame: .zero)
        setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        setContentCompressionResistancePriority(UILayoutPriority(1), for: .horizontal)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
