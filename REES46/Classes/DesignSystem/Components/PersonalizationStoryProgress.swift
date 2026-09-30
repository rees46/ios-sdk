import UIKit

/// Прогресс сторис: по полоске на слайд.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), шапка Navigation/Story.
/// `count` полосок равной ширины, высота 2, шаг 2, скругление 1. Дорожка — Line/Generic,
/// заполнение — Text/Secondary. Слайды до `current` заполнены целиком, текущий —
/// на `progress` (0…1), следующие пусты.
///
/// Цвета — динамические `UIColor` на фоне вью, поэтому тема переключается сама.
@_spi(PersonalizationUI) public final class PersonalizationStoryProgress: UIView {

    /// Высота полосок.
    public static let height: CGFloat = 2
    private static let gap: CGFloat = PersonalizationSpacing.xs  // 2
    private static let radius: CGFloat = 1

    /// Число слайдов.
    public var count: Int = 0 {
        didSet {
            guard oldValue != count else { return }
            rebuild()
        }
    }

    /// Индекс текущего слайда.
    public var current: Int = 0 {
        didSet { setNeedsLayout() }
    }

    /// Заполнение текущей полоски, 0…1.
    public var progress: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    private var tracks: [UIView] = []
    private var fills: [UIView] = []

    public init(count: Int = 0) {
        super.init(frame: .zero)
        self.count = count
        rebuild()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Self.height)
    }

    private func rebuild() {
        tracks.forEach { $0.removeFromSuperview() }
        tracks = []
        fills = []
        for _ in 0..<max(0, count) {
            let track = UIView()
            track.backgroundColor = PersonalizationColor.lineGeneric
            track.layer.cornerRadius = Self.radius
            track.clipsToBounds = true
            let fill = UIView()
            fill.backgroundColor = PersonalizationColor.textSecondary
            track.addSubview(fill)
            addSubview(track)
            tracks.append(track)
            fills.append(fill)
        }
        setNeedsLayout()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let n = tracks.count
        guard n > 0 else { return }
        let width = max(0, (bounds.width - Self.gap * CGFloat(n - 1)) / CGFloat(n))
        for index in 0..<n {
            let track = tracks[index]
            track.frame = CGRect(x: CGFloat(index) * (width + Self.gap), y: 0, width: width, height: bounds.height)
            fills[index].frame = CGRect(x: 0, y: 0, width: width * fraction(of: index), height: bounds.height)
        }
    }

    /// Заполнение полоски: прошедшие — целиком, текущая — на `progress`, будущие — пусто.
    func fraction(of index: Int) -> CGFloat {
        if index < current { return 1 }
        if index > current { return 0 }
        return min(max(progress, 0), 1)
    }
}
