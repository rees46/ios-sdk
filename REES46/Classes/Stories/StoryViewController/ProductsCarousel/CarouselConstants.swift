import Foundation
import UIKit

struct CarouselConstantsF {
    static let leftDistanceToView: CGFloat = 40
    static let rightDistanceToView: CGFloat = 40
    static let carouselMinimumLineSpacing: CGFloat = 10
    static let carouselItemWidth = (UIScreen.main.bounds.width - CarouselConstantsF.leftDistanceToView - CarouselConstantsF.rightDistanceToView - (CarouselConstantsF.carouselMinimumLineSpacing / 2)) / 1.65
    static let carouselItemSlowWidth = (UIScreen.main.bounds.width - CarouselConstantsF.leftDistanceToView - CarouselConstantsF.rightDistanceToView - (CarouselConstantsF.carouselMinimumLineSpacing / 2)) / 1.2
}
