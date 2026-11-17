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
    /// The read timeout of this request alone; `nil` is the default one (`sdk/core/network.md`).
    var timeout: TimeInterval?
    /// The method's value of a `2xx` answer's body — empty when the answer had none; throws when the
    /// body is not one (`decoding`).
    let decode: (Data) throws -> Value

    /// The request as the core sends it.
    var coreRequest: CoreRequest {
        CoreRequest(method: method, path: path, query: query, body: body, timeout: timeout)
    }
}

extension ApiRequest {

    /// A `GET` whose answer reads as `Answer` (`LenientDecoding`), made into the value by `value`.
    static func get<Answer: Decodable>(
        _ path: String,
        query: [String: String] = [:],
        timeout: TimeInterval? = nil,
        answer: Answer.Type,
        value: @escaping (Answer) -> Value
    ) -> ApiRequest {
        ApiRequest(method: .get, path: path, query: query, timeout: timeout) { body in
            value(try JSONDecoder().decode(Answer.self, from: body))
        }
    }
}
