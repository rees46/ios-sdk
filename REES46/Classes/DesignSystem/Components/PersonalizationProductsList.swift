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
            collectionView.reloadData()
            invalidateIntrinsicContentSize()
        }
    }

    /// Хост кладёт изображение товара в `UIImageView` своим загрузчиком.
    public var imageLoader: ((UIImageView, PersonalizationProduct) -> Void)?
    public var onProductAction: ((PersonalizationProduct) -> Void)?

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

    public override func layoutSubviews() {
        super.layoutSubviews()
        flow.invalidateLayout()
    }

    /// Высота — по содержимому: карусель в одну строку карточек, плитка и список
    /// целиком, чтобы блок вставал в экран хоста без своего скролла.
    public override var intrinsicContentSize: CGSize {
        collectionView.layoutIfNeeded()
        let content = collectionView.collectionViewLayout.collectionViewContentSize
        return CGSize(width: UIView.noIntrinsicMetric, height: content.height)
    }

    /// Ширина ячейки: карусель — 220 из макета, плитка — половина без зазора, список — вся.
    private func cellWidth() -> CGFloat {
        let width = collectionView.bounds.width
        switch layout {
        case .carousel: return 220
        case .grid: return floor((width - PersonalizationSpacing.xl) / 2)
        case .list: return width
        }
    }

    private final class Cell: UICollectionViewCell {
        static let reuseId = "PersonalizationProductsList.Cell"
        let card = PersonalizationProductCard()

        override init(frame: CGRect) {
            super.init(frame: frame)
            card.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(card)
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
        card.brand = product.brand
        card.name = product.name
        card.price = product.price
        card.oldPrice = product.oldPrice
        card.discount = product.discount
        card.actionText = product.actionText
        if let rating = product.ratingValue { card.setRating(value: rating, reviews: product.reviews) }
        card.onAction = { [weak self] in self?.onProductAction?(product) }
        card.image.imageView.image = nil
        imageLoader?(card.image.imageView, product)
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = cellWidth()
        let card = PersonalizationProductCard(type: layout.cardType)
        let product = products[indexPath.item]
        card.brand = product.brand
        card.name = product.name
        card.price = product.price
        card.oldPrice = product.oldPrice
        card.discount = product.discount
        card.actionText = product.actionText
        if let rating = product.ratingValue { card.setRating(value: rating, reviews: product.reviews) }
        let height = card.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        return CGSize(width: width, height: ceil(height))
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
