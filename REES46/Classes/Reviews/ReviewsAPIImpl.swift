//
//  ReviewsAPIImpl.swift
//  REES46
//

import Foundation

struct ReviewsAPIImpl: ReviewsAPI {

    let requests: NamespaceRequests

    // MARK: - Scores

    func createNps(
        rate: Int, channel: String, category: String, orderId: String?, comment: String?, label: String?,
        completion: @escaping (Result<PollReview, Rees46.SdkError>) -> Void
    ) {
        requests.call("reviews.createNps", completion: completion) {
            try Self.scoreRequest(.nps, rate: rate, channel: channel, subject: category, orderId: orderId, comment: comment, label: label)
        }
    }

    func createNps(
        rate: Int, channel: String, category: String, orderId: String?, comment: String?, label: String?
    ) async throws -> PollReview {
        try await requests.value("reviews.createNps") {
            try Self.scoreRequest(.nps, rate: rate, channel: channel, subject: category, orderId: orderId, comment: comment, label: label)
        }
    }

    func createCsat(
        rate: Int, channel: String, campaign: String, orderId: String?, comment: String?, label: String?,
        completion: @escaping (Result<PollReview, Rees46.SdkError>) -> Void
    ) {
        requests.call("reviews.createCsat", completion: completion) {
            try Self.scoreRequest(.csat, rate: rate, channel: channel, subject: campaign, orderId: orderId, comment: comment, label: label)
        }
    }

    func createCsat(
        rate: Int, channel: String, campaign: String, orderId: String?, comment: String?, label: String?
    ) async throws -> PollReview {
        try await requests.value("reviews.createCsat") {
            try Self.scoreRequest(.csat, rate: rate, channel: channel, subject: campaign, orderId: orderId, comment: comment, label: label)
        }
    }

    func createCes(
        rate: Int, channel: String, campaign: String, orderId: String?, comment: String?, label: String?,
        completion: @escaping (Result<PollReview, Rees46.SdkError>) -> Void
    ) {
        requests.call("reviews.createCes", completion: completion) {
            try Self.scoreRequest(.ces, rate: rate, channel: channel, subject: campaign, orderId: orderId, comment: comment, label: label)
        }
    }

    func createCes(
        rate: Int, channel: String, campaign: String, orderId: String?, comment: String?, label: String?
    ) async throws -> PollReview {
        try await requests.value("reviews.createCes") {
            try Self.scoreRequest(.ces, rate: rate, channel: channel, subject: campaign, orderId: orderId, comment: comment, label: label)
        }
    }

    // MARK: - Dictionaries

    func getNpsCategories(completion: @escaping (Result<[NpsCategory], Rees46.SdkError>) -> Void) {
        requests.call("reviews.getNpsCategories", completion: completion) { Self.npsCategoriesRequest }
    }

    func getNpsCategories() async throws -> [NpsCategory] {
        try await requests.value("reviews.getNpsCategories") { Self.npsCategoriesRequest }
    }

    func getNpsChannels(completion: @escaping (Result<[PollChannel], Rees46.SdkError>) -> Void) {
        requests.call("reviews.getNpsChannels", completion: completion) { Self.npsChannelsRequest }
    }

    func getNpsChannels() async throws -> [PollChannel] {
        try await requests.value("reviews.getNpsChannels") { Self.npsChannelsRequest }
    }

    func getCsatCampaigns(completion: @escaping (Result<[CsatCampaign], Rees46.SdkError>) -> Void) {
        requests.call("reviews.getCsatCampaigns", completion: completion) { Self.csatCampaignsRequest }
    }

    func getCsatCampaigns() async throws -> [CsatCampaign] {
        try await requests.value("reviews.getCsatCampaigns") { Self.csatCampaignsRequest }
    }

    func getCesCampaigns(completion: @escaping (Result<[CesCampaign], Rees46.SdkError>) -> Void) {
        requests.call("reviews.getCesCampaigns", completion: completion) { Self.cesCampaignsRequest }
    }

    func getCesCampaigns() async throws -> [CesCampaign] {
        try await requests.value("reviews.getCesCampaigns") { Self.cesCampaignsRequest }
    }

    // MARK: - Reviews of products

    func getProductReviews(
        itemId: String, limit: Int?, offset: Int?,
        completion: @escaping (Result<ProductReviewsResponse, Rees46.SdkError>) -> Void
    ) {
        requests.call("reviews.getProductReviews", completion: completion) {
            try Self.productReviewsRequest(itemId: itemId, limit: limit, offset: offset)
        }
    }

    func getProductReviews(itemId: String, limit: Int?, offset: Int?) async throws -> ProductReviewsResponse {
        try await requests.value("reviews.getProductReviews") {
            try Self.productReviewsRequest(itemId: itemId, limit: limit, offset: offset)
        }
    }

    func getClientReviews(orderId: String, completion: @escaping (Result<[ClientReview], Rees46.SdkError>) -> Void) {
        requests.call("reviews.getClientReviews", completion: completion) { try Self.clientReviewsRequest(orderId: orderId) }
    }

