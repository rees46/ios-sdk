import UIKit

/// Цена товара на слайде сторис: обычная, со скидкой или с промокодом.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), компонент Card/Story/Price
/// (виды Price, Discount, Promo code; Installment в макете есть, но данных под него нет).
///
/// Плашка со скруглением 12 и заливкой #F2F2F2 95% — в макете сырой цвет без переменной,
/// одинаковый в обеих темах, поэтому и текст на ней всегда тёмный (Text/Dark *).
/// Левая колонка с полями 12/16: старая цена (необязательная, группа 50%) — сумма SemiBold 14
/// зачёркнутая и валюта Regular 14/16, Text/Dark Secondary; цена — сумма SemiBold 24 и валюта
/// Regular 14/16 с шагом 4 по базовой линии, Text/Dark Primary. Валюта — хвост отформатированной
/// строки без цифр: `"1 190 900 ₽"` → `1 190 900` и `₽`, см. `splitCurrency(_:)`.
///
/// Правый блок:
/// - `discount` — заливка Brand/Primary, поля 0/16, SemiBold 36 Text/Light Primary («10%»);
///   левая колонка забирает остаток ширины.
/// - `promoCode` — заливка Text/Dark Primary (чёрная), поля 12/16 по центру: подпись SemiBold 14
///   Text/Light Secondary («Promo code») и код SemiBold 24 Text/Light Primary; иконка копирования
///   24 (глиф 20, Text/Light Hint) в правом верхнем углу с полем 4. Колонки делят ширину
///   поровну, длинный код забирает сколько ему нужно.
///
/// Нажатие на промокод: блок чуть увеличивается («Tap Zoom Effect» макета), код уходит
/// в буфер обмена, показывается тост `copiedText` и зовётся `onPromoCopied`.
/// Увеличенный блок выходит за края плашки — поэтому скругление и обрезка живут
/// на подложке, а не на самом компоненте.
@_spi(PersonalizationUI) public final class PersonalizationStoryPrice: UIView {

    /// Вид правого блока.
    public enum Kind: Equatable {
        /// Только цена.
        case price
        /// Скидка: текст блока, например «10%».
        case discount(String)
        /// Промокод: сам код.
        case promoCode(String)
    }

    /// Отформатированная цена, например «1 190 900 ₽».
    public var price: String? {
        didSet { applyPrices() }
    }

    /// Старая цена, зачёркнутая. `nil` — не показывать.
    public var oldPrice: String? {
        didSet { applyPrices() }
    }

    public var kind: Kind = .price {
        didSet { applyKind() }
    }

    /// Подпись над промокодом.
    public var promoCaption: String? = "Promo code" {
        didSet { applyKind() }
    }

    /// Текст тоста после копирования. `nil` или пусто — без тоста.
    public var copiedText: String? = "Copied"

    /// Край экрана для тоста.
    public var toastPosition: PersonalizationToast.Position = .top

    /// Промокод скопирован в буфер обмена.
    public var onPromoCopied: ((String) -> Void)?

    /// Масштаб промокода под пальцем.
    static let pressedScale: CGFloat = 1.03
    /// Заливка плашки: #F2F2F2 95%, в макете без переменной.
    static let boxColor = PersonalizationColorSet.rgba(0xF2F2F2, 0.95)

    private static let radius: CGFloat = PersonalizationRadius.xl2  // 12

    private static let amountStyle = PersonalizationTextStyle(size: 24, lineHeight: 30, tracking: 0, weight: .semibold)
    private static let currencyStyle = PersonalizationTextStyle(size: 14, lineHeight: 16, tracking: 0, weight: .regular)
    private static let oldAmountStyle = PersonalizationTextStyle(size: 14, lineHeight: 16, tracking: 0, weight: .semibold)
    private static let discountStyle = PersonalizationTextStyle(size: 36, lineHeight: 44, tracking: 0, weight: .semibold)
    // Подпись промокода 14/16: блок промокода той же высоты 70, что и колонка цены.
    private static let captionStyle = PersonalizationTextStyle(size: 14, lineHeight: 16, tracking: 0, weight: .semibold)
    private static let codeStyle = PersonalizationTextStyle(size: 24, lineHeight: 30, tracking: 0, weight: .semibold)

