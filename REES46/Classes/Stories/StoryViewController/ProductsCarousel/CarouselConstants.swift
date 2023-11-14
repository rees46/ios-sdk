import Foundation
import UIKit

struct CarouselProductsConstants {
    static let cLeftDistanceToView: CGFloat = 40
    static let cRightDistanceToView: CGFloat = 40
    static let productCarouselMinimumLineSpacing: CGFloat = 10
    static let productCarouselItemWidth = (UIScreen.main.bounds.width - CarouselProductsConstants.cLeftDistanceToView - CarouselProductsConstants.cRightDistanceToView - (CarouselProductsConstants.productCarouselMinimumLineSpacing / 2)) / 1.65
    static let productCarouselItemSlimWidth = (UIScreen.main.bounds.width - CarouselProductsConstants.cLeftDistanceToView - CarouselProductsConstants.cRightDistanceToView - (CarouselProductsConstants.productCarouselMinimumLineSpacing / 2)) / 1.2
}
