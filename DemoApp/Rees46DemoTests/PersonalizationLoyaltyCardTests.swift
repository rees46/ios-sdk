import XCTest
@_spi(PersonalizationUI) @testable import REES46

/// The loyalty card as the Wallet frames draw it: pass proportions of at least 370×560, sections
/// that disappear when the host gives them nothing, stamps clamped to the total, the stripe at
/// width / 2.6 with the emblem overhanging its end, and the Elevation 3 shadow outside the clip.
final class PersonalizationLoyaltyCardTests: XCTestCase {

    private var host: UIWindow!

    override func setUp() {
        super.setUp()
        // Never shown, but a window: updates made after the first layout take the path they take
        // on screen, and the card sits under the window's top safe area, as it may in an app.
        host = UIWindow(frame: CGRect(x: 0, y: 0, width: 430, height: 2000))
    }

    override func tearDown() {
        host = nil
        super.tearDown()
    }

    // MARK: - Fixtures

    /// A card pinned to the top of the host at `width`, sized by its own constraints.
    private func laidOut(_ card: PersonalizationLoyaltyCard, width: CGFloat = 370) -> PersonalizationLoyaltyCard {
        card.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: host.topAnchor),
            card.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            card.widthAnchor.constraint(equalToConstant: width)
        ])
        host.layoutIfNeeded()
        return card
    }

    private func image(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { _ in }
    }

    private func filled() -> PersonalizationLoyaltyCard {
        fill(PersonalizationLoyaltyCard())
    }

    @discardableResult
    private func fill(_ card: PersonalizationLoyaltyCard) -> PersonalizationLoyaltyCard {
        card.logoLoader = { [unowned self] view in view.image = self.image(width: 336, height: 102) }
        card.stripeLoader = { [unowned self] view in view.image = self.image(width: 768, height: 432) }
        card.emblemLoader = { [unowned self] view in view.image = self.image(width: 359, height: 411) }
        card.balanceLabel = "Бонусы"
        card.balanceValue = "50 550"
        card.fields = [.init(label: "Владелец", value: "Олег"), .init(label: "Уровень", value: "Базовый")]
        card.stampsTotal = 5
        card.stamps = 2
        card.code = "2000012345678"
        return card
    }

    private func collected(_ card: PersonalizationLoyaltyCard) -> Int {
        card.stripe.stampsRow.arrangedSubviews.filter { $0.tintColor == PersonalizationColor.textLightSecondary }.count
    }

    // MARK: - Sections

    func testAnEmptyCardHasNoSectionsButKeepsThePassProportions() {
        let card = laidOut(PersonalizationLoyaltyCard())

        for section in [card.header, card.stripe, card.info, card.codeSection] {
            XCTAssertTrue(section.isHidden)
            XCTAssertNil(section.superview, "taken out of the column, not squeezed")
        }
        XCTAssertEqual(card.bounds.height, 560, accuracy: 0.5)
    }

    func testEachSectionAppearsWithItsContent() {
        let card = laidOut(PersonalizationLoyaltyCard())

        card.balanceValue = "50 550"
        XCTAssertFalse(card.header.isHidden, "balance alone")
        XCTAssertTrue(card.logoView.isHidden)
        card.balanceValue = nil
        card.logoLoader = { [unowned self] view in view.image = self.image(width: 336, height: 102) }
        XCTAssertFalse(card.header.isHidden, "logo alone")
        XCTAssertFalse(card.logoView.isHidden)

        card.stampsTotal = 3
        XCTAssertFalse(card.stripe.isHidden, "stamps alone")
        card.stampsTotal = 0
        XCTAssertTrue(card.stripe.isHidden)
        card.emblemLoader = { [unowned self] view in view.image = self.image(width: 359, height: 411) }
        XCTAssertFalse(card.stripe.isHidden, "emblem alone")

        card.fields = [.init(label: "Уровень", value: "Базовый")]
        XCTAssertFalse(card.info.isHidden)
        card.fields = []
        XCTAssertTrue(card.info.isHidden)

        card.code = "2000012345678"
        XCTAssertFalse(card.codeSection.isHidden)
        card.code = "é"
        XCTAssertTrue(card.codeSection.isHidden, "a code Code 128 cannot carry hides the section")
    }

    func testStampsAreClampedToTheTotal() {
        let card = PersonalizationLoyaltyCard()
        card.stampsTotal = 5

        card.stamps = 4
        XCTAssertEqual(card.stripe.stampsRow.arrangedSubviews.count, 5)
        XCTAssertEqual(collected(card), 4)

        card.stamps = 7
        XCTAssertEqual(card.stripe.stampsRow.arrangedSubviews.count, 5)
        XCTAssertEqual(collected(card), 5)

        card.stamps = -2
        XCTAssertEqual(collected(card), 0)

        card.stamps = 3
        card.stampsTotal = 2
        XCTAssertEqual(card.stripe.stampsRow.arrangedSubviews.count, 2)
        XCTAssertEqual(collected(card), 2, "clamped whichever is set last")
    }

    // MARK: - Geometry

    func testTheCardIsAtLeastWidthTimes560Over370AndGrowsWithItsContent() {
        let wide = laidOut(filled())
        XCTAssertEqual(wide.bounds.height, 560, accuracy: 0.5, "the content fits the pass")
        XCTAssertEqual(wide.codeSection.convert(wide.codeSection.bounds, to: wide).maxY, 560, accuracy: 0.5, "code at the bottom")

        let narrow = laidOut(filled(), width: 200)
        let sections = [narrow.header, narrow.stripe, narrow.info, narrow.codeSection].map { $0.bounds.height }.reduce(0, +)
        XCTAssertGreaterThan(narrow.bounds.height, 200 * 560 / 370, "taller than the pass")
        XCTAssertEqual(narrow.bounds.height, sections, accuracy: 0.5, "exactly as tall as the content")
    }

    func testContentArrivingAfterLayoutGrowsTheCard() {
        let card = laidOut(PersonalizationLoyaltyCard(), width: 200)
        XCTAssertEqual(card.bounds.height, 200 * 560 / 370, accuracy: 0.5)

        fill(card)
        host.layoutIfNeeded()
        let sections = [card.header, card.stripe, card.info, card.codeSection].map { $0.bounds.height }.reduce(0, +)
        XCTAssertGreaterThan(card.bounds.height, 200 * 560 / 370)
        XCTAssertEqual(card.bounds.height, sections, accuracy: 0.5)
    }

    func testSectionPaddingIs16EvenUnderTheSafeArea() {
        let card = laidOut(filled())
        XCTAssertEqual(card.header.bounds.height, 16 + 14 + 24 + 16, accuracy: 0.5, "balance label and value")
        XCTAssertEqual(card.info.bounds.height, 16 + 14 + 32 + 16, accuracy: 0.5, "field label and value")
        XCTAssertEqual(card.codeSection.bounds.height, 24 + 20 + 42 + 20 + 24, accuracy: 0.5)
    }

    func testTheLogoIs33HighAndAsWideAsItsImage() {
        let card = laidOut(filled())
        XCTAssertEqual(card.logoView.bounds.height, 33, accuracy: 0.01)
        XCTAssertEqual(card.logoView.bounds.width, 33 * 336 / 102, accuracy: 0.5)
        XCTAssertEqual(card.logoView.convert(card.logoView.bounds, to: card).minX, 16, accuracy: 0.01)
    }

    func testTheStripeIsWidthOver2_6AndTheEmblemOverhangsItsEnd() {
        let card = laidOut(filled())
        card.stripe.layoutIfNeeded()
        let stripe = card.stripe.bounds
        let emblem = card.stripe.emblemView.frame

        XCTAssertEqual(stripe.height, 370 / 2.6, accuracy: 0.5)
        XCTAssertEqual(emblem.height, stripe.height * 1.4545, accuracy: 0.01)
        XCTAssertEqual(emblem.width, emblem.height * 359 / 411, accuracy: 0.01)
        XCTAssertEqual(emblem.maxX, stripe.width + stripe.height * 0.17, accuracy: 0.01)
        XCTAssertEqual(emblem.minY, -stripe.height * 0.1166, accuracy: 0.01)
        XCTAssertTrue(card.stripe.clipsToBounds, "the emblem is cut by the stripe")
    }

    func testTheCardCastsTheElevation3ShadowOutsideItsClip() {
        let card = laidOut(filled())
        XCTAssertFalse(card.clipsToBounds, "clipping would cut the shadow off")
        XCTAssertEqual(card.layer.shadowOpacity, 1)
        XCTAssertEqual(card.layer.shadowOffset.height, 23)
        XCTAssertEqual(card.layer.shadowRadius, 11.5)
        XCTAssertNotNil(card.layer.shadowPath)
        let second = card.layer.sublayers?.first { $0.shadowOpacity > 0 && $0 !== card.layer }
        XCTAssertEqual(second?.shadowOffset.height, 6, "the second layer of Elevation 3")
        XCTAssertEqual(second?.shadowRadius, 6.5)
    }
}
