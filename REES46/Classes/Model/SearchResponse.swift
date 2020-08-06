//
//  SearchResponse.swift
//  FBSnapshotTestCase
//
//  Created by Арсений Дорогин on 31.07.2020.
//

import Foundation

public struct SearchResponse {
    // TODO
    var categories: [Category]
    var products: [Product]
    var productsTotal: Int
    var queries: [Query]
    
    init(json: [String: Any]) {
        let cats = json["categories"] as! [[String:Any]]
        var catsTemp = [Category]()
        for item in cats{
            catsTemp.append(Category(json: item))
        }
        self.categories = catsTemp
        
        let prods = json["products"] as! [[String:Any]]
        var prodsTemp = [Product]()
        for item in prods{
            prodsTemp.append(Product(json: item))
        }
        self.products = prodsTemp
        
        let quers = json["queries"] as! [[String:Any]]
        var quersTemp = [Query]()
        for item in quers{
            quersTemp.append(Query(json: item))
        }
        self.queries = quersTemp
        
        self.productsTotal = json["products_total"] as! Int
    }
}

public struct Product {
    var brand: String
    var id: String
    var name: String
    var oldPrice: Double
    var picture: String
    var price: Double
    var priceFormatted: String
    var url: String
    
    init(json: [String: Any]) {
        self.brand = json["brand"] as! String
        self.id = json["id"] as! String
        self.name = json["name"] as! String
        self.oldPrice = json["old_price"] as! Double
        self.picture = json["picture"] as! String
        self.price = json["price"] as! Double
        self.priceFormatted = json["price_formatted"] as! String
        self.url = json["url"] as! String
    }
}

public struct Query {
    
    var name: String
    var url: String
    
    init(json: [String: Any]) {
        self.name = json["name"] as! String
        self.url = json["url"] as! String
    }
}

public struct Category {
    var id: String
    var name: String
    var url: String
    
    
    init(json: [String: Any]) {
        self.id = json["id"] as! String
        self.name = json["name"] as! String
        self.url = json["url"] as! String
    }
}
