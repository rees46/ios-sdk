import Foundation
import UIKit

struct CarouselConstants {
    static let leftDistanceToView: CGFloat = 40 //55
    static let rightDistanceToView: CGFloat = 40
    static let carouselMinimumLineSpacing: CGFloat = 10
    static let carouselItemWidth = (UIScreen.main.bounds.width - CarouselConstants.leftDistanceToView - CarouselConstants.rightDistanceToView - (CarouselConstants.carouselMinimumLineSpacing / 2)) / 1.65
}
