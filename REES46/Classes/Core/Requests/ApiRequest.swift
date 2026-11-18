//
//  ApiRequest.swift
//  REES46
//
//  One request of a namespace's method (`sdk.<namespace>.<method>`): what it sends and how the answer
//  becomes the method's value. `NamespaceRequests` sends it through the new core.
//

import Foundation

struct ApiRequest<Value> {

    let method: CoreRequest.Method
    /// The path under the API host, without a leading slash: `products/cart`.
    let path: String
    /// The query of a `GET`, without the common fields: the core adds them (`CommonFields`).
    var query: [String: String] = [:]
    /// The JSON body of a `POST`, without the common fields.
    var body: [String: Any] = [:]
    /// Query fields that repeat, as Rails reads a list: `promo_codes[]=A&promo_codes[]=B`.
    var queryLists: [String: [String]] = [:]
    /// The read timeout of this request alone; `nil` is the default one (`sdk/core/network.md`).
    var timeout: TimeInterval?
    /// The host it goes to: the API's, or API v3's for the methods the contract puts there.
    var host: ApiHost = .api
    /// A server method's request (`SecretQuery`): it goes with `shop_id` and none of the device's fields.
    var secret = false
    /// The method's value of a `2xx` answer's body — empty when the answer had none; throws when the
    /// body is not one (`decoding`).
    let decode: (Data) throws -> Value

    /// The request as the core sends it.
    var coreRequest: CoreRequest {
        var request = CoreRequest(method: method, path: path, query: query, body: body, timeout: timeout, queryLists: queryLists)
        request.secret = secret
        return request
    }
}

/// The host of a namespace's request (`sdk/core/network.md`, "Хосты"): the namespace's file of the
/// contract names the methods that do not go to the API host.
enum ApiHost: Equatable {
    /// `Rees46Config.apiDomain`: the API.
    case api
    /// `Rees46Config.appDomain`: API v3, on the host of the shop's account.
    case app
}

extension ApiRequest {

    /// A `GET` whose answer reads as `Answer` (`LenientDecoding`), made into the value by `value`. An
    /// answer without a body is `whenEmpty` — a `2xx` without one is a success with an empty result
    /// (`sdk/core/network.md`) —, or `decoding` for a method that has no empty value.
    static func get<Answer: Decodable>(
        _ path: String,
        query: [String: String] = [:],
        timeout: TimeInterval? = nil,
        answer: Answer.Type,
        whenEmpty: Value? = nil,
        value: @escaping (Answer) -> Value
    ) -> ApiRequest {
        ApiRequest(method: .get, path: path, query: query, timeout: timeout) { body in
            if body.isEmpty, let empty = whenEmpty {
                return empty
            }
            return value(try JSONDecoder().decode(Answer.self, from: body))
        }
    }
}
