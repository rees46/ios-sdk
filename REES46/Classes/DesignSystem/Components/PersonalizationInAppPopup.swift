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
/// Текстовая кнопка закрытия (`closeText`) в макете не нарисована — её даёт админка
/// отдельным тумблером рядом с кнопкой действия, поэтому она здесь вторичной кнопкой
/// под основной. Пустой текст — кнопки нет, остаётся один крестик.
///
/// Отступ 20 у модалки и интерлиньяж 48 у полноэкранного заголовка вне шкал кита —
/// взяты из макета как есть.
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
        didSet {
            actionButton.text = actionText
            actionButton.isHidden = (actionText ?? "").isEmpty
        }
    }

    /// Подпись кнопки закрытия. Пусто — остаётся только крестик.
    public var closeText: String? {
        didSet {
            closeButton.text = closeText
            closeButton.isHidden = (closeText ?? "").isEmpty
        }
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
        clipsToBounds = true

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
        closeIcon.iconStart = PersonalizationIcons.crossLarge
        closeIcon.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        column.axis = .vertical
        card.axis = .vertical
        textStack.axis = .vertical
        textStack.spacing = PersonalizationSpacing.md
        buttons.axis = .vertical
        buttons.spacing = PersonalizationSpacing.md

        for stack in [column, card, textStack, buttons] {
            stack.translatesAutoresizingMaskIntoConstraints = false
        }
        closeIcon.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
    }

    @objc private func actionTapped() { onAction?() }

    @objc private func closeTapped() { onClose?() }

    private func rebuild() {
        subviews.forEach { $0.removeFromSuperview() }
        [column, card, textStack, buttons].forEach { stack in
            stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        }
        NSLayoutConstraint.deactivate(closeIconConstraints)
        closeIconConstraints = []

        let modal = presentation == .modal
        let pad: CGFloat = modal ? 20 : PersonalizationSpacing.xl2
        let gapSection: CGFloat = modal ? 20 : PersonalizationSpacing.xl2
        let overImage = contentView == .imageBackground

        applyShape(modal: modal)
        applyText()
        closeIcon.onDark = overImage
        closeButton.onDark = overImage

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(textLabel)
        buttons.addArrangedSubview(actionButton)
        buttons.addArrangedSubview(closeButton)

        switch contentView {
        case .image:
            column.spacing = 0
            column.addArrangedSubview(topImageView)
            card.spacing = modal ? PersonalizationSpacing.xl : PersonalizationSpacing.xl2
            card.isLayoutMarginsRelativeArrangement = true
            card.directionalLayoutMargins = .init(top: pad, leading: pad, bottom: pad, trailing: pad)
            card.addArrangedSubview(textStack)
            card.addArrangedSubview(buttons)
            column.addArrangedSubview(card)
            // Картинка забирает всё, что остаётся над карточкой.
            topImageView.setContentHuggingPriority(UILayoutPriority(1), for: .vertical)
            topImageView.setContentCompressionResistancePriority(UILayoutPriority(1), for: .vertical)

        case .imageBackground:
            addSubview(backgroundImageView)
            NSLayoutConstraint.activate([
                backgroundImageView.topAnchor.constraint(equalTo: topAnchor),
                backgroundImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
                backgroundImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
                backgroundImageView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            column.spacing = gapSection
            column.isLayoutMarginsRelativeArrangement = true
            column.directionalLayoutMargins = .init(top: pad, leading: pad, bottom: pad, trailing: pad)
            // Здесь крестик не накладкой, а первой строкой: в макете он занимает свою
            // строку, иначе заголовок заезжает под него.
            let closeRow = UIView()
            closeRow.addSubview(closeIcon)
            NSLayoutConstraint.activate([
                closeIcon.topAnchor.constraint(equalTo: closeRow.topAnchor),
                closeIcon.bottomAnchor.constraint(equalTo: closeRow.bottomAnchor),
                closeIcon.trailingAnchor.constraint(equalTo: closeRow.trailingAnchor)
            ])
            column.addArrangedSubview(closeRow)
            // Текст прижат к низу: распорка съедает свободное место сверху.
            let spacer = UIView()
            spacer.setContentHuggingPriority(UILayoutPriority(1), for: .vertical)
            column.addArrangedSubview(spacer)
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
                centre.spacing = PersonalizationSpacing.xl2
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

        addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor),
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Крестик всегда на месте — у видов без картинки тоже. У фона-картинки он уже
        // стоит в колонке, здесь накладкой поверх содержимого.
        if !overImage {
            addSubview(closeIcon)
            closeIconConstraints = [
                closeIcon.topAnchor.constraint(equalTo: topAnchor, constant: pad),
                closeIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad)
            ]
            NSLayoutConstraint.activate(closeIconConstraints)
        }

        imageLoader?(imageTarget)
    }

    private func applyText() {
        let modal = presentation == .modal
        // У видов без картинки текст в макете по центру, с картинкой — по левому краю.
        let centred = contentView == .text || contentView == .icon
        let overImage = contentView == .imageBackground

        // Полноэкранный заголовок в макете 36/48, а ступень 4XL кита — 36/52:
        // кегль с одной ступени, интерлиньяж с другой, как и в остальном файле.
        let titleStyle = modal
            ? PersonalizationTypography.xl3Emphasized
            : PersonalizationTextStyle(size: 36, lineHeight: 48, tracking: -0.5, weight: .semibold)
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
        // Background/Modal, а не Card: в светлой они совпадают (белый), в тёмной у модалки
        // своя ступень. В Figma компонент привязан к Card, но значение Card в ките отстало
        // от файла (там уже белый) — ресинк цветов отдельной задачей.
        backgroundColor = PersonalizationColor.backgroundModal
        layer.cornerRadius = modal ? PersonalizationRadius.xl6 : 0
        card.backgroundColor = PersonalizationColor.backgroundModal
    }
}
