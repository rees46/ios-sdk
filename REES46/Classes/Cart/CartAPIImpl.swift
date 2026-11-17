//
//  CartAPIImpl.swift
//  REES46
//

import Foundation

struct CartAPIImpl: CartAPI {

    let requests: NamespaceRequests

    func get(completion: @escaping (Result<[CartItem], Rees46.SdkError>) -> Void) {
        requests.call("cart.get", completion: completion) { Self.cartRequest }
    }

    func get() async throws -> [CartItem] {
        try await requests.value("cart.get") { Self.cartRequest }
    }

    /// `GET products/cart` with nothing but the common fields the core adds: the API finds the cart by the
    /// device id. An answer without a body is an empty cart.
    static var cartRequest: ApiRequest<[CartItem]> {
        .get("products/cart", answer: CartAnswer.self, whenEmpty: []) { $0.items }
    }
}

/// The answer of `GET products/cart` in either of its shapes (`sdk/contract/cart.md`), as Android reads it:
/// today's `{"status": "success", "data": {"items": [...]}}`, else the documented
/// `{"status": "success", "payload": {"cart_items": [...]}}`, so the server's move to the second one
/// breaks nothing. Without a list in either place it is not a cart (`decoding`).
struct CartAnswer: Decodable {

    let items: [CartItem]

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: AnswerKey.self)
        let lines = (try? root.nestedContainer(keyedBy: AnswerKey.self, forKey: "data"))?.lenientList(Line.self, "items")
            ?? (try? root.nestedContainer(keyedBy: AnswerKey.self, forKey: "payload"))?.lenientList(Line.self, "cart_items")
        guard let lines = lines else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "neither data.items nor payload.cart_items is a list"
            ))
        }
        items = lines.compactMap(\.item)
    }

    /// One line: a product without an id is left out, one without a quantity is one of it.
    private struct Line: Decodable {
        let item: CartItem?

        init(from decoder: Decoder) throws {
            let line = try decoder.container(keyedBy: AnswerKey.self)
            item = line.lenientString("uniqid").map { CartItem(productId: $0, quantity: line.lenientInt("quantity") ?? 1) }
        }
    }
}
