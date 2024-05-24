import UIKit
import Foundation

class TextBlockView: UIView {
    let yOffset: CGFloat
    
    private let label: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(with textBlockConfiguration: TextBlockConfiguration) {
        self.yOffset = textBlockConfiguration.appearanceConfiguration.yOffset
        super.init(frame: .zero)
        configureLabel(with: textBlockConfiguration)
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
    
    private func configureLabel(with config: TextBlockConfiguration) {
        label.font = config.fontConfiguration.font
        label.textColor = config.appearanceConfiguration.textColor
        self.layer.cornerRadius = config.appearanceConfiguration.cornerRadius
        self.clipsToBounds = config.appearanceConfiguration.clipsToBounds
        self.backgroundColor = config.appearanceConfiguration.backgroundColor
        label.attributedText = config.textConfiguration.text
        label.textAlignment = config.textConfiguration.textAlignment
    }
    
    override func layoutSubviews() {
        setupView()
    }
}
