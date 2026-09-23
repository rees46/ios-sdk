import UIKit

/// Инап-попап: карточка с картинкой, заголовком, текстом и кнопками.
///
/// Источник: Figma Mobile SDK UI Kit, страница InAppPopup / Modal (1:33),
/// компонент-сеты In App Popup/Modal (469:2767) и In App Popup/Fullscreen (469:2835).
/// У обоих четыре вида: картинка сверху, картинка фоном, только текст, иконка.
///
/// Позицию на экране (верх/центр/низ/во весь экран) компонент не выбирает — это дело
/// того, кто его показывает; здесь только `presentation`, от которой зависят метрики:
/// у модалки скругление 24 и отступы 20, у полноэкранной скруглений нет и отступы 24,
/// а кегли на ступень крупнее.
///
/// Крестик стоит **всегда** и принадлежит самому попапу, а не контейнеру картинки:
/// в макете виды «только текст» и «иконка» картинки не имеют, но крестик у них нарисован.
/// Он круглый (компонент Close: кнопка MD с радиусом Rounded) и во всех видах лежит поверх
/// содержимого в углу, на отступе попапа; над фотографией — в тёмном варианте.
/// Текстовая кнопка закрытия (`closeText`) в макете не нарисована — её даёт админка
/// отдельным тумблером рядом с кнопкой действия, поэтому она здесь вторичной кнопкой
/// под основной. Пустой текст — кнопки нет, остаётся один крестик.
///
/// Поля и зазор между блоками — семантические отступы Padding/Gap Modal (20) и
/// Padding/Gap Full Screen (24), скругление модалки — радиус Modal, фон — Background/Card,
/// тень модалки — Elevation 3. Скругление и обрезка живут на внутренней карточке,
/// а тень — на самом попапе: обрезка на одном слое с тенью срезала бы её.
@_spi(PersonalizationUI) public final class PersonalizationInAppPopup: UIView {

    /// Вид попапа: чем занято место над текстом.
    public enum ContentView {
        case image, imageBackground, text, icon
    }

    /// Модалка карточкой или во весь экран — от этого зависят метрики.
    public enum Presentation {
        case modal, fullscreen
    }

    public var contentView: ContentView = .image {
        didSet { rebuild() }
    }

    public var presentation: Presentation = .modal {
        didSet { rebuild() }
    }

    public var title: String? {
        didSet { applyText() }
    }

    public var text: String? {
        didSet { applyText() }
    }

    /// Подпись кнопки действия. Пусто — кнопки нет.
    public var actionText: String? {
        didSet { applyButtons() }
    }

    /// Подпись кнопки закрытия. Пусто — остаётся только крестик.
    public var closeText: String? {
        didSet { applyButtons() }
    }

    /// Иконка вида `.icon`.
    public var icon: UIImage? {
        didSet { iconView.image = icon }
    }

    /// Картинку грузит хост — кит не тянет сеть.
    public var imageLoader: ((UIImageView) -> Void)? {
        didSet { imageLoader?(imageTarget) }
    }

    public var onAction: (() -> Void)?
    public var onClose: (() -> Void)?

    private let backgroundImageView = UIImageView()
    private let topImageView = UIImageView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let textLabel = UILabel()
    private let actionButton = PersonalizationButton()
    private let closeButton = PersonalizationButton()
    private let closeIcon = PersonalizationButton()

    /// Карточка: фон, скругление и обрезка; всё содержимое лежит в ней.
    private let surface = UIView()
    /// Второй слой тени Elevation 3: `CALayer` рисует одну тень, первую несёт слой попапа.
    private let secondShadow = CALayer()

    private let column = UIStackView()
    private let card = UIStackView()
    private let textStack = UIStackView()
    private let buttons = UIStackView()
    private var closeIconConstraints: [NSLayoutConstraint] = []

    public init() {
        super.init(frame: .zero)
        setup()
        rebuild()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        rebuild()
    }

    private var imageTarget: UIImageView {
        contentView == .imageBackground ? backgroundImageView : topImageView
    }

