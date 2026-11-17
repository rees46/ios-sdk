//
//  SearchAPIImpl.swift
//  REES46
//

import Foundation

struct SearchAPIImpl: SearchAPI {

    let requests: NamespaceRequests

    func blank(completion: @escaping (Result<Rees46.SearchBlankResponse, Rees46.SdkError>) -> Void) {
        requests.call("search.blank", completion: completion) { Self.blankRequest }
    }

    func blank() async throws -> Rees46.SearchBlankResponse {
        try await requests.value("search.blank") { Self.blankRequest }
    }

    func instant(
        query: String,
        locations: [String]?,
        excludedMerchants: [String]?,
        excludedBrands: [String]?,
        completion: @escaping (Result<Rees46.SearchInstantResponse, Rees46.SdkError>) -> Void
    ) {
        requests.call("search.instant", completion: completion) {
            try Self.instantRequest(query: query, locations: locations, excludedMerchants: excludedMerchants, excludedBrands: excludedBrands)
        }
    }

    func instant(
        query: String,
        locations: [String]?,
        excludedMerchants: [String]?,
        excludedBrands: [String]?
    ) async throws -> Rees46.SearchInstantResponse {
        try await requests.value("search.instant") {
            try Self.instantRequest(query: query, locations: locations, excludedMerchants: excludedMerchants, excludedBrands: excludedBrands)
        }
    }

    func full(
        query: String,
        request: Rees46.SearchFullRequest,
        completion: @escaping (Result<Rees46.SearchFullResponse, Rees46.SdkError>) -> Void
    ) {
        requests.call("search.full", completion: completion) { try Self.fullRequest(query: query, request) }
    }

    func full(query: String, request: Rees46.SearchFullRequest) async throws -> Rees46.SearchFullResponse {
        try await requests.value("search.full") { try Self.fullRequest(query: query, request) }
    }

    // MARK: - Requests

    /// `GET search/blank` with the common fields alone. An answer without a body has nothing to show.
    static var blankRequest: ApiRequest<Rees46.SearchBlankResponse> {
        ApiRequest(method: .get, path: "search/blank") { body in
            try Readable<Rees46.SearchBlankResponse>.read(body.isEmpty ? Data("{}".utf8) : body)
        }
    }

    static func instantRequest(
        query: String,
        locations: [String]?,
        excludedMerchants: [String]?,
        excludedBrands: [String]?
    ) throws -> ApiRequest<Rees46.SearchInstantResponse> {
        let text = try CatalogQuery.identifier(query, "query")
        var fields = CatalogQuery(["type": "instant_search", "search_query": text])
        fields.set("locations", list: locations)
        fields.set("excluded_merchants", list: merchantsToExclude(excludedMerchants, locations: locations))
        fields.set("excluded_brands", list: excludedBrands)
        return ApiRequest(method: .get, path: "search", query: fields.fields) { body in
            try Readable<Rees46.SearchInstantResponse>.read(body)
        }
    }

    /// The direction goes as `order`, the page as `page`: the names of the documentation, which the
    /// server reads beside `sort_dir` and `offset`.
    static func fullRequest(query: String, _ request: Rees46.SearchFullRequest) throws -> ApiRequest<Rees46.SearchFullResponse> {
        let text = try CatalogQuery.identifier(query, "query")
        var fields = CatalogQuery(["type": "full_search", "search_query": text])
        try CatalogQuery.positive(request.limit, "limit")
        try CatalogQuery.positive(request.page, "page")
        try CatalogQuery.positive(request.categoryLimit, "categoryLimit")
        try CatalogQuery.positive(request.brandLimit, "brandLimit")
        try CatalogQuery.prices(request.priceMin, request.priceMax)
        fields.set("categories", list: request.categoryIds)
        fields.set("brands", list: request.brands)
        fields.set("excluded_brands", list: request.excludedBrands)
        fields.set("merchants", list: request.merchants)
        fields.set("excluded_merchants", list: merchantsToExclude(request.excludedMerchants, locations: request.locations))
        fields.set("locations", list: request.locations)
        fields.set("price_min", number: request.priceMin)
        fields.set("price_max", number: request.priceMax)
        fields.set("colors", list: request.colors)
        fields.set("fashion_sizes", list: request.fashionSizes)
        fields.set("exclude", list: request.excludedItemIds)
        try fields.set("filters", filters: request.filters)
        fields.set("sort_by", request.sortBy?.rawValue)
        fields.set("order", request.sortDir?.rawValue)
        fields.set("no_clarification", request.disableClarification ? "true" : nil)
        fields.set("category_limit", int: request.categoryLimit)
        fields.set("brand_limit", int: request.brandLimit)
        fields.set("limit", int: request.limit)
        fields.set("page", int: request.page)
        return ApiRequest(method: .get, path: "search", query: fields.fields) { body in
            try Readable<Rees46.SearchFullResponse>.read(body)
        }
    }

    /// The merchants to leave out, only with locations: the server looks for them inside the locations,
    /// and without any the search finds no product.
    private static func merchantsToExclude(_ merchants: [String]?, locations: [String]?) -> [String]? {
        guard let locations = locations, !locations.isEmpty else { return nil }
        return merchants
    }
}
