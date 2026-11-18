//
//  ReviewsFixtureCalls.swift
//  REES46CoreTests, REES46Tests
//
//  The calls of the `reviews` fixture (`Fixtures/proposed/reviews.json`) made from their arguments, and the
//  methods' values written by the contract's field names, so a value is compared with a case's `result`.
//  The package tests and the demo app's tests compile this one file.
//

import Foundation
@_spi(Bridge) @testable import REES46

enum ReviewsFixtureCalls {

    // MARK: - The request of a call

    /// A request of `reviews` without its type: what it sends, and how an answer becomes its value.
    struct Request {
        let method: CoreRequest.Method
        let path: String
        let host: ApiHost
        let query: [String: String]
        let body: [String: Any]
        /// The method's value of `response`, or its error.
        let value: (NetworkClient.Response, SdkLogger) -> Result<Any, Rees46.SdkError>
    }

    /// The request `call` builds; throws what the method refuses before it sends anything.
    static func request(for call: ContractCase.Call) throws -> Request {
        let args = Arguments(call.args)
        let name = call.name
        switch call.method {
        case "createNps":
            return erase(name, try ReviewsAPIImpl.scoreRequest(
                .nps, rate: args.int("rate"), channel: args.string("channel"), subject: args.string("category"),
                orderId: args.optional("orderId"), comment: args.optional("comment"), label: args.optional("label")
            ))
        case "createCsat":
            return erase(name, try ReviewsAPIImpl.scoreRequest(
                .csat, rate: args.int("rate"), channel: args.string("channel"), subject: args.string("campaign"),
                orderId: args.optional("orderId"), comment: args.optional("comment"), label: args.optional("label")
            ))
        case "createCes":
            return erase(name, try ReviewsAPIImpl.scoreRequest(
                .ces, rate: args.int("rate"), channel: args.string("channel"), subject: args.string("campaign"),
                orderId: args.optional("orderId"), comment: args.optional("comment"), label: args.optional("label")
            ))
        case "getNpsCategories":
            return erase(name, ReviewsAPIImpl.npsCategoriesRequest)
        case "getNpsChannels":
            return erase(name, ReviewsAPIImpl.npsChannelsRequest)
        case "getCsatCampaigns":
            return erase(name, ReviewsAPIImpl.csatCampaignsRequest)
        case "getCesCampaigns":
            return erase(name, ReviewsAPIImpl.cesCampaignsRequest)
        case "getProductReviews":
            return erase(name, try ReviewsAPIImpl.productReviewsRequest(
                itemId: args.string("itemId"), limit: args.optionalInt("limit"), offset: args.optionalInt("offset")
            ))
        case "getClientReviews":
            return erase(name, try ReviewsAPIImpl.clientReviewsRequest(orderId: args.string("orderId")))
        default:
            throw Unknown(method: call.method)
        }
    }

    struct Unknown: Error {
        let method: String
    }

    private static func erase<Value>(_ name: String, _ request: ApiRequest<Value>) -> Request {
        Request(method: request.method, path: request.path, host: request.host, query: request.query, body: request.body) { response, logger in
            NamespaceRequests.value(of: response, for: request, call: name, logger: logger).map { $0 as Any }
        }
    }

    // MARK: - The call through the namespace

    /// Calls the method of `call` on `reviews` with its `completion`; `completion` gets the value as `Any`.
    static func run(_ call: ContractCase.Call, on reviews: ReviewsAPI, completion: @escaping (Result<Any, Rees46.SdkError>) -> Void) {
        let args = Arguments(call.args)
        func done<Value>(_ result: Result<Value, Rees46.SdkError>) {
            completion(result.map { $0 as Any })
        }
        switch call.method {
        case "createNps":
            reviews.createNps(
                rate: args.int("rate"), channel: args.string("channel"), category: args.string("category"),
                orderId: args.optional("orderId"), comment: args.optional("comment"), label: args.optional("label"), completion: done
            )
        case "createCsat":
            reviews.createCsat(
                rate: args.int("rate"), channel: args.string("channel"), campaign: args.string("campaign"),
                orderId: args.optional("orderId"), comment: args.optional("comment"), label: args.optional("label"), completion: done
            )
        case "createCes":
            reviews.createCes(
                rate: args.int("rate"), channel: args.string("channel"), campaign: args.string("campaign"),
                orderId: args.optional("orderId"), comment: args.optional("comment"), label: args.optional("label"), completion: done
            )
        case "getNpsCategories":
            reviews.getNpsCategories(completion: done)
        case "getNpsChannels":
            reviews.getNpsChannels(completion: done)
        case "getCsatCampaigns":
            reviews.getCsatCampaigns(completion: done)
        case "getCesCampaigns":
            reviews.getCesCampaigns(completion: done)
        case "getProductReviews":
            reviews.getProductReviews(
                itemId: args.string("itemId"), limit: args.optionalInt("limit"), offset: args.optionalInt("offset"), completion: done
            )
        case "getClientReviews":
            reviews.getClientReviews(orderId: args.string("orderId"), completion: done)
        default:
            completion(.failure(.invalidArgument("the fixture calls an unknown method \(call.method)")))
        }
    }

