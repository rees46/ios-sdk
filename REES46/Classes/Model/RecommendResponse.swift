//
//  RecommendResponse.swift
//  FBSnapshotTestCase
//
//  Created by Арсений Дорогин on 31.07.2020.
//

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
    public var name: String = ""
    public var brand: String = ""
    public var imageUrl: String = ""
    public var url: String = ""
    public var categories = [Category]()
    public var price: Double = 0
    public var oldPrice: String?
    public var currency: String = ""

    init(json: [String: Any]) {
        id = json["id"] as? String ?? ""
        name = json["name"] as? String ?? ""
        brand = json["brand"] as? String ?? ""
        imageUrl = json["image_url"] as? String ?? ""
        url = json["url"] as? String ?? ""
        let cats = json["categories"] as? [[String: Any]] ?? []
        var catsTemp = [Category]()
        for item in cats {
            catsTemp.append(Category(json: item))
        }
        categories = catsTemp
        price = json["price"] as? Double ?? 0
        oldPrice = json["oldprice"] as? String
        currency = json["currency"] as? String ?? ""
    }
}


public enum RecommendedByCase: String {
    case dynamic = "dynamic"
    case chain = "chain"
    case transactional = "transactional"
    case fullSearch = "full_search"
    case instantSearch = "instant_search"
    case digestMail = "digest_mail"
    case webPushDigest = "web_push_digest"
    case mobilePushBulk = "mobile_push_bulk"
    
    func getCodeField() -> String {
        switch self {
        case .digestMail:
            return "digest_mail_code"
        case .webPushDigest:
            return "web_push_digest_code"
        default:
            return "recommender_code"
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
