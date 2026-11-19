//
//  SegmentsAPI.swift
//  REES46
//
//  The `segments` namespace of the contract (`sdk/contract/segments.md`).
//

import Foundation

/**
 The customer's segments and the device's A/B group. The SDK adds the customer to the shop's static
 segments and removes them; the server works out the dynamic ones, which the SDK only reads.

 For the Flutter and React Native bridges, as every namespace but `tracking`: `@_spi(Bridge) import
 REES46` and a shop started with `Rees46.initializeBridge`. On the old core `add`, `remove` and `get` end
 as `notInitialized` and send nothing; `getAbGroup` is the device's on either.

 Every `completion` is called once, on the main thread, with the value or the error: `notInitialized` on
 the old core or after `release()`, `shopBlocked`, `invalidArgument` — a `segmentId` not above 0, an
 empty contact — before anything is sent, `network`, `timeout`, `http(code:serverCode:)`, `decoding`,
 `cancelled` for a call `release()` ended. The `async` forms throw the same `Rees46.SdkError`, and
 cancelling the task ends the call as `cancelled`. Nothing is repeated: the app decides.
 */
@_spi(Bridge)
public protocol SegmentsAPI {

    /// Adds the customer to a static segment (`POST segments/add`). With `email` or `phone` the server
    /// acts on the contact's owner without moving the device to them, unlike `profile.set`.
    func add(segmentId: Int, email: String?, phone: String?, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void)

    func add(segmentId: Int, email: String?, phone: String?) async throws

    /// Removes the customer from a static segment (`POST segments/remove`); not being in it is no error.
    func remove(segmentId: Int, email: String?, phone: String?, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void)

    func remove(segmentId: Int, email: String?, phone: String?) async throws

    /// The segments the customer is in now, static and dynamic (`GET segments/get`); none is an empty
    /// list. A device the server does not know is `http(404)`.
    func get(completion: @escaping (Result<[Rees46.Segment], Rees46.SdkError>) -> Void)

    func get() async throws -> [Rees46.Segment]

    /// The device's A/B group, `"A"` or `"B"`: picked once, the same for every shop of the app, kept
    /// across launches, `release()` and `deleteUserCredentials()`. It goes as `segment` in every
    /// request. No network, no error.
    func getAbGroup() -> String
}

/// The arguments by default: protocol requirements cannot carry them.
@_spi(Bridge)
extension SegmentsAPI {

    public func add(
        segmentId: Int,
        email: String? = nil,
        phone: String? = nil,
        completion: @escaping (Result<Void, Rees46.SdkError>) -> Void
    ) {
        add(segmentId: segmentId, email: email, phone: phone, completion: completion)
    }

    public func add(segmentId: Int, email: String? = nil, phone: String? = nil) async throws {
        try await add(segmentId: segmentId, email: email, phone: phone)
    }

    public func remove(
        segmentId: Int,
        email: String? = nil,
        phone: String? = nil,
        completion: @escaping (Result<Void, Rees46.SdkError>) -> Void
    ) {
        remove(segmentId: segmentId, email: email, phone: phone, completion: completion)
    }

    public func remove(segmentId: Int, email: String? = nil, phone: String? = nil) async throws {
        try await remove(segmentId: segmentId, email: email, phone: phone)
    }
}

@_spi(Bridge)
extension Rees46 {

    /// A segment the customer is in.
    public struct Segment: Equatable {
        public let id: Int
        /// `dynamic`, `static`, `less_often`, `rfm`, `rfm3`, `unknown`: an open set, a new type the
        /// server adds comes as it is. `""` when the answer gives the segment none.
        public let type: String
    }
}

@_spi(Bridge)
extension PersonalizationSDK {

    /// The customer's segments and the device's A/B group (`SegmentsAPI`): the requests on the new core
    /// only.
    public var segments: SegmentsAPI {
        SegmentsAPIImpl(requests: NamespaceRequests(self), abGroup: segment, popups: self as? SimplePersonalizationSDK)
    }
}

struct SegmentsAPIImpl: SegmentsAPI {

    let requests: NamespaceRequests
    /// The device's A/B group: it does not change.
    let abGroup: String
    /// The instance whose popups v3 hear that the segments changed.
    weak var popups: SimplePersonalizationSDK?

    func add(segmentId: Int, email: String?, phone: String?, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void) {
        requests.call("segments.add", completion: completion) {
            try changing(Self.changeRequest("segments/add", segmentId: segmentId, email: email, phone: phone), "add")
        }
    }

    func add(segmentId: Int, email: String?, phone: String?) async throws {
        try await requests.value("segments.add") {
            try changing(Self.changeRequest("segments/add", segmentId: segmentId, email: email, phone: phone), "add")
        }
    }

    func remove(segmentId: Int, email: String?, phone: String?, completion: @escaping (Result<Void, Rees46.SdkError>) -> Void) {
        requests.call("segments.remove", completion: completion) {
            try changing(Self.changeRequest("segments/remove", segmentId: segmentId, email: email, phone: phone), "remove")
        }
    }

    func remove(segmentId: Int, email: String?, phone: String?) async throws {
        try await requests.value("segments.remove") {
            try changing(Self.changeRequest("segments/remove", segmentId: segmentId, email: email, phone: phone), "remove")
        }
    }

    func get(completion: @escaping (Result<[Rees46.Segment], Rees46.SdkError>) -> Void) {
        requests.call("segments.get", completion: completion) { Self.listRequest }
    }

    func get() async throws -> [Rees46.Segment] {
        try await requests.value("segments.get") { Self.listRequest }
    }

    func getAbGroup() -> String {
        abGroup
    }

    /// `request` once it is on its way: popups v3 load their list anew for segments new in the session,
    /// as for the old `addToSegment` and `removeFromSegment`.
    private func changing(_ request: ApiRequest<Void>, _ action: String) -> ApiRequest<Void> {
        popups?.popupsV3.contextChanged("segment", signature: action + ClientBody.signature(request.body))
        return request
    }

    // MARK: - Requests

    /// A request of `path` for the segment: `segment_id` a number, as the API has it.
    static func changeRequest(_ path: String, segmentId: Int, email: String?, phone: String?) throws -> ApiRequest<Void> {
        guard segmentId > 0 else {
            throw Rees46.SdkError.invalidArgument("segmentId must be above 0")
        }
        var body = ClientBody(["segment_id": segmentId])
        try body.identifier("email", email, "email")
        try body.identifier("phone", phone, "phone")
        return ApiRequest(method: .post, path: path, body: body.fields) { _ in () }
    }

    /// `GET segments/get` — the server answers no `POST` there —: a list at the top of the answer; an
    /// answer without a body is none. An answer that is not a list is `decoding`.
    static var listRequest: ApiRequest<[Rees46.Segment]> {
        ApiRequest(method: .get, path: "segments/get") { body in
            guard !body.isEmpty else { return [] }
            return try Readable<Rees46.Segment>.readList(body)
        }
    }
}

extension Rees46.Segment: AnswerReadable {

    /// A segment without an id is left out.
    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        guard let id = answer.lenientInt("id") else {
            throw DecodingError.keyNotFound(AnswerKey("id"), DecodingError.Context(codingPath: answer.codingPath, debugDescription: "no id"))
        }
        self.id = id
        type = answer.lenientString("type") ?? ""
    }
}
