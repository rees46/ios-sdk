import UIKit

/// Карта лояльности в духе пропуска Apple Wallet.
///
/// Источник: Figma Mobile SDK UI Kit, страница Loyalty (1:34), фреймы Wallet/iOS/Light Theme
/// (570:9879) и Wallet/iOS/Dark Theme (570:10131); компонент Wallet (570:9111) в секции Card
/// страницы Components. Части: шапка с Wallet/Logo (570:9034) и балансом из набора полей
/// Wallet (559:8973), лента Wallet/Stripe (520:8923) со штампами Wallet/Stamps (570:10384),
/// поля Wallet/Info (570:9081) и штрихкод Wallet/Code (520:8886).
///
/// Данных SDK карта не берёт: статус программы (`getLoyaltyStatus`) отдаёт только участие
/// и уровень, ни баланса, ни штампов, ни номера карты в нём нет. Всё, что на карте, передаёт
/// хост. Форма вступления из той же страницы макета не нарисована.
///
/// Пропорции пропуска 370×560: ширину задаёт разметка, высота не меньше ширины × 560/370
/// и растёт, если содержимому тесно. Секции идут без зазоров сверху вниз, штрихкод прижат
/// к низу — свободное место остаётся над ним. Пустая секция скрыта целиком.
///
/// Скругление — 2XL (12), содержимое обрезано по нему; фон — Background/Card или
/// `cardColor`; текст — Text/Primary или `contentColor` (только подписи и значения,
/// логотип — картинка хоста, кит его не красит). Обводка 1 внутрь — Line/Generic Subtle,
/// тень — Elevation 3. Как у инап-попапа, тень на самой карте, а скругление и обрезка —
/// на внутренней подложке: обрезка на одном слое с тенью срезала бы её.
///
/// Картинки (логотип, лента, эмблема уровня) грузит хост — кит не тянет сеть. Карта отдаёт
/// загрузчику `UIImageView` и сама замечает, когда в нём появилась картинка: от неё
/// зависят видимость секций и ширина логотипа.
@_spi(PersonalizationUI) public final class PersonalizationLoyaltyCard: UIView {

    /// Поле секции Info: подпись и значение — «Владелец» / «Олег».
    public struct Field: Equatable {
        public var label: String
        public var value: String

        public init(label: String, value: String) {
            self.label = label
            self.value = value
        }
    }

    /// Фон карты. `nil` — Background/Card. В тёмном примере макета — фирменный синий
    /// (#0087E8, Semantic/Info), такого токена у кита нет, его передаёт хост.
    public var cardColor: UIColor? {
        didSet { applyColors() }
    }

    /// Цвет подписей и значений. `nil` — Text/Primary.
    public var contentColor: UIColor? {
        didSet { applyText() }
    }

    /// Подпись баланса в шапке — «Бонусы». Выводится капсом.
    public var balanceLabel: String? {
        didSet { applyText() }
    }

    /// Значение баланса — «50 550». Строка приходит отформатированной.
    public var balanceValue: String? {
        didSet { applyText() }
    }

    /// Поля секции Info по порядку, делят ширину поровну. Пусто — секции нет.
    /// Тумблер Show Owner из макета — это просто поле владельца, которое хост не передал.
    public var fields: [Field] = [] {
        didSet { rebuildFields() }
    }

    /// Собранные штампы: первые `stamps` из `stampsTotal` закрашены. Обрезается до 0…stampsTotal.
    public var stamps: Int = 0 {
        didSet { applyStamps() }
    }

    /// Сколько штампов всего. 0 — ряда штампов нет.
    public var stampsTotal: Int = 0 {
        didSet { applyStamps() }
    }

    /// Номер карты для штрихкода Code 128. Пусто или не кодируется — секции штрихкода нет,
    /// а карта всё равно держит пропорции пропуска.
    public var code: String? {
        didSet { applyCode() }
    }

    /// Логотип в шапке: высота 33, ширина по пропорциям картинки.
    public var logoLoader: ((UIImageView) -> Void)? {
        didSet { load(logoView, with: logoLoader) }
    }

    /// Картинка ленты, заполняет её с обрезкой.
    public var stripeLoader: ((UIImageView) -> Void)? {
        didSet { load(stripe.imageView, with: stripeLoader) }
    }