    /// The arguments of a call by the contract's names.
    private struct Arguments {
        let values: [String: Any]

        init(_ values: [String: Any]) {
            self.values = values
        }

        func string(_ name: String) -> String {
            values[name] as? String ?? ""
        }

        func optional(_ name: String) -> String? {
            values[name] as? String
        }

        func int(_ name: String) -> Int {
            (values[name] as? NSNumber)?.intValue ?? 0
        }

        func optionalInt(_ name: String) -> Int? {
            (values[name] as? NSNumber)?.intValue
        }
    }

    /// The host the contract puts `path` on: API v3 — the polls — on `appDomain`, the rest on the API.
    static func host(of path: String) -> ApiHost {
        path.hasPrefix("api/v3/") ? .app : .api
    }

    // MARK: - Values by the contract's names

    /// `value` — a model of `reviews` or a list of them — as JSON with the contract's field names; an
    /// empty field is left out, as a case's `result` leaves it out.
    static func json(_ value: Any) -> Any {
        switch value {
        case let list as [Any]:
            return list.map(json)
        case let review as PollReview:
            return ["id": review.id]
        case let category as NpsCategory:
            return compact([
                "code": category.code, "name": category.name,
                "detractorQuestion": category.detractorQuestion, "passiveQuestion": category.passiveQuestion,
                "promoterQuestion": category.promoterQuestion, "detractorSuccess": category.detractorSuccess,
                "passiveSuccess": category.passiveSuccess, "promoterSuccess": category.promoterSuccess,
                "buttonLabel": category.buttonLabel,
            ])
        case let campaign as CsatCampaign:
            return compact([
                "code": campaign.code, "name": campaign.name,
                "dissatisfiedQuestion": campaign.dissatisfiedQuestion, "neutralQuestion": campaign.neutralQuestion,
                "satisfiedQuestion": campaign.satisfiedQuestion, "dissatisfiedSuccess": campaign.dissatisfiedSuccess,
                "neutralSuccess": campaign.neutralSuccess, "satisfiedSuccess": campaign.satisfiedSuccess,
                "buttonLabel": campaign.buttonLabel,
            ])
        case let campaign as CesCampaign:
            return compact([
                "code": campaign.code, "name": campaign.name,
                "difficultQuestion": campaign.difficultQuestion, "neutralQuestion": campaign.neutralQuestion,
                "easyQuestion": campaign.easyQuestion, "difficultSuccess": campaign.difficultSuccess,
                "neutralSuccess": campaign.neutralSuccess, "easySuccess": campaign.easySuccess,
                "buttonLabel": campaign.buttonLabel,
            ])
        case let channel as PollChannel:
            return ["code": channel.code, "name": channel.name]
        case let response as ProductReviewsResponse:
            var ratings: [String: Any] = [:]
            response.summary.ratings.forEach { ratings[String($0.key)] = $0.value }
            return [
                "summary": compact(["count": response.summary.count, "averageRating": response.summary.averageRating, "ratings": ratings]),
                "reviews": response.reviews.map(json),
            ]
        case let review as ProductReview:
            return compact([
                "id": review.id, "rating": review.rating, "comment": review.comment, "author": review.author,
                "createdAt": review.createdAt,
            ])
        case let review as ClientReview:
            return compact([
                "id": review.id, "itemId": review.itemId, "orderId": review.orderId, "rating": review.rating,
                "comment": review.comment, "state": review.state?.rawValue, "createdAt": review.createdAt,
            ])
        default:
            return "\(value)"
        }
    }

    /// Whether `value` is the case's `expected` result.
    static func matches(_ value: Any, _ expected: Any?) -> Bool {
        guard let expected = expected else { return false }
        return canonical(json(value)) == canonical(expected)
    }

    /// JSON with sorted keys: two values are the same JSON when their texts are.
    static func canonical(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed]) else {
            return "not JSON: \(value)"
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static func compact(_ fields: [String: Any?]) -> [String: Any] {
        fields.compactMapValues { $0 }
    }
}
