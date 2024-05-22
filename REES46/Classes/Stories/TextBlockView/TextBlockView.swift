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
            .unknown: ""
        ]
        
        var fontName = fontMap[fontType] ?? ""
        
        if textBlockObject.textBold == true && textBlockObject.textItalic == true {
            fontName += "-BoldItalic"
        } else if textBlockObject.textBold == true {
            fontName += "-Bold"
        } else if textBlockObject.textItalic == true {
            fontName += "-Italic"
        }
        
        label.font = UIFont(name: fontName, size: fontSize)
        label.textColor = UIColor(hexString:textBlockObject.textColor ?? "#000000")
        self.layer.cornerRadius = CGFloat(textBlockObject.cornerRadius)
        self.clipsToBounds = true
        self.backgroundColor = textBackgroundWithOpacity(from: textBlockObject)
        
        if let textLineSpacing = textBlockObject.textLineSpacing {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = textLineSpacing
            let attributedText = NSAttributedString(string: textBlockObject.textInput ?? "", attributes: [NSAttributedString.Key.paragraphStyle: paragraphStyle])
            label.attributedText = attributedText
        } else {
            label.text = textBlockObject.textInput
        }
        
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
    
    private func textBackgroundWithOpacity(from textBlockObject: StoriesElement) -> UIColor {
        guard let opacityString = textBlockObject.textBackgroundColorOpacity,
              let opacityValue = extractOpacity(from: opacityString) else {
            return UIColor(hexString: textBlockObject.textBackgroundColor ?? "") }
        
        let color = UIColor(hexString: textBlockObject.textBackgroundColor ?? "").withAlphaComponent(opacityValue)
        
        return color.withAlphaComponent(opacityValue)
    }
    
    private func extractOpacity(from opacityString: String) -> CGFloat? {
        let percentageString = opacityString.trimmingCharacters(in: CharacterSet(charactersIn: "%"))
        if let percentage = Double(percentageString) {
            return CGFloat(percentage) / 100.0
        }
        return nil
    }
}
