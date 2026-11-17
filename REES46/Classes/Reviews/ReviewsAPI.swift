//
//  ReviewsAPI.swift
//  REES46
//
//  The `reviews` namespace of the contract (`sdk/contract/reviews.md`).
//

import Foundation

/**
 The customer's feedback: NPS, CSAT and CES scores with the dictionaries behind them, and the reviews of
 products. The app asks for a score with its own interface and sends it with a `create…` method; the
 question and the thanks for a score come from the dictionary.

 The polls go to API v3, on the host of the shop's account (`Rees46Config.appDomain`); the reviews of
 products go to the API host (`apiDomain`).

 For the Flutter and React Native bridges, as every namespace but `tracking`: `@_spi(Bridge) import
 REES46` and a shop started with `Rees46.initializeBridge`. On the old core every method ends as
 `notInitialized` and sends nothing. The SDK's `review(rate:channel:category:orderId:comment:completion:)`
 stays as it is for apps.

 Every `completion` is called once, on the main thread, with the value or the error: `notInitialized` on
 the old core or after `release()`; `shopBlocked`; `invalidArgument` for an argument the method refuses,
 and then nothing is sent; `network`, `timeout`; `http(code:serverCode:)` for an answer outside `2xx`;
 `decoding` for an answer that is not the method's; `cancelled` for a call `release()` ended. A `402`,
 `403` or `404` here does not change the state of the SDK. Nothing is repeated: the app decides. The
 `async` form of each method throws the same `Rees46.SdkError`; cancelling the task ends the call as
 `cancelled`.
 */
@_spi(Bridge)
public protocol ReviewsAPI {

    /**
     An NPS score: how ready the customer is to recommend the shop (`POST api/v3/polls/nps/reviews` on
     `appDomain`). The question and the thanks come from `NpsCategory`: 0–6 — `detractor…`, 7–8 —
     `passive…`, 9–10 — `promoter…`.

     - Parameters:
       - rate: from 0 to 10.
       - channel: the code of the channel in the shop's account; not empty.
       - category: the code of the category — what is scored; not empty.
       - orderId: the order scored, if one is. Another customer's order is `http(404)`; an order the
         server does not know it drops, and keeps the score without it. `nil` or empty is not sent.
       - comment: `nil` or empty is not sent. A score sent again the same day without one keeps the
         earlier comment if the score is the same, and clears it if the score changed.
       - label: a mark that groups the reviews in the report; `nil` or empty is not sent.

     The same channel, category, order and label scored again the same day (in the shop's time zone)
     makes no new review: the server updates the earlier one, and `PollReview.id` is its id. A score
     with a comment — the answer to the question after the score — goes to the latest review of the
     last 90 days with the same channel, category, order, label and score and no comment, if there is
     one, rather than making another. `http(400)`
     is a score the server refused, `http(404)` a shop, customer, channel or category it does not know,
     `http(429)` more than 30 scores a minute from the device.
     */
    func createNps(
        rate: Int, channel: String, category: String, orderId: String?, comment: String?, label: String?,
        completion: @escaping (Result<PollReview, Rees46.SdkError>) -> Void
    )

    /// `createNps(rate:channel:category:orderId:comment:label:completion:)` for `async` code.
    func createNps(
        rate: Int, channel: String, category: String, orderId: String?, comment: String?, label: String?
    ) async throws -> PollReview

    /**
     A CSAT score: whether the customer is pleased with one interaction — the delivery, the support, the
     checkout (`POST api/v3/polls/csat/reviews` on `appDomain`). `rate` is from 1 to 5; `campaign` — the
     code of the campaign, what is scored — not empty. The rest as in `createNps`. The question and the
     thanks come from `CsatCampaign`: 1–2 — `dissatisfied…`, 3 — `neutral…`, 4–5 — `satisfied…`.
     */
    func createCsat(
        rate: Int, channel: String, campaign: String, orderId: String?, comment: String?, label: String?,
        completion: @escaping (Result<PollReview, Rees46.SdkError>) -> Void
    )

    /// `createCsat(rate:channel:campaign:orderId:comment:label:completion:)` for `async` code.
    func createCsat(
        rate: Int, channel: String, campaign: String, orderId: String?, comment: String?, label: String?
    ) async throws -> PollReview

    /**
     A CES score: how much effort the task took the customer (`POST api/v3/polls/ces/reviews` on
     `appDomain`). As `createCsat`, but `rate` is from 1 to 7. The question and the thanks come from
     `CesCampaign`: 1–3 — `difficult…`, 4–5 — `neutral…`, 6–7 — `easy…`.
     */
    func createCes(
        rate: Int, channel: String, campaign: String, orderId: String?, comment: String?, label: String?,
        completion: @escaping (Result<PollReview, Rees46.SdkError>) -> Void
    )

    /// `createCes(rate:channel:campaign:orderId:comment:label:completion:)` for `async` code.
    func createCes(
        rate: Int, channel: String, campaign: String, orderId: String?, comment: String?, label: String?
    ) async throws -> PollReview

    /// The NPS categories of the shop's account (`GET api/v3/polls/nps/categories` on `appDomain`); none
    /// is an empty list.
    func getNpsCategories(completion: @escaping (Result<[NpsCategory], Rees46.SdkError>) -> Void)

    /// `getNpsCategories(completion:)` for `async` code.
    func getNpsCategories() async throws -> [NpsCategory]

