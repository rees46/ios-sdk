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
@_spi(PersonalizationUI) public final class PersonalizationStoryNavigation: UIView {

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

    /// Шапка медиа-слайда: тёмные токены и на iOS 12, где тему поддерева не переопределить.
    var forcesDarkTokens = false {
        didSet {
            let tint = PersonalizationStoryColors.token(PersonalizationColor.textSecondary, forcingDark: forcesDarkTokens)
            closeButton.tintColor = tint
            shareButton.tintColor = tint
            progress.forcesDarkTokens = forcesDarkTokens
        }
    }

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
