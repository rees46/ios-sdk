import UIKit
import AVFoundation

/// Переливающаяся заглушка сторис: обложка и подпись в состоянии skeleton.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), Story/Cover и Story/Preview
/// в состоянии Skeleton: градиент чёрный 5% → 30% → 5%. В тёмной теме тот же градиент белый —
/// чёрный на тёмном фоне не виден, а в макете тёмная заглушка светлее фона.
/// Блик бежит по диагонали слева направо, пока вью в окне.
///
/// Форму задаёт владелец — маской слоя или скруглением.
final class PersonalizationStoryShimmer: UIView {

    /// Края градиента: 5%.
    static let edgeColor = PersonalizationColorSet.dynamic(
        light: PersonalizationColorSet.rgba(0x000000, 0.05),
        dark: PersonalizationColorSet.rgba(0xFFFFFF, 0.05)
    )

    /// Середина градиента: 30%.
    static let peakColor = PersonalizationColorSet.dynamic(
        light: PersonalizationColorSet.rgba(0x000000, 0.3),
        dark: PersonalizationColorSet.rgba(0xFFFFFF, 0.3)
    )

    private static let animationKey = "personalization.story.shimmer"

    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isUserInteractionEnabled = false
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.locations = [0, 0.5, 1]
        layer.addSublayer(gradient)
        applyColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        CATransaction.commit()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // cgColor градиента на смену темы сам не перекрашивается.
        applyColors()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Анимация слоя снимается, когда вью уходит из иерархии.
        if window == nil {
            gradient.removeAnimation(forKey: Self.animationKey)
        } else {
            addAnimation()
        }
    }

    override var isHidden: Bool {
        didSet {
            if isHidden {
                gradient.removeAnimation(forKey: Self.animationKey)
            } else if window != nil {
                addAnimation()
            }
        }
    }

    private func applyColors() {
        let edge = PersonalizationStoryColors.cgColor(Self.edgeColor, in: self)
        let peak = PersonalizationStoryColors.cgColor(Self.peakColor, in: self)
        gradient.colors = [edge, peak, edge]
    }

    /// Блик уезжает за край и возвращается с другой стороны: полосы градиента
    /// сдвигаются от «целиком левее» до «целиком правее» видимой области.
    private func addAnimation() {
        guard !isHidden, gradient.animation(forKey: Self.animationKey) == nil else { return }
        let sweep = CABasicAnimation(keyPath: "locations")
        sweep.fromValue = [-1, -0.5, 0]
        sweep.toValue = [1, 1.5, 2]
        sweep.duration = 1.2
        sweep.repeatCount = .infinity
        sweep.isRemovedOnCompletion = false
        gradient.add(sweep, forKey: Self.animationKey)
    }
}

/// Цвета из данных сторис и разрешение динамических цветов для слоёв.
enum PersonalizationStoryColors {

    /// `cgColor` динамического цвета в теме конкретной вью. Слои тему не знают:
    /// без явного разрешения цвет взялся бы из текущего глобального контекста.
    static func cgColor(_ color: UIColor, in view: UIView) -> CGColor {
        if #available(iOS 13.0, *) {
            return color.resolvedColor(with: view.traitCollection).cgColor
        }
        return color.cgColor
    }

    /// Цвет из hex админки: `#RGB`, `#RRGGBB` или `#RRGGBBAA`. Пусто или мусор — `nil`.
    static func parse(_ hex: String?) -> UIColor? {
        guard var value = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        if value.hasPrefix("#") { value.removeFirst() }
        guard [3, 6, 8].contains(value.count), let number = UInt64(value, radix: 16) else { return nil }
        let r, g, b, a: UInt64
        switch value.count {
        case 3:
            (r, g, b, a) = ((number >> 8) * 17, (number >> 4 & 0xF) * 17, (number & 0xF) * 17, 255)
        case 6:
            (r, g, b, a) = (number >> 16, number >> 8 & 0xFF, number & 0xFF, 255)
        default:
            (r, g, b, a) = (number >> 24, number >> 16 & 0xFF, number >> 8 & 0xFF, number & 0xFF)
        }
        return UIColor(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }

    /// Прозрачность из админки: `"0%"`…`"100%"`. Число без процента — доля, если не больше
    /// единицы, иначе те же проценты. Пусто или мусор — `nil`.
    static func opacity(_ value: String?) -> CGFloat? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let percent = raw.hasSuffix("%")
        let digits = percent ? String(raw.dropLast()) : raw
        guard let number = Double(digits.replacingOccurrences(of: ",", with: ".")) else { return nil }
        let fraction = percent || number > 1 ? number / 100 : number
        return CGFloat(min(max(fraction, 0), 1))
    }

    /// Тёмный ли цвет: по относительной яркости, порог — середина шкалы.
    static func isDark(_ color: UIColor) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            var white: CGFloat = 0
            color.getWhite(&white, alpha: &a)
            return white < 0.5
        }
        return 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.5
    }
}

extension NSLayoutConstraint {
    /// Приоритет прямо в списке `activate`.
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}

/// Звук сторис на весь запуск приложения.
///
/// При первом открытии звук выключен; выбор пользователя помнится до конца процесса и
/// применяется к следующим открытиям. Пока звук выключен, аудиосессия — `.ambient`:
/// ролики не прерывают музыку других приложений. Включение переводит её в `.playback`
/// (звук слышен и в беззвучном режиме). Кнопка громкости вверх, нажатая при открытом
/// просмотрщике, включает звук. Закрытие возвращает категорию, что была до открытия,
/// и отпускает сессию, давая другим приложениям продолжить.
final class PersonalizationStoryAudio: NSObject {

    static let shared = PersonalizationStoryAudio()

    /// Звук сменился: `object` — `PersonalizationStoryAudio`, читать `isMuted`.
    static let didChange = Notification.Name("personalization.stories.muteChanged")

    private(set) var isMuted = true

    private var viewers = 0
    private var saved: (category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions)?
    private var volumeObservation: NSKeyValueObservation?

    /// Просмотрщик открылся.
    func begin() {
        viewers += 1
        guard viewers == 1 else { return }
        let session = AVAudioSession.sharedInstance()
        saved = (session.category, session.mode, session.categoryOptions)
        applyCategory()
        volumeObservation = session.observe(\.outputVolume, options: [.old, .new]) { [weak self] _, change in
            guard let old = change.oldValue, let new = change.newValue, new > old else { return }
            MainThread.run { self?.setMuted(false) }
        }
    }

    /// Просмотрщик закрылся: последний возвращает сессию как было.
    func end() {
        guard viewers > 0 else { return }
        viewers -= 1
        guard viewers == 0 else { return }
        volumeObservation?.invalidate()
        volumeObservation = nil
        let session = AVAudioSession.sharedInstance()
        if let saved {
            try? session.setCategory(saved.category, mode: saved.mode, options: saved.options)
        }
        saved = nil
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    func setMuted(_ muted: Bool) {
        guard muted != isMuted else { return }
        isMuted = muted
        if viewers > 0 { applyCategory() }
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    /// Без звука — `.ambient`, смешивается с чужим звуком; со звуком — `.playback`.
    private func applyCategory() {
        let session = AVAudioSession.sharedInstance()
        if isMuted {
            try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        } else {
            try? session.setCategory(.playback, mode: .default, options: [])
        }
        // Активная сессия нужна, чтобы слышать кнопки громкости; `.ambient` никого не прерывает.
        try? session.setActive(true)
    }

    /// Только для тестов: как при новом запуске.
    func resetForTesting() {
        while viewers > 0 { end() }
        isMuted = true
    }
}