    /// Эмблема уровня поверх ленты справа, выходит за её край и обрезается.
    public var emblemLoader: ((UIImageView) -> Void)? {
        didSet { load(stripe.emblemView, with: emblemLoader) }
    }

    // Секции не приватные — их видимость и геометрию проверяют тесты.
    let header = UIStackView()
    let logoView = ImageSlot()
    let stripe = Stripe()
    let info = UIStackView()
    let codeSection = UIView()

    private let balance = UIStackView()
    private let barcode = PersonalizationBarcode()
    private let balanceLabelView = UILabel()
    private let balanceValueView = UILabel()
    private var fieldViews: [(label: UILabel, value: UILabel)] = []
    private let codeBox = UIView()
    /// Высота 33 и ширина по пропорциям — только пока логотип есть.
    private var logoConstraints: [NSLayoutConstraint] = []

    private let column = UIStackView()
    /// Свободное место — над штрихкодом: распорка забирает его, штрихкод остаётся внизу.
    private let filler = PersonalizationFlexibleSpace(axis: .vertical)

    /// Подложка: фон, скругление, обводка и обрезка; всё содержимое лежит в ней.
    private let surface = UIView()
    /// Второй слой тени Elevation 3: `CALayer` рисует одну тень, первую несёт слой карты.
    private let secondShadow = CALayer()

    public init() {
        super.init(frame: .zero)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        surface.clipsToBounds = true
        surface.layer.borderWidth = 1
        surface.translatesAutoresizingMaskIntoConstraints = false
        addSubview(surface)
        layer.insertSublayer(secondShadow, below: surface.layer)

        setupHeader()
        setupInfo()
        setupCode()

        column.axis = .vertical
        column.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(column)

        // Пропорции пропуска: высота не меньше ширины × 560/370. Равенство слабее сжатия
        // текста, поэтому высокое содержимое карту растягивает, а низкое — нет.
        let ratio: CGFloat = 560.0 / 370.0
        let natural = heightAnchor.constraint(equalTo: widthAnchor, multiplier: ratio)
        natural.priority = .defaultLow
        NSLayoutConstraint.activate([
            surface.topAnchor.constraint(equalTo: topAnchor),
            surface.leadingAnchor.constraint(equalTo: leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: trailingAnchor),
            surface.bottomAnchor.constraint(equalTo: bottomAnchor),
            column.topAnchor.constraint(equalTo: surface.topAnchor),
            column.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            column.bottomAnchor.constraint(equalTo: surface.bottomAnchor),
            // Лента Apple Wallet — 375×144, в макете 368×141.5: высота — ширина / 2.6.
            stripe.heightAnchor.constraint(equalTo: stripe.widthAnchor, multiplier: 1 / 2.6),
            heightAnchor.constraint(greaterThanOrEqualTo: widthAnchor, multiplier: ratio),
            natural
        ])

        for slot in [logoView, stripe.imageView, stripe.emblemView] {
            slot.onChange = { [weak self] in self?.applyImages() }
        }

        applyColors()
        rebuildFields()
        applyStamps()
        applyCode()
        applyImages()
    }

    private func setupHeader() {
        logoView.contentMode = .scaleAspectFit
        logoView.translatesAutoresizingMaskIntoConstraints = false

        for label in [balanceLabelView, balanceValueView] {
            label.numberOfLines = 1
            label.lineBreakMode = .byTruncatingTail
        }
        balance.axis = .vertical
        balance.addArrangedSubview(balanceLabelView)
        balance.addArrangedSubview(balanceValueView)

        // Логотип у начала, баланс у конца: распорка между ними забирает лишнюю ширину.
        header.axis = .horizontal
        header.alignment = .center
        header.addArrangedSubview(logoView)
        header.addArrangedSubview(PersonalizationFlexibleSpace())
        header.addArrangedSubview(balance)
        // В макете между ними зазора нет — баланс просто занимает остаток. MD (8) — чтобы
        // длинный баланс не упёрся в логотип.
        header.setCustomSpacing(PersonalizationSpacing.md, after: logoView)
        header.isLayoutMarginsRelativeArrangement = true
        // Поля — ровно 16: без этого карта под статус-баром прибавила бы к ним безопасную зону.
        header.insetsLayoutMarginsFromSafeArea = false
        let pad = PersonalizationSpacing.xl  // 16
        header.directionalLayoutMargins = .init(top: pad, leading: pad, bottom: pad, trailing: pad)
    }