    private func setup() {
        surface.clipsToBounds = true
        surface.translatesAutoresizingMaskIntoConstraints = false
        addSubview(surface)
        NSLayoutConstraint.activate([
            surface.topAnchor.constraint(equalTo: topAnchor),
            surface.leadingAnchor.constraint(equalTo: leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: trailingAnchor),
            surface.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        layer.insertSublayer(secondShadow, below: surface.layer)

        for view in [backgroundImageView, topImageView] {
            view.contentMode = .scaleAspectFill
            view.clipsToBounds = true
        }
        iconView.contentMode = .scaleAspectFit

        titleLabel.numberOfLines = 0
        textLabel.numberOfLines = 0

        actionButton.size = .lg
        actionButton.view = .primary
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        closeButton.size = .lg
        closeButton.view = .secondary
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        closeIcon.size = .md
        closeIcon.view = .secondary
        closeIcon.rounded = true
        closeIcon.iconStart = PersonalizationIcons.crossLarge
        closeIcon.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        column.axis = .vertical
        card.axis = .vertical
        textStack.axis = .vertical
        textStack.spacing = PersonalizationSpacing.md
        buttons.axis = .vertical

        for stack in [column, card, textStack, buttons] {
            stack.translatesAutoresizingMaskIntoConstraints = false
        }
        closeIcon.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        // didSet на init не срабатывает: без этого попап без текстов показал бы пустые кнопки.
        applyButtons()
    }

    private func applyButtons() {
        actionButton.text = actionText
        actionButton.isHidden = (actionText ?? "").isEmpty
        closeButton.text = closeText
        closeButton.isHidden = (closeText ?? "").isEmpty
        // Пустой ряд кнопок стек не схлопывает: между ним и текстом остался бы отступ.
        buttons.isHidden = actionButton.isHidden && closeButton.isHidden
    }

    @objc private func actionTapped() { onAction?() }

    @objc private func closeTapped() { onClose?() }

    private func rebuild() {
        surface.subviews.forEach { $0.removeFromSuperview() }
        [column, card, textStack, buttons].forEach { stack in
            stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        }
        NSLayoutConstraint.deactivate(closeIconConstraints)
        closeIconConstraints = []

        let modal = presentation == .modal
        let pad = modal ? PersonalizationSpacing.paddingModal : PersonalizationSpacing.paddingFullScreen
        let gapSection = modal ? PersonalizationSpacing.gapModal : PersonalizationSpacing.gapFullScreen
        let overImage = contentView == .imageBackground

        applyShape(modal: modal)
        applyText()
        // Поверх картинки контролы берут инвертированную палитру, иначе тёмная подпись
        // вторичной кнопки тонет в фотографии. Крестик над фотографией и у вида с картинкой
        // сверху: в макете у него там тёмный режим.
        closeIcon.onDark = overImage || contentView == .image
        closeButton.onDark = overImage

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(textLabel)
        // Между кнопками: 12 у модалки, 16 у полноэкранного.
        buttons.spacing = modal ? PersonalizationSpacing.lg : PersonalizationSpacing.xl
        buttons.addArrangedSubview(actionButton)
        buttons.addArrangedSubview(closeButton)

        switch contentView {
        case .image:
            column.spacing = 0
            column.addArrangedSubview(topImageView)
            card.spacing = modal ? PersonalizationSpacing.xl : PersonalizationSpacing.xl3
            card.isLayoutMarginsRelativeArrangement = true
            card.directionalLayoutMargins = .init(top: pad, leading: pad, bottom: pad, trailing: pad)
            card.addArrangedSubview(textStack)
            card.addArrangedSubview(buttons)
            column.addArrangedSubview(card)
            // Картинка забирает всё, что остаётся над карточкой.
            topImageView.setContentHuggingPriority(UILayoutPriority(1), for: .vertical)
            topImageView.setContentCompressionResistancePriority(UILayoutPriority(1), for: .vertical)

        case .imageBackground:
            surface.addSubview(backgroundImageView)
            NSLayoutConstraint.activate([
                backgroundImageView.topAnchor.constraint(equalTo: surface.topAnchor),
                backgroundImageView.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
                backgroundImageView.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
                backgroundImageView.bottomAnchor.constraint(equalTo: surface.bottomAnchor)
            ])
            column.spacing = gapSection
            column.isLayoutMarginsRelativeArrangement = true
            column.directionalLayoutMargins = .init(top: pad, leading: pad, bottom: pad, trailing: pad)
            // Текст прижат к низу: распорка съедает свободное место сверху. Шага после
            // неё нет — высокий текст начинается сразу на отступе попапа.
            let spacer = UIView()
            spacer.setContentHuggingPriority(UILayoutPriority(1), for: .vertical)
            column.addArrangedSubview(spacer)
            column.setCustomSpacing(0, after: spacer)
            column.addArrangedSubview(textStack)
            column.addArrangedSubview(buttons)

        case .text, .icon:
            column.spacing = gapSection
            column.isLayoutMarginsRelativeArrangement = true
            column.directionalLayoutMargins = .init(top: pad, leading: pad, bottom: pad, trailing: pad)
            let centre = UIStackView()
            centre.axis = .vertical
            centre.alignment = .center
            if contentView == .icon {
                centre.spacing = PersonalizationSpacing.xl3
                let side: CGFloat = modal ? 100 : 120
                iconView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    iconView.widthAnchor.constraint(equalToConstant: side),
                    iconView.heightAnchor.constraint(equalToConstant: side)
                ])
                centre.addArrangedSubview(iconView)
            }
            textStack.translatesAutoresizingMaskIntoConstraints = false
            centre.addArrangedSubview(textStack)
            NSLayoutConstraint.activate([
                textStack.leadingAnchor.constraint(equalTo: centre.leadingAnchor),
                textStack.trailingAnchor.constraint(equalTo: centre.trailingAnchor)
            ])
            // Текст по центру по вертикали: распорки сверху и снизу.
            let top = UIView()
            let bottom = UIView()
            for spacer in [top, bottom] {
                spacer.setContentHuggingPriority(UILayoutPriority(1), for: .vertical)
            }
            column.addArrangedSubview(top)
            column.addArrangedSubview(centre)
            column.addArrangedSubview(bottom)
            column.addArrangedSubview(buttons)
            NSLayoutConstraint.activate([
                top.heightAnchor.constraint(equalTo: bottom.heightAnchor)
            ])
        }

        surface.addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: surface.topAnchor),
            column.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            column.bottomAnchor.constraint(equalTo: surface.bottomAnchor)
        ])

        // Крестик всегда на месте — у видов без картинки тоже, накладкой поверх содержимого.
        surface.addSubview(closeIcon)
        closeIconConstraints = [
            closeIcon.topAnchor.constraint(equalTo: surface.topAnchor, constant: pad),
            closeIcon.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -pad)
        ]
        NSLayoutConstraint.activate(closeIconConstraints)

        imageLoader?(imageTarget)
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
        // cgColor тени не переключается на смену темы сам.
        applyShadow()
    }

    private func applyText() {
        let modal = presentation == .modal
        // У видов без картинки текст в макете по центру, с картинкой — по левому краю.
        let centred = contentView == .text || contentView == .icon
        let overImage = contentView == .imageBackground

        let titleStyle = modal
            ? PersonalizationTypography.xl3Emphasized
            : PersonalizationTypography.xl4Emphasized
        let textStyle = modal ? PersonalizationTypography.lgDefault : PersonalizationTypography.xl2Default

        render(
            titleLabel,
            text: title,
            style: titleStyle,
            color: overImage ? PersonalizationColor.textLightPrimary : PersonalizationColor.textPrimary,
            centred: centred
        )
        render(
            textLabel,
            text: text,
            style: textStyle,
            color: overImage ? PersonalizationColor.textLightSecondary : PersonalizationColor.textSecondary,
            centred: centred
        )
    }

    /// Цвет и выравнивание кладутся в атрибуты, а не на лейбл: интерлиньяж доезжает
    /// только через `attributedText`, и заданный отдельно `textColor` он бы перекрыл.
    private func render(
        _ label: UILabel,
        text: String?,
        style: PersonalizationTextStyle,
        color: UIColor,
        centred: Bool
    ) {
        let value = text ?? ""
        label.isHidden = value.isEmpty
        var attributes = style.attributes
        attributes[.foregroundColor] = color
        if let paragraph = (attributes[.paragraphStyle] as? NSParagraphStyle)?
            .mutableCopy() as? NSMutableParagraphStyle {
            paragraph.alignment = centred ? .center : .natural
            attributes[.paragraphStyle] = paragraph
        }
        label.attributedText = NSAttributedString(string: value, attributes: attributes)
    }

    private func applyShape(modal: Bool) {
        surface.backgroundColor = PersonalizationColor.backgroundCard
        surface.layer.cornerRadius = modal ? PersonalizationRadius.modal : 0
        card.backgroundColor = PersonalizationColor.backgroundCard
        applyShadow()
        setNeedsLayout()
    }

    /// Тень Elevation 3 у модалки, у полноэкранного тени нет. Два слоя макета: первый
    /// на слое попапа, второй на подслое под карточкой.
    private func applyShadow() {
        let shadows = presentation == .modal ? PersonalizationElevation.e3 : PersonalizationElevation.none
        for (index, target) in [layer, secondShadow].enumerated() {
            if index < shadows.count {
                shadows[index].apply(to: target)
            } else {
                target.shadowOpacity = 0
            }
        }
    }
}
