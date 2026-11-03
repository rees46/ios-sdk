import UIKit

// Рамка попапа v3 и её место на экране.
//
// Макеты: banner (сверху или снизу, отступы `offsetX`/`offsetY` от краёв безопасной зоны, без
// затемнения), modal (по центру, затемнение; поля 16 сверху и снизу), fullscreen (весь экран в
// безопасной зоне, ширина, высота и радиус рамки не действуют). Высота рамки не больше доступной;
// что не влезло — прокручивается внутри рамки, а фон, рамка, радиус и отступы стоят на месте.

/// Размеры рамки на экране: чистый расчёт, без вью.
struct PopupV3Geometry: Equatable {

    /// Поле модалки сверху и снизу, баннера — со стороны, противоположной краю.
    static let margin: CGFloat = 16

    let width: CGFloat
    /// Не выше — дальше прокрутка.
    let maxHeight: CGFloat
    let minHeight: CGFloat?
    /// Высота из дизайна (px, %, vh) или фуллскрина; `nil` — по содержимому.
    let fixedHeight: CGFloat?
    let padding: CGFloat
    let borderWidth: CGFloat
    let radius: CGFloat
    /// Модалка: центр по вертикали. Баннер сверху: верх рамки. Баннер снизу: низ рамки. Фуллскрин: верх.
    let anchorY: CGFloat
    /// Центр по горизонтали.
    let centerX: CGFloat

    init(layout: PopupV3.Layout, placement: PopupV3.Placement, style raw: PopupV3FrameStyle, bounds: CGSize, safe: UIEdgeInsets, keyboard: CGFloat = 0) {
        let style = raw.resolved(screenWidth: Double(bounds.width))
        let bottomInset = max(safe.bottom, keyboard)
        let freeWidth = max(0, bounds.width - safe.left - safe.right)
        centerX = safe.left + freeWidth / 2
        switch layout {
        case .fullscreen:
            width = freeWidth
            let height = max(0, bounds.height - safe.top - bottomInset)
            maxHeight = height
            minHeight = nil
            fixedHeight = height
            padding = CGFloat(style.padding)
            borderWidth = 0
            radius = 0
            anchorY = safe.top
        case .modal:
            width = min(CGFloat(style.frameWidth(screenWidth: Double(bounds.width))), freeWidth)
            maxHeight = max(0, bounds.height - safe.top - bottomInset - 2 * Self.margin)
            minHeight = style.minimumHeight(screenHeight: Double(bounds.height)).map { CGFloat($0) }
            fixedHeight = style.fixedHeight(screenHeight: Double(bounds.height)).map { CGFloat($0) }
            padding = CGFloat(style.padding)
            borderWidth = CGFloat(style.borderWidth)
            radius = CGFloat(style.borderRadius)
            let top = safe.top + Self.margin
            let bottom = bounds.height - bottomInset - Self.margin
            anchorY = (top + bottom) / 2
        case .banner:
            let offsetX = CGFloat(style.offsetX), offsetY = CGFloat(style.offsetY)
            width = min(CGFloat(style.frameWidth(screenWidth: Double(bounds.width))), max(0, freeWidth - 2 * offsetX))
            maxHeight = max(0, bounds.height - safe.top - bottomInset - offsetY - Self.margin)
            minHeight = style.minimumHeight(screenHeight: Double(bounds.height)).map { CGFloat($0) }
            fixedHeight = style.fixedHeight(screenHeight: Double(bounds.height)).map { CGFloat($0) }
            padding = CGFloat(style.padding)
            borderWidth = CGFloat(style.borderWidth)
            radius = CGFloat(style.borderRadius)
            anchorY = placement == .bottom ? bounds.height - bottomInset - offsetY : safe.top + offsetY
        }
    }
}

/// Рамка: фон, граница, радиус и отступы, внутри — прокрутка с сеткой.
final class PopupV3FrameView: UIView {

    let scrollView = UIScrollView()
    let grid: PopupV3GridView
    private var insetConstraints: [NSLayoutConstraint] = []
    private var contentHeight: NSLayoutConstraint!
    private var fixedHeight: NSLayoutConstraint!
    private var minHeight: NSLayoutConstraint!
    private var maxHeight: NSLayoutConstraint!
    private(set) var width: NSLayoutConstraint!

    init(design: PopupV3Design, context: PopupV3RenderContext) {
        grid = PopupV3GridView(design: design, context: context)
        super.init(frame: .zero)
        clipsToBounds = true
        backgroundColor = design.frame.background.uiColor
        layer.borderColor = design.frame.borderColor.uiColor.cgColor
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive
        if #available(iOS 11.0, *) { scrollView.contentInsetAdjustmentBehavior = .never }
        grid.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        scrollView.addSubview(grid)
        insetConstraints = [
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        ]
        contentHeight = heightAnchor.constraint(equalTo: grid.heightAnchor).withPriority(UILayoutPriority(740))
        fixedHeight = heightAnchor.constraint(equalToConstant: 0).withPriority(UILayoutPriority(745))
        minHeight = heightAnchor.constraint(greaterThanOrEqualToConstant: 0).withPriority(UILayoutPriority(760))
        maxHeight = heightAnchor.constraint(lessThanOrEqualToConstant: 10000)
        width = widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate(insetConstraints + [
            grid.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            grid.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            grid.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            grid.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            contentHeight, minHeight, maxHeight, width
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Размеры под экран: ширина, отступы, высота по содержимому или из дизайна, предел.
    func apply(_ geometry: PopupV3Geometry) {
        let inset = geometry.padding + geometry.borderWidth
        insetConstraints.forEach { $0.constant = inset }
        layer.borderWidth = geometry.borderWidth
        layer.cornerRadius = geometry.radius
        width.constant = geometry.width
        contentHeight.constant = 2 * inset
        maxHeight.constant = geometry.maxHeight
        minHeight.constant = geometry.minHeight ?? 0
        if let fixed = geometry.fixedHeight {
            fixedHeight.constant = fixed
            fixedHeight.isActive = true
            contentHeight.isActive = false
        } else {
            fixedHeight.isActive = false
            contentHeight.isActive = true
        }
    }

    /// Содержимое выше рамки — прокручивается.
    var isScrollable: Bool {
        scrollView.contentSize.height > scrollView.bounds.height + 0.5
    }
}
