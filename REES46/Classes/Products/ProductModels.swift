//
//  ProductModels.swift
//  REES46
//
//  The catalog's models of the contract (`sdk/contract/products.md`): the product of every answer, its
//  categories and parameters, the facets of a listing and the requests of `products`. `collections`,
//  `recommendations` and `search` use them too.
//
//  Nested in the facade, as `Rees46.SdkError` is: the released top-level `Product`, `Category`,
//  `ProductsListResponse` and the rest stay as the old methods return them. A field the answer does not
//  have is `nil`, never an empty string or 0, unless the model says otherwise.
//

import Foundation

@_spi(Bridge)
extension Rees46 {

    /// A product in every answer of the catalog: the card, a listing, a category, a collection,
    /// recommendations, search.
    ///
    /// `id`, `name`, `url`, `price` and `currency` are always there: a product without one of them is left
    /// out of its answer. The other fields are `nil` when the answer does not have them, and so is an
    /// empty text.
    public struct Product: Equatable {
        /// `id`; `uniqid` in the answer of `products.getInfo` when it has one: the shop's own id.
        public let id: String
        /// `group_id`: the group of the product's variants. The server gives a product without a group
        /// a value of its own, `_<id>_`.
        public let groupId: String?
        public let name: String
        public let brand: String?
        public let model: String?
        public let description: String?
        public let barcode: String?
        public let url: String
        public let deeplinkAndroid: String?
        public let deeplinkIos: String?
        /// `image_url`: the original image.
        public let imageUrl: String?
        /// `picture`: the image at the answer's size.
        public let picture: String?
        /// `image_url_resized`: the image by size, `"120"` … `"520"` and `"original"`.
        public let resizedImages: [String: String]?
        public let price: Double
        public let priceFormatted: String?
        /// `price_full`: the price with its fraction.
        public let priceFull: Double?
        public let priceFullFormatted: String?
        /// `oldprice`; `nil` when the product has none — the server's 0 too.
        public let oldPrice: Double?
        public let oldPriceFormatted: String?
        /// `oldprice_full`; `nil` when the product has none — the server's 0 too.
        public let oldPriceFull: Double?
        public let oldPriceFullFormatted: String?
        public let currency: String
        /// `discount_percent`, else `discount` when it is a number: in the card it is a flag.
        public let discountPercent: Int?
        public let discountFormatted: String?
        public let salesRate: Int?
        public let relativeSalesRate: Double?
        /// The server sends it only when it is not 0.
        public let rating: Int?
        /// The server sends `is_new` only when it is true: missing is `false`.
        public let isNew: Bool
        public let stockQuantity: Int?
        public let categoryIds: [String]?
        public let categories: [ProductCategory]?
        public let params: [ProductParam]?
        /// `location_ids`, with `RecommendationRequest.withLocations`: where the product is in stock, or
        /// `["global"]`.
        public let locationIds: [String]?
    }

    /// A category of a product, and a category of the facets of a listing or a search.
    public struct ProductCategory: Equatable {
        public let id: String
        public let name: String?
        public let url: String?
        /// `parent_id`; `parent` in the facets.
        public let parentId: String?
        /// The depth from the root; only in a product's categories.
        public let level: Int?
        /// How many products were found in it; only in the facets.
        public let count: Int?
        /// Only in the facets.
        public let alias: String?
    }

    /// A parameter of a product from the shop's feed: its key and values, numbers as strings.
    public struct ProductParam: Equatable {
        public let key: String
        public let values: [String]
    }

    /// A location of the shop: a store, a city.
    public struct Location: Equatable {
        public let id: String
        public let name: String
        public let type: String?
    }

    /// A brand in the facets, with how many products were found of it.
    public struct Brand: Equatable {
        public let name: String
        public let count: Int
    }

    /// A facet: one parameter of the products in a sidebar of filters. A list facet has `values`, a
    /// numeric one `min` and `max`.
    public struct SearchFilter: Equatable {
        /// How many products have the parameter.
        public let count: Int?
        /// The order of the facets.
        public let priority: Int?
        /// Value → how many products have it.
        public let values: [String: Int]?
        /// `ranges.min`.
        public let min: Double?
        /// `ranges.max`.
        public let max: Double?
    }

    /// The facets of colors and sizes; only in search.
    public struct IndustrialFilters: Equatable {
        public let colors: [ColorFilter]?
        public let fashionSizes: [SizeFilter]?
    }

    public struct ColorFilter: Equatable {
        public let color: String
        public let count: Int
    }

    public struct SizeFilter: Equatable {
        public let size: String
        public let count: Int
    }

    /// The lowest and highest price of the products found.
    public struct PriceRange: Equatable {
        public let min: Double
        public let max: Double
    }

