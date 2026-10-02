import UIKit

/// Кнопка звука видео-слайда сторис.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), видео-слайды: иконка
/// `speaker` / `speakerOff` 32, цвет Text/Secondary, без подложки. В просмотрщике стоит
/// в левом нижнем углу — в ряду Used Products или одна.
///
/// Нажатие переключает `isMuted`, шлёт `.valueChanged` и зовёт `onToggle` с новым значением.
/// VoiceOver называет текущее состояние звука, а не действие: кнопка — переключатель,
/// включённый звук отмечен признаком `.selected` (на iOS 17+ ещё и `.toggleButton`).
@_spi(PersonalizationUI) public final class PersonalizationStorySoundButton: UIControl {

    public static let side: CGFloat = 32

    /// Звук выключен: иконка `speakerOff`.
    public var isMuted = true {
        didSet { apply() }
    }

    /// Нажатие: новое значение `isMuted`.
    public var onToggle: ((Bool) -> Void)?

    /// Подписи для VoiceOver — текущее состояние: звук включён — `soundOnLabel`,
    /// выключен — `soundOffLabel`.
    public var soundOnLabel: String? = "Sound on" {
        didSet { apply() }
    }
    public var soundOffLabel: String? = "Sound off" {
        didSet { apply() }
    }

    /// Кнопка на медиа-слайде: тёмные токены и на iOS 12.
    var forcesDarkTokens = false {
        didSet { icon.tintColor = PersonalizationStoryColors.token(PersonalizationColor.textSecondary, forcingDark: forcesDarkTokens) }
    }

    public override var isHighlighted: Bool {
        didSet { icon.alpha = isHighlighted ? 0.5 : 1 }
    }

    private let icon = UIImageView()

    public init(isMuted: Bool = true) {
        super.init(frame: .zero)
        self.isMuted = isMuted
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        icon.contentMode = .scaleAspectFit
        icon.tintColor = PersonalizationColor.textSecondary
        icon.isUserInteractionEnabled = false
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.side),
            heightAnchor.constraint(equalToConstant: Self.side),
            icon.topAnchor.constraint(equalTo: topAnchor),
            icon.bottomAnchor.constraint(equalTo: bottomAnchor),
            icon.leadingAnchor.constraint(equalTo: leadingAnchor),
            icon.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        isAccessibilityElement = true
        apply()
    }

    @objc private func tapped() {
        isMuted.toggle()
        sendActions(for: .valueChanged)
        onToggle?(isMuted)
    }

    private func apply() {
        icon.image = isMuted ? PersonalizationIcons.speakerOff : PersonalizationIcons.speaker
        accessibilityLabel = isMuted ? soundOffLabel : soundOnLabel
        var traits: UIAccessibilityTraits = .button
        if #available(iOS 17.0, *) { traits.insert(.toggleButton) }
        if !isMuted { traits.insert(.selected) }
        accessibilityTraits = traits
    }
}
