import XCTest
@_spi(PersonalizationUI) @testable import REES46

/// One mapper turns any API product into the kit card, whichever SDK model carried it:
/// search and `products` (`Product`), recommendations (`Recommended`), category and collection
/// (`CategoryProduct`), `products/get` (`ProductInfo`).
final class ProductMapperTests: XCTestCase {

    private let discountedUrl = "https://www.technodom.kz/p/holodilnik-beko-rdsk-mw-52173"

    // MARK: - Live samples

    func testRecommended_discounted_showsOldPriceAndDiscount() {
        let json = ApiFixtures.product("recommend_extended", id: ApiFixtures.discountedId, key: "recommends")
        let card = Recommended(json: json).toCardProduct(actionText: "Add to cart")

        XCTAssertEqual(card.id, ApiFixtures.discountedId)
        XCTAssertEqual(card.name, "Двухкамерный холодильник Beko RDSK-240M00W")
        XCTAssertEqual(card.price, "164 990 ₽")
        XCTAssertEqual(card.oldPrice, "174 990 ₽")
        XCTAssertEqual(card.discount, "-6%")
        XCTAssertEqual(card.brand, "Beko")
        XCTAssertEqual(card.imageUrl, "https://pictures.rees46.ru/resize-images/180/c1140c8254976de297c3caf971701a/132229.jpg")
        XCTAssertEqual(card.deeplink, discountedUrl)
        XCTAssertTrue(card.url?.hasPrefix(discountedUrl + "?recommended_by=dynamic") == true)
        XCTAssertEqual(card.actionText, "Add to cart")
        XCTAssertNil(card.ratingValue)
    }

    func testRecommended_fullPrice_hasNoOldPriceOrDiscount() {
        let json = ApiFixtures.product("recommend_extended", id: ApiFixtures.fullPriceId, key: "recommends")
        let card = Recommended(json: json).toCardProduct()

        XCTAssertEqual(card.price, "15 990 ₽")
        XCTAssertNil(card.oldPrice)
        XCTAssertNil(card.discount)
        XCTAssertNil(card.actionText)
    }

    func testSameProduct_mapsToSameCard_whateverTheModel() {
        let json = ApiFixtures.product("products", id: ApiFixtures.discountedId)
        var info = json
        info["uniqid"] = json["id"]
        let cards = [
            Product(json: json).toCardProduct(),
            Recommended(json: json).toCardProduct(),
            CategoryProduct(json: json).toCardProduct(),
            ProductInfo(json: info).toCardProduct()
        ]

        for card in cards {
            XCTAssertEqual(card.id, ApiFixtures.discountedId)
            XCTAssertEqual(card.price, "164 990 ₽")
            XCTAssertEqual(card.oldPrice, "174 990 ₽")
            XCTAssertEqual(card.discount, "-6%")
            XCTAssertEqual(card.brand, "Beko")
            XCTAssertEqual(card.imageUrl, cards[0].imageUrl)
            XCTAssertEqual(card.url, cards[0].url)
            XCTAssertEqual(card.deeplink, discountedUrl)
        }
    }

    func testCategoryProduct_fullPrice() {
        let card = CategoryProduct(json: ApiFixtures.product("category", id: ApiFixtures.fullPriceId)).toCardProduct()

        XCTAssertEqual(card.price, "15 990 ₽")
        XCTAssertNil(card.oldPrice)
        XCTAssertNil(card.discount)
        XCTAssertEqual(card.brand, "Honor")
        XCTAssertEqual(card.imageUrl, "https://pictures.rees46.ru/resize-images/180/c1140c8254976de297c3caf971701a/146384.jpg")
        XCTAssertEqual(card.deeplink, "https://www.technodom.kz/p/naushniki-nakladnye-honor-choice-headphones-lite-gray-5504adgf-300252")
    }

    func testSearchProduct_keepsSearchCardAsBefore() {
        let card = Product(json: ApiFixtures.products("search_full")[0]).toCardProduct(actionText: nil)

        XCTAssertEqual(card.id, "292523")
        XCTAssertEqual(card.price, "179 990 ₽")
        XCTAssertNil(card.oldPrice)
        XCTAssertNil(card.discount)
        XCTAssertEqual(card.brand, "Samsung")
        XCTAssertEqual(card.imageUrl, "https://pictures.rees46.ru/resize-images/180/c1140c8254976de297c3caf971701a/143748.jpg")
    }

