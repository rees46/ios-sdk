import UIKit

// Общие стили элементов попапа v3: шрифты, текст с разметкой, коробка и кнопки. CSS px — это
// точки iOS. Шрифтов сайта по имени не ищем: системный, `monospace` и `serif` — по ключевому слову.

enum PopupV3Fonts {

    /// Вес CSS (100…900) → вес системного шрифта.
    static func weight(_ css: Double) -> UIFont.Weight {
        switch css {
        case ..<150: return .ultraLight
        case ..<250: return .thin
        case ..<350: return .light
        case ..<450: return .regular
        case ..<550: return .medium
        case ..<650: return .semibold
        case ..<750: return .bold
        case ..<850: return .heavy
        default: return .black
        }
    }

    static func font(size: Double, weight css: Double, family: String?, bold: Bool = false, italic: Bool = false) -> UIFont {
        let size = CGFloat(max(1, size))
        let weight = weight(bold ? max(css, 700) : css)
        let lower = family?.lowercased() ?? ""
        var font: UIFont
        if lower.contains("mono") {
            if #available(iOS 13.0, *) {
                font = .monospacedSystemFont(ofSize: size, weight: weight)
            } else {
                font = UIFont(name: "Menlo", size: size) ?? .systemFont(ofSize: size, weight: weight)
            }
        } else {
            font = .systemFont(ofSize: size, weight: weight)
            if lower.contains("serif"), !lower.contains("sans"), #available(iOS 13.0, *),
               let descriptor = font.fontDescriptor.withDesign(.serif) {
                font = UIFont(descriptor: descriptor, size: size)
            }
        }
        if italic, let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(.traitItalic)) {
            font = UIFont(descriptor: descriptor, size: size)
        }
        return font
    }

    /// Текст с разметкой: начертания кусков поверх общего шрифта, межстрочный — множитель CSS
    /// `line-height`, межбуквенный — `letter-spacing` в точках.
    static func attributed(
        _ spans: [PopupV3Span],
        size: Double,
        weight: Double,
        family: String?,
        color: CSSColor,
        lineHeight: Double?,
        letterSpacing: Double = 0,
        align: NSTextAlignment = .natural
    ) -> NSAttributedString {
        let base = font(size: size, weight: weight, family: family)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = align
        paragraph.lineBreakMode = .byWordWrapping
        var baselineOffset: CGFloat = 0
        if let lineHeight, lineHeight > 0 {
            let points = CGFloat(size * lineHeight)
            if points >= base.lineHeight {
                paragraph.minimumLineHeight = points
                paragraph.maximumLineHeight = points
                baselineOffset = (points - base.lineHeight) / 4
            }
        }
        let result = NSMutableAttributedString()
        for span in spans {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font(size: size, weight: weight, family: family, bold: span.bold, italic: span.italic),
                .foregroundColor: color.uiColor,
                .paragraphStyle: paragraph,
                .baselineOffset: baselineOffset
            ]
            if letterSpacing != 0 { attributes[.kern] = CGFloat(letterSpacing) }
            if span.underline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
            if span.strike { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            if span.overline { attributes[.popupV3Overline] = true }
            result.append(NSAttributedString(string: span.text, attributes: attributes))
        }
        return result
    }

    static func alignment(_ align: PopupV3HAlign) -> NSTextAlignment {
        switch align {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }
}

/// Многострочная подпись, которая знает свою ширину в Auto Layout и рисует надчёркивание
/// (`^^текст^^`): у `NSAttributedString` такого атрибута нет.
final class PopupV3Label: UILabel {

    override init(frame: CGRect) {
        super.init(frame: frame)
        numberOfLines = 0
        lineBreakMode = .byWordWrapping
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        setContentHuggingPriority(.defaultHigh, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if preferredMaxLayoutWidth != bounds.width {
            preferredMaxLayoutWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect)
        guard let text = attributedText, text.length > 0 else { return }
        var ranges: [NSRange] = []
        text.enumerateAttribute(.popupV3Overline, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if value != nil { ranges.append(range) }
        }
        guard !ranges.isEmpty, let context = UIGraphicsGetCurrentContext() else { return }
        let storage = NSTextStorage(attributedString: text)
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: rect.width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = numberOfLines
        container.lineBreakMode = lineBreakMode
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        let used = layout.usedRect(for: container)
        let top = rect.minY + max(0, (rect.height - used.height) / 2)
        for range in ranges {
            let color = (text.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor) ?? textColor ?? .black
            let font = (text.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont) ?? self.font ?? .systemFont(ofSize: 14)
            let glyphs = layout.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            layout.enumerateEnclosingRects(forGlyphRange: glyphs, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: container) { box, _ in
                let line = max(1, font.pointSize / 14)
                let lineTop = top + box.minY + max(0, box.height - font.lineHeight) / 2 + font.ascender - font.capHeight - line * 2
                context.setFillColor(color.cgColor)
                context.fill(CGRect(x: rect.minX + box.minX, y: lineTop, width: box.width, height: line))
            }
        }
    }
}

/// Обёртка элемента — «коробка» стилей: фон, рамка, радиус, отступы, непрозрачность, тень.
/// Содержимое стоит внутри отступов и рамки.
class PopupV3BoxView: UIView {

