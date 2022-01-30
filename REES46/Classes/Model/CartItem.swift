//
//  CartItem.swift
//  REES46
//
//  Created by Arseniy Dorogin on 30.01.2022.
//

import Foundation

public struct CartItem {
    var id: String
    var quanity: Int = 1
    
    public init(id: String, quanity: Int = 1) {
        self.id = id
        self.quanity = quanity
    }
}
