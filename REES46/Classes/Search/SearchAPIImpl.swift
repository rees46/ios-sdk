//
//  SearchAPIImpl.swift
//  REES46
//

import Foundation

struct SearchAPIImpl: SearchAPI {

    let requests: NamespaceRequests
    /// The instance whose `/init` says whether the agent is on.
    weak var instance: SimplePersonalizationSDK?

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

    var agentEnabled: Bool {
        guard let instance = instance, instance.core is CoreV2 else { return false }
        return instance.agentSearch.isOn
    }

    func agentDialog(
        sessionId: Int?,
        locations: [String]?,
        completion: @escaping (Result<Rees46.AgentDialogResponse, Rees46.SdkError>) -> Void
    ) {
        requests.call("search.agentDialog", completion: completion) { Self.agentDialogRequest(sessionId: sessionId, locations: locations) }
    }

    func agentDialog(sessionId: Int?, locations: [String]?) async throws -> Rees46.AgentDialogResponse {
        try await requests.value("search.agentDialog") { Self.agentDialogRequest(sessionId: sessionId, locations: locations) }
    }

    func agent(
        message: String,
        sessionId: Int?,
        locations: [String]?,
        completion: @escaping (Result<Rees46.AgentResponse, Rees46.SdkError>) -> Void
    ) {
        requests.call("search.agent", completion: completion) {
            try Self.agentRequest(message: message, sessionId: sessionId, locations: locations)
        }
    }

    func agent(message: String, sessionId: Int?, locations: [String]?) async throws -> Rees46.AgentResponse {
        try await requests.value("search.agent") {
            try Self.agentRequest(message: message, sessionId: sessionId, locations: locations)
        }
    }

    // MARK: - Requests

    /// `GET search/blank` with the common fields alone. An answer without a body, or an empty list — the
    /// server's empty object (PHP) —, has nothing to show.
    static var blankRequest: ApiRequest<Rees46.SearchBlankResponse> {
        ApiRequest(method: .get, path: "search/blank") { body in
            if body.isEmpty || ((try? JSONSerialization.jsonObject(with: body)) as? [Any])?.isEmpty == true {
                return try Readable<Rees46.SearchBlankResponse>.read(Data("{}".utf8))
            }
            return try Readable<Rees46.SearchBlankResponse>.read(body)
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

    /// The path of the agent on the host of API v3.
    static let agentPath = "api/v3/storefront/search/agent"
    /// The server gives the agent up to 40 seconds and two more tries of its model: the read timeout of a
    /// message (`sdk/contract/search.md`). The dialog has the common one.
    static let agentTimeout: TimeInterval = 60
    /// The longest message the server takes.
    static let agentMessageLimit = 500

    /// `GET api/v3/storefront/search/agent` on `appDomain`. An answer without a body has no session.
    static func agentDialogRequest(sessionId: Int?, locations: [String]?) -> ApiRequest<Rees46.AgentDialogResponse> {
        var fields = CatalogQuery()
        fields.set("session_id", int: sessionId)
        fields.set("location", list: locations)
        var request = ApiRequest(method: .get, path: agentPath, query: fields.fields) { body in
            try Readable<Rees46.AgentDialogResponse>.read(body.isEmpty ? Data("{}".utf8) : body)
        }
        request.host = .app
        return request
    }

    /// `POST api/v3/storefront/search/agent` on `appDomain`, a JSON body, read timeout 60 seconds. The
    /// message is counted in characters as the server counts them, by Unicode scalars.
    static func agentRequest(message: String, sessionId: Int?, locations: [String]?) throws -> ApiRequest<Rees46.AgentResponse> {
        let text = try CatalogQuery.identifier(message, "message")
        guard text.unicodeScalars.count <= agentMessageLimit else {
            throw Rees46.SdkError.invalidArgument("message is longer than \(agentMessageLimit) characters")
        }
        var body: [String: Any] = ["message": text]
        body["session_id"] = sessionId
        if let locations = locations, !locations.isEmpty {
            body["location"] = locations.joined(separator: ",")
        }
        var request = ApiRequest(method: .post, path: agentPath, body: body, timeout: agentTimeout) { body in
            try Readable<Rees46.AgentResponse>.read(body)
        }
        request.host = .app
        return request
    }

    /// The merchants to leave out, only with locations: the server looks for them inside the locations,
    /// and without any the search finds no product.
    private static func merchantsToExclude(_ merchants: [String]?, locations: [String]?) -> [String]? {
        guard let locations = locations, !locations.isEmpty else { return nil }
        return merchants
    }
}
