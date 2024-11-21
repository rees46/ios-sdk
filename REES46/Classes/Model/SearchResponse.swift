import Foundation

public struct Filter {
    public var count: Int
    public var values: [String: Int]
    
    init(json: [String: Any]) {
        self.count = json["count"] as? Int ?? 0
        self.values = json["values"] as? [String: Int] ?? [:]
    }
}

public struct IndustrialFilters {
    public var fashionSizes: [FashionSizes]
    public var fashionColors: [FashionColors]

    init(json: [String: Any]) {
        let sizes = json["fashion_sizes"] as? [[String: Any]] ?? []
        var fashionSizesTemp = [FashionSizes]()
        for item in sizes {
            fashionSizesTemp.append(FashionSizes(json: item))
        }
        fashionSizes = fashionSizesTemp
        
        let colors = json["colors"] as? [[String: Any]] ?? []
        var fashionColorsTemp = [FashionColors]()
        for item in colors {
            fashionColorsTemp.append(FashionColors(json: item))
        }
        fashionColors = fashionColorsTemp
    }
}

public struct FashionSizes {
    public var count: Int
    public var size: String
    
    init(json: [String: Any]) {
        self.count = json["count"] as? Int  ?? 0
        self.size = json["size"] as? String ?? ""
    }
}

public struct FashionColors {
    public var count: Int
    public var color: String
    
    init(json: [String: Any]) {
        self.count = json["count"] as? Int ?? 0
        self.color = json["color"] as? String ?? ""
    }
}

public struct PriceRange {
    public var min: Double
    public var max: Double
    
    init(json: [String: Any]) {
        self.min = json["min"] as? Double ?? 0
        self.max = json["max"] as? Double ?? 0
    }
}

public struct Suggest {
    public var name: String
    public var url: String
    public var deeplinkIos: String
    
    init(json: [String: Any]) {
        self.name = json["name"] as? String ?? ""
        self.url = json["url"] as? String ?? ""
        self.deeplinkIos = json["deeplink_ios"] as? String ?? ""
    }
}

public struct SearchBlankResponse {
    public var lastQueries: [Query]
    public var suggests: [Suggest]
    public var lastProducts: Bool
    public var products: [Product]
    
    init(json: [String: Any]) {
        let lastQueriesTemp = json["last_queries"] as? [[String: Any]] ?? []
        var quyArr = [Query]()
        for item in lastQueriesTemp {
            quyArr.append(Query(json: item))
        }
        lastQueries = quyArr
        
        let suggestsTemp = json["suggests"] as? [[String: Any]] ?? []
        var sugArr = [Suggest]()
        for item in suggestsTemp {
            sugArr.append(Suggest(json: item))
        }
        suggests = sugArr
        
        lastProducts = json["last_products"] as? Bool ?? true
        
        let productsTemp = json["products"] as? [[String: Any]] ?? []
        var productArr = [Product]()
        for item in productsTemp {
            productArr.append(Product(json: item))
        }
        products = productArr
    }
}

public struct Redirect {
    public var query: String = ""
    public var redirectUrl: String = ""
    public var deeplink: String?
    public var deeplinkIos: String?
    
    init(json: [String: Any]) {
        self.query = json["query"] as? String ?? ""
        self.redirectUrl = json["redirect_link"] as? String ?? ""
        self.deeplink = json["deep_link"] as? String
        self.deeplinkIos = json["deeplink_ios"] as? String
    }
}

public struct SearchResponse {
    public var categories: [Category]
    public var products: [Product]
    public var productsTotal: Int
    public var queries: [Query]
    public var filters: [String: Filter]?
    public var industrialFilters: IndustrialFilters?
    public var brands: [String]?
    public var priceRange: PriceRange?
    public var redirect: Redirect?

