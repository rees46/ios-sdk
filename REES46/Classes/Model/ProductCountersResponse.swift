import Foundation

/// Response for the `GET /products/counters` request.
///
/// Envelope: `{ "daily": {...}, "now": {...}, "triggers": {...} }`.
public struct ProductCountersResponse {
    public var daily: ProductCounter?
    public var now: ProductCounter?
    public var triggers: ProductCounterTriggers?

    init(json: [String: Any]) {
        if let daily = json["daily"] as? [String: Any] {
            self.daily = ProductCounter(json: daily)
        }
        if let now = json["now"] as? [String: Any] {
            self.now = ProductCounter(json: now)
        }
        if let triggers = json["triggers"] as? [String: Any] {
            self.triggers = ProductCounterTriggers(json: triggers)
        }
    }
}

public struct ProductCounter {
    public var view: Int
    public var cart: Int
    public var purchase: Int

    init(json: [String: Any]) {
        view = json["view"] as? Int ?? 0
        cart = json["cart"] as? Int ?? 0
        purchase = json["purchase"] as? Int ?? 0
    }
}

public struct ProductCounterTriggers {
    public var backInStock: Int
    public var priceDrop: Int

    init(json: [String: Any]) {
        backInStock = json["back_in_stock"] as? Int ?? 0
        priceDrop = json["price_drop"] as? Int ?? 0
    }
}
