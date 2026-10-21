import XCTest
@testable import REES46

/// Every endpoint sends the product in one shape; the models must keep what the UI needs from it:
/// old price, discount, `deeplink_ios`, `is_new`, resized pictures. Fixtures are live API samples.
final class ProductModelsParsingTests: XCTestCase {

    // MARK: - Category and collection (`CategoryProduct`)

    func testCategoryResponse_keepsFacetsPriceRangeAndCategories() {
        let response = CategoryResponse(json: ApiFixtures.json("category"))

        XCTAssertEqual(response.products.count, 2)
        XCTAssertEqual(response.filters?.count, 3)
        XCTAssertEqual(response.filters?["NFC"]?.count, 6)
        XCTAssertEqual(response.filters?["NFC"]?.values["Нет"], 6)
        XCTAssertEqual(response.priceRange?.min, 190)
        XCTAssertEqual(response.priceRange?.max, 1863890)
        XCTAssertFalse(response.categories.isEmpty)
        XCTAssertEqual(response.categories.first?.id, "smartfony-i-gadzhety")
        XCTAssertEqual(response.categories.first?.count, 2320)
        XCTAssertFalse(response.brands.isEmpty)
    }

    func testCategoryResponse_withoutFacets_leavesThemEmpty() {
        let response = CategoryResponse(json: ["products_total": 0, "products": []])

        XCTAssertNil(response.filters)
        XCTAssertNil(response.priceRange)
        XCTAssertTrue(response.categories.isEmpty)
    }

    func testCategoryProduct_fullPrice_hasNoDiscount() {
        let product = CategoryProduct(json: ApiFixtures.product("category", id: ApiFixtures.fullPriceId))

        XCTAssertEqual(product.price, 15990)
        XCTAssertNil(product.oldPrice)
        XCTAssertNil(product.oldPriceFormatted)
        XCTAssertNil(product.discount)
        XCTAssertNil(product.discountFormatted)
        XCTAssertNil(product.discountPercent)
        XCTAssertEqual(
            product.deeplinkIos,
            "https://www.technodom.kz/p/naushniki-nakladnye-honor-choice-headphones-lite-gray-5504adgf-300252"
        )
        XCTAssertEqual(
            product.resizedImages?["120"],
            "https://pictures.rees46.ru/resize-images/120/c1140c8254976de297c3caf971701a/146384.jpg"
        )
    }

    func testCategoryProduct_discounted_keepsOldPriceAndDiscount() {
        // Collections share the category product model; `products` returns the discounted one.
        let collection = CollectionResponse(json: ApiFixtures.json("products"))
        let product = collection.products.first { $0.id == ApiFixtures.discountedId }

        XCTAssertEqual(product?.price, 164990)
        XCTAssertEqual(product?.oldPrice, 174990)
        XCTAssertEqual(product?.oldPriceFormatted, "174 990 ₽")
        XCTAssertEqual(product?.oldPriceFull, 174990)
        XCTAssertEqual(product?.oldPriceFullFormatted, "174 990.00 ₽")
        XCTAssertEqual(product?.discount, 6)
        XCTAssertEqual(product?.discountFormatted, "6%")
        XCTAssertEqual(product?.discountPercent, 5)
        XCTAssertEqual(product?.deeplinkIos, "https://www.technodom.kz/p/holodilnik-beko-rdsk-mw-52173")
    }

    func testCategoryProduct_readsIsNew() {
        XCTAssertEqual(CategoryProduct(json: ["id": "1", "is_new": true]).isNew, true)
        XCTAssertNil(CategoryProduct(json: ["id": "1"]).isNew)
    }

    // MARK: - Products list and search (`Product`)

