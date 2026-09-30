import UIKit

/// Штрихкод Code 128.
///
/// Источник: Figma Mobile SDK UI Kit, компонент Wallet/Code (520:8886): штрихкод 232×42
/// на белой подложке. Здесь только штрихи — подложку с полями рисует тот, кто кладёт
/// штрихкод (карта лояльности, промокод).
///
/// Ширина модуля — целое число пикселей: дробные модули на экране размываются, и сканер
/// читает их хуже. Поэтому штрихкод не растягивается ровно на 232, а берёт наибольший
/// целый модуль, при котором в 232 помещается, — итоговая ширина чуть меньше и зависит
/// от длины кода. Если разметка дала меньше 232, модуль считается от того, что дали.
///
/// Строку, которую Code 128 не несёт (пустую, не ASCII), не рисует — размер нулевой.
@_spi(PersonalizationUI) public final class PersonalizationBarcode: UIView {

    /// Кодируемая строка — номер карты, промокод. Она же — подпись для VoiceOver.
    public var code: String? {
        didSet { applyCode() }
    }

    /// Есть ли что рисовать: строка задана и кодируется.
    public var hasBars: Bool { modules != nil }

    private var modules: [Bool]?

    public init(code: String? = nil) {
        super.init(frame: .zero)
        self.code = code
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Своего фона нет: белое поле вокруг — забота того, кто кладёт штрихкод.
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        // didSet на init не срабатывает.
        applyCode()
    }

    private func applyCode() {
        modules = code.flatMap(PersonalizationCode128.encode)
        accessibilityLabel = code
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
    }

    public override var intrinsicContentSize: CGSize {
        guard let count = modules?.count else { return .zero }
        return CGSize(width: CGFloat(count) * moduleWidth(available: Self.preferredWidth), height: Self.preferredHeight)
    }

    public override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        // Модуль считается в пикселях: на экране с другой плотностью и ширина другая.
        if previous?.displayScale != traitCollection.displayScale {
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }

    public override func draw(_ rect: CGRect) {
        guard let bars = modules, let context = UIGraphicsGetCurrentContext() else { return }
        let scale = self.scale
        let module = moduleWidth(available: min(bounds.width, Self.preferredWidth))
        // По центру, если разметка дала больше, чем занимают модули; начало — на границе пикселя.
        var x = max(0, ((bounds.width - CGFloat(bars.count) * module) / 2 * scale).rounded()) / scale
        // Штрихи чёрные в любой теме: сканеру нужен контраст, а не палитра.
        context.setFillColor(UIColor.black.cgColor)
        var index = 0
        while index < bars.count {
            var run = 1
            while index + run < bars.count, bars[index + run] == bars[index] { run += 1 }
            if bars[index] {
                context.fill(CGRect(x: x, y: 0, width: CGFloat(run) * module, height: bounds.height))
            }
            x += CGFloat(run) * module
            index += run
        }
    }

    /// Ширина модуля в пунктах: наибольшее целое число пикселей, при котором все модули
    /// помещаются в `available`, но не меньше одного пикселя. Допуск в тысячную пикселя —
    /// против ширины из разметки вроде 204.99999, иначе модуль потерял бы целый пиксель.
    private func moduleWidth(available: CGFloat) -> CGFloat {
        guard let count = modules?.count, count > 0 else { return 0 }
        let pixels = max(1, (available * scale / CGFloat(count) + 0.001).rounded(.down))
        return pixels / scale
    }

    /// Плотность экрана. До попадания в окно у трейтов её нет — тогда берётся главный экран.
    private var scale: CGFloat {
        let scale = traitCollection.displayScale
        return scale > 0 ? scale : UIScreen.main.scale
    }

    private static let preferredWidth: CGFloat = 232
    private static let preferredHeight: CGFloat = 42
}
