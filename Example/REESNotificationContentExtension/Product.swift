//
//  Product.swift
//  REESNotificationContentExtension
//
//  Created by Арсений Дорогин on 06.01.2021.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import Foundation


struct Product {
    var deepUrl: String = ""
    var price: String = ""
    var oldPrice: String? = nil
    var name: String = ""
    var imageUrl: String = ""
    
    init(json: [String: Any]) {
        self.deepUrl = json["uri"] as? String ?? ""
        self.price = json["price"] as? String ?? ""
        self.oldPrice = json["old_price"] as? String
        self.name = json["name"] as? String ?? ""
        self.imageUrl = json["image_url"] as? String ?? ""
    }
}
