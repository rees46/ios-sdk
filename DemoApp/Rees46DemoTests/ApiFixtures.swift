import XCTest

/// Live API samples (shop c1140c…, api.rees46.ru) bundled with the test target under `Fixtures/`.
///
/// One product shape across every endpoint: `api_products.json` and `api_recommend_extended.json`
/// carry the discounted product 52173 (old price, `discount`, `discount_formatted`,
/// `discount_percent`) next to the full-price 300252; the other samples have no discounts.
enum ApiFixtures {

    private final class BundleToken {}

    /// The whole response object of `api_<name>.json`.
    static func json(_ name: String, file: StaticString = #filePath, line: UInt = #line) -> [String: Any] {
        guard let url = Bundle(for: BundleToken.self).url(forResource: "api_\(name)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Fixture api_\(name).json is missing from the test bundle", file: file, line: line)
            return [:]
        }
        return object
    }

    /// Products of a response under `key` (`products`, or `recommends` for recommendations).
    static func products(_ name: String, key: String = "products") -> [[String: Any]] {
        json(name)[key] as? [[String: Any]] ?? []
    }

    /// The product with `id` from a response, for picking the discounted / full-price one by id.
    static func product(_ name: String, id: String, key: String = "products") -> [String: Any] {
        products(name, key: key).first { $0["id"] as? String == id } ?? [:]
    }

    static let discountedId = "52173"
    static let fullPriceId = "300252"
}
