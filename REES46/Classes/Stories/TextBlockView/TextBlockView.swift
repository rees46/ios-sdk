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
        
        configureLabel()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: StoryTextBlockConstants.topAnchorOffsetConstant),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: StoryTextBlockConstants.bottomAnchorOffsetConstant),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: StoryTextBlockConstants.leftAnchorOffsetConstant),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: StoryTextBlockConstants.rightAnchorOffsetConstant)
        ])
    }
    
    private func configureLabel() {
        let fontType = textBlockObject.fontType ?? .unknown
        let fontSize = textBlockObject.fontSize ?? UIFont.systemFontSize
        
        let font = SdkConfiguration.stories.getFont(
            for: fontType,
            isBold: textBlockObject.textBold ?? false,
            isItalic: textBlockObject.textItalic ?? false,
            fontSize: fontSize
        )
        
        label.font = font
        label.textColor = textBlockObject.textColor != nil
        ? UIColor(hexString: textBlockObject.textColor!)
        : .black
        
        self.layer.cornerRadius = CGFloat(textBlockObject.cornerRadius)
        self.clipsToBounds = true
        self.backgroundColor = textBlockObject.textBackgroundColor != nil
        ? UIColor(hexString: textBlockObject.textBackgroundColor!).withOpacity(from: textBlockObject.textBackgroundColorOpacity ?? "")
        : UIColor.clear
        
        if let textLineSpacing = textBlockObject.textLineSpacing,
           let textBlockInput = textBlockObject.textInput {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = textLineSpacing
            let attributedText = NSAttributedString(string: textBlockInput,
                                                    attributes: [NSAttributedString.Key.paragraphStyle: paragraphStyle])
            label.attributedText = attributedText
        } else {
            label.text = textBlockObject.textInput
        }
        
        label.textAlignment = {
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
    
    override func layoutSubviews() {
        setupView()
    }
}