    func testProductsList_discountedProduct_keepsDiscountFields() {
        let response = ProductsListResponse(json: ApiFixtures.json("products"))
        let discounted = response.products.first { $0.id == ApiFixtures.discountedId }
        let fullPrice = response.products.first { $0.id == ApiFixtures.fullPriceId }

        XCTAssertEqual(discounted?.oldPrice, 174990)
        XCTAssertEqual(discounted?.oldPriceFormatted, "174 990 ₽")
        XCTAssertEqual(discounted?.discount, 6)
        XCTAssertEqual(discounted?.discountFormatted, "6%")
        XCTAssertEqual(discounted?.discountPercent, 5)

        XCTAssertEqual(fullPrice?.oldPrice, 0)
        XCTAssertEqual(fullPrice?.discount, 0)
        XCTAssertNil(fullPrice?.discountFormatted)
        XCTAssertNil(fullPrice?.discountPercent)
    }

    func testSearchProduct_keepsDeeplinkAndPicture() {
        let response = SearchResponse(json: ApiFixtures.json("search_full"))
        let product = response.products.first

        XCTAssertEqual(response.productsTotal, 833)
        XCTAssertEqual(product?.id, "292523")
        XCTAssertEqual(product?.deeplinkIos, "https://www.technodom.kz/p/stiralnaya-mashina-samsung-ww60ak4s00celt-292523")
        XCTAssertEqual(
            product?.resizedImageUrl,
            "https://pictures.rees46.ru/resize-images/180/c1140c8254976de297c3caf971701a/143748.jpg"
        )
        XCTAssertNil(product?.discountFormatted)
    }

    // MARK: - Recommendations (`Recommended`)

    func testRecommended_discounted_keepsDiscountFields() {
        let response = RecommenderResponse(json: ApiFixtures.json("recommend_extended"))
        let discounted = response.recommended.first { $0.id == ApiFixtures.discountedId }
        let fullPrice = response.recommended.first { $0.id == ApiFixtures.fullPriceId }

        XCTAssertEqual(response.title, "Популярные")
        XCTAssertEqual(discounted?.oldPrice, 174990)
        XCTAssertEqual(discounted?.oldPriceFormatted, "174 990 ₽")
        XCTAssertEqual(discounted?.discount, 6)
        XCTAssertEqual(discounted?.discountFormatted, "6%")
        XCTAssertEqual(discounted?.discountPercent, 5)
        XCTAssertEqual(discounted?.deeplinkIos, "https://www.technodom.kz/p/holodilnik-beko-rdsk-mw-52173")

        XCTAssertNil(fullPrice?.oldPriceFormatted)
        XCTAssertNil(fullPrice?.discountFormatted)
        XCTAssertNil(fullPrice?.discountPercent)
    }

    func testRecommended_readsIsNew() {
        XCTAssertEqual(Recommended(json: ["id": "1", "is_new": true]).isNew, true)
        XCTAssertNil(Recommended(json: ["id": "1"]).isNew)
    }

    // MARK: - Product info (`ProductInfo`)

    func testProductInfo_fullPrice_hasNoDiscount() {
        let product = ProductInfo(json: ApiFixtures.json("product_info"))

        XCTAssertEqual(product.id, "868")
        // The price comes as a string here, unlike the other endpoints.
        XCTAssertEqual(product.price, 14990)
        XCTAssertEqual(product.priceFormatted, "14 990 ₽")
        XCTAssertEqual(product.deeplinkIos, "https://www.technodom.kz/p/garnitura-nakladnaa-logitech-h-white-868")
        // `products/get` sends `"discount": false` for a product without a discount.
        XCTAssertEqual(product.discount, 0)
        XCTAssertNil(product.discountFormatted)
        XCTAssertNil(product.discountPercent)
    }

    func testProductInfo_discounted_keepsDiscountFields() {
        var json = ApiFixtures.product("products", id: ApiFixtures.discountedId)
        json["uniqid"] = json["id"]
        let product = ProductInfo(json: json)

        XCTAssertEqual(product.oldPrice, 174990)
        XCTAssertEqual(product.discount, 6)
        XCTAssertEqual(product.discountFormatted, "6%")
        XCTAssertEqual(product.discountPercent, 5)
    }
}
