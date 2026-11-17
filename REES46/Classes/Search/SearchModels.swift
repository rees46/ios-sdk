//
//  SearchModels.swift
//  REES46
//
//  The models of the `search` namespace (`sdk/contract/search.md`). Nested in the facade, as the
//  catalog's are: the released `SearchBlankResponse`, `Query` and `PopularItem` stay as the old methods
//  return them.
//

import Foundation

@_spi(Bridge)
extension Rees46 {

    /// The filters, sorting and page of `search.full`.
    ///
    /// Lists go as one value joined by `,`, an empty one as none. `limit`, `page`, `categoryLimit` and
    /// `brandLimit` start at 1, a price is not negative and `priceMin` not above `priceMax`: otherwise
    /// the call is `invalidArgument` and sends nothing.
    public struct SearchFullRequest: Equatable {
        public var categoryIds: [String]?
        public var brands: [String]?
        public var excludedBrands: [String]?
        /// For marketplaces.
        public var merchants: [String]?
        /// For marketplaces; sent only with `locations`: the server looks for the merchants inside them,
        /// and without any it finds no product.
        public var excludedMerchants: [String]?
        public var locations: [String]?
        public var priceMin: Double?
        public var priceMax: Double?
        public var colors: [String]?
        public var fashionSizes: [String]?
        /// Products to leave out: the ones in the cart, say.
        public var excludedItemIds: [String]?
        /// A parameter of the products → its values; sent as JSON.
        public var filters: [String: [String]]?
        public var sortBy: SortBy?
        public var sortDir: SortDirection?
        /// Turns the clarifying search off.
        public var disableClarification: Bool
        /// How many categories the facet has.
        public var categoryLimit: Int?
        /// How many brands the facet has; 1000 by default.
        public var brandLimit: Int?
        public var limit: Int?
        public var page: Int?

        public init(
            categoryIds: [String]? = nil,
            brands: [String]? = nil,
            excludedBrands: [String]? = nil,
            merchants: [String]? = nil,
            excludedMerchants: [String]? = nil,
            locations: [String]? = nil,
            priceMin: Double? = nil,
            priceMax: Double? = nil,
            colors: [String]? = nil,
            fashionSizes: [String]? = nil,
            excludedItemIds: [String]? = nil,
            filters: [String: [String]]? = nil,
            sortBy: SortBy? = nil,
            sortDir: SortDirection? = nil,
            disableClarification: Bool = false,
            categoryLimit: Int? = nil,
            brandLimit: Int? = nil,
            limit: Int? = nil,
            page: Int? = nil
        ) {
            self.categoryIds = categoryIds
            self.brands = brands
            self.excludedBrands = excludedBrands
            self.merchants = merchants
            self.excludedMerchants = excludedMerchants
            self.locations = locations
            self.priceMin = priceMin
            self.priceMax = priceMax
            self.colors = colors
            self.fashionSizes = fashionSizes
            self.excludedItemIds = excludedItemIds
            self.filters = filters
            self.sortBy = sortBy
            self.sortDir = sortDir
            self.disableClarification = disableClarification
            self.categoryLimit = categoryLimit
            self.brandLimit = brandLimit
            self.limit = limit
            self.page = page
        }
    }

    /// What an empty search field shows.
    public struct SearchBlankResponse: Equatable {
        /// The products the customer viewed last (`lastProducts`), or popular ones.
        public let products: [Product]?
        /// Whether `products` are the ones the customer viewed last; missing is `false`.
        public let lastProducts: Bool
        public let lastQueries: [Query]?
        public let suggests: [Query]?
        public let popularCategories: [PopularItem]?
        public let popularBrands: [PopularItem]?
        public let popularLinks: [PopularItem]?
    }

    /// The products and hints while the customer types.
    public struct SearchInstantResponse: Equatable {
        /// The query after the layout and typos were fixed.
        public let searchQuery: String?
        public let searchQueryOriginal: String?
        /// Whether the clarifying search worked.
        public let clarification: Bool?
        public let productsTotal: Int?
        public let products: [Product]
        public let categories: [ProductCategory]?
        /// Hints of queries.
        public let queries: [Query]?
        public let locations: [Location]?
        /// The page the shop opens for this query instead of results.
        public let redirect: SearchRedirect?
    }

