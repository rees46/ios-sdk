import UIKit

/// Шапка просмотрщика сторис: прогресс и крестик.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), компонент Navigation/Story.
/// Колонка с шагом 12: `PersonalizationStoryProgress` и строка высотой 32 с крестиком
/// у правого края. Крестик 32x32 с глифом 18 (иконка `cross`), цвет Text/Secondary,
/// прозрачность 65%.
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

    /// Шапка медиа-слайда: тёмные токены и на iOS 12, где тему поддерева не переопределить.
    var forcesDarkTokens = false {
        didSet {
            closeButton.tintColor = PersonalizationStoryColors.token(PersonalizationColor.textSecondary, forcingDark: forcesDarkTokens)
            progress.forcesDarkTokens = forcesDarkTokens
        }
    }

    private let closeButton = UIButton(type: .custom)

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
        closeButton.imageView?.contentMode = .scaleAspectFit
        closeButton.tintColor = PersonalizationColor.textSecondary
        closeButton.alpha = Self.closeOpacity
        closeButton.accessibilityLabel = closeLabel
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        progress.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progress)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            progress.topAnchor.constraint(equalTo: topAnchor),
            progress.leadingAnchor.constraint(equalTo: leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: trailingAnchor),
            progress.heightAnchor.constraint(equalToConstant: PersonalizationStoryProgress.height),
            closeButton.topAnchor.constraint(equalTo: progress.bottomAnchor, constant: PersonalizationSpacing.lg),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: Self.closeSide),
            closeButton.heightAnchor.constraint(equalToConstant: Self.closeSide),
            closeButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc private func closeTapped() {
        onClose?()
    }
}
