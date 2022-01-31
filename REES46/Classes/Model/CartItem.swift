//
//  CartItem.swift
//  REES46
//
//  Created by Arseniy Dorogin on 30.01.2022.
//

import Foundation

public struct CartItem {
    var productId: String
    var quantity: Int = 1
    
    public init(productId: String, quantity: Int = 1) {
        self.productId = productId
        self.quantity = quantity
    }
}
