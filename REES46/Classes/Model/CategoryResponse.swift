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

    init(json: [String: Any]) {
        productsTotal = json["products_total"] as? Int ?? 0
        products = (json["products"] as? [[String: Any]] ?? []).map { CategoryProduct(json: $0) }
        brands = (json["brands"] as? [[String: Any]] ?? []).map { CategoryBrand(json: $0) }
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

    init(json: [String: Any]) {
        id = json["id"] as? String
        name = json["name"] as? String
        brand = json["brand"] as? String
        price = json["price"] as? Double
        priceFormatted = json["price_formatted"] as? String
        priceFull = json["price_full"] as? Double
        priceFullFormatted = json["price_full_formatted"] as? String
        currency = json["currency"] as? String
        imageUrl = json["image_url"] as? String
        url = json["url"] as? String
        picture = json["picture"] as? String
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
