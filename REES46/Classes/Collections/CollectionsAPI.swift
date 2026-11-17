//
//  CollectionsAPI.swift
//  REES46
//
//  The `collections` namespace of the contract (`sdk/contract/collections.md`).
//

import Foundation

/**
 The shop's product collections: sets of products it makes by rules in its account.

 For the Flutter and React Native bridges, as every namespace but `tracking`: `@_spi(Bridge) import
 REES46` and a shop started with `Rees46.initializeBridge`. On the old core every method ends as
 `notInitialized` and sends nothing.
 */
@_spi(Bridge)
public protocol CollectionsAPI {

    /**
     The products of a collection (`GET collection/{collectionId}`), for the customer of the device.

     `completion` is called once, on the main thread, with the collection or the error: `notInitialized`
     on the old core or after `release()`, `shopBlocked`, `invalidArgument` for an empty `collectionId`,
     `network`, `timeout`, `http(code:serverCode:)` — `400` for a collection that does not exist or is
     not active —, `decoding` for an answer without products, `cancelled` for a call `release()` ended.
     Nothing is repeated: the app decides.
     */
    func get(collectionId: String, completion: @escaping (Result<Rees46.CollectionResponse, Rees46.SdkError>) -> Void)

    /// `get(collectionId:completion:)` for `async` code: throws the `Rees46.SdkError`; cancelling the task
    /// ends the call as `cancelled`.
    func get(collectionId: String) async throws -> Rees46.CollectionResponse
}

@_spi(Bridge)
extension Rees46 {

    /// The products of a collection (`collections.get`).
    public struct CollectionResponse: Equatable {
        public let products: [Product]
    }
}

@_spi(Bridge)
extension PersonalizationSDK {

    /// The shop's product collections (`CollectionsAPI`): on the new core only.
    public var collections: CollectionsAPI {
        CollectionsAPIImpl(requests: NamespaceRequests(self))
    }
}

struct CollectionsAPIImpl: CollectionsAPI {

    let requests: NamespaceRequests

    func get(collectionId: String, completion: @escaping (Result<Rees46.CollectionResponse, Rees46.SdkError>) -> Void) {
        requests.call("collections.get", completion: completion) { try Self.collectionRequest(collectionId: collectionId) }
    }

    func get(collectionId: String) async throws -> Rees46.CollectionResponse {
        try await requests.value("collections.get") { try Self.collectionRequest(collectionId: collectionId) }
    }

    /// `GET collection/{id}`, the id encoded in the path, without the contacts of the customer: the
    /// server finds the customer by the device id.
    static func collectionRequest(collectionId: String) throws -> ApiRequest<Rees46.CollectionResponse> {
        let id = try CatalogQuery.identifier(collectionId, "collectionId")
        return ApiRequest(method: .get, path: "collection/\(CatalogQuery.pathSegment(id))") { body in
            try Readable<Rees46.CollectionResponse>.read(body)
        }
    }
}

extension Rees46.CollectionResponse: AnswerReadable {

    /// Without a list of products it is not a collection (`decoding`).
    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        products = try answer.requiredModels(Rees46.Product.self, "products")
    }
}