    init(json: [String: Any]) {
        let cats = json["categories"] as? [[String: Any]] ?? []
        var catsTemp = [Category]()
        for item in cats {
            catsTemp.append(Category(json: item))
        }
        categories = catsTemp

        let prods = json["products"] as? [[String: Any]] ?? []
        var prodsTemp = [Product]()
        for item in prods {
            prodsTemp.append(Product(json: item))
        }
        products = prodsTemp

        let quers = json["queries"] as? [[String: Any]] ?? []
        var quersTemp = [Query]()
        for item in quers {
            quersTemp.append(Query(json: item))
        }
        queries = quersTemp

        productsTotal = (json["products_total"] as? Int) ?? 0
        
        if let filtersJSON = json["filters"] as? [String: Any] {
            var filtersResult = [String: Filter]()
            for item in filtersJSON {
                if let dict = item.value as? [String: Any] {
                    filtersResult[item.key] = Filter(json: dict)
                }
            }
            self.filters = filtersResult
        }
        
        if let brandsJSON = json["brands"] as? [[String: Any]] {
            var brandsResult = [String]()
            for item in brandsJSON {
                if let name = item["name"] as? String {
                    brandsResult.append(name)
                }
            }
            self.brands = brandsResult
        }
        
        if let industrialFiltersJSON = json["industrial_filters"] as? [String: Any] {
            self.industrialFilters = IndustrialFilters(json: industrialFiltersJSON)
        }
        
        if let priceRangeJSON = json["price_range"] as? [String: Any] {
            self.priceRange = PriceRange(json: priceRangeJSON)
        }
        
        if let redirectJSON = json["search_query_redirects"] as? [String: Any] {
            self.redirect = Redirect(json: redirectJSON)
        }
    }
}

public struct Product {
    public var id: String = ""
    public var barcode: String = ""
    public var name: String = ""
    public var brand: String = ""
    public var model: String = ""
    public var description: String = ""
    public var imageUrl: String = ""
    public var resizedImageUrl: String = ""
    public var resizedImages: [String: String] = [:]
    public var url: String
    public var deeplinkIos: String

    public var price: Double
    public var priceFormatted: String
    public var priceFull: Double
    public var priceFullFormatted: String
    public var oldPrice: Double
    public var oldPriceFormatted: String
    public var oldPriceFull: Double
    public var oldPriceFullFormatted: String

    public var currency: String
    public var salesRate: Int = 0
    public var discount: Int = 0
    public var relativeSalesRate: Float = 0.0
    public var isNew: Bool?
    public var params: [[String: Any]]?
    
    init(json: [String: Any]) {
        id = json["id"] as? String ?? ""
        barcode = json["barcode"] as? String ?? ""
        name = json["name"] as? String ?? ""
        brand = json["brand"] as? String ?? ""
        model = json["model"] as? String ?? ""
        description = json["description"] as? String ?? ""
        imageUrl = json["image_url"] as? String ?? ""
        resizedImageUrl = json["picture"] as? String ?? ""
        resizedImages = json["image_url_resized"] as? [String: String] ?? [:]
        url = json["url"] as? String ?? ""
        deeplinkIos = json["deeplink_ios"] as? String ?? ""
        
        price = json["price"] as? Double ?? 0
        priceFormatted = json["price_formatted"] as? String ?? ""
        priceFull = json["price_full"] as? Double ?? 0
        priceFullFormatted = json["price_full_formatted"] as? String ?? ""
        oldPrice = json["oldprice"] as? Double ?? 0
        oldPriceFormatted = json["oldprice_formatted"] as? String ?? ""
        oldPriceFull = json["oldprice_full"] as? Double ?? 0
        oldPriceFullFormatted = json["oldprice_full_formatted"] as? String ?? ""
        currency = json["currency"] as? String ?? ""
        isNew = json["is_new"] as? Bool
        params = json["params"] as? [[String: Any]]
        
        discount = json["discount"] as? Int ?? 0
        salesRate = json["sales_rate"] as? Int ?? 0
        relativeSalesRate = json["relative_sales_rate"] as? Float ?? 0.0
    }
}

public struct Query {
    public var name: String
    public var url: String
    public var deeplinkIos: String

    init(json: [String: Any]) {
        name = json["name"] as? String ?? ""
        url = json["url"] as? String ?? ""
        deeplinkIos = json["deeplink_ios"] as? String ?? ""
    }
}

public struct Category {
    public var id: String = ""
    public var name: String = ""
    public var url: String?
    public var alias: String?
    public var parentId: String?
    public var count: Int?

    init(json: [String: Any]) {
        id = json["id"] as? String ?? ""
        name = json["name"] as? String ?? ""
        url = json["url"] as? String
        alias = json["alias"] as? String
        parentId = json["parent"] as? String
        count = json["count"] as? Int
    }
}

public struct Location {
    public var id: String = ""
    public var name: String = ""

    init(json: [String: Any]) {
        id = json["id"] as? String ?? ""
        name = json["name"] as? String ?? ""
    }
}
