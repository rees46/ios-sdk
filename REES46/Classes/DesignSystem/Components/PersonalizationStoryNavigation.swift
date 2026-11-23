import UIKit

/// Шапка просмотрщика сторис: прогресс, «Поделиться» и крестик.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), компонент Navigation/Story.
/// Колонка с шагом 12: `PersonalizationStoryProgress` и строка высотой 32 с крестиком
/// у правого края. Крестик 32x32 с глифом 18 (иконка `cross`), цвет Text/Secondary,
/// прозрачность 65%.
///
/// «Поделиться» (иконка `share`, из веба — в Figma её нет) — соседка крестика слева, через 8,
/// той же коробки, цвета и прозрачности, без фона. Видна, только если у слайда есть ссылка.
///
/// Цвета берутся из темы вью: на медиа-слайде просмотрщик включает тёмную тему,
/// и шапка становится светлой сама.
public final class PersonalizationStoryNavigation: UIView {

    /// Высота шапки: полоски, шаг и строка крестика.
    public static let height: CGFloat = PersonalizationStoryProgress.height + PersonalizationSpacing.lg + closeSide

    private static let closeSide: CGFloat = 32
    private static let closeOpacity: CGFloat = 0.65

    public let progress = PersonalizationStoryProgress()

    /// Нажатие на крестик.
    public var onClose: (() -> Void)?

    /// Подпись крестика для VoiceOver.
    public var closeLabel: String? = "Close" {
        didSet { closeButton.accessibilityLabel = closeLabel }
    }

    /// Нажатие на «Поделиться».
    public var onShare: (() -> Void)?

    /// Подпись «Поделиться» для VoiceOver.
    public var shareLabel: String? = "Share" {
        didSet { shareButton.accessibilityLabel = shareLabel }
    }

    /// Кнопка «Поделиться» видна; по умолчанию скрыта.
    public var isShareVisible: Bool {
        get { !shareButton.isHidden }
        set { shareButton.isHidden = !newValue }
    }

    /// Откуда показывать окно «Поделиться» на iPad.
    var shareAnchor: UIView { shareButton }

    private let closeButton = UIButton(type: .custom)
    private let shareButton = UIButton(type: .custom)

    public init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Иконка 32 с глифом 18 — ровно крестик из макета, без масштабирования.
        closeButton.setImage(PersonalizationIcons.cross, for: .normal)
        closeButton.accessibilityLabel = closeLabel
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        // «Поделиться» — глиф той же величины в той же коробке.
        shareButton.setImage(PersonalizationIcons.share, for: .normal)
        shareButton.accessibilityLabel = shareLabel
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        shareButton.isHidden = true
        for button in [closeButton, shareButton] {
            button.imageView?.contentMode = .scaleAspectFit
            button.tintColor = PersonalizationColor.textSecondary
            button.alpha = Self.closeOpacity
        }

        progress.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progress)
        addSubview(closeButton)
        addSubview(shareButton)

        NSLayoutConstraint.activate([
            progress.topAnchor.constraint(equalTo: topAnchor),
            progress.leadingAnchor.constraint(equalTo: leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: trailingAnchor),
            progress.heightAnchor.constraint(equalToConstant: PersonalizationStoryProgress.height),
            closeButton.topAnchor.constraint(equalTo: progress.bottomAnchor, constant: PersonalizationSpacing.lg),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: Self.closeSide),
            closeButton.heightAnchor.constraint(equalToConstant: Self.closeSide),
            closeButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            shareButton.topAnchor.constraint(equalTo: closeButton.topAnchor),
            shareButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -PersonalizationSpacing.md),
            shareButton.widthAnchor.constraint(equalToConstant: Self.closeSide),
            shareButton.heightAnchor.constraint(equalToConstant: Self.closeSide)
        ])
    }

    @objc private func closeTapped() {
        onClose?()
    }

    @objc private func shareTapped() {
        onShare?()
    }
}

/// Шапка слайда — элемент `header` ленты API v3, как в вебе: иконка, заголовок и подзаголовок
/// в одну строку; нажатие — `click` и ссылка шапки (без ссылки — только `click`). Вид — кита,
/// одинаковый у четырёх SDK: круглая иконка 40, шаг 12 до текстов, заголовок — мелкий основной
/// текст кита (SM/Emphasized), подзаголовок — подпись (XS/Default) цвета Text/Secondary; цвета —
/// из темы слайда (на медиа светлые). Стоит под строкой навигации.
final class PersonalizationStoryHeaderView: UIControl {

    static let iconSide: CGFloat = 40
    /// Шаг от иконки до текстов.
    static let gap = PersonalizationSpacing.lg  // 12

    let header: PersonalizationStorySlide.Header
    let icon = UIImageView()
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()

    init(header: PersonalizationStorySlide.Header, imageLoader: ((UIImageView, String) -> Void)?) {
        self.header = header
        super.init(frame: .zero)
        icon.contentMode = .scaleAspectFill
        icon.clipsToBounds = true
        icon.layer.cornerRadius = Self.iconSide / 2
        icon.backgroundColor = PersonalizationColor.neutral50
        icon.isHidden = header.iconUrl == nil
        PersonalizationStoryImages.load(into: icon, url: header.iconUrl, loader: imageLoader)
        PersonalizationTypography.smEmphasized.apply(to: titleLabel, text: header.title)
        titleLabel.textColor = PersonalizationColor.textPrimary
        titleLabel.isHidden = header.title == nil
        PersonalizationTypography.xsDefault.apply(to: subtitleLabel, text: header.subtitle)
        subtitleLabel.textColor = PersonalizationColor.textSecondary
        subtitleLabel.isHidden = header.subtitle == nil
        for label in [titleLabel, subtitleLabel] {
            label.numberOfLines = 1
            label.lineBreakMode = .byTruncatingTail
        }
        let texts = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        texts.axis = .vertical
        let row = UIStackView(arrangedSubviews: [icon, texts])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Self.gap
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: Self.iconSide),
            icon.heightAnchor.constraint(equalToConstant: Self.iconSide),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        isAccessibilityElement = true
        accessibilityTraits = header.link == nil ? .staticText : .link
        accessibilityLabel = [header.title, header.subtitle].compactMap { $0 }.joined(separator: ", ")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }
}
