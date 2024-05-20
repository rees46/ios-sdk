import Foundation
import UIKit

public struct CarouselProductsConstants {
    public static let cLeftDistanceToView: CGFloat = 40
    public static let cRightDistanceToView: CGFloat = 40
    
    public static let productCarouselMinimumLineSpacing: CGFloat = 10
    
    public static let carouselWidthCoefficient: CGFloat = 1.4 // 1.65
    public static let carouselSlimWidthCoefficient: CGFloat = 1.2
    
    public static let productCarouselItemWidth = (UIScreen.main.bounds.width - CarouselProductsConstants.cLeftDistanceToView - CarouselProductsConstants.cRightDistanceToView - (CarouselProductsConstants.productCarouselMinimumLineSpacing / 2)) / carouselWidthCoefficient
    
    public static let productCarouselItemSlimWidth = (UIScreen.main.bounds.width - CarouselProductsConstants.cLeftDistanceToView - CarouselProductsConstants.cRightDistanceToView - (CarouselProductsConstants.productCarouselMinimumLineSpacing / 2)) / carouselSlimWidthCoefficient
}
