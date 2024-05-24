import Foundation
import UIKit

public struct TBFontConfiguration {
    let font: UIFont
    
    init(from textBlockObject: StoriesElement) {
        let fontType = textBlockObject.fontType ?? .unknown
        let fontSize = textBlockObject.fontSize ?? UIFont.systemFontSize
        let isFontBold = textBlockObject.textBold ?? false
        let isFontItalic = textBlockObject.textItalic ?? false
        
        self.font = TBFontConfiguration.getFont(for: fontType,
                                              isBold: isFontBold,
                                              isItalic: isFontItalic,
                                              fontSize: fontSize)
    }
    
    private static func getFont(for fontType: FontType,
                                isBold: Bool = false,
                                isItalic: Bool = false,
                                fontSize: CGFloat) -> UIFont {
        let fontMap: [FontType: String] = [
            .monospaced: StoryTextBlockConstants.FontConstants.monospaced,
            .serif: StoryTextBlockConstants.FontConstants.serif,
            .sansSerif: StoryTextBlockConstants.FontConstants.sansSerif,
            .unknown: UIFont.systemFont(ofSize: fontSize).fontName
        ]
        
        var font: UIFont
        if let fontName = fontMap[fontType], !fontName.isEmpty {
            font = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        } else {
            font = UIFont.systemFont(ofSize: fontSize)
        }
        
        var symbolicTraits: UIFontDescriptor.SymbolicTraits = []
        if isBold {
            symbolicTraits.insert(.traitBold)
        }
        if isItalic {
            symbolicTraits.insert(.traitItalic)
        }
        
        if let descriptor = font.fontDescriptor.withSymbolicTraits(symbolicTraits) {
            font = UIFont(descriptor: descriptor, size: fontSize)
        }
        
        return font
    }
}