    /// One interval of prices with how many products are in it.
    public struct PriceInterval: Equatable {
        /// 0 when the answer has none.
        public let from: Double
        /// `nil`: no upper bound.
        public let to: Double?
        public let count: Int?
    }

    /// The products of the catalog by filters (`products.getList`).
    public struct ProductsListResponse: Equatable {
        public let productsTotal: Int?
        public let products: [Product]
        public let categories: [ProductCategory]?
        public let brands: [Brand]?
        public let locations: [Location]?
        /// The name of a parameter → its facet.
        public let filters: [String: SearchFilter]?
        /// Only search has it: `/products` does not send it.
        public let industrialFilters: IndustrialFilters?
        public let priceRange: PriceRange?
        public let priceRanges: [PriceInterval]?
        public let priceMedian: Double?
    }

    /// The products of a category with its facets (`products.getCategory`).
    public struct CategoryResponse: Equatable {
        public let productsTotal: Int?
        public let products: [Product]
        public let categories: [ProductCategory]?
        public let brands: [Brand]?
        /// The name of a parameter → its facet.
        public let filters: [String: SearchFilter]?
        public let priceRange: PriceRange?
        public let priceRanges: [PriceInterval]?
        public let priceMedian: Double?
    }

    /// What a listing is sorted by. An open set: a key the server adds goes as it is, with no new
    /// version of the SDK.
    public struct SortBy: RawRepresentable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let price = SortBy(rawValue: "price")
        public static let discount = SortBy(rawValue: "discount")
        public static let salesRate = SortBy(rawValue: "sales_rate")
        public static let date = SortBy(rawValue: "date")
        public static let priceMargin = SortBy(rawValue: "price_margin")
        /// The server applies it only together with another key, which the contract does not send yet.
        public static let rating = SortBy(rawValue: "rating")
        /// Only `search.full`: a listing refuses it (`invalidArgument`).
        public static let relevance = SortBy(rawValue: "relevance")
    }

    /// The direction of the sorting; the server sorts in descending order without one.
    public enum SortDirection: String {
        case asc
        case desc
    }

    /// The filters, sorting and page of `products.getList`; without any, the first page of the whole
    /// catalog.
    ///
    /// Lists go as one value joined by `,`, an empty one as none. `limit` and `page` start at 1, a price
    /// is not negative and `priceMin` not above `priceMax`: otherwise the call is `invalidArgument` and
    /// sends nothing. The server drops the fraction of a price.
    public struct ProductsListRequest: Equatable {
        public var categoryIds: [String]?
        public var brands: [String]?
        /// For marketplaces.
        public var merchants: [String]?
        /// Products in stock in these locations.
        public var locations: [String]?
        public var priceMin: Double?
        public var priceMax: Double?
        /// A parameter of the products → its values; sent as JSON.
        public var filters: [String: [String]]?
        /// Not `relevance`.
        public var sortBy: SortBy?
        public var sortDir: SortDirection?
        public var limit: Int?
        public var page: Int?

        public init(
            categoryIds: [String]? = nil,
            brands: [String]? = nil,
            merchants: [String]? = nil,
            locations: [String]? = nil,
            priceMin: Double? = nil,
            priceMax: Double? = nil,
            filters: [String: [String]]? = nil,
            sortBy: SortBy? = nil,
            sortDir: SortDirection? = nil,
            limit: Int? = nil,
            page: Int? = nil
        ) {
            self.categoryIds = categoryIds
            self.brands = brands
            self.merchants = merchants
            self.locations = locations
            self.priceMin = priceMin
            self.priceMax = priceMax
            self.filters = filters
            self.sortBy = sortBy
            self.sortDir = sortDir
            self.limit = limit
            self.page = page
        }
    }

    /// The filters, sorting and page of `products.getCategory`, by the rules of `ProductsListRequest`.
    public struct CategoryRequest: Equatable {
        public var brands: [String]?
        public var locations: [String]?
        /// A parameter of the products → its values; sent as JSON.
        public var filters: [String: [String]]?
        public var priceMin: Double?
        public var priceMax: Double?
        /// Not `relevance`.
        public var sortBy: SortBy?
        public var sortDir: SortDirection?
        public var limit: Int?
        public var page: Int?

        public init(
            brands: [String]? = nil,
            locations: [String]? = nil,
            filters: [String: [String]]? = nil,
            priceMin: Double? = nil,
            priceMax: Double? = nil,
            sortBy: SortBy? = nil,
            sortDir: SortDirection? = nil,
            limit: Int? = nil,
            page: Int? = nil
        ) {
            self.brands = brands
            self.locations = locations
            self.filters = filters
            self.priceMin = priceMin
            self.priceMax = priceMax
            self.sortBy = sortBy
            self.sortDir = sortDir
            self.limit = limit
            self.page = page
        }
    }
}
