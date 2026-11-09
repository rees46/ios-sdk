import XCTest
@testable import REES46

/// The list card in a narrow column (a 360 pt phone, a large font): the discount badge and the
/// button move under the price instead of squeezing each other; a wide column keeps one line.
/// A grid card with long prices puts the old price above the price instead of cutting it.
final class PersonalizationProductCardTests: XCTestCase {

    func testWideListCardKeepsPriceAndButtonOnOneLine() {
        let card = listCard()
        layOut(card, width: 600)

        XCTAssertLessThan(frame(of: buttonOf(card), in: card).minY, frame(of: label("7 990 ₽", in: card), in: card).maxY)
        XCTAssertLessThan(frame(of: badgeOf(card), in: card).minY, frame(of: label("7 990 ₽", in: card), in: card).maxY)
    }

    func testNarrowListCardMovesTheButtonUnderThePriceToTheRightEdge() {
        let card = listCard()
        layOut(card, width: 280)

        let button = frame(of: buttonOf(card), in: card)
        XCTAssertGreaterThanOrEqual(button.minY, frame(of: label("9 990 ₽", in: card), in: card).maxY)
        XCTAssertEqual(button.maxX, card.bounds.maxX, accuracy: 0.5)
        XCTAssertEqual(frame(of: label("7 990 ₽", in: card), in: card).minX, 120 + PersonalizationSpacing.lg, accuracy: 0.5)
    }

    func testBadgeMovesUnderThePriceWhenEvenTheyDoNotFit() {
        let card = listCard()
        layOut(card, width: 200)

        XCTAssertGreaterThanOrEqual(frame(of: badgeOf(card), in: card).minY, frame(of: label("7 990 ₽", in: card), in: card).maxY)
    }

    func testTheListMeasuresTheWrappedCardTaller() {
        let card = listCard()
        let wide = height(of: card, width: 600)
        let narrow = height(of: card, width: 280)

        XCTAssertGreaterThan(narrow, wide)
    }

    func testAMeasuredGridCardSwitchedToTheListMeasuresAsAList() {
        let card = gridCard()
        _ = height(of: card, width: 171)

        card.type = .list

        XCTAssertGreaterThanOrEqual(height(of: card, width: 358), 120)
    }

    /// A cell's card switched from the grid to the list and given the next product: the old price
    /// the grid hid shows again, and the button moves under the price.
    func testAGridCardSwitchedToTheListShowsTheOldPriceTheGridHid() {
        let card = PersonalizationProductCard(type: .grid)
        card.show(PersonalizationProduct(id: "1", name: "Mouse", price: "14 990 ₽", actionText: "Add to cart"))
        layOut(card, width: 171)

        card.type = .list
        card.show(PersonalizationProduct(
            id: "2", name: "Power supply", price: "48 990 ₽", oldPrice: "62 990 ₽", discount: "-22%", actionText: "Add to cart"
        ))
        layOut(card, width: 358)

        let old = label("62 990 ₽", in: card)
        XCTAssertEqual(frame(of: old, in: card).width, old.intrinsicContentSize.width, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(frame(of: buttonOf(card), in: card).minY, frame(of: old, in: card).maxY)
    }

    func testLongGridPricesPutTheOldPriceAboveThePrice() {
        let card = gridCard()
        layOut(card, width: 160)

        let price = frame(of: label("799 990 ₽", in: card), in: card)
        let old = frame(of: label("1 574 990 ₽", in: card), in: card)
        XCTAssertLessThanOrEqual(old.maxY, price.minY + 0.5)
        XCTAssertEqual(old.minX, price.minX, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(old.width, label("1 574 990 ₽", in: card).intrinsicContentSize.width - 0.5)
    }

    func testGridPricesThatFitStayOnOneLine() {
        let card = gridCard()
        layOut(card, width: 400)

        let price = frame(of: label("799 990 ₽", in: card), in: card)
        let old = frame(of: label("1 574 990 ₽", in: card), in: card)
        XCTAssertGreaterThan(old.minX, price.maxX)
        XCTAssertGreaterThan(old.maxY, price.minY)
    }

    // MARK: - Helpers

    private func gridCard() -> PersonalizationProductCard {
        let card = PersonalizationProductCard(type: .grid)
        card.brand = "Bang & Olufsen"
        card.name = "TV"
        card.price = "799 990 ₽"
        card.oldPrice = "1 574 990 ₽"
        card.discount = "-49%"
        card.actionText = "Add to cart"
        return card
    }

    private func listCard() -> PersonalizationProductCard {
        let card = PersonalizationProductCard(type: .list)
        card.imageAspect = .landscape
        card.name = "Mouse"
        card.price = "7 990 ₽"
        card.oldPrice = "9 990 ₽"
        card.discount = "-20%"
        card.actionText = "Add to cart"
        return card
    }

    /// Measured the way the kit's lists measure a cell: fixed width, height by content.
    private func height(of card: UIView, width: CGFloat) -> CGFloat {
        card.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
    }

    private func layOut(_ card: UIView, width: CGFloat) {
        card.frame = CGRect(x: 0, y: 0, width: width, height: height(of: card, width: width))
        card.layoutIfNeeded()
        // The wrap is decided in layoutSubviews; the second pass places the stacks it changed.
        card.layoutIfNeeded()
    }

    private func frame(of view: UIView, in card: UIView) -> CGRect {
        view.convert(view.bounds, to: card)
    }

    private func all(_ root: UIView) -> [UIView] {
        [root] + root.subviews.flatMap(all)
    }

    private func label(_ text: String, in card: UIView) -> UILabel {
        all(card).compactMap { $0 as? UILabel }.first { ($0.attributedText?.string ?? $0.text) == text }!
    }

    private func buttonOf(_ card: UIView) -> PersonalizationButton {
        all(card).compactMap { $0 as? PersonalizationButton }.first!
    }

    private func badgeOf(_ card: UIView) -> PersonalizationBadge {
        all(card).compactMap { $0 as? PersonalizationBadge }.first { !$0.isHidden }!
    }
}
