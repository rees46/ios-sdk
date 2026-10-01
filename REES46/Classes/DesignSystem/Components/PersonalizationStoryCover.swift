import UIKit

/// Обложка сторис: аватар в кольце, 88x88.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), компонент Story/Cover
/// и кольцо Progress/Circular.
///
/// Кольцо — обводка 4 внутрь круга 88, картинка — круг 76 с полем 6. Цвет кольца
/// по состоянию: `default` — Button/Primary, `pinned` — Semantic/Warning и метка
/// «в избранном» 24 в правом нижнем углу (x62 y62), `viewed` — Semantic/Neutral Subtle,
/// `skeleton` — кольцо и круг картинки переливаются заглушкой.
///
/// Сегменты: при `segments > 1` кольцо делится на столько дуг с небольшими зазорами —
/// по дуге на слайд. Дуги просмотренных слайдов (`seen` — их номера) красятся
/// Button/Primary Disabled (Brand/Primary 65%), остальные — цветом состояния.
/// Просмотренная сторис (`viewed`) — всегда сплошное кольцо Neutral Subtle, без сегментов.
///
/// Картинку компонент не грузит: хост кладёт её в `imageView`.
/// Кольцо рисуют слои `CAShapeLayer`, а их `cgColor` за сменой темы не следит —
/// цвета переставляются из `traitCollectionDidChange`.
@_spi(PersonalizationUI) public final class PersonalizationStoryCover: UIView {

    public enum State {
        case `default`, pinned, viewed, skeleton
    }

    /// Сторона обложки из макета.
    public static let side: CGFloat = 88
    /// Толщина кольца.
    static let ringWidth: CGFloat = 4
    /// Поле между краем обложки и картинкой: кольцо 4 плюс просвет 2.
    static let imageInset: CGFloat = 6
    /// Зазор между сегментами, по дуге.
    static let segmentGap: CGFloat = 4
    /// Угол метки «в избранном» от левого верхнего края обложки.
    static let badgeOrigin: CGFloat = 62

    public var state: State = .default {
        didSet { applyState() }
    }

    /// Число сегментов кольца — слайдов сторис. 0 или 1 — сплошное кольцо.
    public var segments: Int = 0 {
        didSet { setNeedsLayout() }
    }

    /// Номера просмотренных слайдов: их сегменты подсвечены.
    public var seen: Set<Int> = [] {
        didSet { setNeedsLayout() }
    }

    /// Сюда хост загружает аватар сторис.
    public let imageView = UIImageView()

    private let ring = CALayer()
    private var arcs: [CAShapeLayer] = []
    private let badge = PersonalizationFavoritesBadge()
    private let shimmer = PersonalizationStoryShimmer()
    private let shimmerMask = CAShapeLayer()

    public init(state: State = .default) {
        super.init(frame: .zero)
        self.state = state
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        layer.addSublayer(ring)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        // Заглушка до загрузки, как у картинки товара.
        imageView.backgroundColor = PersonalizationColor.neutral50
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        // Заглушка покрывает всю обложку, форму ей даёт маска: кольцо плюс круг картинки.
        shimmerMask.fillRule = .evenOdd
        shimmer.layer.mask = shimmerMask
        shimmer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(shimmer)

        badge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(badge)

        let inset = Self.imageInset
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.side),
            heightAnchor.constraint(equalToConstant: Self.side),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            shimmer.topAnchor.constraint(equalTo: topAnchor),
            shimmer.bottomAnchor.constraint(equalTo: bottomAnchor),
            shimmer.leadingAnchor.constraint(equalTo: leadingAnchor),
            shimmer.trailingAnchor.constraint(equalTo: trailingAnchor),
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.badgeOrigin),
            badge.topAnchor.constraint(equalTo: topAnchor, constant: Self.badgeOrigin)
        ])
        applyState()
    }

    private func applyState() {
        let skeleton = state == .skeleton
        badge.isHidden = state != .pinned
        shimmer.isHidden = !skeleton
        imageView.isHidden = skeleton
        ring.isHidden = skeleton
        setNeedsLayout()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        imageView.layer.cornerRadius = imageView.bounds.width / 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ring.frame = bounds
        shimmerMask.frame = shimmer.bounds
        shimmerMask.path = skeletonPath()
        drawArcs()
        CATransaction.commit()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // cgColor кольца на смену темы сам не перекрашивается.
        drawArcs()
    }

    /// Сегментов на кольце: у просмотренной сторис кольцо сплошное.
    var arcCount: Int {
        state == .viewed ? 1 : max(1, segments)
    }

    /// Дуги кольца: одна сплошная или по сегменту на слайд, от верхней точки по часовой.
    private func drawArcs() {
        let count = arcCount
        while arcs.count < count {
            let arc = CAShapeLayer()
            arc.fillColor = UIColor.clear.cgColor
            arc.lineCap = .butt
            ring.addSublayer(arc)
            arcs.append(arc)
        }
        while arcs.count > count {
            arcs.removeLast().removeFromSuperlayer()
        }

        let scale = bounds.width / Self.side
        let lineWidth = Self.ringWidth * scale
        let radius = (min(bounds.width, bounds.height) - lineWidth) / 2
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        guard radius > 0 else { return }

        let angles = Self.segmentAngles(count: count, gapAngle: Self.segmentGap * scale / radius)
        for (index, arc) in arcs.enumerated() {
            arc.frame = ring.bounds
            arc.lineWidth = lineWidth
            arc.path = UIBezierPath(
                arcCenter: center,
                radius: radius,
                startAngle: angles[index].start,
                endAngle: angles[index].end,
                clockwise: true
            ).cgPath
            arc.strokeColor = PersonalizationStoryColors.cgColor(color(ofSegment: index), in: self)
        }
    }

    /// Углы дуг: `count` равных дуг, между соседями зазор `gapAngle`, первая начинается
    /// от верхней точки (с половиной зазора). Одна дуга — полный круг без зазора.
    static func segmentAngles(count: Int, gapAngle: CGFloat) -> [(start: CGFloat, end: CGFloat)] {
        let top = -CGFloat.pi / 2
        guard count > 1 else { return [(top, top + 2 * .pi)] }
        let sweep = (2 * .pi - CGFloat(count) * gapAngle) / CGFloat(count)
        return (0..<count).map { index in
            let start = top + gapAngle / 2 + CGFloat(index) * (sweep + gapAngle)
            return (start, start + sweep)
        }
    }

    func color(ofSegment index: Int) -> UIColor {
        // Сплошное кольцо просмотренность слайдов не показывает.
        let isSeen = arcCount > 1 && seen.contains(index)
        switch state {
        case .viewed: return PersonalizationColor.neutralSubtle
        case .skeleton: return .clear
        case .pinned: return isSeen ? PersonalizationColor.buttonPrimaryDisabled : PersonalizationColor.semanticWarning
        case .default: return isSeen ? PersonalizationColor.buttonPrimaryDisabled : PersonalizationColor.buttonPrimary
        }
    }

    /// Маска заглушки по правилу even-odd: круг обложки минус внутренний край кольца
    /// даёт кольцо, круг картинки внутри снова закрашен.
    private func skeletonPath() -> CGPath {
        let scale = bounds.width / Self.side
        let path = UIBezierPath(ovalIn: bounds)
        path.append(UIBezierPath(ovalIn: bounds.insetBy(dx: Self.ringWidth * scale, dy: Self.ringWidth * scale)))
        path.append(UIBezierPath(ovalIn: bounds.insetBy(dx: Self.imageInset * scale, dy: Self.imageInset * scale)))
        return path.cgPath
    }
}
