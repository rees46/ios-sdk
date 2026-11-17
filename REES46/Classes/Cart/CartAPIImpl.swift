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
    /// device id.
    static var cartRequest: ApiRequest<[CartItem]> {
        .get("products/cart", answer: CartAnswer.self) { $0.items }
    }
}

/// The answer of `GET products/cart` in either of its shapes (`sdk/contract/cart.md`): today's
/// `{"status": "success", "data": {"items": [...]}}` and the documented
/// `{"status": "success", "payload": {"cart_items": [...]}}`, so the server's move to the second one
/// breaks nothing. Anything else is not a cart.
struct CartAnswer: Decodable {

    let items: [CartItem]

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: AnswerKey.self)
        if let data = try? root.nestedContainer(keyedBy: AnswerKey.self, forKey: "data") {
            items = try Self.lines(in: data, "items")
        } else if let payload = try? root.nestedContainer(keyedBy: AnswerKey.self, forKey: "payload") {
            items = try Self.lines(in: payload, "cart_items")
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "neither data.items nor payload.cart_items"
            ))
        }
    }

    /// The lines at `key`; missing or `null` is an empty cart, anything but a list is not a cart.
    private static func lines(in container: KeyedDecodingContainer<AnswerKey>, _ key: AnswerKey) throws -> [CartItem] {
        if let lines = container.lenientList(Line.self, key) {
            return lines.compactMap(\.item)
        }
        guard container.contains(key), (try? container.decodeNil(forKey: key)) != true else {
            return []
        }
        throw DecodingError.typeMismatch([Line].self, DecodingError.Context(
            codingPath: container.codingPath + [key as CodingKey],
            debugDescription: "the lines of the cart are not a list"
        ))
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
