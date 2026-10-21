import UIKit

/// Текстовый блок слайда сторис.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), компонент Text Block.
/// С заливкой (непрозрачность больше нуля) блок в рамке кита: скругление 12, поля 12/16
/// у крупного текста и 8/16 у остального, фон — цвет из админки со своей прозрачностью.
/// Без заливки — ни полей, ни фона, только текст.
///
/// Кегль, цвет, выравнивание, жирность, курсив и интерлиньяж приходят из элемента;
/// для хоста есть пресеты `Style.large` 48/48, `medium` 30/36, `small` 20/24 (Regular).
/// Цвет текста по умолчанию — Text/Light Primary на заливке и Text/Primary без неё.
///
/// С `promoCode` блок — кнопка: нажатие копирует код в буфер обмена, показывает тост
/// `copiedText` сверху и зовёт `onPromoCopied`.
@_spi(PersonalizationUI) public final class PersonalizationStoryTextBlock: UIView {

    /// Кегль и интерлиньяж.
    public struct Style: Equatable {
        public var size: CGFloat
        public var lineHeight: CGFloat

        public init(size: CGFloat, lineHeight: CGFloat) {
            self.size = size
            self.lineHeight = lineHeight
        }

        /// Large — 48/48.
        public static let large = Style(size: 48, lineHeight: 48)
        /// Medium — 30/36.
        public static let medium = Style(size: 30, lineHeight: 36)
        /// Small — 20/24.
        public static let small = Style(size: 20, lineHeight: 24)

        /// Интерлиньяж по пресету для кегля, когда админка его не задала: у кегля пресета —
        /// интерлиньяж пресета, у прочих — та же пропорция, что у ближайшего по кеглю.
        /// При равном расстоянии берётся больший пресет (39 — Large, как на всех платформах).
        public static func presetLineHeight(for size: CGFloat) -> CGFloat {
            // `min` отдаёт первый из равных, поэтому пресеты идут от большего к меньшему.
            let presets = [Style.large, .medium, .small]
            let nearest = presets.min { abs($0.size - size) < abs($1.size - size) } ?? .small
            return (size * nearest.lineHeight / nearest.size).rounded()
        }
    }

    /// Гарнитура из админки. `default` — шрифт темы кита.
    public enum FontFamily {
        case `default`, sansSerif, serif, monospaced
    }

    public var text: String? {
        didSet { applyText() }
    }

    public var style: Style = .medium {
        didSet { applyAll() }
    }

    public var bold = false {
        didSet { applyText() }
    }

    public var italic = false {
        didSet { applyText() }
    }

    public var fontFamily: FontFamily = .default {
        didSet { applyText() }
    }

    public var alignment: NSTextAlignment = .natural {
        didSet { applyText() }
    }

    /// Цвет текста. `nil` — по умолчанию для вида блока.
    public var textColor: UIColor? {
        didSet { applyText() }
    }

    /// Заливка вместе с прозрачностью. `nil` или прозрачная — блок без рамки.
    public var fill: UIColor? {
        didSet { applyAll() }
    }

    /// Промокод блока: нажатие копирует его. `nil` — блок не нажимается.
    public var promoCode: String? {
        didSet { applyPromo() }
    }

    /// Текст тоста после копирования. `nil` или пусто — без тоста.
    public var copiedText: String? = "Copied"

    /// Промокод скопирован в буфер обмена.
    public var onPromoCopied: ((String) -> Void)?

    /// Блок на медиа-слайде: тёмные токены и на iOS 12, где тему поддерева не переопределить.
    var forcesDarkTokens = false {
        didSet { applyText() }
    }

