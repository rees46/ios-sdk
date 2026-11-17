//
//  CatalogQuery.swift
//  REES46
//
//  The query of a catalog's request (`sdk/contract/products.md`, "ProductsListRequest"), built and
//  checked before anything is sent: a refused argument throws `Rees46.SdkError.invalidArgument`.
//

import Foundation

/// The fields of one request's query: what is `nil` or empty is not sent.
struct CatalogQuery {

    private(set) var fields: [String: String] = [:]

    init(_ fields: [String: String] = [:]) {
        self.fields = fields
    }

    /// `value`, when there is one.
    mutating func set(_ name: String, _ value: String?) {
        guard let value = value else { return }
        fields[name] = value
    }

    /// A list as one value joined by `,` without spaces: the server splits on `,` and keeps the
    /// spaces. An empty list is none.
    mutating func set(_ name: String, list: [String]?) {
        guard let list = list, !list.isEmpty else { return }
        fields[name] = list.joined(separator: ",")
    }

    /// A number without a needless fraction: `100`, not `100.0`.
    mutating func set(_ name: String, number: Double?) {
        set(name, number.map(Self.number))
    }

    mutating func set(_ name: String, int: Int?) {
        set(name, int.map(String.init))
    }

    /// The free filters as the JSON text the API reads, keys sorted; none for an empty map.
    mutating func set(_ name: String, filters: [String: [String]]?) throws {
        guard let filters = filters, !filters.isEmpty else { return }
        guard let data = SafeJSON.data(filters, options: [.sortedKeys, .withoutEscapingSlashes]),
              let text = String(data: data, encoding: .utf8)
        else {
            throw Rees46.SdkError.invalidArgument("\(name) are not valid JSON")
        }
        fields[name] = text
    }

    // MARK: - Values

    /// `value` without a needless fraction.
    static func number(_ value: Double) -> String {
        if value.rounded() == value, abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(value)
    }

    /// `value` as one segment of a path: everything but the unreserved characters of a URL is
    /// percent-encoded, `/` included.
    static func pathSegment(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
    }

    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    // MARK: - Checks

    /// A required identifier: `invalidArgument` when it is empty or blank.
    static func identifier(_ value: String, _ name: String) throws -> String {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Rees46.SdkError.invalidArgument("\(name) is empty")
        }
        return value
    }

    /// A count that starts at 1: `limit`, `page`.
    static func positive(_ value: Int?, _ name: String) throws {
        if let value = value, value < 1 {
            throw Rees46.SdkError.invalidArgument("\(name) must be at least 1")
        }
    }

    /// A price range: finite, not negative, the lowest not above the highest.
    static func prices(_ min: Double?, _ max: Double?) throws {
        for (name, value) in [("priceMin", min), ("priceMax", max)] {
            if let value = value, !value.isFinite || value < 0 {
                throw Rees46.SdkError.invalidArgument("\(name) must be a number not below 0")
            }
        }
        if let min = min, let max = max, min > max {
            throw Rees46.SdkError.invalidArgument("priceMin is above priceMax")
        }
    }

    /// The sorting of a listing: `relevance` is the search's.
    static func listingSort(_ sortBy: Rees46.SortBy?) throws {
        if sortBy == .relevance {
            throw Rees46.SdkError.invalidArgument("sortBy relevance is for search.full only")
        }
    }
}
