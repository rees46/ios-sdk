//
//  SearchAPI.swift
//  REES46
//
//  The `search` namespace of the contract (`sdk/contract/search.md`).
//

import Foundation

/**
 Search in the shop's catalog: what to show in an empty search field (`blank`), products and hints while
 the customer types (`instant`), and the page of results with facets, sorting and pages (`full`).

 The methods send no event: when the customer searched, the app calls `tracking.search` itself. A
 product opened from the results counts for the search with the source `instantSearch` or `fullSearch`
 and the query as its code.

 For the Flutter and React Native bridges, as every namespace but `tracking`: `@_spi(Bridge) import
 REES46` and a shop started with `Rees46.initializeBridge`. On the old core every method ends as
 `notInitialized` and sends nothing.

 Every `completion` is called once, on the main thread, with the value or the error: `notInitialized` on
 the old core or after `release()`, `shopBlocked`, `invalidArgument` for an argument refused before
 anything is sent, `network`, `timeout`, `http(code:serverCode:)`, `decoding`, `cancelled` for a call
 `release()` ended. The `async` forms throw the same `Rees46.SdkError`, and cancelling the task ends the
 call as `cancelled`. Nothing is repeated: the app decides.
 */
@_spi(Bridge)
public protocol SearchAPI {

    /// The empty search (`GET search/blank`): the customer's last queries, the products they viewed last
    /// or popular ones, hints, popular categories, brands and links.
    func blank(completion: @escaping (Result<Rees46.SearchBlankResponse, Rees46.SdkError>) -> Void)

    func blank() async throws -> Rees46.SearchBlankResponse

    /// The search while the customer types (`GET search`, `instant_search`). `query` is not empty.
    /// `excludedMerchants` goes only with `locations`: the server looks for the merchants inside them,
    /// and without any it finds no product.
    func instant(
        query: String,
        locations: [String]?,
        excludedMerchants: [String]?,
        excludedBrands: [String]?,
        completion: @escaping (Result<Rees46.SearchInstantResponse, Rees46.SdkError>) -> Void
    )

    func instant(
        query: String,
        locations: [String]?,
        excludedMerchants: [String]?,
        excludedBrands: [String]?
    ) async throws -> Rees46.SearchInstantResponse

    /// The page of results (`GET search`, `full_search`). `query` is not empty.
    func full(
        query: String,
        request: Rees46.SearchFullRequest,
        completion: @escaping (Result<Rees46.SearchFullResponse, Rees46.SdkError>) -> Void
    )

    func full(query: String, request: Rees46.SearchFullRequest) async throws -> Rees46.SearchFullResponse
}

/// The arguments by default: protocol requirements cannot carry them.
@_spi(Bridge)
extension SearchAPI {

    public func instant(
        query: String,
        locations: [String]? = nil,
        excludedMerchants: [String]? = nil,
        excludedBrands: [String]? = nil,
        completion: @escaping (Result<Rees46.SearchInstantResponse, Rees46.SdkError>) -> Void
    ) {
        instant(query: query, locations: locations, excludedMerchants: excludedMerchants, excludedBrands: excludedBrands, completion: completion)
    }

    public func instant(
        query: String,
        locations: [String]? = nil,
        excludedMerchants: [String]? = nil,
        excludedBrands: [String]? = nil
    ) async throws -> Rees46.SearchInstantResponse {
        try await instant(query: query, locations: locations, excludedMerchants: excludedMerchants, excludedBrands: excludedBrands)
    }

    /// The first page of results without filters.
    public func full(query: String, completion: @escaping (Result<Rees46.SearchFullResponse, Rees46.SdkError>) -> Void) {
        full(query: query, request: Rees46.SearchFullRequest(), completion: completion)
    }

    /// The first page of results without filters.
    public func full(query: String) async throws -> Rees46.SearchFullResponse {
        try await full(query: query, request: Rees46.SearchFullRequest())
    }
}

@_spi(Bridge)
extension PersonalizationSDK {

    /// Search in the shop's catalog (`SearchAPI`): on the new core only.
    public var search: SearchAPI {
        SearchAPIImpl(requests: NamespaceRequests(self))
    }
}