    private lazy var promoTap = UITapGestureRecognizer(target: self, action: #selector(promoTapped))

    /// Блок с заливкой: рамка кита — поля и скругление.
    public var isSolid: Bool {
        Self.isSolid(fill)
    }

    private let label = UILabel()
    private var insetConstraints: [NSLayoutConstraint] = []

    public init(text: String? = nil, style: Style = .medium, fill: UIColor? = nil) {
        super.init(frame: .zero)
        self.text = text
        self.style = style
        self.fill = fill
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    /// Все параметры блока разом — так их отдаёт слайд.
    public func apply(_ block: PersonalizationStorySlide.TextBlock) {
        text = block.text
        style = block.style
        bold = block.bold
        italic = block.italic
        fontFamily = block.fontFamily
        alignment = block.alignment
        textColor = block.textColor
        fill = block.fill
        promoCode = block.promoCode
    }

    private func applyPromo() {
        let active = !(promoCode ?? "").isEmpty
        if active, promoTap.view == nil {
            addGestureRecognizer(promoTap)
        } else if !active, promoTap.view != nil {
            removeGestureRecognizer(promoTap)
        }
        accessibilityTraits = active ? .button : .staticText
    }

    @objc private func promoTapped() {
        guard let promoCode, !promoCode.isEmpty else { return }
        UIPasteboard.general.string = promoCode
        if let copiedText, !copiedText.isEmpty {
            PersonalizationToast.show(copiedText, in: window, position: .top)
        }
        onPromoCopied?(promoCode)
    }

    private func setup() {
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        applyAll()
    }

    // MARK: - Вид

    /// Есть ли у заливки видимая часть. Прозрачность берётся из самого цвета.
    static func isSolid(_ fill: UIColor?) -> Bool {
        guard let fill else { return false }
        return fill.cgColor.alpha > 0
    }

    /// Поля блока: у крупного текста (кегль больше Medium) 12/16, у остального 8/16,
    /// без заливки — ноль.
    static func insets(style: Style, solid: Bool) -> UIEdgeInsets {
        guard solid else { return .zero }
        let vertical = style.size > Style.medium.size ? PersonalizationSpacing.lg : PersonalizationSpacing.md
        let horizontal = PersonalizationSpacing.xl
        return UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    private func applyAll() {
        let solid = isSolid
        backgroundColor = solid ? fill : .clear
        layer.cornerRadius = solid ? PersonalizationRadius.xl2 : 0  // 12

        NSLayoutConstraint.deactivate(insetConstraints)
        let insets = Self.insets(style: style, solid: solid)
        insetConstraints = [
            label.topAnchor.constraint(equalTo: topAnchor, constant: insets.top),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right)
        ]
        NSLayoutConstraint.activate(insetConstraints)
        applyText()
    }

    private func applyText() {
        guard let text, !text.isEmpty else {
            label.attributedText = nil
            return
        }
        let font = Self.font(style: style, family: fontFamily, bold: bold, italic: italic)
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = style.lineHeight
        paragraph.maximumLineHeight = style.lineHeight
        paragraph.alignment = alignment
        let color = textColor ?? PersonalizationStoryColors.token(
            isSolid ? PersonalizationColor.textLightPrimary : PersonalizationColor.textPrimary,
            forcingDark: forcesDarkTokens
        )
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .paragraphStyle: paragraph,
            .foregroundColor: color,
            // Как в типографике кита: текст по центру строки заданной высоты.
            .baselineOffset: (style.lineHeight - font.lineHeight) / 4
        ])
    }

    /// Шрифт блока. Гарнитура по умолчанию — из темы кита; засечки и моноширинный —
    /// системные варианты (до iOS 13 — Georgia и Menlo, как у старых сторис).
    static func font(style: Style, family: FontFamily, bold: Bool, italic: Bool) -> UIFont {
        let weight: UIFont.Weight = bold ? .semibold : .regular
        var font: UIFont
        switch family {
        case .default, .sansSerif:
            font = PersonalizationTheme.current.font(style.size, weight)
        case .serif, .monospaced:
            let system = UIFont.systemFont(ofSize: style.size, weight: weight)
            if #available(iOS 13.0, *),
               let descriptor = system.fontDescriptor.withDesign(family == .serif ? .serif : .monospaced) {
                font = UIFont(descriptor: descriptor, size: style.size)
            } else {
                font = UIFont(name: family == .serif ? "Georgia" : "Menlo", size: style.size) ?? system
            }
        }
        if italic {
            var traits = font.fontDescriptor.symbolicTraits
            traits.insert(.traitItalic)
            if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                font = UIFont(descriptor: descriptor, size: style.size)
            }
        }
        return font
    }
}
