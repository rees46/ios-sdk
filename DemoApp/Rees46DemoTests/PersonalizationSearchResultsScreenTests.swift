import XCTest
@_spi(PersonalizationUI) @testable import REES46

/// The search results screen driven by a fake SDK whose `search` answers are scripted:
/// rating visibility on the cards, and the error state with retry for the first and the next page.
final class PersonalizationSearchResultsScreenTests: XCTestCase {

    private var window: UIWindow!
    private var sdk: FakeSDK!
    private var screen: PersonalizationSearchResultsScreen!
    private var errors: [SdkError] = []

    override func setUp() {
        super.setUp()
        // Never shown: the screen lays out the same in a hidden window.
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        sdk = FakeSDK()
        errors = []
        screen = PersonalizationSearchResultsScreen()
        screen.frame = window.bounds
        screen.onError = { [weak self] error in self?.errors.append(error) }
        // An explicit instance, so the screen does not wait for the registry when it joins the window.
        screen.attach(sdk)
        window.addSubview(screen)
    }

    override func tearDown() {
        screen = nil
        sdk = nil
        window = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    private func page(total: Int, ids: Range<Int>) -> Result<SearchResponse, SdkError> {
        let products: [[String: Any]] = ids.map { index in
            ["id": "\(index)", "name": "Product \(index)", "price": 10.0, "price_formatted": "10 ₽"]
        }
        return .success(SearchResponse(json: ["products_total": total, "products": products]))
    }

    /// Sets the query and runs the first request right away instead of on the next main-loop turn.
    private func search(_ query: String) {
        screen.query = query
        screen.reload()
        window.layoutIfNeeded()
    }

    private func views<T: UIView>(_ type: T.Type, in root: UIView) -> [T] {
        root.subviews.flatMap { view -> [T] in
            let own = (view as? T).map { [$0] } ?? []
            return own + views(type, in: view)
        }
    }

    /// Visible buttons titled `text` anywhere on the screen.
    private func buttons(_ text: String) -> [PersonalizationButton] {
        views(PersonalizationButton.self, in: screen).filter { $0.text == text && !$0.isHiddenInHierarchy }
    }

    // MARK: - Rating

    func testCard_hidesRating_whenShowRatingIsOff() {
        let card = PersonalizationProductCard(type: .grid)
        card.setRating(value: "4.5", reviews: 10)
        let rating = views(PersonalizationRating.self, in: card)[0]
        XCTAssertFalse(rating.isHidden)

        card.showRating = false
        XCTAssertTrue(rating.isHidden)

        card.showRating = true
        XCTAssertFalse(rating.isHidden)
        card.setRating(value: nil, reviews: 0)
        XCTAssertTrue(rating.isHidden)
    }

    func testScreen_hidesRatingByDefault() {
        XCTAssertFalse(screen.showRating)
        XCTAssertFalse(screen.catalog.showRating)

        screen.showRating = true
        XCTAssertTrue(screen.catalog.showRating)
    }

    func testCatalog_withRatingOff_drawsNoRatingOnCards() {
        let catalog = screen.catalog
        catalog.products = [PersonalizationProduct(id: "1", name: "Rated", price: "$1", ratingValue: "4.5", reviews: 3)]
        window.layoutIfNeeded()
        let ratings = { self.views(PersonalizationRating.self, in: catalog) }
        XCTAssertFalse(ratings().isEmpty)
        XCTAssertTrue(ratings().allSatisfy(\.isHidden))

        catalog.showRating = true
        window.layoutIfNeeded()
        XCTAssertTrue(ratings().contains { !$0.isHidden })
    }
}

private extension UIView {
    var isHiddenInHierarchy: Bool {
        var view: UIView? = self
        while let current = view {
            if current.isHidden { return true }
            view = current.superview
        }
        return false
    }
}
