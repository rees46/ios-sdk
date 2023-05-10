import Foundation

struct Product {
    var deepUrl: String = ""
    var price: String = ""
    var oldPrice: String?
    var name: String = ""
    var imageUrl: String = ""
    var id: String = ""

    init(json: [String: Any]) {
        deepUrl = json["url"] as? String ?? ""
        if let priceString = json["price"] as? String {
            price = priceString
        } else if let priceInt = json["price"] as? Int {
            price = String(priceInt)
        } else if let priceDouble = json["price"] as? Double {
            price = String(priceDouble)
        }
        if let priceString = json["oldprice"] as? String {
            oldPrice = priceString
        } else if let priceInt = json["oldprice"] as? Int {
            oldPrice = String(priceInt)
        } else if let priceDouble = json["oldprice"] as? Double {
            oldPrice = String(priceDouble)
        }
        name = json["name"] as? String ?? ""
        imageUrl = json["image_url"] as? String ?? ""
        id = json["uniqid"] as? String ?? ""
    }
}
