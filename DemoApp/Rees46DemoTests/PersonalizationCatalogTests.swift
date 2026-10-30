import XCTest
@_spi(PersonalizationUI) import REES46

/// The catalogue is one recycling list: however many pages are loaded, only the cards on screen
/// exist and they are reused while scrolling. Switched to `isScrollEnabled = false` for a host's
/// own scroll view, it lays out whole instead.
///
/// Cards are counted by the distinct image views handed to `imageLoader`: every card that was
/// ever created gets its image loaded, so that is how many cards the list has made.
final class PersonalizationCatalogTests: XCTestCase {

    private var window: UIWindow!
    private var imageViews = Set<ObjectIdentifier>()

    override func setUp() {
        super.setUp()
        // Never shown: the list lays out the same in a hidden window, and being in one sends
        // updates down the path a catalogue on screen takes.
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        imageViews = []
    }

    override func tearDown() {
        window = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    private func products(_ count: Int) -> [PersonalizationProduct] {
        (0..<count).map { index in
            PersonalizationProduct(
                id: "\(index)", name: "Product \(index)", price: "$\(index)", imageUrl: "https://example.com/\(index).jpg",
                brand: "Brand", ratingValue: "4.5", reviews: 10, actionText: "Add to cart"
            )
        }
    }

    /// A catalogue filling the window, as the search results screen places it.
    private func screenCatalog(products count: Int) -> PersonalizationCatalog {
        let catalog = PersonalizationCatalog()
        catalog.frame = window.bounds
        catalog.contentInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        catalog.imageLoader = { [weak self] imageView, _ in self?.imageViews.insert(ObjectIdentifier(imageView)) }
        window.addSubview(catalog)
        catalog.products = products(count)
        window.layoutIfNeeded()
        return catalog
    }

    private func list(of catalog: PersonalizationCatalog) -> UICollectionView {
        catalog.subviews.compactMap { $0 as? UICollectionView }[0]
    }

    private func frame(_ list: UICollectionView, section: Int, item: Int) -> CGRect {
        list.layoutAttributesForItem(at: IndexPath(item: item, section: section))?.frame ?? .null
    }

    private func settle() {
        // Row heights are checked after the rows lay out, so a change can take a second pass.
        for _ in 0..<3 { window.layoutIfNeeded() }
    }

    // MARK: - Recycling

    func testTwoHundredProductsInABoundedFrameCreateOnlyAScreenfulOfCards() {
        let catalog = screenCatalog(products: 200)
        let list = list(of: catalog)

        let onScreen = list.collectionViewLayout.layoutAttributesForElements(in: list.bounds)?
            .filter { $0.indexPath.section == 1 }.count ?? 0

        XCTAssertTrue(list.isScrollEnabled)
        XCTAssertGreaterThan(list.contentSize.height, 20 * catalog.bounds.height, "the list knows its full height")
        XCTAssertGreaterThan(onScreen, 0)
        XCTAssertLessThanOrEqual(list.visibleCells.count, onScreen + 2, "only the cards on screen exist")
        XCTAssertLessThanOrEqual(imageViews.count, onScreen + 4, "a screen holds a few rows of cards, not all 200")

        // Scroll through everything a screen at a time: the cards leaving the screen are reused.
        var offset: CGFloat = 0
        while offset < list.contentSize.height {
            offset += catalog.bounds.height / 2
            list.contentOffset = CGPoint(x: list.contentOffset.x, y: min(offset, list.contentSize.height - catalog.bounds.height))
            list.layoutIfNeeded()
        }

        XCTAssertTrue(list.indexPathsForVisibleItems.contains(IndexPath(item: 199, section: 1)))
        XCTAssertLessThanOrEqual(imageViews.count, 20, "two hundred products went by in a couple of screens of cards")
    }

    func testAppendedPagesKeepOnlyTheVisibleCardsAndDoNotRebindThem() {
        let catalog = screenCatalog(products: 20)
        let list = list(of: catalog)
        var loads = 0
        catalog.imageLoader = { [weak self] imageView, _ in
            loads += 1
            self?.imageViews.insert(ObjectIdentifier(imageView))
        }

        catalog.products = products(40)
        window.layoutIfNeeded()
        XCTAssertEqual(loads, 0, "the next page goes below; the cards on screen keep their images")

        for page in 3...10 {
            list.contentOffset = CGPoint(x: list.contentOffset.x, y: list.contentSize.height - catalog.bounds.height)
            window.layoutIfNeeded()
            catalog.products = products(page * 20)
            window.layoutIfNeeded()
        }

        XCTAssertEqual(list.numberOfItems(inSection: 1), 200)
        XCTAssertLessThanOrEqual(list.visibleCells.count, 10)
        XCTAssertLessThanOrEqual(imageViews.count, 20)
    }

    func testNearTheEndAsksForTheNextPage() {
        let catalog = screenCatalog(products: 40)
        let list = list(of: catalog)
        var asked = 0
        catalog.onNearEnd = { asked += 1 }

        list.contentOffset = CGPoint(x: list.contentOffset.x, y: catalog.bounds.height)
        XCTAssertEqual(asked, 0, "far from the end")

        list.contentOffset = CGPoint(x: list.contentOffset.x, y: list.contentSize.height - catalog.bounds.height)
        XCTAssertGreaterThan(asked, 0)
    }

    // MARK: - Layout

    func testBlocksAre12ApartAndCards16InARowAsTallAsTheTallestCard() {
        let header = UIView()
        header.heightAnchor.constraint(equalToConstant: 40).isActive = true
        let catalog = PersonalizationCatalog()
        catalog.frame = window.bounds
        window.addSubview(catalog)
        catalog.header = header
        var items = products(3)
        items[0] = PersonalizationProduct(
            id: "long", name: "A product with a name long enough to wrap onto a second line", price: "$1",
            brand: "Brand", ratingValue: "4.5", reviews: 10, actionText: "Add to cart"
        )
        catalog.products = items
        catalog.setCount(prefix: "Showing", shown: 3, separator: "of", total: 9)
        window.layoutIfNeeded()
        let list = list(of: catalog)

        let top = frame(list, section: 0, item: 0)
        let first = frame(list, section: 1, item: 0)
        let second = frame(list, section: 1, item: 1)
        let third = frame(list, section: 1, item: 2)
        let count = frame(list, section: 2, item: 0)

        XCTAssertEqual(top.height, 40)
        XCTAssertEqual(first.minY, top.maxY + 12)
        XCTAssertEqual(second.minY, first.minY)
        XCTAssertEqual(second.height, first.height, "a grid row is as tall as its tallest card")
        XCTAssertEqual(second.minX - first.maxX, 16, accuracy: 1)
        XCTAssertEqual(second.maxX, catalog.bounds.width, accuracy: 0.5)
        XCTAssertEqual(third.minY, first.maxY + 16)
        XCTAssertEqual(third.minX, 0)
        XCTAssertEqual(count.minY, third.maxY + 12)

        catalog.isLoading = true
        XCTAssertEqual(list.numberOfItems(inSection: 2), 1, "while loading the loader replaces count and load more")

        catalog.isLoading = false
        catalog.layout = .list
        window.layoutIfNeeded()
        let row = frame(list, section: 1, item: 0)
        XCTAssertEqual(row.width, catalog.bounds.width)
        XCTAssertEqual(frame(list, section: 1, item: 1).minY, row.maxY + 16)
    }

    /// Switched from the grid, the list measures each card for its own product: a discounted one
    /// after a plain one is as tall as it would be alone, its button under the price.
    func testListCardsSwitchedFromTheGridAreMeasuredForTheirOwnProduct() {
        let plain = PersonalizationProduct(id: "1", name: "Mouse", price: "14 990 ₽", actionText: "Add to cart")
        let discounted = PersonalizationProduct(
            id: "2", name: "Power supply 750W Ocypus Iota P750 ATX 3.1 80+Gold Full Modular", price: "48 990 ₽",
            oldPrice: "62 990 ₽", discount: "-22%", actionText: "Add to cart"
        )
        let catalog = screenCatalog(products: 0)
        catalog.products = [plain, discounted, plain]
        settle()
        let list = list(of: catalog)

        catalog.layout = .list
        settle()

        let alone = PersonalizationProductCard(type: .list)
        alone.showRating = false  // the product has no rating, so the catalogue's card shows none
        alone.name = discounted.name
        alone.price = discounted.price
        alone.oldPrice = discounted.oldPrice
        alone.discount = discounted.discount
        alone.actionText = discounted.actionText
        let width = frame(list, section: 1, item: 1).width
        let expected = ceil(alone.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height)
        XCTAssertGreaterThanOrEqual(frame(list, section: 1, item: 0).height, 120, "a card is as tall as its image")
        XCTAssertEqual(frame(list, section: 1, item: 1).height, expected)
        XCTAssertGreaterThan(expected, 120, "the two-line name and the button under the price")
    }

    func testAGrowingHeaderMovesTheCardsDown() {
        let header = UILabel()
        header.numberOfLines = 0
        header.text = "One line"
        let catalog = screenCatalog(products: 4)
        catalog.header = header
        settle()
        let list = list(of: catalog)
        let before = frame(list, section: 1, item: 0).minY

        header.text = "One line\nand another\nand a third"
        settle()

        XCTAssertGreaterThan(frame(list, section: 1, item: 0).minY, before + 20)
        XCTAssertEqual(frame(list, section: 1, item: 0).minY, frame(list, section: 0, item: 0).maxY + 12)
    }

    // MARK: - Inside another scroll view

    func testWithoutItsOwnScrollingTheCatalogueLaysOutWhole() {
        let catalog = PersonalizationCatalog()
        catalog.isScrollEnabled = false
        catalog.imageLoader = { [weak self] imageView, _ in self?.imageViews.insert(ObjectIdentifier(imageView)) }
        catalog.header = PersonalizationTitle(text: "Sneakers")
        catalog.products = products(6)
        catalog.setCount(prefix: "Showing", shown: 6, separator: "of", total: 128)
        catalog.loadMoreText = "Load more"

        // The showcase column: a stack in a vertical scroll view.
        let scroll = UIScrollView(frame: window.bounds)
        let stack = UIStackView(arrangedSubviews: [catalog])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        window.addSubview(scroll)
        settle()
        let list = list(of: catalog)

        XCTAssertFalse(list.isScrollEnabled)
        XCTAssertGreaterThan(catalog.bounds.height, 0)
        XCTAssertEqual(catalog.bounds.height, list.contentSize.height, accuracy: 0.5, "as tall as its content")
        XCTAssertEqual(list.contentOffset.y, 0)
        XCTAssertEqual(imageViews.count, 6, "all cards are laid out")
        XCTAssertEqual(list.numberOfItems(inSection: 2), 2)
        XCTAssertEqual(frame(list, section: 2, item: 1).maxY, list.contentSize.height, accuracy: 0.5)
    }
}
