import UIKit
import AVFoundation

/// Переливающаяся заглушка сторис: обложка и подпись в состоянии skeleton.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), Story/Cover и Story/Preview
/// в состоянии Skeleton: градиент 5% → 30% → 5%. Цвет — Text/Primary, как у остальных
/// заглушек кита: чёрный в светлой теме, белый в тёмной, и подмена темы хостом доходит и сюда.
/// Блик бежит по диагонали слева направо, пока вью в окне.
///
/// Форму задаёт владелец — маской слоя или скруглением.
final class PersonalizationStoryShimmer: UIView {

    /// Прозрачность краёв и середины градиента.
    static let edgeAlpha: CGFloat = 0.05
    static let peakAlpha: CGFloat = 0.3

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
        let base = PersonalizationStoryColors.cgColor(PersonalizationColor.textPrimary, in: self)
        let edge = base.copy(alpha: base.alpha * Self.edgeAlpha) ?? base
        let peak = base.copy(alpha: base.alpha * Self.peakAlpha) ?? base
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

    /// Токен кита на медиа-слайде. С iOS 13 тёмную тему поддереву даёт
    /// `overrideUserInterfaceStyle`, и токен остаётся динамическим; на iOS 12 переопределять
    /// тему нечем — берётся тёмное значение токена напрямую.
    static func token(_ color: UIColor, forcingDark: Bool) -> UIColor {
        if #available(iOS 13.0, *) { return color }
        return forcingDark ? PersonalizationColorSet.darkVariant(of: color) : color
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
///
/// Звук может забрать и система: выдернули наушники, прервал звонок, Siri или чужое
/// приложение. Тогда текущий показ идёт дальше без звука (`isSilenced`), а выбор
/// пользователя не меняется: следующее открытие — снова как он выбрал. Звук возвращает
/// кнопка, громкость вверх или конец прерывания, после которого система разрешает играть.
final class PersonalizationStoryAudio: NSObject {

    static let shared = PersonalizationStoryAudio()

    /// Звук сменился: `object` — `PersonalizationStoryAudio`, читать `isPlaybackMuted`.
    /// Приходит и после вмешательства системы — просмотрщик заново запускает ролик.
    static let didChange = Notification.Name("personalization.stories.muteChanged")

    /// Выбор пользователя: звук выключен. Система его не меняет.
    private(set) var isMuted = true

    /// Звук забрала система — до конца текущего показа или пока пользователь не включит.
    private(set) var isSilenced = false

    /// Что слышно сейчас: без звука по выбору пользователя или по воле системы.
    var isPlaybackMuted: Bool { isMuted || isSilenced }

    private var viewers = 0
    private var saved: (category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions)?
    private var volumeObservation: NSKeyValueObservation?
    private var sessionObservers: [NSObjectProtocol] = []
    /// Тишину включило прерывание: его конец может вернуть звук.
    private var silencedByInterruption = false
    /// Выход звука при прошлом замере громкости: громкость меняется и при смене выхода,
    /// это не нажатие кнопки.
    private var volumeRoute: [String] = []

    /// Просмотрщик открылся.
    func begin() {
        viewers += 1
        guard viewers == 1 else { return }
        let session = AVAudioSession.sharedInstance()
        saved = (session.category, session.mode, session.categoryOptions)
        applyCategory()
        volumeRoute = Self.outputs(of: session)
        volumeObservation = session.observe(\.outputVolume, options: [.old, .new]) { [weak self] session, change in
            guard let old = change.oldValue, let new = change.newValue else { return }
            let route = Self.outputs(of: session)
            MainThread.run { self?.volumeChanged(from: old, to: new, route: route) }
        }
        let center = NotificationCenter.default
        sessionObservers = [
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
                self?.interrupted(note)
            },
            center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] note in
                self?.routeChanged(note)
            }
        ]
    }

    /// Просмотрщик закрылся: последний возвращает сессию как было.
    func end() {
        guard viewers > 0 else { return }
        viewers -= 1
        guard viewers == 0 else { return }
        volumeObservation?.invalidate()
        volumeObservation = nil
        sessionObservers.forEach { NotificationCenter.default.removeObserver($0) }
        sessionObservers = []
        isSilenced = false
        silencedByInterruption = false
        let session = AVAudioSession.sharedInstance()
        if let saved {
            try? session.setCategory(saved.category, mode: saved.mode, options: saved.options)
        }
        saved = nil
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Выбор пользователя — кнопкой или громкостью вверх. Снимает и тишину от системы.
    func setMuted(_ muted: Bool) {
        guard muted != isMuted || isSilenced else { return }
        isMuted = muted
        isSilenced = false
        silencedByInterruption = false
        if viewers > 0 { applyCategory() }
        notify()
    }

    /// Плеер остановила система, а не просмотрщик: звук она забрала — дальше без него.
    func playbackStoppedBySystem() {
        silence(byInterruption: false)
        notify()
    }

    private func notify() {
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    /// Тишина на текущий показ; выбор пользователя прежний.
    private func silence(byInterruption: Bool) {
        guard viewers > 0, !isMuted, !isSilenced else { return }
        isSilenced = true
        silencedByInterruption = byInterruption
        applyCategory()
    }

    /// Прерывание: на время — тишина; по концу сессия снова активна, а звук возвращается,
    /// только если система разрешила (`shouldResume`) и забирало его само прерывание.
    private func interrupted(_ note: Notification) {
        guard viewers > 0,
              let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            // Прерывание, случившееся, пока приложение спало, уже кончилось.
            guard !Self.wasSuspended(note) else { return }
            silence(byInterruption: true)
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            if options.contains(.shouldResume), silencedByInterruption {
                isSilenced = false
                silencedByInterruption = false
            }
            applyCategory()
        @unknown default:
            return
        }
        notify()
    }

    private static func wasSuspended(_ note: Notification) -> Bool {
        if #available(iOS 14.5, *) {
            let reason = note.userInfo?[AVAudioSessionInterruptionReasonKey] as? UInt
            return reason == AVAudioSession.InterruptionReason.appWasSuspended.rawValue
        }
        return note.userInfo?[AVAudioSessionInterruptionWasSuspendedKey] as? Bool ?? false
    }

    /// Пропал выход звука (выдернули наушники, отключилась колонка): дальше без звука,
    /// чтобы ролик не заговорил в динамик.
    private func routeChanged(_ note: Notification) {
        guard viewers > 0,
              let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
        silence(byInterruption: false)
        notify()
    }

    /// Громкость вверх на том же выходе — включить звук. Скачок громкости при смене выхода
    /// (у наушников и динамика своя громкость) — не нажатие.
    func volumeChanged(from old: Float, to new: Float, route: [String]) {
        let sameRoute = route == volumeRoute
        volumeRoute = route
        guard viewers > 0, sameRoute, new > old else { return }
        setMuted(false)
    }

    private static func outputs(of session: AVAudioSession) -> [String] {
        session.currentRoute.outputs.map(\.uid)
    }

    /// Без звука — `.ambient`, смешивается с чужим звуком; со звуком — `.playback`.
    private func applyCategory() {
        let session = AVAudioSession.sharedInstance()
        if isPlaybackMuted {
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
        isSilenced = false
    }
}

extension UIResponder {
    /// Ближайший контроллер по цепочке ответчиков — от него виджеты кита показывают экраны.
    var personalizationNearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }
}

extension UIViewController {
    /// Верхний показанный поверх этого контроллер: модальный экран показывается с него.
    var personalizationTopmost: UIViewController {
        var top = self
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    /// Корневой контроллер ключевого окна — когда показывать не от кого.
    static var personalizationKeyRoot: UIViewController? {
        let windows: [UIWindow]
        if #available(iOS 13.0, *) {
            windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive }
                .flatMap(\.windows)
        } else {
            windows = UIApplication.shared.windows
        }
        return (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    }
}