    let content = UIView()
    let box: PopupV3Box

    init(box: PopupV3Box) {
        self.box = box
        super.init(frame: .zero)
        layer.backgroundColor = box.background.uiColor.cgColor
        layer.cornerRadius = CGFloat(box.borderRadius)
        layer.borderWidth = CGFloat(box.borderWidth)
        layer.borderColor = box.borderColor.uiColor.cgColor
        alpha = CGFloat(box.opacity)
        if box.hasShadow {
            layer.shadowColor = box.shadowColor.with(alpha: 255).uiColor.cgColor
            layer.shadowOpacity = Float(box.shadowColor.alpha) / 255
            layer.shadowOffset = CGSize(width: 0, height: box.shadowY)
            layer.shadowRadius = CGFloat(box.shadowBlur) / 2
        }
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        let insetX = CGFloat(box.paddingX + box.borderWidth)
        let insetY = CGFloat(box.paddingY + box.borderWidth)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor, constant: insetY),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insetY),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insetX),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insetX)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Вью внутри содержимого, по краям.
    func fill(with view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: content.topAnchor),
            view.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: content.trailingAnchor)
        ])
    }
}

/// Кнопка по стилям дизайна: подпись с разметкой или картинка, фон, радиус, отступы.
/// Нажатие — подсветка прозрачностью, двойные нажатия гасит сам элемент.
final class PopupV3ButtonControl: UIControl {

    let label = PopupV3Label()
    private(set) var style: PopupV3ButtonStyle
    private let family: String?
    private let weight: Double

    init(text: String, style: PopupV3ButtonStyle, family: String?, weight: Double = 500, lineHeight: Double? = nil) {
        self.style = style
        self.family = family
        self.weight = weight
        super.init(frame: .zero)
        isAccessibilityElement = true
        accessibilityTraits = .button
        apply(style)
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        let x = CGFloat(style.paddingX), y = CGFloat(style.paddingY)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: y),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -y),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: x),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -x)
        ])
        setText(text, lineHeight: lineHeight)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setText(_ text: String, lineHeight: Double? = nil, align: NSTextAlignment = .center) {
        label.attributedText = PopupV3Fonts.attributed(
            PopupV3Markup.spans(text), size: style.fontSize, weight: weight, family: family,
            color: style.textColor, lineHeight: lineHeight, align: align
        )
        accessibilityLabel = PopupV3Markup.plain(text)
    }

    private func apply(_ style: PopupV3ButtonStyle) {
        layer.backgroundColor = style.background.uiColor.cgColor
        layer.cornerRadius = CGFloat(style.radius)
        clipsToBounds = false
    }

    /// Радиус 999 и т. п. — не больше половины высоты, как у CSS.
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(CGFloat(style.radius), bounds.height / 2, bounds.width / 2)
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : (isEnabled ? 1 : 0.6) }
    }

    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1 : 0.6 }
    }
}

/// Поле ввода по стилям формы попапа.
final class PopupV3TextField: UITextField {

    private let insets: UIEdgeInsets

    init(style: PopupV3InputStyle, fontSize: Double, paddingY: Double, placeholder: String) {
        insets = UIEdgeInsets(top: CGFloat(paddingY), left: 12, bottom: CGFloat(paddingY), right: 12)
        super.init(frame: .zero)
        backgroundColor = style.background.uiColor
        textColor = style.textColor.uiColor
        tintColor = style.textColor.uiColor
        layer.borderWidth = 1
        layer.borderColor = style.borderColor.uiColor.cgColor
        layer.cornerRadius = CGFloat(style.radius)
        font = .systemFont(ofSize: CGFloat(fontSize))
        attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [
            .foregroundColor: style.textColor.uiColor.withAlphaComponent(0.45),
            .font: UIFont.systemFont(ofSize: CGFloat(fontSize))
        ])
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: insets) }
    override func editingRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: insets) }
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: insets) }

    override var intrinsicContentSize: CGSize {
        let line = (font ?? .systemFont(ofSize: 13)).lineHeight * 1.25
        return CGSize(width: UIView.noIntrinsicMetric, height: ceil(line + insets.top + insets.bottom + 2))
    }

    /// Поле в окне попапа: окно должно стать ключевым, иначе клавиатура не появится.
    override func becomeFirstResponder() -> Bool {
        if let window, !window.isKeyWindow { window.makeKey() }
        return super.becomeFirstResponder()
    }
}

/// Простая проверка email — как `type="email"` браузера: `что-то@что-то.что-то` без пробелов.
enum PopupV3Validation {
    static func isEmail(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.contains(where: \.isWhitespace) else { return false }
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        return domain.count >= 2 && domain.allSatisfy { !$0.isEmpty }
    }

    /// Телефон: `+` в начале, цифры, пробелы, скобки и дефисы; цифр от 10 до 15.
    static func isPhone(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet(charactersIn: "+0123456789 ()-")
        guard !value.isEmpty, value.unicodeScalars.allSatisfy(allowed.contains) else { return false }
        if let plus = value.firstIndex(of: "+"), plus != value.startIndex { return false }
        let digits = value.filter(\.isNumber).count
        return (10...15).contains(digits)
    }
}
