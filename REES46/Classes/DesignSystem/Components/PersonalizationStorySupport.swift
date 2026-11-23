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
        return color.resolvedColor(with: view.traitCollection).cgColor
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

    /// Цвет ленты v3 — один разбор на фон слайда, цвет текста и заливку блока: `#RGB`, `#RRGGBB`,
    /// `#RRGGBBAA` и `rgb()`/`rgba()` (через запятые или пробелы, альфа после `/`, как в CSS).
    /// Пусто или мусор — `nil`. Старая лента разбирает только hex (`parse(_:)`).
    static func parse(css value: String?) -> UIColor? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        if text.lowercased().hasPrefix("rgb") { return CSSColor.parse(text)?.uiColor }
        return parse(text)
    }

    /// Тема кита для текста на цвете, как правило четырёх SDK: светлый текст кита (тёмная тема) или
    /// тёмный (светлая) — какой контрастнее с цветом по WCAG. Альфа цвета не учитывается.
    static func interfaceStyle(on color: UIColor) -> UIUserInterfaceStyle {
        let text = PersonalizationColor.textPrimary
        let light = text.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        let dark = text.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        return contrast(light, color) > contrast(dark, color) ? .dark : .light
    }

    /// Контраст двух цветов по WCAG: от 1 до 21.
    static func contrast(_ first: UIColor, _ second: UIColor) -> CGFloat {
        let one = luminance(first), two = luminance(second)
        return (max(one, two) + 0.05) / (min(one, two) + 0.05)
    }

    /// Относительная яркость по WCAG.
    static func luminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if !color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            var white: CGFloat = 0
            color.getWhite(&white, alpha: &alpha)
            (red, green, blue) = (white, white, white)
        }
        func linear(_ value: CGFloat) -> CGFloat {
            let value = min(max(value, 0), 1)
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
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

    /// Прозрачность заливки текстового блока ленты v3, как `calculateOpacity` веба: число в начале
    /// записи (`parseFloat`) — проценты: `"50"`, `"50%"` и `50` — 0,5, `"0.5"` — 0,005. Нет значения,
    /// пустая строка, `0` числом (у веба — «нет прозрачности»), не число и вне 0…100 — `nil`: цвет
    /// как есть.
    static func cssOpacity(_ value: Any?) -> CGFloat? {
        let number: Double?
        switch value {
        case let flag as NSNumber where flag === kCFBooleanTrue || flag === kCFBooleanFalse:
            return nil
        case let numeric as NSNumber:
            number = numeric.doubleValue == 0 ? nil : numeric.doubleValue
        case let text as String:
            number = leadingNumber(text)
        default:
            number = nil
        }
        guard let number, number.isFinite, (0...100).contains(number) else { return nil }
        return CGFloat(number / 100)
    }

    /// Число в начале строки, как `parseFloat`: пробелы впереди пропускаются, хвост (`%`, буквы)
    /// не мешает; числа нет — `nil`.
    static func leadingNumber(_ text: String) -> Double? {
        let trimmed = text.drop(while: { $0.isWhitespace })
        guard let range = trimmed.range(of: #"^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?"#, options: .regularExpression) else { return nil }
        return Double(trimmed[range])
    }

}

extension NSLayoutConstraint {
    /// Приоритет прямо в списке `activate`.
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}

/// Выбор звука просмотрщика сторис: выключен ли звук.
///
/// Старые просмотрщики (старая лента, данные хоста) делят один выбор на весь запуск —
/// `PersonalizationStoryAudio.shared.processChoice`: при первом открытии звук выключен, дальше —
/// как выбрал пользователь, до конца процесса. Просмотрщик ленты v3 держит свой, отдельный от него:
/// при открытии — сохранённый в разделе магазина (как `<prefix>-stories-mute` веба, который помнит
/// его по сайту), без записи — без звука. Сохраняет только кнопка звука; громкость вверх включает
/// звук лишь на этот показ.
final class PersonalizationStoryMuteChoice {

    /// Звук выключен.
    private(set) var isMuted: Bool
    /// Где помнится выбор кнопкой; `nil` — до конца процесса.
    private let store: (defaults: UserDefaults, key: String)?

    /// Выбор без хранилища: так начинается общий выбор запуска.
    init(isMuted: Bool = true) {
        self.isMuted = isMuted
        store = nil
    }

    /// Выбор, сохранённый под `key` в `defaults`; без записи — без звука.
    init(defaults: UserDefaults, key: String) {
        isMuted = defaults.object(forKey: key) as? Bool ?? true
        store = (defaults, key)
    }

    /// Ключ выбора в хранилище, если он есть.
    var key: String? { store?.key }

    /// Новый выбор; `remember` — выбор кнопкой: он сохраняется, если есть где.
    func set(_ muted: Bool, remember: Bool) {
        isMuted = muted
        if remember, let store { store.defaults.set(muted, forKey: store.key) }
    }
}

/// Звук сторис: аудиосессия на время показа и выбор пользователя.
///
/// Выбор — у просмотрщика (`PersonalizationStoryMuteChoice`): у старых — общий на весь запуск,
/// у ленты v3 — свой. Слышно по выбору последнего открытого просмотрщика. Пока звук выключен,
/// аудиосессия — `.ambient`: ролики не прерывают музыку других приложений. Включение переводит её
/// в `.playback` (звук слышен и в беззвучном режиме). Кнопка громкости вверх, нажатая при открытом
/// просмотрщике, включает звук. Закрытие возвращает категорию, что была до открытия, и отпускает
/// сессию, давая другим приложениям продолжить.
///
/// Звук может забрать и система: выдернули наушники, прервал звонок, Siri или чужое
/// приложение. Тогда текущий показ идёт дальше без звука (`isSilenced`), а выбор
/// пользователя не меняется: следующее открытие — снова как он выбрал. Звук возвращает
/// кнопка, громкость вверх или конец прерывания, после которого система разрешает играть.
final class PersonalizationStoryAudio: NSObject {

    static let shared = PersonalizationStoryAudio()

    /// Звук сменился: `object` — `PersonalizationStoryAudio`; просмотрщик читает свой `isMuted`.
    /// Приходит и после вмешательства системы — просмотрщик заново запускает ролик.
    static let didChange = Notification.Name("personalization.stories.muteChanged")

    /// Выбор старых просмотрщиков — один на весь запуск.
    let processChoice = PersonalizationStoryMuteChoice()

    /// Выбор пользователя последнего открытого просмотрщика: звук выключен. Система его не меняет.
    var isMuted: Bool { choice.isMuted }

    /// Звук забрала система — до конца текущего показа или пока пользователь не включит.
    private(set) var isSilenced = false

    /// Что слышно сейчас: без звука по выбору пользователя или по воле системы.
    var isPlaybackMuted: Bool { isMuted || isSilenced }

    /// Ключ выбора звука просмотрщиков ленты v3 в разделе магазина — как `<prefix>-stories-mute`
    /// веба, который помнит его по сайту; в разделе нескольких магазинов — со своим магазином
    /// (`StoragePartition.keyScope`).
    static let rememberedKey = "personalization_sdk.stories_muted"

    private var viewers = 0
    /// Выборы открытых просмотрщиков по порядку открытия: слышно по последнему.
    private var choices: [PersonalizationStoryMuteChoice] = []
    private var choice: PersonalizationStoryMuteChoice { choices.last ?? processChoice }
    private var saved: (category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions)?
    private var volumeObservation: NSKeyValueObservation?
    private var sessionObservers: [NSObjectProtocol] = []
    /// Тишину включило прерывание: его конец может вернуть звук.
    private var silencedByInterruption = false
    /// Выход звука при прошлом замере громкости: громкость меняется и при смене выхода,
    /// это не нажатие кнопки.
    private var volumeRoute: [String] = []

    /// Просмотрщик открылся со своим выбором звука; без него — общий выбор запуска.
    func begin(choice: PersonalizationStoryMuteChoice? = nil) {
        let choice = choice ?? processChoice
        let changed = choice !== self.choice
        choices.append(choice)
        viewers += 1
        guard viewers == 1 else {
            if changed {
                applyCategory()
                notify()
            }
            return
        }
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
    func end(choice: PersonalizationStoryMuteChoice? = nil) {
        let choice = choice ?? processChoice
        let before = self.choice
        if let index = choices.lastIndex(where: { $0 === choice }) { choices.remove(at: index) }
        guard viewers > 0 else { return }
        viewers -= 1
        guard viewers == 0 else {
            // Слышно снова по выбору оставшегося просмотрщика.
            if self.choice !== before {
                applyCategory()
                notify()
            }
            return
        }
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

    /// Выбор пользователя кнопкой звука: у просмотрщика ленты v3 он сохраняется в разделе магазина.
    /// `choice` — выбор просмотрщика с кнопкой; без него — последнего открытого. Снимает и тишину
    /// от системы.
    func setMuted(_ muted: Bool, choice: PersonalizationStoryMuteChoice? = nil) {
        choose(muted, choice: choice ?? self.choice, remember: true)
    }

    /// Выбор кнопкой или громкостью: громкость его не сохраняет.
    private func choose(_ muted: Bool, choice: PersonalizationStoryMuteChoice, remember: Bool) {
        let changed = muted != choice.isMuted
        choice.set(muted, remember: remember)
        let current = choice === self.choice
        guard changed || (current && isSilenced) else { return }
        if current {
            isSilenced = false
            silencedByInterruption = false
            if viewers > 0 { applyCategory() }
        }
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
        let reason = note.userInfo?[AVAudioSessionInterruptionReasonKey] as? UInt
        return reason == AVAudioSession.InterruptionReason.appWasSuspended.rawValue
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
        choose(false, choice: choice, remember: false)
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
        while viewers > 0 { end(choice: choices.last) }
        choices = []
        processChoice.set(true, remember: false)
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

    /// Корневой контроллер ключевого окна — когда показывать не от кого. Сцена на экране:
    /// активная, а без неё — неактивная (центр управления, звонок, холодный старт по ссылке,
    /// пока сцена не активировалась). Сцены на экране нет — `nil`.
    static var personalizationKeyRoot: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for state in [UIScene.ActivationState.foregroundActive, .foregroundInactive] {
            let windows = scenes.filter { $0.activationState == state }.flatMap(\.windows)
            if let root = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController { return root }
        }
        return nil
    }
}
