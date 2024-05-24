import Foundation
import UIKit

public struct TextBlockConfiguration {
    let fontConfiguration: TBFontConfiguration
    let appearanceConfiguration: TBAppearanceConfigurable
    let textConfiguration: TBTextConfigurable
    
    init(from textBlockObject: StoriesElement) {
        self.fontConfiguration = TBFontConfiguration(from: textBlockObject)
        self.appearanceConfiguration = TBAppearanceConfiguration(from: textBlockObject)
        self.textConfiguration = TBTextConfiguration(from: textBlockObject)
    }
}
