import Foundation
import UIKit

public enum Event {
    case productView (id: String)
    case categoryView (id: String)
    case productAddedToFavorites(id: String)
    case productRemovedFromFavorites(id: String)
    case productAddedToCart (id: String, amount: Int = 1)
    case productRemovedFromCart (id: String)
    case search (query: String)
    case synchronizeCart (items: [CartItem])
    case synchronizeFavorites(ids: [String])
    case slideView(storyId: String, slideId: String)
    case slideClick(storyId: String, slideId: String)
    case orderCreated(orderId: String, totalValue: Double, products: [(id: String, amount: Int, price: Float)], deliveryAddress: String? = nil, deliveryType: String? = nil, promocode: String? = nil, paymentType: String? = nil, taxFree: Bool? = nil)
}
