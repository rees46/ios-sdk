import UIKit
import Foundation

class TextBlockView: UIView {
    
    let textBlockObject: StoriesElement
    
    private let label: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(textBlockObject: StoriesElement) {
        self.textBlockObject = textBlockObject
        super.init(frame: .zero)
        setupView()
        
        let fontType = textBlockObject.fontType ?? .unknown
        let fontSize = textBlockObject.fontSize ?? 14
        let fontMap: [FontType: String] = [
            .monospaced: "Menlo",
            .serif: "Georgia",
            .sansSerif: "Arial",
            .unknown: "Helvetica-Neue"
        ]
        
        let fontName = fontMap[fontType] ?? "Helvetica-Neue"
        var fontDescriptor = UIFontDescriptor(name: fontName, size: fontSize)
        
        if textBlockObject.textBold == true {
            fontDescriptor = fontDescriptor.withSymbolicTraits(.traitBold) ?? fontDescriptor
        }
        
        if textBlockObject.textItalic == true {
            fontDescriptor = fontDescriptor.withSymbolicTraits(.traitItalic) ?? fontDescriptor
        }
        
        label.font = UIFont(descriptor: fontDescriptor, size: fontSize)
        print(label.font.fontName)
        
        
        label.textColor = textBlockObject.textColor
        self.layer.cornerRadius = 5
        self.clipsToBounds = true
        self.backgroundColor = textBlockObject.textBackgroundColor
        label.textAlignment = {
            switch textBlockObject.textAlignment {
            case "left":
                return .left
            case "right":
                return .right
            case "center":
                return .center
            default:
                return .left
            }
        }()
        
        if let textLineSpacing = textBlockObject.textLineSpacing {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = textLineSpacing
            let attributedText = NSAttributedString(string: textBlockObject.textInput ?? "", attributes: [NSAttributedString.Key.paragraphStyle: paragraphStyle])
            label.attributedText = attributedText
        } else {
            label.text = textBlockObject.textInput
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5)
        ])
    }
}
