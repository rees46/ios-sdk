import Foundation

/// Response for the `GET /category/{category}` request.
///
/// Mirrors the full-search payload: the matched products plus faceting metadata.
/// Products are exposed via a light [CategoryProduct] model; consumers needing the
/// full catalog shape can fetch a product via `getProductInfo`.
public struct CategoryResponse {
    public var productsTotal: Int
    public var products: [CategoryProduct]
    public var brands: [CategoryBrand]
    /// Store facets, as in `SearchResponse.filters`; `nil` when the response has none.
    public var filters: [String: Filter]?
    public var priceRange: PriceRange?
    /// Subcategories with product counts, as in `SearchResponse.categories`.
    public var categories: [Category] = []

    init(json: [String: Any]) {
        productsTotal = json["products_total"] as? Int ?? 0
        products = (json["products"] as? [[String: Any]] ?? []).map { CategoryProduct(json: $0) }
        brands = (json["brands"] as? [[String: Any]] ?? []).map { CategoryBrand(json: $0) }
        if let filtersJSON = json["filters"] as? [String: Any] {
            var filtersResult = [String: Filter]()
            for item in filtersJSON {
                if let dict = item.value as? [String: Any] {
                    filtersResult[item.key] = Filter(json: dict)
                }
            }
            filters = filtersResult
        }
        if let priceRangeJSON = json["price_range"] as? [String: Any] {
            priceRange = PriceRange(json: priceRangeJSON)
        }
        categories = (json["categories"] as? [[String: Any]] ?? []).map { Category(json: $0) }
    }
}

public struct CategoryProduct {
    public var id: String?
    public var name: String?
    public var brand: String?
    public var price: Double?
    public var priceFormatted: String?
    public var priceFull: Double?
    public var priceFullFormatted: String?
    public var currency: String?
    public var imageUrl: String?
    public var url: String?
    public var picture: String?
    public var oldPrice: Double?
    public var oldPriceFormatted: String?
    public var oldPriceFull: Double?
    public var oldPriceFullFormatted: String?
    public var discount: Int?
    public var discountFormatted: String?
    public var discountPercent: Int?
    public var isNew: Bool?
    public var deeplinkIos: String?
    public var resizedImages: [String: String]?

    init(json: [String: Any]) {
        id = json["id"] as? String
        name = json["name"] as? String
        brand = json["brand"] as? String
        price = JSONNumber.double(json["price"])
        priceFormatted = json["price_formatted"] as? String
        priceFull = JSONNumber.double(json["price_full"])
        priceFullFormatted = json["price_full_formatted"] as? String
        currency = json["currency"] as? String
        imageUrl = json["image_url"] as? String
        url = json["url"] as? String
        picture = json["picture"] as? String
        oldPrice = JSONNumber.double(json["oldprice"])
        oldPriceFormatted = json["oldprice_formatted"] as? String
        oldPriceFull = JSONNumber.double(json["oldprice_full"])
        oldPriceFullFormatted = json["oldprice_full_formatted"] as? String
        discount = JSONNumber.int(json["discount"])
        discountFormatted = json["discount_formatted"] as? String
        discountPercent = JSONNumber.int(json["discount_percent"])
        isNew = json["is_new"] as? Bool
        deeplinkIos = json["deeplink_ios"] as? String
        resizedImages = json["image_url_resized"] as? [String: String]
    }
}

public struct CategoryBrand {
    public var name: String?
    public var count: Int?

    init(json: [String: Any]) {
        name = json["name"] as? String
        count = json["count"] as? Int
    }
}