    private let surface = UIView()
    private let row = UIStackView()
    private let left = UIView()
    private let oldPriceLabel = UILabel()
    private let amountLabel = UILabel()
    private let currencyLabel = UILabel()
    private let right = PromoBlock()
    private let discountLabel = UILabel()
    private let captionLabel = UILabel()
    private let codeLabel = UILabel()
    private let copyIcon = UIImageView()
    private let promoColumn = UIStackView()
    private var equalWidths: NSLayoutConstraint?

    public init(price: String? = nil, oldPrice: String? = nil, kind: Kind = .price) {
        super.init(frame: .zero)
        self.price = price
        self.oldPrice = oldPrice
        self.kind = kind
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        surface.backgroundColor = Self.boxColor
        surface.layer.cornerRadius = Self.radius
        surface.clipsToBounds = true
        surface.isUserInteractionEnabled = false
        surface.translatesAutoresizingMaskIntoConstraints = false
        addSubview(surface)

        row.axis = .horizontal
        row.alignment = .fill
        row.distribution = .fill
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            surface.topAnchor.constraint(equalTo: topAnchor),
            surface.bottomAnchor.constraint(equalTo: bottomAnchor),
            surface.leadingAnchor.constraint(equalTo: leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        buildLeft()
        buildRight()
        row.addArrangedSubview(left)
        row.addArrangedSubview(right)

        applyPrices()
        applyKind()
    }

    /// Левая колонка: старая цена над ценой, по центру высоты с полями 12/16.
    private func buildLeft() {
        oldPriceLabel.alpha = 0.5
        oldPriceLabel.numberOfLines = 1
        amountLabel.numberOfLines = 1
        currencyLabel.numberOfLines = 1
        // Цену не режем: при длинном промокоде сжимается сам код, а не сумма.
        for label in [oldPriceLabel, amountLabel, currencyLabel] {
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        let priceRow = UIStackView(arrangedSubviews: [amountLabel, currencyLabel])
        priceRow.axis = .horizontal
        priceRow.alignment = .firstBaseline
        priceRow.spacing = PersonalizationSpacing.sm  // 4

        let column = UIStackView(arrangedSubviews: [oldPriceLabel, priceRow])
        column.axis = .vertical
        column.alignment = .leading
        column.translatesAutoresizingMaskIntoConstraints = false
        left.addSubview(column)
        pinCentered(column, in: left, vertical: PersonalizationSpacing.lg, horizontal: PersonalizationSpacing.xl)
    }

    /// Правый блок: один контрол на оба вида, наполнение меняется по `kind`.
    private func buildRight() {
        right.layer.cornerRadius = Self.radius
        // Скруглены только внешние углы: блок стыкуется с левой колонкой прямой стороной.
        right.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        right.addTarget(self, action: #selector(promoTapped), for: .touchUpInside)
        right.isAccessibilityElement = true

        discountLabel.numberOfLines = 1
        discountLabel.textAlignment = .center
        discountLabel.translatesAutoresizingMaskIntoConstraints = false
        discountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        right.addSubview(discountLabel)
        NSLayoutConstraint.activate([
            discountLabel.leadingAnchor.constraint(equalTo: right.leadingAnchor, constant: PersonalizationSpacing.xl),
            discountLabel.trailingAnchor.constraint(equalTo: right.trailingAnchor, constant: -PersonalizationSpacing.xl),
            discountLabel.centerYAnchor.constraint(equalTo: right.centerYAnchor),
            discountLabel.topAnchor.constraint(greaterThanOrEqualTo: right.topAnchor),
            discountLabel.bottomAnchor.constraint(lessThanOrEqualTo: right.bottomAnchor)
        ])

        captionLabel.numberOfLines = 1
        codeLabel.numberOfLines = 1
        // Длинный код забирает ширину у равного деления колонок, а в самом крайнем
        // случае уменьшается, а не обрезается.
        codeLabel.adjustsFontSizeToFitWidth = true
        codeLabel.minimumScaleFactor = 0.5
        codeLabel.setContentCompressionResistancePriority(UILayoutPriority(760), for: .horizontal)
        captionLabel.setContentCompressionResistancePriority(UILayoutPriority(760), for: .horizontal)
        promoColumn.addArrangedSubview(captionLabel)
        promoColumn.addArrangedSubview(codeLabel)
        promoColumn.axis = .vertical
        promoColumn.alignment = .center
        promoColumn.isUserInteractionEnabled = false
        promoColumn.translatesAutoresizingMaskIntoConstraints = false
        right.addSubview(promoColumn)
        pinCentered(promoColumn, in: right, vertical: PersonalizationSpacing.lg, horizontal: PersonalizationSpacing.xl, centerX: true)

        copyIcon.image = PersonalizationIcons.copy
        copyIcon.tintColor = PersonalizationColor.textLightHint
        copyIcon.contentMode = .scaleAspectFit
        copyIcon.isUserInteractionEnabled = false
        copyIcon.translatesAutoresizingMaskIntoConstraints = false
        right.addSubview(copyIcon)
        let inset = PersonalizationSpacing.sm  // 4
        NSLayoutConstraint.activate([
            copyIcon.topAnchor.constraint(equalTo: right.topAnchor, constant: inset),
            copyIcon.trailingAnchor.constraint(equalTo: right.trailingAnchor, constant: -inset),
            copyIcon.widthAnchor.constraint(equalToConstant: 24),
            copyIcon.heightAnchor.constraint(equalToConstant: 24)
        ])

        // Поровну делят ширину только колонки промокода; приоритет ниже сопротивления кода.
        equalWidths = left.widthAnchor.constraint(equalTo: right.widthAnchor)
        equalWidths?.priority = .defaultHigh
    }

    /// Содержимое по центру высоты контейнера с минимальными полями: высоту задаёт
    /// самая высокая из колонок, у второй содержимое встаёт посередине. По горизонтали
    /// колонка цены прижата к левому полю, колонка промокода стоит по центру.
    private func pinCentered(_ content: UIView, in container: UIView, vertical: CGFloat, horizontal: CGFloat, centerX: Bool = false) {
        let top = content.topAnchor.constraint(equalTo: container.topAnchor, constant: vertical)
        top.priority = .defaultLow
        let horizontalPosition = centerX
            ? content.centerXAnchor.constraint(equalTo: container.centerXAnchor)
            : content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: horizontal).withPriority(.defaultHigh)
        NSLayoutConstraint.activate([
            content.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            content.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor, constant: vertical),
            content.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -vertical),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: horizontal),
            content.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -horizontal),
            horizontalPosition,
            top
        ])
    }

    private func applyPrices() {
        let current = Self.splitCurrency(price ?? "")
        amountLabel.attributedText = Self.text(current.amount, Self.amountStyle, PersonalizationColor.textDarkPrimary)
        currencyLabel.attributedText = Self.text(current.currency, Self.currencyStyle, PersonalizationColor.textDarkPrimary)
        currencyLabel.isHidden = current.currency == nil

        if let oldPrice, !oldPrice.isEmpty {
            let old = Self.splitCurrency(oldPrice)
            let color = PersonalizationColor.textDarkSecondary
            let text = NSMutableAttributedString()
            if let amount = Self.text(old.amount, Self.oldAmountStyle, color) { text.append(amount) }
            if let currency = old.currency, let tail = Self.text(" " + currency, Self.currencyStyle, color) {
                text.append(tail)
            }
            // Зачёркнута вся строка, вместе с валютой, как в макете.
            text.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: text.length))
            oldPriceLabel.attributedText = text
            oldPriceLabel.isHidden = false
        } else {
            oldPriceLabel.attributedText = nil
            oldPriceLabel.isHidden = true
        }
    }

    private func applyKind() {
        right.transform = .identity
        switch kind {
        case .price:
            right.isHidden = true
            equalWidths?.isActive = false
        case .discount(let text):
            right.isHidden = false
            right.isEnabled = false
            right.backgroundColor = PersonalizationColor.brandPrimary
            discountLabel.isHidden = false
            promoColumn.isHidden = true
            copyIcon.isHidden = true
            discountLabel.attributedText = Self.text(text, Self.discountStyle, PersonalizationColor.textLightPrimary)
            right.accessibilityLabel = text
            right.accessibilityTraits = .staticText
            // Блок скидки по содержимому, остаток ширины у левой колонки.
            equalWidths?.isActive = false
            right.setContentHuggingPriority(.required, for: .horizontal)
            left.setContentHuggingPriority(.defaultLow, for: .horizontal)
        case .promoCode(let code):
            right.isHidden = false
            right.isEnabled = true
            right.backgroundColor = PersonalizationColor.textDarkPrimary
            discountLabel.isHidden = true
            promoColumn.isHidden = false
            copyIcon.isHidden = false
            captionLabel.attributedText = Self.centered(promoCaption, Self.captionStyle, PersonalizationColor.textLightSecondary)
            captionLabel.isHidden = (promoCaption ?? "").isEmpty
            codeLabel.attributedText = Self.centered(code, Self.codeStyle, PersonalizationColor.textLightPrimary)
            right.accessibilityLabel = [promoCaption, code].compactMap { $0 }.joined(separator: " ")
            right.accessibilityTraits = .button
            right.setContentHuggingPriority(.defaultLow, for: .horizontal)
            left.setContentHuggingPriority(.defaultLow, for: .horizontal)
            equalWidths?.isActive = true
        }
    }

    @objc private func promoTapped() {
        guard case .promoCode(let code) = kind else { return }
        UIPasteboard.general.string = code
        if let copiedText, !copiedText.isEmpty {
            PersonalizationToast.show(copiedText, in: window, position: toastPosition)
        }
        onPromoCopied?(code)
    }

    // MARK: - Текст

    /// Делит отформатированную цену на сумму и валюту: валюта — хвост строки после
    /// последней цифры (`"1 190 900 ₽"` → `1 190 900` + `₽`, `"12,99 €"` → `12,99` + `€`).
    /// Без такого хвоста (`"$140"`, `"Free"`) вся строка — сумма, валюты нет.
    public static func splitCurrency(_ formatted: String) -> (amount: String, currency: String?) {
        let trimmed = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let lastDigit = trimmed.lastIndex(where: { $0.isNumber }) else { return (trimmed, nil) }
        let tail = trimmed[trimmed.index(after: lastDigit)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tail.isEmpty else { return (trimmed, nil) }
        let amount = trimmed[...lastDigit].trimmingCharacters(in: .whitespacesAndNewlines)
        return (amount, tail)
    }

    private static func text(_ value: String?, _ style: PersonalizationTextStyle, _ color: UIColor) -> NSAttributedString? {
        guard let value else { return nil }
        var attributes = style.attributes
        attributes[.foregroundColor] = color
        return NSAttributedString(string: value, attributes: attributes)
    }

    /// Текст по центру: выравнивание живёт в параграфе стиля, он перекрывает лейбл.
    private static func centered(_ value: String?, _ style: PersonalizationTextStyle, _ color: UIColor) -> NSAttributedString? {
        guard let value else { return nil }
        var attributes = style.attributes
        attributes[.foregroundColor] = color
        let paragraph = (style.paragraphStyle.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        paragraph.alignment = .center
        attributes[.paragraphStyle] = paragraph
        return NSAttributedString(string: value, attributes: attributes)
    }
}

/// Правый блок цены: под пальцем промокод чуть увеличивается.
private final class PromoBlock: UIControl {

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            let scale = isHighlighted ? PersonalizationStoryPrice.pressedScale : 1
            UIView.animate(
                withDuration: 0.15,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction],
                animations: { self.transform = CGAffineTransform(scaleX: scale, y: scale) }
            )
        }
    }
}
