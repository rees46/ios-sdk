import UIKit
import Foundation

public struct RecommendationsConstants {
    static let recommendationsLeftDistanceToView: CGFloat = 20
    static let recommendationsRightDistanceToView: CGFloat = 20
    static let recommendationsCollectionMinimumLineSpacing: CGFloat = 10
    
    static let recommendationsCollectionItemWidth = (UIScreen.main.bounds.width - RecommendationsConstants.recommendationsLeftDistanceToView - RecommendationsConstants.recommendationsRightDistanceToView - (RecommendationsConstants.recommendationsCollectionMinimumLineSpacing / 2)) / 1.65
}
