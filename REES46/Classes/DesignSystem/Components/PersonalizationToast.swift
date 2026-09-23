import UIKit

/// Тост: короткое сообщение в плашке-пилюле поверх экрана — «Скопировано».
///
/// Источник: Figma Mobile SDK UI Kit, страница Components, секция Toast (367:16179),
/// компонент 367:16178; на странице Stories — фреймы 367:16063 (снизу) и 367:16106 (сверху).
///
/// Скругление — радиус Toast (999, то есть пилюля), фон — Background/Float, тень —
/// Elevation 2, поля 16 по вертикали и 20 по горизонтали. Текст 18/18 Medium по центру.
/// В макете он покрашен сырым #000 без переменной — здесь Text/Primary, чтобы тост
/// читался и в тёмной теме. Однострочный тост — 50 в высоту.
///
/// Саму плашку можно положить куда угодно как обычную вью, но обычно её показывает
/// `show(_:in:position:duration:)`: поверх экрана, с появлением и исчезновением.
/// Тень на самом тосте, фон и скругление — на внутренней подложке, как у инап-попапа.
@_spi(PersonalizationUI) public final class PersonalizationToast: UIView {

    /// Край экрана, у которого стоит тост.
    public enum Position {
        case top, bottom
    }

    public var text: String? {
        didSet { applyText() }
    }

    private let label = UILabel()
    /// Подложка: фон и скругление. Обрезки нет — внутри только текст с полями.
    private let surface = UIView()
    /// Второй слой тени Elevation 2: `CALayer` рисует одну тень, первую несёт слой тоста.
    private let secondShadow = CALayer()
    /// Отложенное скрытие у показанного презентером тоста.
    private var dismissWork: DispatchWorkItem?

    public init(text: String? = nil) {
        super.init(frame: .zero)
        self.text = text
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        surface.translatesAutoresizingMaskIntoConstraints = false
        addSubview(surface)
        layer.insertSublayer(secondShadow, below: surface.layer)

        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(label)

        let vertical = PersonalizationSpacing.xl     // 16
        let horizontal = PersonalizationSpacing.xl2  // 20
        NSLayoutConstraint.activate([
            surface.topAnchor.constraint(equalTo: topAnchor),
            surface.leadingAnchor.constraint(equalTo: leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: trailingAnchor),
            surface.bottomAnchor.constraint(equalTo: bottomAnchor),
            label.topAnchor.constraint(equalTo: surface.topAnchor, constant: vertical),
            label.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -vertical),
            label.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: horizontal),
            label.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -horizontal)
        ])

        surface.backgroundColor = PersonalizationColor.backgroundFloat
        applyShadow()
        applyText()
    }

    private func applyText() {
        let value = text ?? ""
        var attributes = Self.textStyle.attributes
        attributes[.foregroundColor] = PersonalizationColor.textPrimary
        // Выравнивание живёт в параграфе стиля, поэтому центрирование задаётся в нём.
        let paragraph = (Self.textStyle.paragraphStyle.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        paragraph.alignment = .center
        attributes[.paragraphStyle] = paragraph
        label.attributedText = NSAttributedString(string: value, attributes: attributes)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        // Радиус Toast — 999: пилюлю даёт половина высоты, больше неё скругление не бывает.
        let radius = min(PersonalizationRadius.toast, min(bounds.width, bounds.height) / 2)
        surface.layer.cornerRadius = radius
        // Форма тени задана явно, иначе слой вычислял бы её по альфе содержимого каждый кадр.
        let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: bounds.size), cornerRadius: radius).cgPath
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

    /// Elevation 2 двумя слоями: первый на слое тоста, второй на подслое под подложкой.
    private func applyShadow() {
        let shadows = PersonalizationElevation.e2
        for (index, target) in [layer, secondShadow].enumerated() where index < shadows.count {
            shadows[index].apply(to: target)
        }
    }

    /// Medium 18/18 без трекинга — в типографической шкале такой ступени нет.
    private static let textStyle = PersonalizationTextStyle(size: 18, lineHeight: 18, tracking: 0, weight: .medium)

    // MARK: - Показ

    /// Тост, который сейчас на экране: новый показ его заменяет.
    private static weak var current: PersonalizationToast?

    /// Показывает тост поверх экрана и через `duration` секунд убирает его.
    ///
    /// Контейнер по умолчанию — ключевое окно. Тост стоит по центру, в 16 от края безопасной
    /// зоны (сверху или снизу) и не шире контейнера без полей по 16; длинный текст переносится.
    /// Появляется и исчезает затуханием за 0,2 с. Новый показ заменяет тост, который ещё
    /// на экране, — тосты не копятся. Касаний тост не перехватывает: они проходят к тому,
    /// что под ним. Текст зачитывается VoiceOver как объявление.
    ///
    /// Вызывать с главного потока. Возвращает показанный тост или `nil`, если показать
    /// некуда — контейнер не передан и ключевого окна нет.
    @discardableResult
    public static func show(
        _ text: String,
        in container: UIView? = nil,
        position: Position = .bottom,
        duration: TimeInterval = 2
    ) -> PersonalizationToast? {
        guard let host = container ?? keyWindow else { return nil }
        current?.remove()

        let toast = PersonalizationToast(text: text)
        // Касания проходят сквозь тост к экрану под ним.
        toast.isUserInteractionEnabled = false
        toast.alpha = 0
        toast.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(toast)

        let edge = PersonalizationSpacing.xl  // 16
        let guide = host.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: edge),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -edge),
            position == .top
                ? toast.topAnchor.constraint(equalTo: guide.topAnchor, constant: edge)
                : toast.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -edge)
        ])
        current = toast

        UIView.animate(withDuration: fadeDuration) { toast.alpha = 1 }
        UIAccessibility.post(notification: .announcement, argument: text)

        let work = DispatchWorkItem { [weak toast] in toast?.fadeOut() }
        toast.dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
        return toast
    }

    /// Убирает показанный тост раньше срока.
    public static func dismiss() {
        current?.fadeOut()
    }

    private func fadeOut() {
        dismissWork?.cancel()
        dismissWork = nil
        UIView.animate(withDuration: Self.fadeDuration, animations: { self.alpha = 0 }, completion: { _ in
            self.remove()
        })
    }

    /// Снимает тост сразу, без анимации.
    private func remove() {
        dismissWork?.cancel()
        dismissWork = nil
        removeFromSuperview()
        if Self.current === self { Self.current = nil }
    }

    private static let fadeDuration: TimeInterval = 0.2

    /// Ключевое окно активной сцены; до iOS 13 сцен нет — окно делегата приложения.
    private static var keyWindow: UIWindow? {
        if #available(iOS 13.0, *) {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let active = scenes.filter { $0.activationState == .foregroundActive }
            for scene in active + scenes {
                if let window = scene.windows.first(where: { $0.isKeyWindow }) { return window }
            }
            return active.first?.windows.first
        }
        return UIApplication.shared.delegate?.window ?? nil
    }
}
