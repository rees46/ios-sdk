import UIKit

/// Лента, плитка и список карточек товара на одном `UICollectionView`.
///
/// Источник: Figma Mobile SDK UI Kit, секция Card — Products Carousel (203:6296)
/// и Products Grid (203:4766) в видах Grid и List.
/// Карусель — карточки Carousel горизонтально с шагом 16; плитка — карточки Grid
/// в две колонки с шагом 16 по обеим осям; список — карточки List столбиком с шагом 16.
///
/// Карточки — `PersonalizationProductCard`. Картинки грузит хост через `imageLoader`.
@_spi(PersonalizationUI) public final class PersonalizationProductsList: UIView {

    public enum Layout {
        case carousel, grid, list

        var cardType: PersonalizationProductCard.CardType {
            switch self {
            case .carousel: return .carousel
            case .grid: return .grid
            case .list: return .list
            }
        }
    }

    public var layout: Layout = .carousel {
        didSet { applyLayout() }
    }

    public var products: [PersonalizationProduct] = [] {
        didSet {
            itemHeightCache = nil
            collectionView.reloadData()
            invalidateIntrinsicContentSize()
        }
    }

    /// Хост кладёт изображение товара в `UIImageView` своим загрузчиком.
    public var imageLoader: ((UIImageView, PersonalizationProduct) -> Void)?
    public var onProductAction: ((PersonalizationProduct) -> Void)?

    /// Нажатие на карточку — открыть товар.
    public var onProductTap: ((PersonalizationProduct) -> Void)?

    /// Пропорция картинок карточек, см. `PersonalizationProductCard.imageAspect`.
    public var imageAspect: PersonalizationProductImage.Aspect = .square {
        didSet {
            itemHeightCache = nil
            collectionView.reloadData()
            invalidateIntrinsicContentSize()
        }
    }

    /// Индекс первой видимой карточки: по нему Recommender-блок двигает точки.
    public var onFirstVisibleChanged: ((Int) -> Void)?

    public let collectionView: UICollectionView
    private let flow = UICollectionViewFlowLayout()
    private var lastFirstVisible = -1

    public init(layout: Layout = .carousel) {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: flow)
        super.init(frame: .zero)
        self.layout = layout
        setup()
    }

    required init?(coder: NSCoder) {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: flow)
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(Cell.self, forCellWithReuseIdentifier: Cell.reuseId)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        applyLayout()
    }

    private func applyLayout() {
        itemHeightCache = nil
        let gap = PersonalizationSpacing.xl  // 16
        flow.minimumLineSpacing = gap
        flow.minimumInteritemSpacing = gap
        flow.scrollDirection = layout == .carousel ? .horizontal : .vertical
        // Плитка и список сами не скроллят: их высоту задаёт содержимое,
        // прокрутка остаётся за экраном хоста.
        collectionView.isScrollEnabled = layout == .carousel
        collectionView.reloadData()
        invalidateIntrinsicContentSize()
    }

    /// Высота считается от ширины, а ширину блок узнаёт только в первом layout:
    /// пока её нет, содержимое сложено под ноль. Как только ширина меняется,
    /// intrinsic-высота объявляется устаревшей — иначе стек хоста оставит блок
    /// с высотой, посчитанной для нулевой ширины.
    private var lastLaidOutWidth: CGFloat = -1

    public override func layoutSubviews() {
        super.layoutSubviews()
        flow.invalidateLayout()
        if bounds.width != lastLaidOutWidth {
            lastLaidOutWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
    }

    /// Высота — по содержимому: карусель в одну строку карточек, плитка и список
    /// целиком, чтобы блок вставал в экран хоста без своего скролла.
    ///
    /// Считается по самой высокой карточке, а не по contentSize коллекции:
    /// у горизонтальной раскладки contentSize берёт высоту из bounds, то есть из
    /// нуля до первого layout — блок никогда бы не вырос.
    public override var intrinsicContentSize: CGSize {
        let count = products.count
        guard count > 0 else { return CGSize(width: UIView.noIntrinsicMetric, height: 0) }
        let gap = PersonalizationSpacing.xl
        let rows: Int
        switch layout {
        case .carousel: rows = 1
        case .grid: rows = (count + 1) / 2
        case .list: rows = count
        }
        let height = CGFloat(rows) * itemHeight() + CGFloat(rows - 1) * gap
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    /// Единая высота ячейки: самая высокая карточка при текущей ширине.
    /// Промер карточек не бесплатный, поэтому результат кэшируется по ширине;
    /// смена товаров или раскладки сбрасывает кэш.
    private var itemHeightCache: (width: CGFloat, height: CGFloat)?

    private func itemHeight() -> CGFloat {
        let width = cellWidth()
        guard width > 0 else { return 0 }
        if let cache = itemHeightCache, cache.width == width { return cache.height }
        let height = products.map { cardHeight(for: $0, width: width) }.max() ?? 0
        itemHeightCache = (width, height)
        return height
    }

    private func cardHeight(for product: PersonalizationProduct, width: CGFloat) -> CGFloat {
        let card = PersonalizationProductCard(type: layout.cardType)
        card.imageAspect = imageAspect
        card.brand = product.brand
        card.name = product.name
        card.price = product.price
        card.oldPrice = product.oldPrice
        card.discount = product.discount
        card.actionText = product.actionText
        card.setRating(value: product.ratingValue, reviews: product.reviews)
        let height = card.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        return ceil(height)
    }

    /// Ширина ячейки: карусель — 220 из макета, плитка — половина без зазора, список — вся.
    private func cellWidth() -> CGFloat {
        let width = collectionView.bounds.width
        switch layout {
        case .carousel: return 220
        case .grid: return max(0, floor((width - PersonalizationSpacing.xl) / 2))
        case .list: return max(0, width)
        }
    }

    private final class Cell: UICollectionViewCell {
        static let reuseId = "PersonalizationProductsList.Cell"
        let card = PersonalizationProductCard()

        override init(frame: CGRect) {
            super.init(frame: frame)
            card.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(card)
            // Все ячейки одной высоты (по самой высокой карточке); карточка занимает
            // ячейку целиком, а лишнюю высоту забирает её распорка между верхом и
            // низом — цена и кнопка соседей остаются на одной линии.
            NSLayoutConstraint.activate([
                card.topAnchor.constraint(equalTo: contentView.topAnchor),
                card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
            ])
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    }
}

extension PersonalizationProductsList: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        products.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Cell.reuseId, for: indexPath) as! Cell
        let product = products[indexPath.item]
        let card = cell.card
        card.type = layout.cardType
        card.imageAspect = imageAspect
        card.brand = product.brand
        card.name = product.name
        card.price = product.price
        card.oldPrice = product.oldPrice
        card.discount = product.discount
        card.actionText = product.actionText
        card.setRating(value: product.ratingValue, reviews: product.reviews)
        card.onAction = { [weak self] in self?.onProductAction?(product) }
        card.onTap = { [weak self] in self?.onProductTap?(product) }
        card.image.imageView.image = nil
        imageLoader?(card.image.imageView, product)
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: cellWidth(), height: itemHeight())
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard layout == .carousel else { return }
        let visible = collectionView.indexPathsForVisibleItems
            .filter { collectionView.bounds.contains(collectionView.layoutAttributesForItem(at: $0)?.frame ?? .null) }
            .map(\.item)
        guard let first = visible.min(), first != lastFirstVisible else { return }
        lastFirstVisible = first
        onFirstVisibleChanged?(first)
    }
}
