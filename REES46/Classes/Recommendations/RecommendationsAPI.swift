//
//  RecommendationsAPI.swift
//  REES46
//
//  The `recommendations` namespace of the contract (`sdk/contract/recommendations.md`).
//

import Foundation

/**
 The shop's blocks of recommendations: similar products, bought together, popular and the rest, set up in
 its account. A block gives its products for the customer and where they are: on a product's card, in a
 category, on the search's page.

 For the Flutter and React Native bridges, as every namespace but `tracking`: `@_spi(Bridge) import
 REES46` and a shop started with `Rees46.initializeBridge`. On the old core every method ends as
 `notInitialized` and sends nothing.
 */
@_spi(Bridge)
public protocol RecommendationsAPI {

    /**
     The products of the block `code` (`GET recommend/{code}`).

     With `extended`, the default, the products come whole; without it only their ids (`itemIds`). A
     block on pause gives no products. For the views, carts and purchases to count for the block, send
     them to `tracking` with the source `TrackingSource(type: .dynamic, code: code)`.

     `completion` is called once, on the main thread, with the block or the error: `notInitialized` on
     the old core or after `release()`, `shopBlocked`, `invalidArgument` for an empty `code` or a
     refused request, `network`, `timeout`, `http(code:serverCode:)` — `404` for a block the shop does not
     have, `402` for a service not paid —, `decoding`, `cancelled` for a call `release()` ended. Nothing
     is repeated: the app decides.
     */
    func get(
        code: String,
        request: Rees46.RecommendationRequest,
        completion: @escaping (Result<Rees46.RecommendationResponse, Rees46.SdkError>) -> Void
    )

    /// `get(code:request:completion:)` for `async` code: throws the `Rees46.SdkError`; cancelling the task
    /// ends the call as `cancelled`.
    func get(code: String, request: Rees46.RecommendationRequest) async throws -> Rees46.RecommendationResponse
}

/// The request by default: protocol requirements cannot carry it.
@_spi(Bridge)
extension RecommendationsAPI {

    /// The block's products, whole, without a context.
    public func get(code: String, completion: @escaping (Result<Rees46.RecommendationResponse, Rees46.SdkError>) -> Void) {
        get(code: code, request: Rees46.RecommendationRequest(), completion: completion)
    }

    /// The block's products, whole, without a context.
    public func get(code: String) async throws -> Rees46.RecommendationResponse {
        try await get(code: code, request: Rees46.RecommendationRequest())
    }
}

@_spi(Bridge)
extension Rees46 {

    /// Where the customer is and what the block gives (`recommendations.get`).
    ///
    /// Lists go as one value joined by `,`, an empty one as none. `limit` starts at 1, and
    /// `withLocations` needs `extended`: otherwise the call is `invalidArgument` and sends nothing.
    public struct RecommendationRequest: Equatable {
        /// The product on screen: a card, a cart.
        public var itemId: String?
        /// The category on screen.
        public var categoryId: String?
        /// The search query on screen, for a block on the search's page.
        public var searchQuery: String?
        public var excludedItemIds: [String]?
        public var brands: [String]?
        public var locations: [String]?
        public var limit: Int?
        /// The products whole; without it, only their ids (`RecommendationResponse.itemIds`).
        public var extended: Bool
        /// Each product's `locationIds`; only with `extended`.
        public var withLocations: Bool

        public init(
            itemId: String? = nil,
            categoryId: String? = nil,
            searchQuery: String? = nil,
            excludedItemIds: [String]? = nil,
            brands: [String]? = nil,
            locations: [String]? = nil,
            limit: Int? = nil,
            extended: Bool = true,
            withLocations: Bool = false
        ) {
            self.itemId = itemId
            self.categoryId = categoryId
            self.searchQuery = searchQuery
            self.excludedItemIds = excludedItemIds
            self.brands = brands
            self.locations = locations
            self.limit = limit
            self.extended = extended
            self.withLocations = withLocations
        }
    }

    /// The products of a block.
    public struct RecommendationResponse: Equatable {
        /// The block's id.
        public let id: Int?
        /// The block's title.
        public let title: String?
        /// The link of the title, when the block has one.
        public let link: String?
        /// The products, with `extended`; empty without it, and for a block on pause.
        public let products: [Product]
        /// The products' ids: of `products` with `extended`, the answer's list without it.
        public let itemIds: [String]
    }
}

@_spi(Bridge)
extension PersonalizationSDK {

    /// The shop's blocks of recommendations (`RecommendationsAPI`): on the new core only.
    public var recommendations: RecommendationsAPI {
        RecommendationsAPIImpl(requests: NamespaceRequests(self))
    }
}
