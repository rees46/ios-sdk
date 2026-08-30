import Foundation
import UIKit

/**
 Legacy transport for the standard tracking events, reached through the deprecated
 `PersonalizationSDK.track(event:recommendedBy:completion:)`.

 Frozen on purpose: the cases keep the exact shape they shipped with. Adding an associated value here
 would compile for anyone *constructing* a case but break every host that *pattern-matches* one
 (`case let .slideView(storyId, slideId)` stops compiling once a third value appears). The richer
 payloads the `tracking` namespace sends — a cart line's price, the ids a search returned, an explicit
 stories block code — travel next to the event in the internal ``TrackEventDetails`` instead.
 */
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
    @available(*, deprecated, message: "Use PersonalizationSDK.trackPurchase(_:recommendedBy:completion:) with PurchaseTrackingRequest.")
    case orderCreated(orderId: String, totalValue: Double, products: [(id: String, amount: Int, price: Float)], deliveryAddress: String? = nil, deliveryType: String? = nil, promocode: String? = nil, paymentType: String? = nil, taxFree: Bool? = nil)
}
