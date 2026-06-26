import Foundation

/// Response for the `GET /collection/{id}` request.
///
/// A configured product collection: `{ "products": [...] }`. Products share the
/// light [CategoryProduct] shape used by the category listing.
public struct CollectionResponse {
    public var products: [CategoryProduct]

    init(json: [String: Any]) {
        products = (json["products"] as? [[String: Any]] ?? []).map { CategoryProduct(json: $0) }
    }
}
