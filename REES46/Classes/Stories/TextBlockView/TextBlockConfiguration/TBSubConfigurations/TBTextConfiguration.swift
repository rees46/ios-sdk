import Foundation
import UIKit

protocol TBTextConfigurable {
    var text: NSAttributedString { get }
    var textAlignment: NSTextAlignment { get }
}

public struct TBTextConfiguration: TBTextConfigurable {
    let text: NSAttributedString
    let textAlignment: NSTextAlignment
    
    init(from textBlockObject: StoriesElement) {
        if let textLineSpacing = textBlockObject.textLineSpacing,
           let textBlockInput = textBlockObject.textInput {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = textLineSpacing
            self.text = NSAttributedString(string: textBlockInput, attributes: [NSAttributedString.Key.paragraphStyle: paragraphStyle])
        } else {
            self.text = NSAttributedString(string: textBlockObject.textInput ?? "")
        }
        
        self.textAlignment = {
            switch textBlockObject.textAlignment {
            case .left:
                return .left
            case .right:
                return .right
            case .center:
                return .center
            default:
                return .left
            }
        }()
    }
}
