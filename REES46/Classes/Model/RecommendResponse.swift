import Foundation

public struct RecommenderResponse {
    public var recommended: [Recommended] /// products  array
    public var title: String = "" ///title block recommendation

    init(json: [String: Any]) {
        let recs = json["recommends"] as? [[String: Any]] ?? []
        var recsTemp = [Recommended]()
        for item in recs {
            recsTemp.append(Recommended(json: item))
        }
        recommended = recsTemp
        title = (json["title"] as? String) ?? ""
    }
}

public struct Recommended {
    public var id: String = ""
    public var barcode: String = ""
    public var name: String = ""
    public var brand: String = ""
    public var model: String = ""
    public var description: String = ""
    public var imageUrl: String = ""
    public var resizedImageUrl: String = ""
    public var url: String = ""
    public var deeplinkIos: String = ""
    public var categories = [Category]()

    public var price: Double = 0
    public var priceFormatted: String?
    public var priceFull: Double = 0
    public var priceFullFormatted: String?
    public var oldPrice: Double = 0
    public var oldPriceFormatted: String?
    public var oldPriceFull: Double = 0
    public var oldPriceFullFormatted: String?

    public var currency: String = ""
    public var salesRate: Int = 0
    public var discount: Int = 0
    public var rating: Int = 0
    public var relativeSalesRate: Float = 0.0
    public var paramsRaw: [[String: Any]]?
    public var fashionOriginalSizes: [String] = []
    public var fashionSizes: [String] = []
    public var fashionColors: [String] = []
    public var resizedImages: [String: String] = [:]

    init(json: [String: Any]) {
        id = json["id"] as? String ?? ""
        barcode = json["barcode"] as? String ?? ""
        name = json["name"] as? String ?? ""
        brand = json["brand"] as? String ?? ""
        model = json["model"] as? String ?? ""
        description = json["description"] as? String ?? ""
        imageUrl = json["image_url"] as? String ?? ""
        resizedImageUrl = json["picture"] as? String ?? ""
        url = json["url"] as? String ?? ""
        deeplinkIos = json["deeplink_ios"] as? String ?? ""
        price = json["price"] as? Double ?? 0
        priceFormatted = json["price_formatted"] as? String
        priceFull = json["price_full"] as? Double ?? 0
        priceFullFormatted = json["price_full_formatted"] as? String
        oldPrice = json["oldprice"] as? Double ?? 0
        oldPriceFormatted = json["oldprice_formatted"] as? String
        oldPriceFull = json["oldprice_full"] as? Double ?? 0
        oldPriceFullFormatted = json["oldprice_full_formatted"] as? String
        currency = json["currency"] as? String ?? ""
        salesRate = json["sales_rate"] as? Int ?? 0
        relativeSalesRate = json["relative_sales_rate"] as? Float ?? 0.0
        discount = json["discount"] as? Int ?? 0
        rating = json["rating"] as? Int ?? 0
        resizedImages = json["image_url_resized"] as? [String: String] ?? [:]
        
        
        let cats = json["categories"] as? [[String: Any]] ?? []
        var catsTemp = [Category]()
        for item in cats {
            catsTemp.append(Category(json: item))
        }
        categories = catsTemp
        
        fashionOriginalSizes = json["fashion_original_sizes"] as? [String] ?? []
        fashionSizes = json["fashion_sizes"] as? [String] ?? []
        fashionColors = json["fashion_colors"] as? [String] ?? []
        
        // TODO: convert to objects
        paramsRaw = json["params"] as? [[String: Any]]
        
    }
}

public enum RecommendedByCase: String {
    case dynamic = "dynamic"
    case chain = "chain"
    case transactional = "transactional"
    case fullSearch = "full_search"
    case instantSearch = "instant_search"
    case bulk = "bulk"
    case webPushDigest = "web_push_digest"
    
    func getCodeField() -> String {
        switch self {
        case .webPushDigest:
            return "web_push_digest_code"
        default:
            return "recommended_code"
        }
    }
}

public class RecomendedBy {
    
    var code: String = ""
    var type: RecommendedByCase = .chain
    
    public init(type: RecommendedByCase, code: String) {
        self.type = type
        self.code = code
    }
    
    func getParams() -> [String: String] {
        let params = [
            "recommended_by": type.rawValue,
            "\(type.getCodeField())": code
        ]
        return params
    }
}
