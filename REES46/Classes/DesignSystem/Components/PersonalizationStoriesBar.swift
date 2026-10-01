import UIKit

/// Лента сторис: превью в горизонтальной прокрутке.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), фреймы Stories block
/// (светлый и тёмный): `PersonalizationStoryPreview` в ряд с шагом 16 и полем 16.
/// Поле и шаг хост может поменять — `contentInsets` и `spacing`.
///
/// Пока `isLoading`, вместо превью стоят `skeletonCount` заглушек (в макете четыре).
/// Картинки грузит хост через `imageLoader`. Смена `items` с теми же id обновляет
/// превью на месте — состояние кольца и сегменты — без перезагрузки картинок.
@_spi(PersonalizationUI) public final class PersonalizationStoriesBar: UIView {

    /// Превью в ленте.
    public struct Item {
        public var id: String
        public var title: String
        public var imageUrl: String?
        /// `default`, `pinned` или `viewed`; skeleton лента ставит сама на время загрузки.
        public var state: PersonalizationStoryCover.State
        /// Число слайдов: столько сегментов у кольца. 0 — сплошное.
        public var segments: Int
        /// Номера просмотренных слайдов: эти сегменты подсвечены.
        public var seen: Set<Int>

        public init(
            id: String,
            title: String,
            imageUrl: String? = nil,
            state: PersonalizationStoryCover.State = .default,
            segments: Int = 0,
            seen: Set<Int> = []
        ) {
            self.id = id
            self.title = title
            self.imageUrl = imageUrl
            self.state = state
            self.segments = segments
            self.seen = seen
        }
    }

    public var items: [Item] = [] {
        didSet { render(previous: oldValue) }
    }

    /// Загрузка: вместо превью заглушки.
    public var isLoading = false {
        didSet {
            guard oldValue != isLoading else { return }
            rebuild()
        }
    }

    /// Сколько заглушек показывать при загрузке.
    public var skeletonCount = 4 {
        didSet { if isLoading { rebuild() } }
    }

    /// Поля ленты. По макету 16 со всех сторон.
    public var contentInsets = UIEdgeInsets(
        top: PersonalizationSpacing.xl,
        left: PersonalizationSpacing.xl,
        bottom: PersonalizationSpacing.xl,
        right: PersonalizationSpacing.xl
    ) {
        didSet { applyInsets() }
    }

    /// Шаг между превью. По макету 16.
    public var spacing: CGFloat = PersonalizationSpacing.xl {
        didSet { stack.spacing = spacing }
    }

    /// Хост кладёт аватар сторис в `UIImageView` своим загрузчиком.
    public var imageLoader: ((UIImageView, Item) -> Void)? {
        // Загрузчик, заданный после `items`, подгружает уже показанные обложки.
        didSet { reloadImages() }
    }

    /// Нажатие на превью: сторис и её индекс в `items`.
    public var onItemTap: ((Item, Int) -> Void)?

    public let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var previews: [PersonalizationStoryPreview] = []
    private var insetConstraints: [NSLayoutConstraint] = []

    public init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        stack.axis = .horizontal
        stack.alignment = .top
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        applyInsets()
    }

    private func applyInsets() {
        NSLayoutConstraint.deactivate(insetConstraints)
        let content = scrollView.contentLayoutGuide
        insetConstraints = [
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: contentInsets.top),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -contentInsets.bottom),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: contentInsets.left),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -contentInsets.right),
            // Прокрутка только по горизонтали: по вертикали содержимое ровно по рамке.
            stack.heightAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.heightAnchor,
                constant: -(contentInsets.top + contentInsets.bottom)
            )
        ]
        NSLayoutConstraint.activate(insetConstraints)
        invalidateIntrinsicContentSize()
    }

    /// Высота — одна строка превью плюс поля; ширину задаёт хост.
    public override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: contentInsets.top + PersonalizationStoryPreview.height + contentInsets.bottom
        )
    }

    /// Те же сторис в том же порядке — обновить превью на месте, иначе собрать заново.
    private func render(previous: [Item]) {
        guard !isLoading else { return }
        let sameStories = previous.map(\.id) == items.map(\.id) && previews.count == items.count
        guard sameStories else {
            rebuild()
            return
        }
        for (index, item) in items.enumerated() {
            let preview = previews[index]
            apply(item, to: preview)
            if previous[index].imageUrl != item.imageUrl {
                preview.cover.imageView.image = nil
                imageLoader?(preview.cover.imageView, item)
            }
        }
    }

    private func rebuild() {
        previews.forEach { $0.removeFromSuperview() }
        previews = []
        if isLoading {
            for _ in 0..<max(0, skeletonCount) {
                let preview = PersonalizationStoryPreview(state: .skeleton)
                stack.addArrangedSubview(preview)
                previews.append(preview)
            }
            return
        }
        for (index, item) in items.enumerated() {
            let preview = PersonalizationStoryPreview()
            apply(item, to: preview)
            preview.onTap = { [weak self] in
                guard let self, index < self.items.count else { return }
                self.onItemTap?(self.items[index], index)
            }
            stack.addArrangedSubview(preview)
            previews.append(preview)
            imageLoader?(preview.cover.imageView, item)
        }
    }

    private func reloadImages() {
        guard !isLoading, previews.count == items.count else { return }
        for (index, item) in items.enumerated() {
            imageLoader?(previews[index].cover.imageView, item)
        }
    }

    private func apply(_ item: Item, to preview: PersonalizationStoryPreview) {
        preview.title = item.title
        preview.state = item.state
        preview.cover.segments = item.segments
        preview.cover.seen = item.seen
    }
}
