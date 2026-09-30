import UIKit
import CoreText

/// Обратный отсчёт до конца акции: дни, часы, минуты, секунды.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), компонент Timer, виды
/// Merged и Separate. `merged` — одна плашка со скруглением 12, поля 8/12, шаг 12,
/// заливка Neutral/Neutral 100; `separate` — четыре плашки со скруглением 8, поля 8/12,
/// шаг 8, каждая тянется поровну. Единица — число SemiBold 36 Text/Primary и подпись
/// Regular 20 Text/Secondary, шаг 2, по базовой линии. Подписи по умолчанию d/h/m/s.
///
/// Тикает раз в секунду, пока вью в окне; на нуле останавливается и зовёт `onFinish`.
/// Цифры моноширинные, чтобы строка не дёргалась каждую секунду.
/// В API сторис таймера нет — компонент для хоста.
@_spi(PersonalizationUI) public final class PersonalizationStoryTimer: UIView {

    public enum View {
        case merged, separate
    }

    /// Подписи единиц.
    public struct Units: Equatable {
        public var days: String
        public var hours: String
        public var minutes: String
        public var seconds: String

        public init(days: String = "d", hours: String = "h", minutes: String = "m", seconds: String = "s") {
            self.days = days
            self.hours = hours
            self.minutes = minutes
            self.seconds = seconds
        }
    }

    /// Момент окончания. `nil` — нули.
    public var endDate: Date? {
        didSet {
            finished = false
            render()
            updateClock()
        }
    }

    public var view: View = .merged {
        didSet { rebuild() }
    }

    public var units = Units() {
        didSet { render() }
    }

    /// Отсчёт дошёл до нуля.
    public var onFinish: (() -> Void)?

    /// Откуда таймер берёт «сейчас»; подменяется в тестах.
    var now: () -> Date = Date.init

    private static let numberStyle = PersonalizationTextStyle(size: 36, lineHeight: 44, tracking: 0, weight: .semibold)
    private static let unitStyle = PersonalizationTextStyle(size: 20, lineHeight: 24, tracking: 0, weight: .regular)

    private var numberLabels: [UILabel] = []
    private var unitLabels: [UILabel] = []
    private var root: UIView?
    private var clock: Timer?
    private var finished = false

    public init(endDate: Date? = nil, view: View = .merged) {
        super.init(frame: .zero)
        self.endDate = endDate
        self.view = view
        rebuild()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        rebuild()
    }

    deinit {
        clock?.invalidate()
    }

    // MARK: - Отсчёт

    /// Остаток по единицам: дни, часы, минуты, секунды. Отрицательный остаток — нули.
    static func parts(remaining: TimeInterval) -> (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let total = max(0, Int(remaining.rounded(.down)))
        return (total / 86_400, total % 86_400 / 3_600, total % 3_600 / 60, total % 60)
    }

    /// Числа как на плашках: дни без ведущего нуля, остальное двумя цифрами.
    static func texts(remaining: TimeInterval) -> [String] {
        let value = parts(remaining: remaining)
        return [String(value.days)] + [value.hours, value.minutes, value.seconds].map { String(format: "%02d", $0) }
    }

    private var remaining: TimeInterval {
        guard let endDate else { return 0 }
        return endDate.timeIntervalSince(now())
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        updateClock()
    }

    /// Часы идут, только пока таймер на экране и не дошёл до нуля.
    private func updateClock() {
        clock?.invalidate()
        clock = nil
        guard window != nil, endDate != nil, remaining > 0 else {
            render()
            return
        }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        clock = timer
        render()
    }

    private func tick() {
        render()
        guard remaining <= 0 else { return }
        clock?.invalidate()
        clock = nil
        if !finished {
            finished = true
            onFinish?()
        }
    }

    // MARK: - Раскладка

    private func rebuild() {
        root?.removeFromSuperview()
        numberLabels = []
        unitLabels = []

        let unitViews = (0..<4).map { _ in makeUnit() }
        let content: UIView
        switch view {
        case .merged:
            let row = UIStackView(arrangedSubviews: unitViews)
            row.axis = .horizontal
            // Единицы одного кегля: по центру — то же, что по базовой линии.
            row.alignment = .center
            row.spacing = PersonalizationSpacing.lg  // 12
            let pill = box(around: row, radius: PersonalizationRadius.xl2)  // 12
            content = pill
        case .separate:
            let row = UIStackView(arrangedSubviews: unitViews.map { box(around: $0, radius: PersonalizationRadius.lg) })  // 8
            row.axis = .horizontal
            row.alignment = .fill
            row.distribution = .fillEqually
            row.spacing = PersonalizationSpacing.md  // 8
            content = row
        }
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        root = content
        render()
    }

    /// Плашка Neutral 100 с полями 8/12, содержимое по центру.
    private func box(around content: UIView, radius: CGFloat) -> UIView {
        let box = UIView()
        box.backgroundColor = PersonalizationColor.neutral100
        box.layer.cornerRadius = radius
        content.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: box.topAnchor, constant: PersonalizationSpacing.md),
            content.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -PersonalizationSpacing.md),
            content.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: box.leadingAnchor, constant: PersonalizationSpacing.lg),
            content.trailingAnchor.constraint(lessThanOrEqualTo: box.trailingAnchor, constant: -PersonalizationSpacing.lg)
        ])
        return box
    }

    /// Единица: число и подпись с шагом 2 по базовой линии.
    private func makeUnit() -> UIView {
        let number = UILabel()
        let unit = UILabel()
        number.setContentCompressionResistancePriority(.required, for: .horizontal)
        unit.setContentCompressionResistancePriority(.required, for: .horizontal)
        numberLabels.append(number)
        unitLabels.append(unit)
        let stack = UIStackView(arrangedSubviews: [number, unit])
        stack.axis = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = PersonalizationSpacing.xs  // 2
        return stack
    }

    private func render() {
        let numbers = Self.texts(remaining: remaining)
        let names = [units.days, units.hours, units.minutes, units.seconds]
        for (index, label) in numberLabels.enumerated() where index < numbers.count {
            label.attributedText = Self.number(numbers[index])
        }
        for (index, label) in unitLabels.enumerated() where index < names.count {
            var attributes = Self.unitStyle.attributes
            attributes[.foregroundColor] = PersonalizationColor.textSecondary
            label.attributedText = NSAttributedString(string: names[index], attributes: attributes)
        }
    }

    /// Число моноширинными цифрами: иначе «11» уже «00», и строка ездит каждую секунду.
    private static func number(_ text: String) -> NSAttributedString {
        var attributes = numberStyle.attributes
        attributes[.foregroundColor] = PersonalizationColor.textPrimary
        if let font = attributes[.font] as? UIFont {
            let setting: [UIFontDescriptor.FeatureKey: Int]
            if #available(iOS 15.0, *) {
                setting = [.type: kNumberSpacingType, .selector: kMonospacedNumbersSelector]
            } else {
                setting = [.featureIdentifier: kNumberSpacingType, .typeIdentifier: kMonospacedNumbersSelector]
            }
            let descriptor = font.fontDescriptor.addingAttributes([.featureSettings: [setting]])
            attributes[.font] = UIFont(descriptor: descriptor, size: font.pointSize)
        }
        return NSAttributedString(string: text, attributes: attributes)
    }
}
