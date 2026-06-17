import Foundation

/// Response for the `orders/last_for_user` request.
///
/// The endpoint returns a top-level JSON array of products that belong to the
/// user's last order, so `products` is mapped directly from that array.
public struct LastOrderProductsResponse {
    public var products: [Product]

    init(array: [[String: Any]]) {
        self.products = array.map { Product(json: $0) }
    }
}