    func getClientReviews(orderId: String) async throws -> [ClientReview] {
        try await requests.value("reviews.getClientReviews") { try Self.clientReviewsRequest(orderId: orderId) }
    }
}

// MARK: - Requests

extension ReviewsAPIImpl {

    /// A poll of API v3 and its scale.
    enum Poll: String {
        case nps, csat, ces

        var scale: ClosedRange<Int> {
            switch self {
            case .nps: return 0...10
            case .csat: return 1...5
            case .ces: return 1...7
            }
        }

        /// The field of what is scored: a category of NPS, a campaign of CSAT and CES.
        var subject: String {
            self == .nps ? "category" : "campaign"
        }
    }

    /// `POST api/v3/polls/<poll>/reviews` on `appDomain`: the score, the channel and what is scored; the
    /// order, the comment and the label only when they are given and not empty. A score off the poll's
    /// scale or an empty channel or subject is `invalidArgument`, and nothing is sent. The answer is
    /// `payload.review.id`; one without it — an empty body too — is `decoding`.
    static func scoreRequest(
        _ poll: Poll, rate: Int, channel: String, subject: String, orderId: String?, comment: String?, label: String?
    ) throws -> ApiRequest<PollReview> {
        guard poll.scale.contains(rate) else {
            throw Rees46.SdkError.invalidArgument("rate must be from \(poll.scale.lowerBound) to \(poll.scale.upperBound)")
        }
        try required(channel, "channel")
        try required(subject, poll.subject)
        var body: [String: Any] = ["rate": rate, "channel": channel, poll.subject: subject]
        for (key, value) in [("order_id", orderId), ("comment", comment), ("label", label)] {
            if let value = ApiArguments.given(value) {
                body[key] = value
            }
        }
        return ApiRequest(method: .post, path: "api/v3/polls/\(poll.rawValue)/reviews", body: body, host: .app) { data in
            try JSONDecoder().decode(PollReviewAnswer.self, from: data).review
        }
    }

    static var npsCategoriesRequest: ApiRequest<[NpsCategory]> {
        dictionaryRequest("api/v3/polls/nps/categories", NpsCategoriesAnswer.self) { $0.items }
    }

    static var npsChannelsRequest: ApiRequest<[PollChannel]> {
        dictionaryRequest("api/v3/polls/nps/channels", PollChannelsAnswer.self) { $0.items }
    }

    static var csatCampaignsRequest: ApiRequest<[CsatCampaign]> {
        dictionaryRequest("api/v3/polls/csat/campaigns", CsatCampaignsAnswer.self) { $0.items }
    }

    static var cesCampaignsRequest: ApiRequest<[CesCampaign]> {
        dictionaryRequest("api/v3/polls/ces/campaigns", CesCampaignsAnswer.self) { $0.items }
    }

    /// `GET reviews/product` on the API host: `product`, and `limit` and `offset` when they are given. An
    /// answer without a body is a product without reviews.
    static func productReviewsRequest(itemId: String, limit: Int?, offset: Int?) throws -> ApiRequest<ProductReviewsResponse> {
        try required(itemId, "itemId")
        var query = ["product": itemId]
        if let limit = limit {
            guard (1...100).contains(limit) else { throw Rees46.SdkError.invalidArgument("limit must be from 1 to 100") }
            query["limit"] = String(limit)
        }
        if let offset = offset {
            guard offset >= 0 else { throw Rees46.SdkError.invalidArgument("offset must not be negative") }
            query["offset"] = String(offset)
        }
        let none = ProductReviewsResponse(summary: ProductRatingSummary(count: 0), reviews: [])
        return .get("reviews/product", query: query, answer: ProductReviewsAnswer.self, whenEmpty: none) { $0.response }
    }

    /// `GET reviews/client` on the API host: `order`. An answer without a body is no review.
    static func clientReviewsRequest(orderId: String) throws -> ApiRequest<[ClientReview]> {
        try required(orderId, "orderId")
        return .get("reviews/client", query: ["order": orderId], answer: ClientReviewsAnswer.self, whenEmpty: []) { $0.items }
    }

    /// A `GET` of a dictionary of the polls on `appDomain`; an answer without a body is an empty one.
    private static func dictionaryRequest<Answer: Decodable, Item>(
        _ path: String, _ answer: Answer.Type, _ items: @escaping (Answer) -> [Item]
    ) -> ApiRequest<[Item]> {
        var request = ApiRequest<[Item]>.get(path, answer: answer, whenEmpty: [], value: items)
        request.host = .app
        return request
    }

    /// Throws `invalidArgument` for an empty or blank `value` of the argument `name`.
    private static func required(_ value: String, _ name: String) throws {
        if ApiArguments.isBlank(value) {
            throw Rees46.SdkError.invalidArgument("\(name) must not be empty")
        }
    }
}