    /// The page of results.
    public struct SearchFullResponse: Equatable {
        public let searchQuery: String?
        public let searchQueryOriginal: String?
        public let clarification: Bool?
        public let productsTotal: Int?
        public let products: [Product]
        public let categories: [ProductCategory]?
        public let brands: [Brand]?
        public let locations: [Location]?
        /// The name of a parameter → its facet.
        public let filters: [String: SearchFilter]?
        public let industrialFilters: IndustrialFilters?
        public let priceRange: PriceRange?
        public let priceRanges: [PriceInterval]?
        public let priceMedian: Double?
    }

    /// A hint or a past query.
    public struct Query: Equatable {
        public let name: String
        /// The full search by it.
        public let url: String?
        /// Only in the hints of the instant search.
        public let score: Double?
    }

    /// A popular category, brand or link.
    public struct PopularItem: Equatable {
        public let name: String
        public let url: String?
    }

    /// A query for which the shop opens a page instead of results (`search_query_redirects`).
    public struct SearchRedirect: Equatable {
        public let query: String?
        /// `redirect_link`.
        public let url: String?
        /// `deep_link`.
        public let deeplink: String?
    }
}

// MARK: - Answers

extension Rees46.SearchBlankResponse: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        products = answer.models(Rees46.Product.self, "products")
        lastProducts = answer.lenientBool("last_products") ?? false
        lastQueries = answer.models(Rees46.Query.self, "last_queries")
        suggests = answer.models(Rees46.Query.self, "suggests")
        popularCategories = answer.models(Rees46.PopularItem.self, "popular_categories")
        popularBrands = answer.models(Rees46.PopularItem.self, "popular_brands")
        popularLinks = answer.models(Rees46.PopularItem.self, "popular_links")
    }
}

extension Rees46.SearchInstantResponse: AnswerReadable {

    /// Without a list of products it is not the search's answer (`decoding`).
    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        products = try answer.requiredModels(Rees46.Product.self, "products")
        searchQuery = answer.lenientString("search_query")
        searchQueryOriginal = answer.lenientString("search_query_original")
        clarification = answer.lenientBool("clarification")
        productsTotal = answer.lenientInt("products_total")
        categories = answer.models(Rees46.ProductCategory.self, "categories")
        queries = answer.models(Rees46.Query.self, "queries")
        locations = answer.models(Rees46.Location.self, "locations")
        redirect = answer.model(Rees46.SearchRedirect.self, "search_query_redirects")
    }
}

extension Rees46.SearchFullResponse: AnswerReadable {

    /// Without a list of products it is not the search's answer (`decoding`).
    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        products = try answer.requiredModels(Rees46.Product.self, "products")
        searchQuery = answer.lenientString("search_query")
        searchQueryOriginal = answer.lenientString("search_query_original")
        clarification = answer.lenientBool("clarification")
        productsTotal = answer.lenientInt("products_total")
        categories = answer.models(Rees46.ProductCategory.self, "categories")
        brands = answer.models(Rees46.Brand.self, "brands")
        locations = answer.models(Rees46.Location.self, "locations")
        filters = answer.modelMap(Rees46.SearchFilter.self, "filters")
        industrialFilters = answer.model(Rees46.IndustrialFilters.self, "industrial_filters")
        priceRange = answer.model(Rees46.PriceRange.self, "price_range")
        priceRanges = answer.models(Rees46.PriceInterval.self, "price_ranges")
        priceMedian = answer.lenientDouble("price_median")
    }
}

extension Rees46.Query: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        name = try answer.requiredString("name")
        url = answer.lenientString("url")
        score = answer.lenientDouble("score")
    }
}

extension Rees46.PopularItem: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        name = try answer.requiredString("name")
        url = answer.lenientString("url")
    }
}

extension Rees46.SearchRedirect: AnswerReadable {

    init(answer: KeyedDecodingContainer<AnswerKey>) throws {
        query = answer.lenientString("query")
        url = answer.lenientString("redirect_link")
        deeplink = answer.lenientString("deep_link")
    }
}
