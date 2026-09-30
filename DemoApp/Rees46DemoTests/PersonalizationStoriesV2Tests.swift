import XCTest
@_spi(PersonalizationUI) @testable import REES46

/// Stories V2 of the kit: the price splits the currency off the server's formatted string and
/// picks its kind from the product (promo code, then discount, then plain price), the timer
/// counts down in d/h/m/s, a text block is framed only when its fill shows, slides pick their
/// theme, the viewer's server data maps from the same `StoryContent` the legacy stories parse,
/// and the cover splits its ring into one arc per slide.
final class PersonalizationStoriesV2Tests: XCTestCase {

    // MARK: - Price: currency split

    private func split(_ formatted: String) -> [String?] {
        let parts = PersonalizationStoryPrice.splitCurrency(formatted)
        return [parts.amount, parts.currency]
    }

    func testCurrencyIsTheTrailingTokenWithoutDigits() {
        XCTAssertEqual(split("1 190 900 ₽"), ["1 190 900", "₽"])
        XCTAssertEqual(split("12,99 €"), ["12,99", "€"])
        XCTAssertEqual(split("9 999₽"), ["9 999", "₽"], "no space before the sign")
        XCTAssertEqual(split("1 190.00 руб."), ["1 190.00", "руб."])
        XCTAssertEqual(split("245\u{00A0}000\u{00A0}₽"), ["245\u{00A0}000", "₽"], "non-breaking spaces of server formatting")
    }

    func testWithoutATrailingTokenTheWholeStringIsTheAmount() {
        XCTAssertEqual(split("$140"), ["$140", nil])
        XCTAssertEqual(split("Free"), ["Free", nil])
        XCTAssertEqual(split(""), ["", nil])
    }

    // MARK: - Price: kind from the product

    private func product(_ item: [String: Any]) -> PersonalizationStorySlide.Offer? {
        let slide: [String: Any] = [
            "id": "39_0", "type": "", "duration": 10, "background": "",
            "elements": [
                ["type": "button", "title": "Buy", "link": "https://shop.example/p?utm=1", "link_ios": "https://shop.example/p"],
                ["type": "product", "item": item]
            ]
        ]
        let content = StoryContent(json: ["id": 1, "stories": [["id": 39, "name": "Test", "slides": [slide]]]])
        return PersonalizationStory.list(from: content).first?.slides.first?.offer
    }

    private let base: [String: Any] = [
        "id": "216908", "name": "Надувной бассейн", "brand": "INTEX",
        "price": 19990, "price_formatted": "19 990 ₽",
        "oldprice": 27990, "oldprice_formatted": "27 990 ₽",
        "image_url": "https://img.example/216908.jpg", "picture": "https://img.example/180/216908.jpg",
        "url": "https://shop.example/p?recommended_by=stories", "deeplink_ios": "https://shop.example/p"
    ]

    private func merged(_ extra: [String: Any]) -> [String: Any] {
        base.merging(extra) { _, new in new }
    }

    func testAPromoCodeWinsOverTheDiscountAndShowsThePriceWithTheCode() {
        let offer = product(merged([
            "discount_percent": 28, "promocode": "PROMO", "price_with_promocode_formatted": "17 990 ₽"
        ]))

        XCTAssertEqual(offer?.priceKind, .promoCode("PROMO"))
        XCTAssertEqual(offer?.displayedPrice, "17 990 ₽")
        XCTAssertEqual(offer?.oldPrice, "27 990 ₽")
    }

    func testADiscountShowsItsPercent() {
        let offer = product(merged(["discount_percent": 28]))

        XCTAssertEqual(offer?.priceKind, .discount("28%"))
        XCTAssertEqual(offer?.displayedPrice, "19 990 ₽")
    }

    func testWithoutPromoCodeAndDiscountOnlyThePrice() {
        // The server sends `null` for a missing discount; an old price equal to the price is no old price.
        let offer = product(merged(["discount_percent": NSNull(), "oldprice": 19990, "oldprice_formatted": "19 990 ₽"]))

        XCTAssertEqual(offer?.priceKind, .price)
        XCTAssertNil(offer?.oldPrice)
    }

