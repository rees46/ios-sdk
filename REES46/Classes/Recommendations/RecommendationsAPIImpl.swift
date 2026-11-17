//
//  RecommendationsAPIImpl.swift
//  REES46
//

import Foundation

struct RecommendationsAPIImpl: RecommendationsAPI {

    let requests: NamespaceRequests

    func get(
        code: String,
        request: Rees46.RecommendationRequest,
        completion: @escaping (Result<Rees46.RecommendationResponse, Rees46.SdkError>) -> Void
    ) {
        requests.call("recommendations.get", completion: completion) { try Self.blockRequest(code: code, request) }
    }

    func get(code: String, request: Rees46.RecommendationRequest) async throws -> Rees46.RecommendationResponse {
        try await requests.value("recommendations.get") { try Self.blockRequest(code: code, request) }
    }

    /// `GET recommend/{code}`, the code encoded in the path. The product goes as `item_id` and the
    /// category as `category`, the names the server prefers; `resize_image` is not sent, the server
    /// does not read it.
    static func blockRequest(code: String, _ request: Rees46.RecommendationRequest) throws -> ApiRequest<Rees46.RecommendationResponse> {
        let code = try CatalogQuery.identifier(code, "code")
        try CatalogQuery.positive(request.limit, "limit")
        if request.withLocations, !request.extended {
            throw Rees46.SdkError.invalidArgument("withLocations needs extended")
        }
        var query = CatalogQuery()
        query.set("item_id", request.itemId)
        query.set("category", request.categoryId)
        query.set("search_query", request.searchQuery)
        query.set("exclude", list: request.excludedItemIds)
        query.set("brands", list: request.brands)
        query.set("locations", list: request.locations)
        query.set("limit", int: request.limit)
        query.set("extended", request.extended ? "true" : nil)
        query.set("with_locations", request.withLocations ? "true" : nil)
        let extended = request.extended
        return ApiRequest(method: .get, path: "recommend/\(CatalogQuery.pathSegment(code))", query: query.fields) { body in
            // A block on pause may answer without a body too: no products.
            let answer = try Readable<RecommendationAnswer>.read(body.isEmpty ? Data("{}".utf8) : body)
            return answer.response(extended: extended)
        }
    }
}

/// The answer of `recommend/{code}`, its `recommends` either products or their ids. A block on pause
/// answers `{"state": "paused"}`, without them: no products. `recommends` that is not a list is not the
/// block's answer (`decoding`).
private struct RecommendationAnswer: AnswerReadable {
    let id: Int?
    let title: String?
    let link: String?
    let products: [Rees46.Product]
    let itemIds: [String]

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        id = answer.lenientInt("id")
        title = answer.lenientString("title")
        link = answer.lenientString("link")
        let present = answer.contains("recommends") && !((try? answer.decodeNil(forKey: "recommends")) ?? true)
        // Objects make products; strings or numbers, the ids of the simple answer.
        let products = answer.models(Rees46.Product.self, "recommends")
        let ids = answer.lenientStrings("recommends")
        if present, products == nil, ids == nil {
            throw DecodingError.typeMismatch([String].self, DecodingError.Context(codingPath: answer.codingPath, debugDescription: "recommends is not a list"))
        }
        self.products = products ?? []
        self.itemIds = ids ?? []
    }

    /// The method's value: the products with `extended`, their ids without it.
    func response(extended: Bool) -> Rees46.RecommendationResponse {
        Rees46.RecommendationResponse(
            id: id,
            title: title,
            link: link,
            products: extended ? products : [],
            itemIds: extended ? products.map(\.id) : itemIds
        )
    }
}