    private func setupInfo() {
        info.axis = .horizontal
        info.distribution = .fillEqually
        info.spacing = PersonalizationSpacing.gapModal  // 20
        info.isLayoutMarginsRelativeArrangement = true
        info.insetsLayoutMarginsFromSafeArea = false
        let pad = PersonalizationSpacing.xl  // 16
        info.directionalLayoutMargins = .init(top: pad, leading: pad, bottom: pad, trailing: pad)
    }

    private func setupCode() {
        // Подложка штрихкода белая в обеих темах: сканеру нужен белый фон, поэтому это
        // константа Brand/White, а не токен темы.
        codeBox.backgroundColor = .white
        codeBox.layer.cornerRadius = PersonalizationRadius.lg  // 8
        codeBox.layer.borderWidth = 1
        codeBox.translatesAutoresizingMaskIntoConstraints = false
        barcode.translatesAutoresizingMaskIntoConstraints = false
        codeBox.addSubview(barcode)
        codeSection.addSubview(codeBox)

        let box = PersonalizationSpacing.xl2   // 20
        let vertical = PersonalizationSpacing.xl3  // 24
        let side = PersonalizationSpacing.xl   // 16
        NSLayoutConstraint.activate([
            barcode.topAnchor.constraint(equalTo: codeBox.topAnchor, constant: box),
            barcode.bottomAnchor.constraint(equalTo: codeBox.bottomAnchor, constant: -box),
            barcode.leadingAnchor.constraint(equalTo: codeBox.leadingAnchor, constant: box),
            barcode.trailingAnchor.constraint(equalTo: codeBox.trailingAnchor, constant: -box),
            codeBox.topAnchor.constraint(equalTo: codeSection.topAnchor, constant: vertical),
            codeBox.bottomAnchor.constraint(equalTo: codeSection.bottomAnchor, constant: -vertical),
            codeBox.centerXAnchor.constraint(equalTo: codeSection.centerXAnchor),
            codeBox.leadingAnchor.constraint(greaterThanOrEqualTo: codeSection.leadingAnchor, constant: side)
        ])
    }

    private func load(_ slot: UIImageView, with loader: ((UIImageView) -> Void)?) {
        slot.image = nil
        loader?(slot)
    }

    // MARK: - Содержимое

    private func applyText() {
        // Баланс прижат к концу строки: в письме справа налево это левый край.
        let trailing: NSTextAlignment = effectiveUserInterfaceLayoutDirection == .rightToLeft ? .left : .right
        render(balanceLabelView, balanceLabel?.uppercased(), style: Self.captionStyle, alignment: trailing)
        render(balanceValueView, balanceValue, style: Self.balanceStyle, alignment: trailing)
        balance.isHidden = balanceLabelView.isHidden && balanceValueView.isHidden

        for (field, views) in zip(fields, fieldViews) {
            render(views.label, field.label.uppercased(), style: Self.captionStyle, alignment: .natural)
            render(views.value, field.value, style: Self.fieldStyle, alignment: .natural)
        }
        applyVisibility()
    }

    private func rebuildFields() {
        info.arrangedSubviews.forEach { info.removeArrangedSubview($0); $0.removeFromSuperview() }
        fieldViews = fields.map { _ in
            let label = UILabel()
            let value = UILabel()
            let column = UIStackView(arrangedSubviews: [label, value])
            column.axis = .vertical
            info.addArrangedSubview(column)
            return (label, value)
        }
        applyText()
    }

    private func applyStamps() {
        let total = max(0, stampsTotal)
        let filled = min(max(0, stamps), total)
        stripe.setStamps(filled: filled, total: total)
        applyImages()
    }

    private func applyCode() {
        barcode.code = code
        applyVisibility()
    }

    /// Картинки хоста приходят когда угодно: от них зависят видимость логотипа, шапки,
    /// ленты и ширина логотипа.
    private func applyImages() {
        NSLayoutConstraint.deactivate(logoConstraints)
        logoConstraints = []
        if let size = logoView.image?.size, size.height > 0 {
            // Ширина чуть слабее обязательной: на очень узкой карте логотип ужмётся
            // (картинка вписывается с сохранением пропорций), а не сломает разметку.
            let width = logoView.widthAnchor.constraint(equalTo: logoView.heightAnchor, multiplier: size.width / size.height)
            width.priority = .required - 1
            logoConstraints = [logoView.heightAnchor.constraint(equalToConstant: 33), width]
            NSLayoutConstraint.activate(logoConstraints)
        }
        logoView.isHidden = logoConstraints.isEmpty
        stripe.setNeedsLayout()
        applyVisibility()
    }