    func testTheProductMapsBrandImageAndTheIOSLink() {
        let offer = product(base)

        XCTAssertEqual(offer?.brand, "INTEX")
        XCTAssertEqual(offer?.imageUrl, "https://img.example/216908.jpg", "the original, not the 180 px picture")
        XCTAssertEqual(offer?.link, "https://shop.example/p", "deeplink_ios before url")
    }

    // MARK: - Server data

    func testSlidesMapKindButtonsCarouselAndTextBlocks() {
        let slide: [String: Any] = [
            "id": 37, "type": "", "duration": 7, "background": "", "background_color": "#000000",
            "elements": [
                ["type": "button", "title": "Go gaming!", "link": "https://demo.example/", "link_ios": ""],
                ["type": "button", "title": ""],
                ["type": "products",
                 "labels": ["show_carousel": "Товары для геймеров", "hide_carousel": "Скрыть товары"],
                 "products": [
                    ["name": "Mouse", "price": 12990, "price_formatted": "12 990 ₽",
                     "oldprice": 15990, "oldprice_formatted": "15 990 ₽", "picture": "https://img.example/m.jpg",
                     "url": "https://shop.example/m"],
                    ["name": "Keyboard", "price": 47790, "price_formatted": "47 790 ₽",
                     "oldprice": 47790, "oldprice_formatted": "47 790 ₽", "url": "https://shop.example/k"]
                 ]],
                ["type": "text_block", "text_input": "Sale", "font_size": "30", "text_line_spacing": "1.2",
                 "text_align": "center", "text_color": "#FFFFFF", "text_background_color": "#00FF00",
                 "text_background_color_opacity": "50%", "y_offset": "25", "bold": true]
            ]
        ]
        let empty: [String: Any] = ["id": 41, "name": "Empty", "slides": [[String: Any]]()]
        let content = StoryContent(json: ["id": 1, "stories": [
            ["id": 40, "name": "Gaming", "avatar": "https://img.example/a.jpg", "pinned": true, "start_position": 0, "slides": [slide]],
            empty
        ]])

        let stories = PersonalizationStory.list(from: content)
        XCTAssertEqual(stories.map(\.id), ["40"], "a story without slides is dropped")
        guard let mapped = stories.first?.slides.first else { return XCTFail("no slide") }

        XCTAssertEqual(mapped.id, "37")
        XCTAssertEqual(mapped.kind, .content)
        XCTAssertEqual(mapped.duration, 7)
        XCTAssertEqual(mapped.buttons.map(\.title), ["Go gaming!"], "a button without a title is not drawn")
        XCTAssertEqual(mapped.buttons.first?.link, "https://demo.example/", "empty link_ios falls back to link")

        XCTAssertEqual(mapped.products?.showLabel, "Товары для геймеров")
        XCTAssertEqual(mapped.products?.items.map(\.name), ["Mouse", "Keyboard"])
        XCTAssertEqual(mapped.products?.items.first?.oldPrice, "15 990 ₽")
        XCTAssertEqual(mapped.products?.items.first?.discountPercent, 19, "(15990 - 12990) / 15990")
        XCTAssertNil(mapped.products?.items.last?.oldPrice)

        guard let block = mapped.textBlocks.first else { return XCTFail("no text block") }
        XCTAssertEqual(block.style, PersonalizationStoryTextBlock.Style(size: 30, lineHeight: 36))
        XCTAssertEqual(block.alignment, .center)
        XCTAssertTrue(block.bold)
        XCTAssertEqual(block.yOffset, 25)
        XCTAssertEqual(block.fill?.cgColor.alpha ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(mapped.interfaceStyle, .dark, "a black background colour")
    }

    func testSlideKindFollowsTheServerType() {
        XCTAssertEqual(PersonalizationStorySlide.kind(of: .image), .image)
        XCTAssertEqual(PersonalizationStorySlide.kind(of: .video), .video)
        XCTAssertEqual(PersonalizationStorySlide.kind(of: .unknown), .content)
    }

    func testMediaSlidesAreDarkProductSlidesFollowTheApp() {
        XCTAssertEqual(PersonalizationStorySlide(id: "1", kind: .image).interfaceStyle, .dark)
        XCTAssertEqual(PersonalizationStorySlide(id: "2", kind: .video).interfaceStyle, .dark)
        XCTAssertEqual(PersonalizationStorySlide(id: "3", kind: .content).interfaceStyle, .unspecified)
        XCTAssertEqual(PersonalizationStorySlide(id: "4", kind: .content, backgroundColor: .white).interfaceStyle, .light)
        XCTAssertEqual(PersonalizationStorySlide(id: "5", kind: .content, background: "https://img.example/bg.jpg").interfaceStyle, .dark)
    }

    func testAMissingDurationFallsBackToFiveSeconds() {
        XCTAssertEqual(PersonalizationStorySlide(id: "1", kind: .image, duration: 0).duration, 5)
    }

    func testAPinnedStoryStaysPinnedOnceViewedOthersTurnGrey() {
        let slides = [PersonalizationStorySlide(id: "1", kind: .content), PersonalizationStorySlide(id: "2", kind: .content)]
        let state = StoriesSeenState(sdk: nil)

        let pinned = state.barItem(PersonalizationStory(id: "p", name: "P", pinned: true, viewed: true, slides: slides))
        XCTAssertEqual(pinned.state, .pinned, "Semantic/Warning ring and the star")
        XCTAssertEqual(pinned.seen, 0, "a finished pinned ring is not lightened")

        let plain = state.barItem(PersonalizationStory(id: "v", name: "V", viewed: true, slides: slides))
        XCTAssertEqual(plain.state, .viewed)

        let fresh = state.barItem(PersonalizationStory(id: "d", name: "D", slides: slides))
        XCTAssertEqual(fresh.state, .default)
        XCTAssertEqual(fresh.segments, 2)
    }

    func testAProductSlideWithoutItsOwnColourSitsOnBackgroundCard() {
        let offer = PersonalizationStorySlide.Offer(id: "1", name: "MacBook", price: "1 190 900 ₽")
        let plain = PersonalizationStorySlideView(
            slide: PersonalizationStorySlide(id: "1", kind: .content, offer: offer),
            texts: .init(), isMuted: true, imageLoader: { _, _ in }
        )
        XCTAssertEqual(plain.backgroundColor, PersonalizationColor.backgroundCard)
        XCTAssertEqual(plain.slide.interfaceStyle, .unspecified, "follows the app")

        let blue = UIColor(red: 0, green: 0x80 / 255.0, blue: 0xF0 / 255.0, alpha: 1)
        let coloured = PersonalizationStorySlideView(
            slide: PersonalizationStorySlide(id: "2", kind: .content, backgroundColor: blue, offer: offer),
            texts: .init(), isMuted: true, imageLoader: { _, _ in }
        )
        XCTAssertEqual(coloured.backgroundColor, blue, "the server's background_color")
        XCTAssertEqual(coloured.slide.interfaceStyle, .dark, "by the colour's brightness")
    }

    // MARK: - Timer

    func testTimerSplitsTheRestIntoDaysHoursMinutesSeconds() {
        let rest: TimeInterval = ((2 * 24 + 18) * 60 + 33) * 60 + 24
        XCTAssertEqual(PersonalizationStoryTimer.texts(remaining: rest), ["2", "18", "33", "24"])
    }

    func testTimerPadsAllButDaysAndRoundsSecondsDown() {
        XCTAssertEqual(PersonalizationStoryTimer.texts(remaining: 3_725.9), ["0", "01", "02", "05"])
        XCTAssertEqual(PersonalizationStoryTimer.texts(remaining: 100 * 86_400), ["100", "00", "00", "00"])
    }

    func testTimerKeepsTwoDigitsForHoursMinutesSeconds() {
        let rest: TimeInterval = ((2 * 24 + 8) * 60 + 3) * 60 + 4
        XCTAssertEqual(PersonalizationStoryTimer.texts(remaining: rest), ["2", "08", "03", "04"], "2d 08h 03m 04s")
    }

    func testTimerStopsAtZero() {
        XCTAssertEqual(PersonalizationStoryTimer.texts(remaining: -5), ["0", "00", "00", "00"])
    }

    // MARK: - Text block

    func testASolidBlockGetsTheKitFrameATransparentOneDoesNot() {
        let solid = PersonalizationStorySlide.TextBlock.fill(color: "#00AA00", opacity: "100%")
        let half = PersonalizationStorySlide.TextBlock.fill(color: "#00AA00", opacity: "50%")
        let invisible = PersonalizationStorySlide.TextBlock.fill(color: "#00AA00", opacity: "0%")
        let noColour = PersonalizationStorySlide.TextBlock.fill(color: "", opacity: "100%")

        XCTAssertTrue(PersonalizationStoryTextBlock.isSolid(solid))
        XCTAssertTrue(PersonalizationStoryTextBlock.isSolid(half))
        XCTAssertFalse(PersonalizationStoryTextBlock.isSolid(invisible))
        XCTAssertFalse(PersonalizationStoryTextBlock.isSolid(noColour))
        XCTAssertNil(noColour)
    }

    func testSolidPaddingIs12ForLargeTextAnd8OtherwiseTransparentHasNone() {
        let large = PersonalizationStoryTextBlock.insets(style: .large, solid: true)
        let medium = PersonalizationStoryTextBlock.insets(style: .medium, solid: true)
        let small = PersonalizationStoryTextBlock.insets(style: .small, solid: true)

        XCTAssertEqual(large, UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        XCTAssertEqual(medium, UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
        XCTAssertEqual(small, UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
        XCTAssertEqual(PersonalizationStoryTextBlock.insets(style: .large, solid: false), .zero)
    }

    func testTheBlockFramesItselfByItsFill() {
        let block = PersonalizationStoryTextBlock(text: "Sale", style: .large, fill: .green)
        XCTAssertTrue(block.isSolid)
        XCTAssertEqual(block.layer.cornerRadius, 12)

        block.fill = UIColor.green.withAlphaComponent(0)
        XCTAssertFalse(block.isSolid)
        XCTAssertEqual(block.layer.cornerRadius, 0)
    }

    func testOpacityStringsFromTheAdmin() {
        XCTAssertEqual(PersonalizationStoryColors.opacity("0%"), 0)
        XCTAssertEqual(PersonalizationStoryColors.opacity("35%") ?? -1, 0.35, accuracy: 0.0001)
        XCTAssertEqual(PersonalizationStoryColors.opacity("100%"), 1)
        XCTAssertEqual(PersonalizationStoryColors.opacity("0.5") ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertNil(PersonalizationStoryColors.opacity(""))
        XCTAssertNil(PersonalizationStoryColors.opacity("abc"))
    }

    func testHexColoursFromTheAdmin() {
        XCTAssertNotNil(PersonalizationStoryColors.parse("#3b82f6"))
        XCTAssertNotNil(PersonalizationStoryColors.parse("fff"))
        XCTAssertEqual(PersonalizationStoryColors.parse("#00000080")?.cgColor.alpha ?? 0, 128.0 / 255, accuracy: 0.001)
        XCTAssertNil(PersonalizationStoryColors.parse(""))
        XCTAssertNil(PersonalizationStoryColors.parse("#12"))
        XCTAssertNil(PersonalizationStoryColors.parse("not a colour"))
    }

    // MARK: - Cover and progress

    func testTheRingSplitsIntoOneArcPerSlideWithEqualGaps() {
        let gap: CGFloat = 0.1
        let arcs = PersonalizationStoryCover.segmentAngles(count: 4, gapAngle: gap)

        XCTAssertEqual(arcs.count, 4)
        XCTAssertEqual(arcs[0].start, -.pi / 2 + gap / 2, accuracy: 0.0001, "the first arc starts at the top")
        for index in 1..<arcs.count {
            XCTAssertEqual(arcs[index].start - arcs[index - 1].end, gap, accuracy: 0.0001)
        }
        let swept = arcs.reduce(0) { $0 + $1.end - $1.start }
        XCTAssertEqual(swept + 4 * gap, 2 * .pi, accuracy: 0.0001)
    }

    func testASingleSlideIsASolidRing() {
        let arcs = PersonalizationStoryCover.segmentAngles(count: 1, gapAngle: 0.1)
        XCTAssertEqual(arcs.count, 1)
        XCTAssertEqual(arcs[0].end - arcs[0].start, 2 * .pi, accuracy: 0.0001)
    }

    func testProgressFillsPastSlidesAndPartOfTheCurrent() {
        let progress = PersonalizationStoryProgress(count: 4)
        progress.current = 2
        progress.progress = 0.4

        XCTAssertEqual([0, 1, 2, 3].map { progress.fraction(of: $0) }, [1, 1, 0.4, 0])
    }

    // MARK: - Layout

    /// Never shown, but a window: the views lay out the way they do on screen.
    private var host: UIWindow!

    override func setUp() {
        super.setUp()
        host = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    }

    override func tearDown() {
        host = nil
        super.tearDown()
    }

    /// The view pinned to the top of the host at `width`, height by its own constraints.
    @discardableResult
    private func laidOut<T: UIView>(_ view: T, width: CGFloat = 370) -> T {
        view.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: host.topAnchor),
            view.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            view.widthAnchor.constraint(equalToConstant: width)
        ])
        host.layoutIfNeeded()
        return view
    }

    /// Left and right columns of the price: the row is the only stack directly inside.
    private func columns(_ price: PersonalizationStoryPrice) -> (left: UIView, right: UIView) {
        let row = price.subviews.compactMap { $0 as? UIStackView }.first!
        return (row.arrangedSubviews[0], row.arrangedSubviews[1])
    }

    func testThePriceBoxIs70HighWithTheOldPrice() {
        let price = laidOut(PersonalizationStoryPrice(price: "1 190 900 ₽", oldPrice: "1 245 000 ₽"))
        XCTAssertEqual(price.frame.height, 70, accuracy: 0.5, "12 + 16 + 30 + 12")
        XCTAssertTrue(columns(price).right.isHidden)
    }

    func testPromoColumnsShareTheWidthAndALongCodeTakesMore() {
        let short = laidOut(PersonalizationStoryPrice(price: "1 190 900 ₽", oldPrice: "1 245 000 ₽", kind: .promoCode("PROMO")))
        let halves = columns(short)
        XCTAssertEqual(short.frame.height, 70, accuracy: 0.5, "12 + 16 + 30 + 12 on both sides")
        XCTAssertEqual(halves.left.frame.width, halves.right.frame.width, accuracy: 0.5)
        XCTAssertEqual(halves.left.frame.width + halves.right.frame.width, 370, accuracy: 0.5)

        let long = laidOut(PersonalizationStoryPrice(price: "1 190 900 ₽", kind: .promoCode("YAGODA-MALINA-2026")))
        let split = columns(long)
        XCTAssertGreaterThan(split.right.frame.width, split.left.frame.width)
        XCTAssertEqual(split.left.frame.width + split.right.frame.width, 370, accuracy: 0.5)
    }

    func testThePromoCodeZoomsTo103PercentUnderTheFinger() {
        XCTAssertEqual(PersonalizationStoryPrice.pressedScale, 1.03)
    }

    func testTheDiscountBlockHugsItsTextAndThePriceTakesTheRest() {
        let price = laidOut(PersonalizationStoryPrice(price: "1 190 900 ₽", oldPrice: "1 245 000 ₽", kind: .discount("10%")))
        let parts = columns(price)
        XCTAssertLessThan(parts.right.frame.width, 150)
        XCTAssertEqual(parts.left.frame.width + parts.right.frame.width, 370, accuracy: 0.5)
        XCTAssertEqual(parts.right.frame.height, price.frame.height, accuracy: 0.5)
    }

    func testTimerMergedIsOnePillSeparateIsFourEqualBoxes() {
        let merged = laidOut(PersonalizationStoryTimer(endDate: Date().addingTimeInterval(3_600), view: .merged))
        XCTAssertEqual(merged.frame.height, 60, accuracy: 0.5, "8 + 44 + 8")

        let separate = laidOut(PersonalizationStoryTimer(endDate: Date().addingTimeInterval(3_600), view: .separate))
        let boxes = (separate.subviews.first as? UIStackView)?.arrangedSubviews ?? []
        XCTAssertEqual(boxes.count, 4)
        let widths = boxes.map(\.frame.width)
        XCTAssertEqual(widths.max() ?? 0, widths.min() ?? 1, accuracy: 0.5, "equal widths")
        XCTAssertEqual(boxes.last?.frame.maxX ?? 0, 370, accuracy: 0.5)
    }

    func testCoverAndPreviewKeepTheirSize() {
        let preview = laidOut(PersonalizationStoryPreview(title: "A very long story name", state: .pinned), width: 88)
        XCTAssertEqual(preview.frame.height, 88 + 8 + 16, accuracy: 0.5)
        XCTAssertEqual(preview.cover.frame.size, CGSize(width: 88, height: 88))
        XCTAssertEqual(preview.cover.imageView.frame, CGRect(x: 6, y: 6, width: 76, height: 76))

        let bar = laidOut(PersonalizationStoriesBar(), width: 402)
        XCTAssertEqual(bar.frame.height, 16 + 112 + 16, accuracy: 0.5)
    }

    func testTheProductSlideFitsTheSquareCardBetweenTheHeaderAndThePrice() {
        let slide = PersonalizationStorySlide(
            id: "1", kind: .content,
            offer: PersonalizationStorySlide.Offer(id: "1", brand: "Apple", name: "MacBook Pro 16", price: "1 190 900 ₽", discountPercent: 10)
        )
        let view = PersonalizationStorySlideView(slide: slide, texts: .init(), isMuted: true, imageLoader: { _, _ in })
        view.safeInsets = Self.islandInsets
        view.frame = host.bounds
        host.addSubview(view)
        host.layoutIfNeeded()

        let card = view.subviews.first { $0.backgroundColor == .white }
        let price = view.subviews.compactMap { $0 as? UIStackView }.first { $0.arrangedSubviews.first is PersonalizationStoryPrice }
        guard let card, let price else { return XCTFail("no card or price") }
        XCTAssertEqual(card.frame.width, card.frame.height, accuracy: 0.5, "square")
        XCTAssertEqual(card.frame.width, 370, accuracy: 0.5, "full content width on a tall screen")
        XCTAssertLessThanOrEqual(card.frame.maxY, price.frame.minY - 16 + 0.5)
        XCTAssertEqual(price.frame.maxY, 874 - 34 - 16, accuracy: 0.5, "16 above the safe area")
        XCTAssertEqual(view.contentGuide.layoutFrame.minY, 62 + 16, accuracy: 0.5, "16 below the Dynamic Island")
    }

    func testOnAShortScreenTheCardShrinksInsteadOfOverlapping() {
        host.frame = CGRect(x: 0, y: 0, width: 375, height: 560)
        let slide = PersonalizationStorySlide(
            id: "1", kind: .content, buttons: [.init(title: "Buy")],
            offer: PersonalizationStorySlide.Offer(id: "1", brand: "Apple", name: "MacBook Pro 16", price: "1 190 900 ₽", promoCode: "PROMO")
        )
        let view = PersonalizationStorySlideView(slide: slide, texts: .init(), isMuted: true, imageLoader: { _, _ in })
        view.frame = host.bounds
        host.addSubview(view)
        host.layoutIfNeeded()

        let card = view.subviews.first { $0.backgroundColor == .white }
        let price = view.subviews.compactMap { $0 as? UIStackView }.first { $0.arrangedSubviews.first is PersonalizationStoryPrice }
        guard let card, let price else { return XCTFail("no card or price") }
        XCTAssertLessThan(card.frame.width, 343)
        XCTAssertEqual(card.frame.width, card.frame.height, accuracy: 0.5)
        XCTAssertLessThanOrEqual(card.frame.maxY, price.frame.minY - 16 + 0.5)
    }

    func testAMediaSlidePutsProductsAtTheBottomAndTextBlocksAtTheirOffset() {
        let slide = PersonalizationStorySlide(
            id: "1", kind: .video, background: "https://video.example/a.mp4",
            products: .init(items: [PersonalizationStorySlide.Offer(id: "1", name: "Mouse", price: "12 990 ₽")]),
            textBlocks: [.init(text: "Sale", style: .large, fill: .green, yOffset: 50)]
        )
        let view = PersonalizationStorySlideView(slide: slide, texts: .init(), isMuted: true, imageLoader: { _, _ in })
        view.safeInsets = Self.islandInsets
        view.frame = host.bounds
        host.addSubview(view)
        host.layoutIfNeeded()

        let block = view.subviews.first { $0 is PersonalizationStoryTextBlock }
        let bottom = view.subviews.compactMap { $0 as? UIStackView }.last
        let used = bottom?.arrangedSubviews.first { $0 is PersonalizationStoryUsedProducts }
        XCTAssertEqual(block?.frame.minY ?? 0, 437, accuracy: 0.5, "50% of 874")
        XCTAssertEqual(block?.frame.width ?? 0, 370, accuracy: 0.5)
        XCTAssertEqual(used?.frame.height ?? 0, 64, accuracy: 0.5, "collapsed: the row only")
        XCTAssertEqual(bottom?.frame.maxY ?? 0, 874 - 34, accuracy: 0.5, "on the safe area: the row has its own 16")
        let background = view.subviews.first { $0 is UIImageView }
        XCTAssertEqual(background?.frame, view.bounds, "the background still goes edge to edge")
        view.stop()
    }

    func testExpandedUsedProductsShowTheCarouselOnTheCardSheet() {
        let used = PersonalizationStoryUsedProducts()
        used.products = (0..<3).map { PersonalizationProduct(id: String($0), name: "Product \($0)", price: "9 999 ₽") }
        used.leadingView = PersonalizationStorySoundButton()
        laidOut(used, width: 402)
        XCTAssertEqual(used.frame.height, 64, accuracy: 0.5, "collapsed: the row only")

        used.isExpanded = true
        host.layoutIfNeeded()
        XCTAssertGreaterThan(used.list.frame.height, 100, "the carousel has its cards' height")
        XCTAssertEqual(used.frame.height, 16 + used.list.frame.height + 16 + 64, accuracy: 0.5)
        XCTAssertEqual(used.backgroundColor, PersonalizationColor.backgroundCard)
    }

    func testThePagePutsTheSlideUnderTheNavigation() {
        let story = PersonalizationStory(id: "s", name: "S", slides: [
            PersonalizationStorySlide(
                id: "1", kind: .content,
                offer: PersonalizationStorySlide.Offer(id: "1", brand: "Apple", name: "MacBook", price: "1 190 900 ₽", promoCode: "PROMO")
            )
        ])
        let viewer = PersonalizationStoriesViewController(stories: [story])
        let page = PersonalizationStoryPageViewController(story: story, storyIndex: 0, startSlide: 0, viewer: viewer)
        page.safeInsets = Self.islandInsets
        page.view.frame = host.bounds
        host.addSubview(page.view)
        host.layoutIfNeeded()

        func all(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(all) }
        let views = all(page.view)
        guard let navigation = views.first(where: { $0 is PersonalizationStoryNavigation }),
              let slide = views.first(where: { $0 is PersonalizationStorySlideView }) as? PersonalizationStorySlideView
        else { return XCTFail("no navigation or slide") }
        let navigationFrame = navigation.convert(navigation.bounds, to: page.view)
        XCTAssertEqual(navigationFrame.height, 46, accuracy: 0.5, "2 + 12 + 32")
        XCTAssertEqual(navigationFrame.width, 402 - 32, accuracy: 0.5)
        XCTAssertEqual(navigationFrame.minY, 62 + 16, accuracy: 0.5, "16 below the Dynamic Island, not under it")
        XCTAssertEqual(slide.contentGuide.layoutFrame.minY, navigationFrame.maxY + 16, accuracy: 0.5)
        XCTAssertEqual(slide.safeInsets, Self.islandInsets, "the slide gets the page's safe area")

        // A new safe area (rotation, a call bar) moves the controls, not the background.
        page.safeInsets = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        host.layoutIfNeeded()
        XCTAssertEqual(navigation.convert(navigation.bounds, to: page.view).minY, 36, accuracy: 0.5)
        XCTAssertEqual(slide.frame, page.view.bounds)
    }

    func testTheViewerHandsItsSafeAreaToThePages() {
        let story = PersonalizationStory(id: "s", name: "S", slides: [PersonalizationStorySlide(id: "1", kind: .content)])
        let viewer = PersonalizationStoriesViewController(stories: [story])
        viewer.view.frame = host.bounds
        host.addSubview(viewer.view)
        host.layoutIfNeeded()
        viewer.view.layoutIfNeeded()

        let pager = viewer.children.compactMap { $0 as? UIPageViewController }.first
        let page = pager?.viewControllers?.first as? PersonalizationStoryPageViewController
        XCTAssertNotNil(page)
        XCTAssertEqual(page?.safeInsets, viewer.view.safeAreaInsets)
    }

    /// Safe area of a Dynamic Island phone in portrait.
    private static let islandInsets = UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0)

    // MARK: - Viewer

    func testTheViewerSkipsEmptyStoriesAndKeepsTheRequestedOne() {
        let stories = [
            PersonalizationStory(id: "a", name: "A", slides: []),
            PersonalizationStory(id: "b", name: "B", slides: [PersonalizationStorySlide(id: "1", kind: .content)])
        ]
        let viewer = PersonalizationStoriesViewController(stories: stories, startIndex: 1)
        XCTAssertEqual(viewer.stories.map(\.id), ["b"])
        XCTAssertEqual(viewer.currentIndex, 0)
        XCTAssertEqual(viewer.modalPresentationStyle, .fullScreen)
    }

    func testThePageWalksSlidesAndTheLastSlideOfTheLastStoryCloses() {
        let story = PersonalizationStory(id: "s", name: "S", startPosition: 1, slides: [
            PersonalizationStorySlide(id: "1", kind: .content),
            PersonalizationStorySlide(id: "2", kind: .content),
            PersonalizationStorySlide(id: "3", kind: .content)
        ])
        let viewer = PersonalizationStoriesViewController(stories: [story])
        var closed = 0
        viewer.onClose = { closed += 1 }
        let page = PersonalizationStoryPageViewController(story: story, storyIndex: 0, startSlide: 1, viewer: viewer)
        page.loadViewIfNeeded()
        XCTAssertEqual(page.slideIndex, 1, "starts at start_position")

        page.previous()
        XCTAssertEqual(page.slideIndex, 0)
        page.previous()
        XCTAssertEqual(page.slideIndex, 0, "no previous story: the first slide again")

        page.next()
        page.next()
        XCTAssertEqual(page.slideIndex, 2)
        page.next()
        XCTAssertEqual(closed, 1, "past the last slide of the last story")
        page.next()
        XCTAssertEqual(closed, 1, "closes once")
    }

    func testSlideViewsAreReportedOnlyWhileThePageIsActive() {
        let story = PersonalizationStory(id: "s", name: "S", slides: [
            PersonalizationStorySlide(id: "1", kind: .content),
            PersonalizationStorySlide(id: "2", kind: .content)
        ])
        let viewer = PersonalizationStoriesViewController(stories: [story])
        var shown: [String] = []
        viewer.onSlideView = { _, slide in shown.append(slide.id) }
        let page = PersonalizationStoryPageViewController(story: story, storyIndex: 0, startSlide: 0, viewer: viewer)
        page.loadViewIfNeeded()
        XCTAssertEqual(shown, [], "not on screen yet")

        page.activate()
        page.activate()
        page.next()
        page.deactivate()
        XCTAssertEqual(shown, ["1", "2"])
    }
}