    func testProductInfo_fullPrice() {
        let card = ProductInfo(json: ApiFixtures.json("product_info")).toCardProduct()

        XCTAssertEqual(card.id, "868")
        XCTAssertEqual(card.price, "14 990 ₽")
        XCTAssertNil(card.oldPrice)
        XCTAssertNil(card.discount)
        XCTAssertEqual(card.deeplink, "https://www.technodom.kz/p/garnitura-nakladnaa-logitech-h-white-868")
    }

    // MARK: - Rules

    private func card(_ json: [String: Any]) -> PersonalizationProduct {
        let base: [String: Any] = ["id": "1", "name": "Item"]
        return Product(json: base.merging(json) { $1 }).toCardProduct()
    }

    func testPrice_withoutFormatted_isNumberWithCurrency() {
        XCTAssertEqual(card(["price": 990.0, "currency": "₽"]).price, "990.0 ₽")
    }

    func testOldPrice_notAbovePrice_isDropped_withItsDiscount() {
        let mapped = card(["price": 100.0, "oldprice": 100.0, "oldprice_formatted": "100 ₽", "discount": 5])

        XCTAssertNil(mapped.oldPrice)
        XCTAssertNil(mapped.discount)
    }

    func testOldPrice_withoutFormatted_isDropped() {
        let mapped = card(["price": 90.0, "oldprice": 100.0, "discount": 10])

        XCTAssertNil(mapped.oldPrice)
        XCTAssertNil(mapped.discount)
    }

    func testDiscount_withoutFormatted_isPercentOfDiscount() {
        let mapped = card(["price": 93.0, "oldprice": 100.0, "oldprice_formatted": "100 ₽", "discount": 7])

        XCTAssertEqual(mapped.oldPrice, "100 ₽")
        XCTAssertEqual(mapped.discount, "-7%")
    }

    func testDiscount_formattedWithMinus_isNotDoubled() {
        let base: [String: Any] = ["price": 90.0, "oldprice": 100.0, "oldprice_formatted": "100 ₽", "discount": 10]

        XCTAssertEqual(card(base.merging(["discount_formatted": "-10%"]) { $1 }).discount, "-10%")
        XCTAssertEqual(card(base.merging(["discount_formatted": "--10%"]) { $1 }).discount, "-10%")
        XCTAssertEqual(card(base.merging(["discount_formatted": "10%"]) { $1 }).discount, "-10%")
    }

    func testDiscount_zeroWithFormattedZero_hasNoBadge() {
        let mapped = card([
            "price": 90.0, "oldprice": 100.0, "oldprice_formatted": "100 ₽", "discount": 0, "discount_formatted": "0%"
        ])

        XCTAssertEqual(mapped.oldPrice, "100 ₽")
        XCTAssertNil(mapped.discount)
    }

    func testDiscount_true_hasNoBadge() {
        let mapped = card(["price": 90.0, "oldprice": 100.0, "oldprice_formatted": "100 ₽", "discount": true])

        XCTAssertEqual(mapped.oldPrice, "100 ₽")
        XCTAssertNil(mapped.discount)
    }

    func testDiscount_onlyPercent_isPercentWithMinus() {
        let mapped = card(["price": 95.0, "oldprice": 100.0, "oldprice_formatted": "100 ₽", "discount_percent": 5])

        XCTAssertEqual(mapped.discount, "-5%")
    }

    func testDiscount_percentWithZeroDiscount_ignoresTheZeroFormatted() {
        let mapped = card([
            "price": 95.0, "oldprice": 100.0, "oldprice_formatted": "100 ₽",
            "discount": 0, "discount_formatted": "0%", "discount_percent": "5"
        ])

        XCTAssertEqual(mapped.discount, "-5%")
    }

    func testDiscount_withoutOldPrice_hasNoBadge() {
        XCTAssertNil(card(["price": 100.0, "discount": 10, "discount_formatted": "10%", "discount_percent": 10]).discount)
    }

    func testOldPrice_withoutDiscount_hasNoBadge() {
        let mapped = card(["price": 90.0, "oldprice": 100.0, "oldprice_formatted": "100 ₽"])

        XCTAssertEqual(mapped.oldPrice, "100 ₽")
        XCTAssertNil(mapped.discount)
    }

    func testPicture_fallsBackToOriginalImage_andEmptyStringsAreNil() {
        let mapped = card(["image_url": "https://example.com/1.jpg", "brand": "", "url": "", "deeplink_ios": ""])

        XCTAssertEqual(mapped.imageUrl, "https://example.com/1.jpg")
        XCTAssertNil(mapped.brand)
        XCTAssertNil(mapped.url)
        XCTAssertNil(mapped.deeplink)
        XCTAssertNil(card([:]).imageUrl)
    }
}