    /// Пустые секции не прячутся в колонке, а вынимаются из неё: у скрытой вью стек
    /// обнуляет высоту обязательным ограничением, и оно спорило бы с полями секций
    /// и пропорцией ленты.
    private func applyVisibility() {
        let sections: [(view: UIView, visible: Bool)] = [
            (header, !logoView.isHidden || !balance.isHidden),
            // Лента есть, когда на ней есть что показать: картинка, эмблема или штампы.
            (stripe, stripe.imageView.image != nil || stripe.emblemView.image != nil || stampsTotal > 0),
            (info, !fields.isEmpty),
            (filler, true),
            (codeSection, barcode.hasBars)
        ]
        for section in sections {
            section.view.isHidden = !section.visible
        }
        let shown = sections.filter { $0.visible }.map { $0.view }
        guard shown != column.arrangedSubviews else { return }
        column.arrangedSubviews.forEach { column.removeArrangedSubview($0); $0.removeFromSuperview() }
        shown.forEach(column.addArrangedSubview)
    }

    /// Цвет и выравнивание кладутся в атрибуты, а не на лейбл: интерлиньяж доезжает
    /// только через `attributedText`, и заданный отдельно `textColor` он бы перекрыл.
    private func render(_ label: UILabel, _ text: String?, style: PersonalizationTextStyle, alignment: NSTextAlignment) {
        let value = text ?? ""
        label.isHidden = value.isEmpty
        label.numberOfLines = 1
        var attributes = style.attributes
        attributes[.foregroundColor] = contentColor ?? PersonalizationColor.textPrimary
        let paragraph = (style.paragraphStyle.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        paragraph.alignment = alignment
        // Одна строка с многоточием: без этого перенос по словам из параграфа просто срежет хвост.
        paragraph.lineBreakMode = .byTruncatingTail
        attributes[.paragraphStyle] = paragraph
        label.attributedText = NSAttributedString(string: value, attributes: attributes)
    }

    // MARK: - Форма и тень

    private func applyColors() {
        surface.backgroundColor = cardColor ?? PersonalizationColor.backgroundCard
        surface.layer.cornerRadius = PersonalizationRadius.xl2  // 12
        applyLayerColors()
        setNeedsLayout()
    }

    /// cgColor динамический цвет не отслеживает — обводки и тень перекрашиваются
    /// при смене темы отсюда.
    private func applyLayerColors() {
        surface.layer.borderColor = PersonalizationColor.lineGenericSubtle.cgColor
        codeBox.layer.borderColor = PersonalizationColor.lineGenericSubtle.cgColor
        let shadows = PersonalizationElevation.e3
        for (index, target) in [layer, secondShadow].enumerated() where index < shadows.count {
            shadows[index].apply(to: target)
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        // Форма тени задана явно: без shadowPath слой вычислял бы её по альфе содержимого
        // на каждом кадре. Подслой второй тени — не view, его рамку двигаем сами.
        let path = UIBezierPath(
            roundedRect: CGRect(origin: .zero, size: bounds.size),
            cornerRadius: surface.layer.cornerRadius
        ).cgPath
        layer.shadowPath = path
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        secondShadow.frame = bounds
        secondShadow.shadowPath = path
        CATransaction.commit()
    }

    public override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        applyLayerColors()
        if previous?.layoutDirection != traitCollection.layoutDirection { applyText() }
    }

    // MARK: - Стили

    /// Подпись баланса и полей: 11/14 SemiBold, трекинг +0.04 em, капсом.
    private static let captionStyle = PersonalizationTextStyle(size: 11, lineHeight: 14, tracking: 11 * 0.04, weight: .semibold)

    /// Значение баланса: 24/24 Regular, трекинг −0.05 em.
    private static let balanceStyle = PersonalizationTextStyle(size: 24, lineHeight: 24, tracking: 24 * -0.05, weight: .regular)

    /// Значение поля: 28/32 Regular, трекинг −0.05 em.
    private static let fieldStyle = PersonalizationTextStyle(size: 28, lineHeight: 32, tracking: 28 * -0.05, weight: .regular)

    // MARK: - Части

    /// Картинка, о смене которой карта узнаёт сама: хост кладёт её загрузчиком когда угодно.
    final class ImageSlot: UIImageView {
        var onChange: (() -> Void)?

        override var image: UIImage? {
            didSet { onChange?() }
        }
    }

    /// Лента: снизу вверх — чёрная подложка, картинка хоста с обрезкой, затемнение 30%,
    /// эмблема уровня и ряд штампов. Всё, что выходит за ленту, обрезается.
    ///
    /// Лента в макете всегда в тёмном режиме, поэтому штампы красятся постоянными светлыми
    /// токенами: собранные — Text/Light Secondary (белый 80%), остальные — Text/Light Hint
    /// (белый 50%).
    final class Stripe: UIView {
        let imageView = ImageSlot()
        let emblemView = ImageSlot()
        let stampsRow = UIStackView()
        private let scrim = UIView()

        override init(frame: CGRect) {
            super.init(frame: frame)
            setup()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setup()
        }

        private func setup() {
            clipsToBounds = true
            // Подложка под картинкой — чёрная константа: лента в макете тёмная в обеих темах.
            backgroundColor = .black
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            // Затемнение — чёрный 30%, тоже константа: светлые штампы должны читаться поверх фото.
            scrim.backgroundColor = UIColor.black.withAlphaComponent(0.3)
            emblemView.contentMode = .scaleAspectFit

            stampsRow.axis = .horizontal
            stampsRow.alignment = .center
            // Поровну: если штампы не влезают в узкую ленту, все ужимаются одинаково.
            stampsRow.distribution = .fillEqually
            stampsRow.spacing = PersonalizationSpacing.md  // 8

            for view in [imageView, scrim] {
                view.translatesAutoresizingMaskIntoConstraints = false
                addSubview(view)
                NSLayoutConstraint.activate([
                    view.topAnchor.constraint(equalTo: topAnchor),
                    view.leadingAnchor.constraint(equalTo: leadingAnchor),
                    view.trailingAnchor.constraint(equalTo: trailingAnchor),
                    view.bottomAnchor.constraint(equalTo: bottomAnchor)
                ])
            }
            // Эмблема раскладывается рамкой в layoutSubviews: её место считается от высоты ленты.
            addSubview(emblemView)
            stampsRow.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stampsRow)
            let side = PersonalizationSpacing.xl  // 16
            NSLayoutConstraint.activate([
                stampsRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: side),
                stampsRow.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -side),
                stampsRow.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        }

        func setStamps(filled: Int, total: Int) {
            stampsRow.arrangedSubviews.forEach { stampsRow.removeArrangedSubview($0); $0.removeFromSuperview() }
            for index in 0..<total {
                let stamp = UIImageView()
                let collected = index < filled
                stamp.image = collected ? PersonalizationIcons.checkRosetteFill : PersonalizationIcons.rosette
                stamp.tintColor = collected ? PersonalizationColor.textLightSecondary : PersonalizationColor.textLightHint
                stamp.contentMode = .scaleAspectFit
                stamp.translatesAutoresizingMaskIntoConstraints = false
                let width = stamp.widthAnchor.constraint(equalToConstant: 32)
                width.priority = .required - 1
                NSLayoutConstraint.activate([width, stamp.heightAnchor.constraint(equalToConstant: 32)])
                stampsRow.addArrangedSubview(stamp)
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            layoutEmblem()
        }

        /// Эмблема высотой 1.4545 высоты ленты, ширина по пропорциям картинки; правый край
        /// выходит за ленту на 0.17 её высоты, верх — на 0.1166 выше ленты. Это геометрия
        /// макета: 179.5×205.8 в точке (212.5, −16.5) на ленте 368×141.5.
        private func layoutEmblem() {
            guard let size = emblemView.image?.size, size.height > 0 else {
                emblemView.frame = .zero
                return
            }
            let stripeHeight = bounds.height
            let height = stripeHeight * 1.4545
            let width = height * size.width / size.height
            let overhang = stripeHeight * 0.17
            // В письме справа налево штампы у правого края — эмблема уходит к левому.
            let x = effectiveUserInterfaceLayoutDirection == .rightToLeft
                ? -overhang
                : bounds.width + overhang - width
            emblemView.frame = CGRect(x: x, y: -stripeHeight * 0.1166, width: width, height: height)
        }
    }
}
