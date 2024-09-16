import UIKit

public protocol RecommendationsWidgetCommunicationProtocol: AnyObject {
    func addToCartProductData(product: Recommended)
    func addToFavoritesProductData(product: Recommended)
    func didTapOnProduct(product: Recommended)
}
