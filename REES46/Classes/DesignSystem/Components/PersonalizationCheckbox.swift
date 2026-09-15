import UIKit

/// Чекбокс дизайн-системы, 20x20.
///
/// Источник: Figma Mobile SDK UI Kit, фрейм Checkbox (205:10128).
/// В макете только размер MD, поэтому размера в API нет.
///
/// Галка и черта рисуются штрихом по геометрии из макета:
/// `M5 10 L8.75 13.75 L15 7.5` и `M5 10 H15`, толщина 2, круглые концы.
@_spi(PersonalizationUI) public final class PersonalizationCheckbox: UIControl {

    public enum State {
        case unchecked, checked, indeterminate
    }

    public static let side: CGFloat = 20

    public var checkState: State = .unchecked {
        didSet { setNeedsDisplay() }
    }

    public override var isEnabled: Bool {
        didSet { setNeedsDisplay() }
    }

    public init(state: State = .unchecked) {
        self.checkState = state
        super.init(frame: CGRect(x: 0, y: 0, width: Self.side, height: Self.side))
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        isOpaque = false
        addTarget(self, action: #selector(toggle), for: .touchUpInside)
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: Self.side, height: Self.side)
    }

    @objc private func toggle() {
        guard isEnabled else { return }
        checkState = checkState == .checked ? .unchecked : .checked
        sendActions(for: .valueChanged)
    }

    public override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Геометрия макета задана для 20x20; при другом размере всё масштабируется.
        let scale = min(rect.width, rect.height) / Self.side
        let radius = PersonalizationRadius.sm * scale  // 4

        let box = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        let filled = checkState != .unchecked

        let fill: UIColor
        if filled {
            fill = isEnabled
                ? PersonalizationColor.buttonPrimary
                : PersonalizationColor.buttonPrimaryDisabled
        } else {
            fill = isEnabled
                ? PersonalizationColor.backgroundInput
                : PersonalizationColor.backgroundInputDisabled
        }
        ctx.setFillColor(fill.cgColor)
        box.fill()

        if !filled {
            // Рамка внутрь, чтобы внешний размер остался ровно 20.
            let inset = rect.insetBy(dx: 0.5 * scale, dy: 0.5 * scale)
            let border = UIBezierPath(roundedRect: inset, cornerRadius: radius)
            border.lineWidth = 1 * scale
            PersonalizationColor.lineInput.setStroke()
            border.stroke()
            return
        }

        let glyph = UIBezierPath()
        switch checkState {
        case .checked:
            glyph.move(to: CGPoint(x: 5 * scale, y: 10 * scale))
            glyph.addLine(to: CGPoint(x: 8.75 * scale, y: 13.75 * scale))
            glyph.addLine(to: CGPoint(x: 15 * scale, y: 7.5 * scale))
        case .indeterminate:
            glyph.move(to: CGPoint(x: 5 * scale, y: 10 * scale))
            glyph.addLine(to: CGPoint(x: 15 * scale, y: 10 * scale))
        case .unchecked:
            return
        }
        glyph.lineWidth = 2 * scale
        glyph.lineCapStyle = .round
        glyph.lineJoinStyle = .round
        PersonalizationColor.textLightPrimary.setStroke()
        glyph.stroke()
    }

    public override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        // Цвета динамические — при смене темы перерисовываем.
        setNeedsDisplay()
    }
}