    /// The channels of the polls (`GET api/v3/polls/nps/channels` on `appDomain`): one list for NPS, CSAT
    /// and CES, which the API gives on the path of NPS only. None is an empty list.
    func getNpsChannels(completion: @escaping (Result<[PollChannel], Rees46.SdkError>) -> Void)

    /// `getNpsChannels(completion:)` for `async` code.
    func getNpsChannels() async throws -> [PollChannel]

    /// The CSAT campaigns of the shop's account (`GET api/v3/polls/csat/campaigns` on `appDomain`); none
    /// is an empty list.
    func getCsatCampaigns(completion: @escaping (Result<[CsatCampaign], Rees46.SdkError>) -> Void)

    /// `getCsatCampaigns(completion:)` for `async` code.
    func getCsatCampaigns() async throws -> [CsatCampaign]

    /// The CES campaigns of the shop's account (`GET api/v3/polls/ces/campaigns` on `appDomain`); none is
    /// an empty list.
    func getCesCampaigns(completion: @escaping (Result<[CesCampaign], Rees46.SdkError>) -> Void)

    /// `getCesCampaigns(completion:)` for `async` code.
    func getCesCampaigns() async throws -> [CesCampaign]

    /**
     The published reviews of a product and its rating, for the product's card (`GET reviews/product` on
     `apiDomain`). The summary counts every published review; `limit` and `offset` page the list only,
     newest first. Reviews on moderation and rejected ones are not here.

     - Parameters:
       - itemId: the product; not empty.
       - limit: from 1 to 100; `nil` is the server's 20.
       - offset: not below 0; `nil` is 0.

     `http(403)` is a shop without the service of reviews, `http(404)` a product the server does not know.
     */
    func getProductReviews(
        itemId: String, limit: Int?, offset: Int?,
        completion: @escaping (Result<ProductReviewsResponse, Rees46.SdkError>) -> Void
    )

    /// `getProductReviews(itemId:limit:offset:completion:)` for `async` code.
    func getProductReviews(itemId: String, limit: Int?, offset: Int?) async throws -> ProductReviewsResponse

    /**
     The reviews the customer of this device left in one order, whatever their moderation, say to show
     a score next to a product in the history of orders (`GET reviews/client` on `apiDomain`). `orderId`
     is not empty. No page; none is an empty list.

     `http(404)` is an order the server does not know or another customer's ("Order not found"), or a
     customer it does not know ("User not found"): the method makes none.
     */
    func getClientReviews(orderId: String, completion: @escaping (Result<[ClientReview], Rees46.SdkError>) -> Void)

    /// `getClientReviews(orderId:completion:)` for `async` code.
    func getClientReviews(orderId: String) async throws -> [ClientReview]
}

/// The calls without the arguments that may be left out. Each is another method than the protocol's,
/// with fewer arguments: a conformer that does not implement a requirement does not compile, instead of
/// calling itself here.
@_spi(Bridge)
extension ReviewsAPI {

    /// `createNps` without an order, a comment or a label.
    public func createNps(
        rate: Int, channel: String, category: String,
        completion: @escaping (Result<PollReview, Rees46.SdkError>) -> Void
    ) {
        createNps(rate: rate, channel: channel, category: category, orderId: nil, comment: nil, label: nil, completion: completion)
    }

    /// `createNps` without an order, a comment or a label, for `async` code.
    public func createNps(rate: Int, channel: String, category: String) async throws -> PollReview {
        try await createNps(rate: rate, channel: channel, category: category, orderId: nil, comment: nil, label: nil)
    }

    /// `createCsat` without an order, a comment or a label.
    public func createCsat(
        rate: Int, channel: String, campaign: String,
        completion: @escaping (Result<PollReview, Rees46.SdkError>) -> Void
    ) {
        createCsat(rate: rate, channel: channel, campaign: campaign, orderId: nil, comment: nil, label: nil, completion: completion)
    }

    /// `createCsat` without an order, a comment or a label, for `async` code.
    public func createCsat(rate: Int, channel: String, campaign: String) async throws -> PollReview {
        try await createCsat(rate: rate, channel: channel, campaign: campaign, orderId: nil, comment: nil, label: nil)
    }

    /// `createCes` without an order, a comment or a label.
    public func createCes(
        rate: Int, channel: String, campaign: String,
        completion: @escaping (Result<PollReview, Rees46.SdkError>) -> Void
    ) {
        createCes(rate: rate, channel: channel, campaign: campaign, orderId: nil, comment: nil, label: nil, completion: completion)
    }

    /// `createCes` without an order, a comment or a label, for `async` code.
    public func createCes(rate: Int, channel: String, campaign: String) async throws -> PollReview {
        try await createCes(rate: rate, channel: channel, campaign: campaign, orderId: nil, comment: nil, label: nil)
    }

    /// `getProductReviews` with the server's page: the 20 newest.
    public func getProductReviews(
        itemId: String,
        completion: @escaping (Result<ProductReviewsResponse, Rees46.SdkError>) -> Void
    ) {
        getProductReviews(itemId: itemId, limit: nil, offset: nil, completion: completion)
    }

    /// `getProductReviews` with the server's page, for `async` code.
    public func getProductReviews(itemId: String) async throws -> ProductReviewsResponse {
        try await getProductReviews(itemId: itemId, limit: nil, offset: nil)
    }
}

@_spi(Bridge)
extension PersonalizationSDK {

    /// The customer's feedback (`ReviewsAPI`): the polls on `appDomain`, the reviews of products on the
    /// API host. On the new core only.
    public var reviews: ReviewsAPI {
        ReviewsAPIImpl(requests: NamespaceRequests(self))
    }
}
